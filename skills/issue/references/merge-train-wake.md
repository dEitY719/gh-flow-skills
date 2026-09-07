# gh-flow:issue — Wake the merge-train dispatcher (Step 2.4.1, dEitY719/dotfiles#1482)

Runs immediately after Step 2.4 (`gh-verify:review-all`) has been dispatched,
whenever Step 2.3 (`gh-pr:create`) produced a PR — regardless of whether Step 2.4
itself succeeded, soft-failed, or warned. It sits between Step 2.4 and Step
2.5 (`gh-resolve:conflict`). Mechanism: `lib/merge-train-wake.sh` — its own
header documents usage, inputs and outputs in full; this file covers the
*why*.

## Why this exists

Before dEitY719/dotfiles#1482, the only thing that could start a merge attempt on a fresh PR
was `pr_merge_train_cron.sh` firing on its own schedule (`*/23 * * * *`
originally). A PR finished by `gh-flow:issue` could therefore sit idle for up
to 23 minutes before anything looked at it. This step closes part of that gap
by calling the same dispatcher script the cron job calls, once, right after
the PR exists.

**It does not, however, cut the triggering PR's own idle time to zero.** The
dispatcher's target count excludes any PR updated within the last
`_PMT_QUIET_MINUTES` (11 minutes — D-6 quiet period, see
`shell-common/tools/custom/pr_merge_train_cron.sh` →
`_pmt_target_count`, and `gh-pr:merge-train`'s `references/ordering.md` for why
11). The PR this step just created has an `updatedAt` of "just now", so it
fails that filter on this very tick — if no other PR in the queue has already
cleared the quiet period, the wake call ends in "No target PR — nothing to
wake a session for" and the triggering PR is not touched. It only becomes
eligible once its own 11-minute quiet period elapses, and from there the
`*/5 * * * *` cron backstop picks it up within another 5 minutes at most —
so the triggering PR's real idle time is **~11–16 minutes**, not zero.

What this step *does* reliably shorten is the idle time of **other** PRs
already sitting in the queue past their quiet period (the common case when
several `gh-flow:issue` runs are in flight) — those get swept up to 5 minutes
earlier than waiting for the next cron tick would have.

The cron job is not removed. Its backstop period is shortened to `*/5 * * *
*` (`shell-common/tools/custom/cron-jobs.json`) so that a dropped or missed
event trigger — e.g. this step running while a previous train is still
`live` — is still picked up within 5 minutes instead of 23.

## Why the dispatcher, not `gh-pr:merge-train` or `--admin-merge`

