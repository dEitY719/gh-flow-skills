#!/bin/sh
# lib/branch-setup.sh — gh-flow:issue-relay Step 2 (skill-check #5, Check 12):
# resolve the destination remote + default branch and compute the working
# branch name for one issue-relay run.
#
# EXECUTE it (never source) — the remote/issue are plain argv to a `bash
# script args` subprocess call, not a positional arg to the `.` dot command
# (a bash/zsh-only extension that dash silently drops — see
# skills/issue/lib/target-binding.sh's header for the sourced-script version
# of this same hazard, worked around there with an env var instead):
#
#   eval "$(bash "${CLAUDE_PLUGIN_ROOT}/skills/issue-relay/lib/branch-setup.sh" "$REMOTE" "$ISSUE" [--base "$BASE"])" || exit 1
#
# Stops short of creating/reusing the branch — the reuse-or-reset decision
# stays a conversation with the user (references/branch-setup.md, "Create or
# reuse" section).
#
# Remote/host resolution mirrors
# skills/relay-merge/references/remote-resolution.md (same
# hard-error-on-missing-remote, never-fall-back-to-origin rule). This is
# issue-relay's own copy rather than a shared script because relay-merge also
# accepts a raw-URL destination with no configured remote, which this
# skill's `--remote <name>` never takes.
#
# Args:    <remote> <issue-number> [--base <branch>]
# Reads:   DOTFILES_ROOT, CLAUDE_PLUGIN_ROOT (plugin-root resolution tiers)
# Prints:  DEST_REPO=... DEST_HOST=... BASE_BRANCH=... BRANCH=... (for eval)
# Exits:   non-zero with an error on stderr on a missing/unparseable remote,
#          an undetectable default branch, or an unfetchable issue title.
#
# Library function, sourceable without running main via
# BRANCH_SETUP_LIB_ONLY=1 (used by lib/branch-setup.selfcheck.sh to unit-test
# the slug computation the skill-check audit flagged as non-deterministic
# prose):
#   _bs_slugify <title>   -> lowercase-hyphenated slug, <=50 chars, on stdout
#
# Self-check: lib/branch-setup.selfcheck.sh

_bs_slugify() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
        | cut -c1-50 \
        | sed -E 's/-+$//'
}

if [ "${BRANCH_SETUP_LIB_ONLY:-0}" != "1" ]; then
    set -eu

    REMOTE=${1:?"usage: branch-setup.sh <remote> <issue-number> [--base <branch>]"}
    ISSUE=${2:?"usage: branch-setup.sh <remote> <issue-number> [--base <branch>]"}
    shift 2
    BASE_BRANCH=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --base)
                BASE_BRANCH=${2:?"--base needs a value"}
                shift 2
                ;;
            *)
                printf '[gh-flow:issue-relay] unknown argument: %s\n' "$1" >&2
                exit 1
                ;;
        esac
    done

    REMOTE_URL=$(git config --get "remote.$REMOTE.url") || {
        printf "[gh-flow:issue-relay] remote '%s' not found. Available remotes:\n" "$REMOTE" >&2
        git remote -v >&2
        exit 1
    }

    # plugin-root resolution: https://github.com/dEitY719/harness-skills/blob/main/references/plugin-root.md
    _bs_sc="${DOTFILES_ROOT:-$HOME/dotfiles}/shell-common"                            # tier 1
    if [ ! -f "$_bs_sc/functions/gh_host.sh" ]; then
        if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then                                     # tier 5
            printf '[gh-flow:issue-relay] no shell-common under %s, and CLAUDE_PLUGIN_ROOT is unset. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
                "$_bs_sc" >&2
            exit 1
        fi
        _bs_sc="$CLAUDE_PLUGIN_ROOT/lib/vendor/shell-common"                          # tier 2
    fi
    unset -f _gh_resolve_host 2>/dev/null || :
    # shellcheck disable=SC1091  # path is resolved at runtime
    [ -f "$_bs_sc/functions/gh_host.sh" ] && . "$_bs_sc/functions/gh_host.sh"
    if ! command -v _gh_resolve_host >/dev/null 2>&1; then                            # tier 5
        printf '[gh-flow:issue-relay] %s did not load a usable shell-common. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
            "$_bs_sc" >&2
        exit 1
    fi

    DEST_REPO=$(_gh_parse_owner_repo_url "$REMOTE_URL") || {
        printf "[gh-flow:issue-relay] could not parse owner/repo from remote '%s' (%s).\n" "$REMOTE" "$REMOTE_URL" >&2
        exit 1
    }
    DEST_HOST=$(_gh_host_from_url "$REMOTE_URL") || DEST_HOST=$(_gh_resolve_host)

    if [ -z "$BASE_BRANCH" ]; then
        BASE_BRANCH=$(git ls-remote --symref "$REMOTE" HEAD 2>/dev/null | awk '/^ref:/ {sub("refs/heads/", "", $2); print $2}')
        if [ -z "$BASE_BRANCH" ]; then
            printf "[gh-flow:issue-relay] could not detect %s's default branch (no --base given).\n" "$REMOTE" >&2
            exit 1
        fi
    fi
    git fetch "$REMOTE" "$BASE_BRANCH" >&2

    TITLE=$(GH_HOST="$DEST_HOST" gh issue view "$ISSUE" --repo "$DEST_REPO" --json title -q .title 2>/dev/null) || {
        printf "[gh-flow:issue-relay] could not fetch issue #%s title from %s (%s).\n" "$ISSUE" "$DEST_REPO" "$DEST_HOST" >&2
        exit 1
    }

    SLUG=$(_bs_slugify "$TITLE")
    BRANCH="issue-${ISSUE}-${SLUG}"

    printf 'DEST_REPO=%s\n' "$DEST_REPO"
    printf 'DEST_HOST=%s\n' "$DEST_HOST"
    printf 'BASE_BRANCH=%s\n' "$BASE_BRANCH"
    printf 'BRANCH=%s\n' "$BRANCH"
fi
