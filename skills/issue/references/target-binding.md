# gh-flow:issue — Binding the GitHub target (dEitY719/dotfiles#1403)

Step 1 resolves the host and repo from the `[remote]`'s URL once and exports
them, so the composition's own `gh` call cannot drift to another server. It
also exports `REMOTE` itself (dEitY719/dotfiles#1498), matching the convention `gh-pr:commit` and
`gh-pr:create` already use.

Set `REMOTE` to the parsed `[remote]` argument from Step 1 **before** running
this block — e.g. `REMOTE=upstream` when `/gh-flow:issue <N> upstream` was
invoked, left unset (defaults to `origin`) otherwise. Do not copy the block
below verbatim without that assignment; `${REMOTE:-origin}` silently reads as
`origin` when `REMOTE` was never set, which defeats the whole point of
threading `[remote]` through the chain.

**This export is not load-bearing for the flow's two non-`Skill()` inline
Bash steps (2.4.1, 2.6)** — PR dEitY719/dotfiles#1539 review (agy + codex) found that a Bash
tool call is not guaranteed to inherit an earlier call's exports, so a step
several `Skill()` calls downstream that trusted `$REMOTE` alone could
silently read the wrong value. Both steps instead re-derive their target
fresh, in their own Bash call, from the literal `<remote>` value the
executing agent already knows from parsing it here in Step 1 — see
`references/merge-train-wake.md` and `references/ai-metrics-step.md`. The
export below remains useful for anything that stays within Step 1's own
Bash call, and for consistency with the rest of the skill suite.

```bash
# plugin-root resolution: https://github.com/dEitY719/harness-skills/blob/main/references/plugin-root.md
_SC="${DOTFILES_ROOT:-$HOME/dotfiles}/shell-common"                                  # tier 1
if [ ! -f "$_SC/functions/gh_host.sh" ]; then
    [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || {                                            # tier 5
        printf '[gh-flow:issue] no shell-common under %s, and CLAUDE_PLUGIN_ROOT is unset. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
            "$_SC" >&2
        return 1 2>/dev/null || exit 1
    }
    _SC="$CLAUDE_PLUGIN_ROOT/lib/vendor/shell-common"                                # tier 2
fi
unset -f _gh_resolve_host 2>/dev/null || :
[ -f "$_SC/functions/gh_host.sh" ] && . "$_SC/functions/gh_host.sh"
command -v _gh_resolve_host >/dev/null 2>&1 || {                                     # tier 5
    printf '[gh-flow:issue] %s did not load a usable shell-common. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
        "$_SC" >&2
    return 1 2>/dev/null || exit 1
}
export SHELL_COMMON="$_SC"
REMOTE="${REMOTE:-origin}"
REMOTE_URL=$(git remote get-url "$REMOTE")
TARGET_REPO=$(_gh_parse_owner_repo_url "$REMOTE_URL")
TARGET_HOST=$(_gh_host_from_url "$REMOTE_URL") || TARGET_HOST=$(_gh_resolve_host)
export GH_HOST="$TARGET_HOST"
export REMOTE TARGET_REPO TARGET_HOST
```

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
