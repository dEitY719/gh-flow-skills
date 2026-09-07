# gh-flow:relay-merge — Push-Capability Probe

Step 2's branch point. The whole skill exists because the network path to
`upstream` is **asymmetric**: fetch works, push is proxy-blocked. But that
block is environment-specific and may not apply, so the skill must never
assume it — it probes first and only falls into relay mode on a *confirmed*
block. If push actually works, the correct answer is the SIMPLE PATH
(delegate to `gh-pr:create`), not relay.

## Why a real push, not `--dry-run` (incident: 2026-08-14, AgentToolbox)

The probe used to be `git push --dry-run`. On 2026-08-14, in the
AgentToolbox repo, that dry-run probe returned `RC=0` ("push would
succeed") three separate times, but a real (non-dry-run) push of the same
commits was blocked every time with `HTTP 403` (`RPC failed; HTTP 403 curl
22`) — a clean, consistent false negative, not a flaky one-off.

Root cause (best understanding): over git's smart-HTTP protocol,
`--dry-run` only performs the ref-negotiation exchange with the server
(roughly the `info/refs` GET-equivalent phase) — it does not POST any pack
data. This network's proxy block triggers specifically on that POST step
(the `git-receive-pack` request that carries the actual objects), which
`--dry-run` never reaches. So `--dry-run` cannot see the block that a real
push hits, and reports "push would succeed" on a path that is in fact
blocked.

**Fix: probe with a real (non-dry-run) push to a throwaway ref**, and
clean the ref up immediately on success. The tradeoff this accepts: on a
successful probe, a disposable branch exists on the destination remote for
the few seconds between the push and its delete-cleanup, in the (rare)
window where cleanup itself might also fail — see "Cleanup" below. That
side effect is judged acceptable because it is the *only* observable
consequence, it is self-correcting even in the failure case (the ref is
harmless, just needs a manual delete — reported, never silently dropped),
and it is far cheaper than the false-negative it replaces: a false
negative sends the user down the SIMPLE PATH, where the real push
(`gh-pr:create`) then fails anyway, and the user has to notice that, re-run this
skill, and wait for relay mode from scratch. A real-push probe eliminates
that whole extra round trip.

## The probe

`lib/relay.sh probe` owns the whole thing — the real push, the
classification, the retry, and the cleanup:

```bash
tmpdir=$(mktemp -d); trap 'rm -rf "$tmpdir"' EXIT
LOCAL=<PR head SHA or local branch>
bash "${CLAUDE_PLUGIN_ROOT}/skills/relay-merge/lib/relay.sh" probe "$REMOTE" "$LOCAL"
```

`$tmpdir` is created here — the earliest point it's needed — and reused
by every later step (patch generation, gist upload); no step re-creates it.

The probe pushes to a **throwaway ref name** (`refs/heads/relay-probe-<ts>-<pid>`)
— never a real branch, never a protected/default branch name — and pushes
it **for real**. This is a real network write.

## Classifying the result

| Exit | stdout | Meaning | Action |
|---|---|---|---|
| 0 | `blocked=no` | push succeeded, probe ref already deleted | **SIMPLE PATH** — delegate to `gh-pr:create`, stop |
| 0 | `blocked=yes` | a block signal matched | continue to Step 3 (relay) |
| 2 | — | inconclusive after the retry | **treat as not-blocked**, take the SIMPLE PATH |

Exit 2 defaults to not-blocked on purpose: relay mode has irreversible side
effects (public gists, a destination issue comment), so it must not trigger
on ambiguous evidence. If the subsequent `gh-pr:create` push then genuinely
fails, the user re-runs this skill and the now-consistent block is confirmed.

### Block signals (confirmed blocked)

Only these count as a definite block — the `RELAY_BLOCK_REGEX` the probe
matches against the git/curl error text, default:

- `HTTP 403` / `403 Forbidden`
- an HTML block-page marker
  (`block(ed)?|proxy|forbidden|corporate policy|access denied`)

Anything else — connection reset, timeout, DNS hiccup, `Could not resolve
host`, TLS errors — is **inconclusive**, not a confirmed block. Flaky
networks must not produce a false "blocked" positive that pushes the user
into the heavier relay flow unnecessarily.

## Cleanup on success (mandatory, not optional)

A successful probe leaves a `relay-probe-*` ref on the destination, so the
delete runs from an `EXIT`/`INT`/`TERM` **trap** inside `relay.sh` — it
fires even if the probe is interrupted, and the model cannot forget it. That
is why the cleanup lives in the script rather than in this prose.

On failure the trap retries the delete once after a short pause. If that
fails too it does **not** swallow it: the probe prints `leftover_ref=<ref>`
on stdout and a plain "please delete it manually" line on stderr. Surface
that in the Step 8 report (`references/report-template.md` → SIMPLE PATH
block) and continue anyway — the leftover ref blocks nothing functionally,
it is clutter that needs a human to clear.

## One retry with backoff

`relay.sh probe` owns this too: on an inconclusive result it waits
`RELAY_PROBE_BACKOFF` (default 3s) and re-probes exactly once, same real
push, same throwaway-ref discipline, before returning exit 2.

## SIMPLE PATH delegation

When push works, hand off to `gh-pr:create` (or an equivalent normal branch push
+ PR creation) for the destination remote and stop. Note in the Step 8
report that the simple path was used and relay mode was skipped. Do not
generate patches or create any gist.