Both alternatives were considered and rejected (issue dEitY719/dotfiles#1482 body, "대안"):

- **Calling `Skill(gh-pr:merge-train)` directly** would bypass NF-1's
  flock + `herdr agent get mt-…` double-lock — if several `gh-flow:issue`
  sessions finish at the same moment, each would start its own train.
  `pr_merge_train_cron.sh` already implements both locks
  (`gh-pr:merge-train`'s `references/cron-dispatcher.md`); calling
  it, not the skill, reuses that protection for free.
- **Adding `--admin-merge` to the flow** was rejected because this repo has
  `required_approving_review_count=0` (no approval to bypass) and an admin
  bypass would also skip the project-board Status gate — a standing
  exception the issue's NF-2 explicitly rules out.

## Guarded to `$HOME/dotfiles`'s own `origin` only (dEitY719/dotfiles#1498, PR dEitY719/dotfiles#1539 review)

`pr_merge_train_cron.sh` (the script `aicron run merge-train` launches) only
ever operates on `$HOME/dotfiles`'s own `origin` remote. Waking it for a PR
that `gh-flow:issue` pushed somewhere the dispatcher can't see nudges a
process that will never find that PR: harmless, but pointless.
`lib/merge-train-wake.sh` gates the call on whether `<remote>` — the same
`[remote]` positional Step 1 resolved (`references/target-binding.md`) —
points at that **same repo**.

Two failure modes were found and closed together, both from PR dEitY719/dotfiles#1539 review
(agy + codex, independently, both BLOCKER):

- **Don't gate on a re-read of `$REMOTE` from the environment.** An earlier
  draft (dangling commit d3e12471, PR dEitY719/dotfiles#1489 review) read `${REMOTE:-origin}`
  before Step 1 ever exported it, so the guard was always true. dEitY719/dotfiles#1498's first
  fix exported `REMOTE` in Step 1 for this to read — but a Bash tool call is
  not guaranteed to inherit a prior call's exports (agy, PR dEitY719/dotfiles#1539): if the
  export doesn't survive to this call, `${REMOTE:-origin}` silently falls
  back to `origin` and fires anyway — the exact failure this guard exists to
  prevent. **The fix: the executing agent substitutes the literal, already-
  known `<remote>` value into the call it makes for this step** — never a
  live `$REMOTE` read. The agent parsed `[remote]` itself in Step 1; that
  value lives in its own conversational context, not in shell state that can
  reset between tool calls.
- **Don't compare by remote *name* alone.** Comparing `<remote> = "origin"`
  as a string (codex, PR dEitY719/dotfiles#1539) conflates "named origin" with "is the repo
  the dispatcher watches" — a fork workflow (`origin` = fork, `upstream` =
  canonical) would still wake the wrong train on a same-named-but-different
  remote. The fix: compare the resolved remote's URL against
  `$HOME/dotfiles`'s own `origin` URL, not the two names.

## The call

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/issue/lib/merge-train-wake.sh" "<remote>" &
```

`<remote>` is the literal value from Step 1's own arg parsing — the
executing agent substitutes it here, never a live `$REMOTE`/`${REMOTE:-origin}`
env read. Run in the background (harness `run_in_background`, or the
trailing `&` above when run as a plain script) and proceed to Step 2.5
immediately — see "Fired in the background, not awaited" below.

In the common single-clone dotfiles setup (the session's own worktree shares
its remotes with `$HOME/dotfiles`, and `[remote]` defaults to `origin`),
the script's own URL comparison resolves the same as a name-based check
would. It only starts to differ — correctly refusing to fire — on a fork
clone or a remote pointed at a different host/repo than `$HOME/dotfiles`'s
own `origin`.

No output on the no-match path — silent skip, matching this skill suite's
convention of staying quiet on an expected, non-error path (e.g.
`gh-issue:implement`'s 3.3b duplicate-PR check). Step 3's report reflects it
as `[SKIP] Step 4.1: merge-train wake  (remote != origin)`
(`references/report-template.md`).

The script invokes `aicron.sh` by absolute path (mirrors how cron itself
invokes it), not via the `aicron` shell function/alias — the function is
guarded by the interactive-shell check in `shell-common/functions/aicron.sh`
and is not reliably available in a skill's non-interactive Bash calls.

**Fired in the background, not awaited.** `pr_merge_train_cron.sh` blocks on
`herdr agent prompt --wait --timeout 240000` when it actually launches a
train — up to ~4 minutes, only to confirm the prompt was *accepted*, not that
the train finished. Step 2.5/2.5.1 (the rebase steps right after this one)
don't depend on the train's outcome, so awaiting that confirmation would only
stall the chain for no benefit. One consequence: the dispatcher's own exit
code is never observed here — see "Soft-fail policy" below.

**Why the `$HOME/dotfiles` fallback is intentional, not a portability gap.**
`gh-flow:issue`'s own precondition is a dedicated feature-branch worktree,
never the checkout at `$HOME/dotfiles` — but crontab always calls
`$HOME/dotfiles/shell-common/tools/custom/aicron.sh`, never a worktree path,
because a worktree is torn down after its PR merges while the crontab entry
is permanent. `SHELL_COMMON` is already canonicalized to the main checkout
by the shell loader (`_dotfiles_root_canonicalize`,
`shell-common/functions/dotfiles_root.sh:110`) in the common case; the
script's `${SHELL_COMMON:-${DOTFILES_ROOT:-$HOME/dotfiles}/shell-common}`
chain falls to the `$HOME/dotfiles` tier only when neither variable is set.
Setting `DOTFILES_ROOT_NO_CANONICALIZE=1` (`_resolve_dotfiles_root_canonical`
in `dotfiles_root.sh`) makes the script wake a worktree-local `aicron.sh`
instead — the shell that intentionally wants that has opted out of the
canonicalization this step otherwise relies on.

## Soft-fail policy (F-2)

This step never stops the chain:

- `<remote>`'s URL doesn't match `$HOME/dotfiles`'s own `origin` URL →
  silent skip, continue. Not a failure — see "Guarded to `$HOME/dotfiles`'s
  own `origin` only" above.
- `aicron.sh` missing at the expected path → one `[WARN]` line, continue.
  This is the only outcome observed synchronously on the `origin` path.
- Once launched in the background, this step does not wait for or inspect
  `aicron run merge-train`'s exit code — including the case where the
  dispatcher declines because a train is already `live` per NF-1, which is
  the expected, common case, not a failure. Any real error surfaces only in
  the dispatcher's own state/log (`aicron status merge-train`), not here.

Step 3's report shows one row for this step: `[OK]` (dispatcher launched,
regardless of what it does after that), `[WARN] (aicron.sh missing)` on the
one synchronous failure path above. It never produces a `stopped at` report
— see `references/report-template.md`.

Self-check: `lib/merge-train-wake.selfcheck.sh`.
