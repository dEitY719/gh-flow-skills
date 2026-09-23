#!/usr/bin/env bash
# Locate the local MAIN checkout of the repo an issue URL names (#41 F-1/F-2).
#
#   bash "$CLAUDE_PLUGIN_ROOT/skills/waves/lib/locate-checkout.sh" <issue-url> [<dir>]
#
# <dir> defaults to the current directory. Search order: the repo <dir> is
# in, if any, else every git repo at depth 1..2 below it. A candidate
# matches when ANY of its remotes, normalised (ssh `git@host:o/r(.git)`,
# `ssh://[user@]host[:port]/o/r`, `https://[user@]host/o/r(.git)`), equals the
# URL's host/owner/repo, case-insensitively. Linked worktrees (`.git` is a
# FILE) are never candidates: the coordinator needs the main checkout.
#
# Read-only (NF-2): `git config` reads only — no fetch, no write, no clone.
#
# Exit 0 prints, one per line:  MAIN= REMOTE= HOST= REPO= ISSUE=
# Exit 2 prints one reason line on stderr (bad URL / 0 matches + clone hint /
# 2+ matches + their paths) — the caller turns it into `gh-flow:waves stopped —`.
#
# Self-check: lib/locate-checkout.selfcheck.sh
set -u

norm() { # norm <remote-url> -> host/owner/repo (lowercase), or nothing
    printf '%s\n' "$1" | sed -E \
        -e 's#^[a-zA-Z+]+://##' -e 's#^[^@/]*@##' \
        -e 's#^([^/:]+):[0-9]+/#\1/#' -e 's#^([^/:]+):#\1/#' \
        -e 's#/+$##' -e 's#\.git$##' | tr 'A-Z' 'a-z' |
        grep -E '^[^/]+/[^/]+/[^/]+$'
}

match_remote() { # match_remote <repo-dir> -> first matching remote name
    git -C "$1" config --get-regexp '^remote\..*\.url$' 2>/dev/null |
        while read -r key url; do
            [ "$(norm "$url")" = "$WANT" ] && { key=${key#remote.}; printf '%s\n' "${key%.url}"; }
        done | head -n 1
}

url=${1:-}
dir=${2:-$PWD}
# Strip ?query / #fragment / trailing slash, then demand the issues shape.
u=${url%%#*}; u=${u%%\?*}; u=${u%/}
if ! printf '%s\n' "$u" | grep -Eq '^https?://[^/]+/[^/]+/[^/]+/issues/[0-9]+$'; then
    printf 'not an issue URL (want https://<host>/<owner>/<repo>/issues/<N>): %s\n' "$url" >&2
    exit 2
fi
rest=${u#*://}
HOST=${rest%%/*}; rest=${rest#*/}
OWNER=${rest%%/*}; rest=${rest#*/}
NAME=${rest%%/*}
ISSUE=${u##*/}
WANT=$(printf '%s/%s/%s' "$HOST" "$OWNER" "$NAME" | tr 'A-Z' 'a-z')

hits=() wts=()
consider() { # consider <repo-dir>
    local r
    r=$(match_remote "$1")
    [ -n "$r" ] || return 0
    if [ -d "$1/.git" ]; then hits+=("$1|$r"); else wts+=("$1"); fi
}

top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) && consider "$top"
if [ "${#hits[@]}" -eq 0 ]; then
    # .git at depth 2 = repo at depth 1; at depth 3 = repo at depth 2.
    while IFS= read -r g; do consider "${g%/.git}"; done < <(
        find "$dir" -mindepth 2 -maxdepth 3 -name .git \( -type d -o -type f \) 2>/dev/null | sort)
fi

case ${#hits[@]} in
0)
    extra=''
    [ "${#wts[@]}" -eq 0 ] || extra=" (only linked worktrees matched, excluded: ${wts[*]})"
    printf 'no local main checkout of %s/%s under %s%s — clone it first: git clone %s %s/%s\n' \
        "$OWNER" "$NAME" "$dir" "$extra" "https://$HOST/$OWNER/$NAME.git" "$dir" "$NAME" >&2
    exit 2 ;;
1)
    printf 'MAIN=%s\nREMOTE=%s\nHOST=%s\nREPO=%s/%s\nISSUE=%s\n' \
        "${hits[0]%|*}" "${hits[0]##*|}" "$HOST" "$OWNER" "$NAME" "$ISSUE" ;;
*)
    printf '%s main checkouts of %s/%s under %s — cd into the one to use and re-run: %s\n' \
        "${#hits[@]}" "$OWNER" "$NAME" "$dir" "$(printf '%s ' "${hits[@]%|*}")" >&2
    exit 2 ;;
esac
