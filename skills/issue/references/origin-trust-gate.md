# gh-flow:issue — Step 1.5: Origin trust gate

`/gh-flow:issue` treats the issue body as its implementation spec and runs six
skills over it unattended. This gate asks the one question the chain never
asked before starting to edit: **who wrote this spec?** An issue authored by a
harness this family trusts starts implementing immediately; anything else has
to survive a validity review first, and a failed review stops the run before
Step 2.1 touches a file (dEitY719/gh-flow-skills#36).

## Where it runs — and where it must never run

```
Step 1     Parse Args + target binding (GH_HOST / TARGET_REPO / REMOTE)
Step 1.5   Exclude-label gate, then origin trust gate   <- here, and only here
Step 2     6x Skill() chain (zero-prose zone - untouched)
Step 3     Report
```

Step 1.5 is a standalone step **between** Step 1 and Step 2, never a substep
inside Step 2 (D-1, NF-3). A review step placed between two of Step 2's
`Skill()` calls emits prose there, and prose there is the exact trigger of the
early-stop failure mode the three guards in `references/critical-contract.md`
exist to prevent. This step ends before the first `Skill()` call, so its
output cannot land inside that zone.

## Escape hatch

`--trust-origin` skips this whole step — no fetch, no parse, no review — and
Step 2 starts as it did before the gate existed. It exists so an unattended
caller (a backlog of pre-#43 issues, every one of them unknown-origin) can be
unblocked by a human in one flag rather than issue by issue (F-8).
`gh-flow:waves` / `gh-flow:wave` have no pass-through for it: their workers hit
the gate, so such issues are run by hand with this flag. A `--trust-origin` run whose issue really does have a blocking
defect is a risk the human explicitly accepted: proceed, no warning.

## Exclude-label gate — runs first (dEitY719/gh-flow-skills#70)

Before the origin check, Step 1.5 asks a cheaper question: **is this issue
human-only work?** A label in the exclude set — default
`wontfix,not-implement,manual`, replaced wholesale by the comma-separated
`GH_FLOW_EXCLUDE_LABELS` (set-but-empty excludes nothing) — means no PR can
finish it (a runbook, another machine's local setup), so the chain must not
start. `gh-flow:wave` / `gh-flow:waves` apply the same gate before they spawn a
worktree; this is the backstop for a direct call and for anything that slips
past them. `TODO` is deliberately not in the default: in this family it is an
ordinary backlog label, and excluding it would empty every `/gh-flow:waves` run.

`--force-manual` skips this gate (and only this gate) — a human who calls
`/gh-flow:issue N --force-manual` has decided the issue is implementable after
all. Same shape as `--trust-origin`: `gh-flow:wave` / `gh-flow:waves` workers
have no pass-through for it.

```sh
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || case "<skill-base-dir>" in /*) CLAUDE_PLUGIN_ROOT=$(cd -P -- "<skill-base-dir>/../.." 2>/dev/null && pwd) ;; esac  # tier 2, agent-filled (#41)
if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ] ||
    [ ! -f "$CLAUDE_PLUGIN_ROOT/skills/issue/lib/manual-gate.sh" ]; then
    printf '[gh-flow:issue] cannot locate skills/issue/lib/manual-gate.sh under CLAUDE_PLUGIN_ROOT (%s). On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
        "${CLAUDE_PLUGIN_ROOT:-unset}" >&2
    exit 1                                   # broken gate: exit 1, not 2
fi
labels=$(GH_HOST="$TARGET_HOST" gh issue view <N> --repo "$TARGET_REPO" \
    --json labels --jq '.labels[].name' 2>/dev/null); rc=$?
printf '%s\n' "$labels" |
    sh "$CLAUDE_PLUGIN_ROOT/skills/issue/lib/manual-gate.sh" "$rc"
# -> "pass" | "excluded <label>" | "skip lookup-failed"
```

| Verdict | Action |
|---|---|
| `pass` | go on to the origin check below |
| `excluded <label>` | stop: zero edits, no comment, report `[BLOCK] Step 1.5: label gate  (excluded label: <label>)`, exit 2 |
| `skip lookup-failed` | stop the same way, reason `label lookup failed` — never fail-open (NF-1): starting a human-only issue costs more than one re-run |
| any, with `--force-manual` | gate skipped, report `[SKIP] Step 1.5: label gate  (--force-manual)` |

Matching is whole-name equality (`manual-later` is not `manual`), non-ASCII
names allowed; the header of `lib/manual-gate.sh` is the full contract and
`lib/manual-gate.selfcheck.sh` its proof. The label gate posts no comment: the
label itself already explains the skip to the next reader.

## Procedure

`<N>` is the issue number; `GH_HOST`/`TARGET_HOST`/`TARGET_REPO` are Step 1's
bindings. Every `gh` call stays host-and-repo pinned (dEitY719/dotfiles#1403).

**`--trust-origin` skips everything below** — do not run the locator and do not
issue the fetch, or the flag costs a `gh` round-trip per issue over exactly the
backlog it exists to unblock. Report the `[SKIP]` row and go straight to Step
2.1.

```sh
# Locate the gate: guard the variable, then prove the file. Never splice a
# default into that path -- the retired tier 4 (dEitY719/harness-skills#22)
# resolves against the current directory, and these skills run inside the
# repository under review, so a repo shipping its own copy of this script
# would get that copy executed (dEitY719/gh-flow-skills#27).
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || case "<skill-base-dir>" in /*) CLAUDE_PLUGIN_ROOT=$(cd -P -- "<skill-base-dir>/../.." 2>/dev/null && pwd) ;; esac  # tier 2, agent-filled (#41)
if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ] ||
    [ ! -f "$CLAUDE_PLUGIN_ROOT/skills/issue/lib/origin-trust-gate.sh" ]; then
    printf '[gh-flow:issue] cannot locate skills/issue/lib/origin-trust-gate.sh under CLAUDE_PLUGIN_ROOT (%s). On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
        "${CLAUDE_PLUGIN_ROOT:-unset}" >&2
    exit 1                                   # broken gate: exit 1, not 2
fi

# Fail-closed (NF-2): a body that cannot be read is an UNKNOWN origin, which
# is untrusted -- never a silent pass to the trusted path.
body=$(GH_HOST="$TARGET_HOST" gh issue view <N> --repo "$TARGET_REPO" \
    --json body --jq .body 2>/dev/null) || body=''

printf '%s\n' "$body" |
    sh "$CLAUDE_PLUGIN_ROOT/skills/issue/lib/origin-trust-gate.sh"
# -> "<harness> trusted"  or  "<harness> review"
```

**An empty `$body` is an automatic BLOCK, not a review.** Zero bytes is zero
information, and the review below cannot clear a spec it cannot read — the
"too little information to judge" arm applies immediately. Fetch failures
therefore fail closed twice over: `none` keeps them off the trusted path, and
an empty body keeps them off the PASS path.

The script prints `<harness> <verdict>` and exits 0 for both verdicts; it
parses, it does not decide the run. Format, trust-set override and parsing
edge cases are documented in its header, and
`lib/origin-trust-gate.selfcheck.sh` is the executable proof of each one.

**Trust set.** Default `claude codex`; override with the family-wide
`GH_TRUSTED_HARNESSES="claude codex ..."` (space-separated). The name is
shared with `gh-issue:*` on purpose — one trust set, one variable, configured
once per machine (dEitY719/gh-issue-skills#44 D-3). Setting it to the empty
string is an empty trust set: every issue takes the review path. An allow-list,
never a deny-list — a harness nobody has vetted must not become trusted just by
being new (D-5).

## Judgment table

| `ORIGIN_HARNESS` | Origin line | Action |
|---|---|---|
| `claude`, `codex` (or any member of `GH_TRUSTED_HARNESSES`) | present | proceed to Step 2.1 with no review (`[SKIP]`) |
| `opencode`, `hermes`, `agy`, any other value | present | validity review, then Step 2.1 only on PASS |
| `none` / empty capture | present | validity review (unknown = untrusted) |
| — | absent (pre-#43 issue) | validity review (unknown = untrusted) |
| any | fetch failed | validity review (NF-2 fail-closed) |
| any | any, with `--trust-origin` | gate skipped entirely (F-8) |

Unknown is untrusted in every row (D-2): the review is a read plus a judgment,
which is cheap, and it only ever stops a run when a real defect is found.

**What this gate is not.** The origin line is a self-declaration written into
the issue body by the tool that filed it — unsigned, unauthenticated, and
editable by anyone with write access to the issue. `Harness(claude)` typed by
hand reads exactly like the real thing. This gate manages the **quality
variance** between harnesses, which is the problem dEitY719/gh-flow-skills#36
describes; it is not an authorization boundary and must never be relied on as
one. Anyone who can edit the issue body can already rewrite the spec the chain
implements, so a forged origin line buys an attacker nothing they did not
already have — which is exactly why the checks below are the real protection
and the trust set is only a way to skip them for issues worth skipping.

## The review — six blocking checks, nothing else

Read the issue body against exactly these — the `$body` already captured in
Procedure, never a second `gh issue view` for the same bytes. This is a search
for reasons **not to start implementing**, not a code review and not a quality
opinion. Anything that is merely unclear, stylistic, or a matter of taste is
not a block.

1. **Self-contradiction.** Two requirements that cannot both hold, or a
   decision that negates its own requirement.
2. **Phantom references.** The spec presupposes a file, path, or symbol that
   does not exist in this repo (and the issue does not ask for it to be
   created).
3. **Unverifiable acceptance criteria.** No criterion that can be executed or
   observed — nothing that could distinguish done from not-done.
4. **Already done / duplicate.** The requirement is already implemented on the
   base branch, or another open issue owns the same change.
5. **Safety-contract violation.** The issue asks for something this family
   forbids: implementing on the default branch, dropping a `--repo` / `GH_HOST`
   pin, merging a PR from a skill that must not merge, editing a vendored tree.
6. **Oversized scope.** The work spans three or more components and needs to be
   split before anything can be implemented as one issue.

**PASS** — none of the six is violated. Proceed to Step 2.1; the report row is
owned by `references/report-template.md`.

**BLOCK** — one or more are violated, *or* the body carries too little
information to judge at all. Stop before Step 2.1. Do not guess a spec into
existence: a run started on a guess produces a branch, a commit, and a PR to
unwind (D-2, Error Cases).

The gate judges; it never edits the issue — rule and rationale live once, in
`references/constraints.md` (D-7).

## On BLOCK

1. **Stop before Step 2.1.** Zero files edited, zero commits, zero PRs.
2. **Comment on the issue** (NF-4, D-8) — soft-fail, so a failed post is one
   `[WARN]` line and never changes the verdict. An unattended caller leaves no
   terminal for a human to read; the card is where the reason has to live.

   ```sh
   GH_HOST="$TARGET_HOST" gh issue comment <N> --repo "$TARGET_REPO" \
       --body-file <file> || printf '[WARN] block comment failed (soft)\n'
   ```

3. **Print the block report** from `references/report-template.md` and
   **exit 2** — this family's code for a policy refusal, the same one the
   block-label guard uses. Exit 1 is reserved for a gate that is itself broken
   (the locator arm above), so a wrapper can tell "this issue was refused" from
   "this check could not run" (NF-1, D-6).
