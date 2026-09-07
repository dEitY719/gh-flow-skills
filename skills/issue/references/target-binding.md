# gh-flow:issue — Binding the GitHub target (dEitY719/dotfiles#1403)

Step 1 resolves the host and repo from the `[remote]`'s URL once, so the
composition's own `gh` call cannot drift to another server. The mechanism
lives in one script, `lib/target-binding.sh` — its own header documents the
usage, exports and inputs in full; this file covers only the *why*.

```bash
GH_FLOW_TARGET_REMOTE="<remote>" . "${CLAUDE_PLUGIN_ROOT:-.}/skills/issue/lib/target-binding.sh" || exit 1
```

`<remote>` is the literal `[remote]` argument from Step 1 — e.g. `upstream`
when `/gh-flow:issue <N> upstream` was invoked, `origin` (the script's own
default) otherwise. Not a positional arg to `.` — that is a bash/zsh
extension, and dash (POSIX `sh`) silently drops it, defaulting to `origin`
regardless of what was passed. The env var works identically everywhere.

**Source fresh from every Bash call that needs the target, never trust an
earlier call's exports to reach it.** PR dEitY719/dotfiles#1539 review (agy + codex)
found that a Bash tool call is not guaranteed to inherit an earlier call's
exports, so a step several `Skill()` calls downstream that trusted `$REMOTE`
alone could silently read the wrong value. Step 1, and internally
`lib/post-ai-metrics.sh` (Step 2.6), each source `lib/target-binding.sh`
fresh in their own Bash call from the literal `<remote>` value the executing
agent already knows from parsing it here in Step 1 — never a live `$REMOTE`
read. (`lib/merge-train-wake.sh`, Step 2.4.1, needs no host/repo resolution
at all — it only compares remote URLs, see `references/merge-train-wake.md`.)

## Why the host is passed explicitly

Step 2.6's `gh api "repos/$TARGET_REPO/..."` — the only `gh` call this
composition makes directly — takes `GH_HOST="$TARGET_HOST"` explicitly; the
repo slug is already in its path. Without the host, `gh` follows its own
`gh repo set-default` rather than git's `origin`, and on a dual-host login
(github.com + GHES) it hits the wrong server with no error.

## Chain-wide since dEitY719/dotfiles#1405

The export used to be a best-effort default only: `gh-pr:commit` and `gh-pr:create` each
re-resolved their own target from `origin`, so `/gh-flow:issue <N> upstream`
still landed the commit's ai-metrics call and the PR itself on `origin` (PR
dEitY719/dotfiles#1404 review, codex). That gap is closed — `[remote]` is now threaded
explicitly into every sub-skill that talks to GitHub:

| Step | Sub-skill | Receives `[remote]` |
|---|---|---|
| 2.1 | `gh-issue:implement` | yes |
| 2.2 | `gh-pr:commit` | yes (dEitY719/dotfiles#1405) |
| 2.3 | `gh-pr:create` | yes (dEitY719/dotfiles#1405) |
| 2.4 | `gh-verify:review-all` | yes (dEitY719/dotfiles#1405) |

So `/gh-flow:issue <N> upstream` implements, commits, opens the PR and reviews
it on `upstream`, never on `origin`.
