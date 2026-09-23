#!/usr/bin/env bash
# Self-check for lib/locate-checkout.sh (#41 F-1/F-2, NF-2). No network:
#
#   bash skills/waves/lib/locate-checkout.selfcheck.sh
#
# Builds a throwaway tree of git repos with synthetic remotes and asserts each
# stop/success arm the issue's acceptance criteria name.
set -u
T="$(cd -- "$(dirname -- "$0")" && pwd)/locate-checkout.sh"
FAIL=0
chk() { # chk <label> <got> <want>
    if [ "$2" = "$3" ]; then echo "ok    $1"; else echo "FAIL  $1: got '$2' want '$3'"; FAIL=1; fi
}
has() { # has <label> <haystack> <needle>
    case $2 in *"$3"*) echo "ok    $1" ;; *) echo "FAIL  $1: '$3' not in '$2'"; FAIL=1 ;; esac
}
repo() { # repo <dir> <remote-name> <url>
    mkdir -p "$1" && git -C "$1" init -q && git -C "$1" remote add "$2" "$3"
}

TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_NOSYSTEM=1 HOME="$TMP/home"
mkdir -p "$HOME"
git config --global user.email t@t && git config --global user.name t

W="$TMP/work"                                    # not a git repo itself
repo "$W/widget" origin git@github.com:Acme/Widget.git
git -C "$W/widget" commit -q --allow-empty -m init
# Make widget's origin genuinely fetchable (to a local bare repo) so case 9
# would catch a stray `git fetch`: a fetch to an unreachable host writes nothing.
git init -q --bare "$TMP/bare/Widget.git"
git config --global url."$TMP/bare/".insteadOf git@github.com:Acme/
git -C "$W/widget" push -q origin HEAD:main 2>/dev/null
git -C "$W/widget" worktree add -q "$W/widget-wt" -b wt 2>/dev/null
repo "$W/group/tool" upstream ssh://git@github.samsungds.net:2222/team/tool
repo "$W/other" origin https://github.com/acme/other.git
repo "$W/a/b/too-deep" origin https://github.com/acme/deep.git
URL=https://github.com/acme/widget/issues/28

# 1. From a non-repo parent: depth-1 match, ssh remote vs https URL, case-folded;
#    the linked worktree of the same repo is not a second candidate.
got=$(bash "$T" "$URL" "$W"); rc=$?
chk "parent dir finds main checkout" "$rc|$got" "0|MAIN=$W/widget
REMOTE=origin
HOST=github.com
REPO=acme/widget
ISSUE=28"

# 2. Depth 2, ssh:// with port, non-origin remote name, GHES host.
got=$(bash "$T" "https://github.samsungds.net/team/tool/issues/5/" "$W" | head -2 | tr '\n' ' ')
chk "depth 2 + ssh:// port + upstream" "$got" "MAIN=$W/group/tool REMOTE=upstream "

# 3. URL with query/fragment still parses.
got=$(bash "$T" "$URL#issuecomment-1" "$W" | sed -n 5p)
chk "fragment stripped" "$got" "ISSUE=28"

# 4. cwd inside the repo itself wins without a subdir scan.
got=$(cd "$W/widget" && bash "$T" "$URL" | head -1)
chk "cwd is the repo" "$got" "MAIN=$W/widget"

# 5. Non-issue URLs are a format error, exit 2.
for bad in https://github.com/acme/widget/pull/3 https://github.com/acme/widget notaurl; do
    err=$(bash "$T" "$bad" "$W" 2>&1 >/dev/null); rc=$?
    chk "rejects $bad (rc)" "$rc" 2
    has "rejects $bad (msg)" "$err" "not an issue URL"
done

# 6. 0 candidates: stop with a clone hint; depth 3 is out of reach.
err=$(bash "$T" https://github.com/acme/deep/issues/1 "$W" 2>&1 >/dev/null); rc=$?
chk "depth 3 not searched (rc)" "$rc" 2
has "0 candidates -> clone hint" "$err" "git clone https://github.com/acme/deep.git $W/deep"

# 7. Only a linked worktree matches: excluded, and said so.
mkdir -p "$TMP/wtonly" && mv "$W/widget-wt" "$TMP/wtonly/widget-wt"
git -C "$W/widget" worktree repair "$TMP/wtonly/widget-wt" 2>/dev/null
err=$(bash "$T" "$URL" "$TMP/wtonly" 2>&1 >/dev/null); rc=$?
chk "worktree only (rc)" "$rc" 2
has "worktree only (msg)" "$err" "only linked worktrees matched, excluded: $TMP/wtonly/widget-wt"

# 8. 2+ main checkouts: list both, stop.
repo "$W/copy" origin https://github.com/acme/widget
err=$(bash "$T" "$URL" "$W" 2>&1 >/dev/null); rc=$?
chk "2 candidates (rc)" "$rc" 2
has "2 candidates lists both" "$err" "2 main checkouts of acme/widget under $W — cd into the one to use and re-run: $W/copy $W/widget"

# 9. NF-2 read-only: nothing under the tree is written during a run (mtime, so
#    a rewrite with identical bytes -- a repeated fetch's FETCH_HEAD -- counts).
touch "$TMP/marker"
bash "$T" "$URL" "$W" >/dev/null 2>&1
chk "read-only" "$(find "$W" -newer "$TMP/marker" | head -3)" ""

exit "$FAIL"
