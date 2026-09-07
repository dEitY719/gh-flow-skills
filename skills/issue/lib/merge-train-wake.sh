#!/bin/sh
# lib/merge-train-wake.sh — gh-flow:issue Step 2.4.1 (dEitY719/dotfiles#1482):
# fire-and-forget wake of the merge-train dispatcher, gated to $HOME/dotfiles's
# own `origin` only (dEitY719/dotfiles#1498, PR dEitY719/dotfiles#1539 review — a
# Bash tool call is not guaranteed to inherit an earlier call's exports, so
# the guard compares the literal `<remote>` value against a fresh
# `git remote get-url`, never a live `$REMOTE` env read).
#
# Usage: merge-train-wake.sh "<remote>"   (the literal value Step 1 parsed —
#                                           never a live $REMOTE env read)
#
# Why this exists, why the dispatcher (not `gh-pr:merge-train` directly), why
# gate by URL and not remote name, and why the `$HOME/dotfiles` fallback is
# intentional: `references/merge-train-wake.md`.
#
# Exit 0 always (soft-fail, never load-bearing for the flow). Prints one
# `[WARN]` line only when `aicron.sh` is missing on the matching-remote path;
# silent on every other path (no-match, or the dispatcher's own outcome —
# fired backgrounded and never awaited).
#
# Self-check: lib/merge-train-wake.selfcheck.sh
set -u

_REMOTE="${1:?remote required}"
_MY_URL=$(git remote get-url "$_REMOTE" 2>/dev/null)
_DOTFILES_ORIGIN_URL=$(git -C "$HOME/dotfiles" remote get-url origin 2>/dev/null)
if [ -n "$_MY_URL" ] && [ "$_MY_URL" = "$_DOTFILES_ORIGIN_URL" ]; then
    _AICRON="${SHELL_COMMON:-${DOTFILES_ROOT:-$HOME/dotfiles}/shell-common}/tools/custom/aicron.sh"
    if [ -x "$_AICRON" ]; then
        "$_AICRON" run merge-train >/dev/null 2>&1 &
    else
        printf '[WARN] aicron not found at %s — merge-train dispatcher wake skipped.\n' "$_AICRON" >&2
    fi
fi
exit 0
