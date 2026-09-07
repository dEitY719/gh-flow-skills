#!/bin/sh
# lib/target-binding.sh — gh-flow:issue Step 1 (dEitY719/dotfiles#1403):
# resolve GH_HOST / TARGET_REPO / TARGET_HOST / REMOTE / SHELL_COMMON from
# one remote name.
#
# SOURCE it, never execute it — the exports are the whole product. Set
# GH_FLOW_TARGET_REMOTE first, in the same shell, then source with no
# arguments:
#
#   GH_FLOW_TARGET_REMOTE="<remote>" . "${CLAUDE_PLUGIN_ROOT:-.}/skills/issue/lib/target-binding.sh" || exit 1
#
# Deliberately not a positional arg to `.` — that is a bash/zsh extension
# POSIX does not require, and dash silently drops it (confirmed: `. file
# ghes` under dash resolves as if `ghes` were never passed, defaulting to
# `origin`). An env var assigned immediately before the `.` call works
# identically everywhere and is exactly as fresh per call.
#
# Set GH_FLOW_TARGET_REMOTE to the literal remote value the executing agent
# already parsed in Step 1 — never a live `$REMOTE` read. A Bash tool call is
# not guaranteed to inherit an earlier call's exports (dEitY719/dotfiles#1498, PR
# dEitY719/dotfiles#1539 review), so every Bash call that needs the target —
# Step 1 itself, and internally inside lib/post-ai-metrics.sh for Step 2.6 —
# sources this file fresh rather than trusting an earlier call's exports.
#
# Reads   GH_FLOW_TARGET_REMOTE (default `origin`), DOTFILES_ROOT, CLAUDE_PLUGIN_ROOT.
# Exports GH_HOST, TARGET_REPO, TARGET_HOST, REMOTE, SHELL_COMMON.
#
# Self-check: lib/target-binding.selfcheck.sh

_tb_remote="${GH_FLOW_TARGET_REMOTE:-origin}"

# plugin-root resolution: https://github.com/dEitY719/harness-skills/blob/main/references/plugin-root.md
_tb_sc="${DOTFILES_ROOT:-$HOME/dotfiles}/shell-common"                            # tier 1
if [ ! -f "$_tb_sc/functions/gh_host.sh" ]; then
    if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then                                     # tier 5
        printf '[gh-flow:issue] no shell-common under %s, and CLAUDE_PLUGIN_ROOT is unset. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
            "$_tb_sc" >&2
        return 1 2>/dev/null || exit 1
    fi
    _tb_sc="$CLAUDE_PLUGIN_ROOT/lib/vendor/shell-common"                          # tier 2
fi
unset -f _gh_resolve_host 2>/dev/null || :
# shellcheck disable=SC1091  # path is resolved at runtime
[ -f "$_tb_sc/functions/gh_host.sh" ] && . "$_tb_sc/functions/gh_host.sh"
if ! command -v _gh_resolve_host >/dev/null 2>&1; then                           # tier 5
    printf '[gh-flow:issue] %s did not load a usable shell-common. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
        "$_tb_sc" >&2
    return 1 2>/dev/null || exit 1
fi
export SHELL_COMMON="$_tb_sc"

REMOTE="$_tb_remote"
if ! REMOTE_URL=$(git remote get-url "$REMOTE" 2>/dev/null); then
    printf '[gh-flow:issue] remote "%s" not found. Available remotes:\n' "$REMOTE" >&2
    git remote -v >&2
    return 1 2>/dev/null || exit 1
fi
if ! TARGET_REPO=$(_gh_parse_owner_repo_url "$REMOTE_URL"); then
    printf '[gh-flow:issue] could not parse owner/repo from remote "%s" (%s) — refusing to fall back to a guessed host with an empty repo.\n' \
        "$REMOTE" "$REMOTE_URL" >&2
    return 1 2>/dev/null || exit 1
fi
TARGET_HOST=$(_gh_host_from_url "$REMOTE_URL") || TARGET_HOST=$(_gh_resolve_host)
export GH_HOST="$TARGET_HOST"
export REMOTE TARGET_REPO TARGET_HOST
