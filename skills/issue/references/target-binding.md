# gh-flow:issue — Binding the GitHub target (dEitY719/dotfiles#1403)

Step 1 resolves the host and repo from the `[remote]`'s URL once, so the
composition's own `gh` call cannot drift to another server. The mechanism
lives in one script, `lib/target-binding.sh` — its own header documents the
usage, exports and inputs in full; this file covers only the *why*.

```bash
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || case "<skill-base-dir>" in /*) CLAUDE_PLUGIN_ROOT=$(cd -P -- "<skill-base-dir>/../.." 2>/dev/null && pwd) ;; esac  # tier 2, agent-filled (#41)
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] &&                                               # tier 2
    [ -f "$CLAUDE_PLUGIN_ROOT/skills/issue/lib/target-binding.sh" ]; then            # proof
    GH_FLOW_TARGET_REMOTE="<remote>" \
        . "$CLAUDE_PLUGIN_ROOT/skills/issue/lib/target-binding.sh" || exit 1
else                                                                                 # tier 5
    printf '[gh-flow:issue] cannot locate skills/issue/lib/target-binding.sh under CLAUDE_PLUGIN_ROOT (%s). On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
        "${CLAUDE_PLUGIN_ROOT:-unset}" >&2
    exit 1
fi
```

`${CLAUDE_PLUGIN_ROOT:-.}` would be the retired tier 4
([harness-skills#22](https://github.com/dEitY719/harness-skills/blob/main/references/plugin-root.md)):
with the variable unset it sources this script from the **current working
directory**, and this skill runs inside the repository under review. Guard the
variable, then prove the file — there is no tier that guesses (#27).

**`<skill-base-dir>` is the agent-filled half of tier 2 (#41 F-6).** A skill
loaded through a plain symlink (`~/.claude*/skills/<name>` -> a checkout's
`skills/<name>`) runs with `CLAUDE_PLUGIN_ROOT` unset, and every guard above
stopped. The first line fills the variable the way
[plugin-root.md](https://github.com/dEitY719/harness-skills/blob/main/references/plugin-root.md)
says a harness without it must: from the path the agent read `SKILL.md` at.
Substitute `<skill-base-dir>` with that literal absolute directory (Claude Code
prints it as "Base directory for this skill"). `cd -P` resolves the symlink
before the `../..`, so the result is the real plugin root; a logical `cd`
would climb the symlink's own parents. A placeholder left unsubstituted, or a
relative path, is refused by the `/*` arm — a relative path resolves against
`$PWD`, which is the retired tier 4 again. The `[ -f ]` proof still decides.
Every block that addresses `$CLAUDE_PLUGIN_ROOT/skills/` in `skills/issue`,
`skills/drain` and `skills/waves` carries the same line, because Bash calls do
not share variables; `tests/plugin-root-skill-base.sh` holds them to it.

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
