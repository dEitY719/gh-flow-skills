#!/usr/bin/env bash
# Self-check for lib/target-binding.sh. No framework, no fixtures:
#
#   bash skills/issue/lib/target-binding.selfcheck.sh
#
# Runs against a throwaway git repo with synthetic remotes, so it needs no
# network, no gh auth, and no dotfiles checkout. Exits non-zero on the first
# behaviour that regressed.
#
# Every `. "$TARGET"` below is the very thing under test, so its path is a
# runtime value by construction.
# shellcheck disable=SC1090
set -u

ROOT=$(cd -- "$(dirname -- "$0")/../../.." && pwd)
TARGET="$ROOT/skills/issue/lib/target-binding.sh"
FAIL=0

chk() { # chk <label> <got> <want>
    if [ "$2" = "$3" ]; then
        echo "ok    $1"
    else
        echo "FAIL  $1: got '$2' want '$3'"
        FAIL=1
    fi
}

TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q
git -C "$TMP" remote add origin git@github.com:acme/widget.git
git -C "$TMP" remote add ghes https://github.samsungds.net/acme/widget.git

# The vendored tier is what a standalone plugin install exercises, so pin
# DOTFILES_ROOT at a path that cannot exist for every case below.
export DOTFILES_ROOT=/nonexistent-dotfiles

cd "$TMP" || exit 1

# 1. github.com remote: repo and host both read from that one URL, REMOTE
#    echoes back the literal value assigned to GH_FLOW_TARGET_REMOTE.
got=$( CLAUDE_PLUGIN_ROOT="$ROOT" GH_FLOW_TARGET_REMOTE=origin . "$TARGET" >/dev/null 2>&1 &&
       printf '%s|%s|%s|%s' "$TARGET_REPO" "$TARGET_HOST" "$GH_HOST" "$REMOTE" )
chk "github.com remote" "$got" "acme/widget|github.com|github.com|origin"

# 2. No GH_FLOW_TARGET_REMOTE defaults to origin.
got=$( CLAUDE_PLUGIN_ROOT="$ROOT" . "$TARGET" >/dev/null 2>&1 && printf '%s' "$REMOTE" )
chk "unset defaults to origin" "$got" "origin"

# 3. GHES remote: the host follows the URL, not the PC's setup mode. This is
#    the dEitY719/dotfiles#1403 case the whole helper exists for — and the
#    discriminating case that would catch a regression back to positional
#    `. file <arg>` (a bash/zsh-only extension dash silently drops, so a
#    naive rewrite would still pass a same-as-default "origin" test but fail
#    exactly this one).
got=$( CLAUDE_PLUGIN_ROOT="$ROOT" GH_FLOW_TARGET_REMOTE=ghes . "$TARGET" >/dev/null 2>&1 &&
       printf '%s|%s' "$TARGET_REPO" "$GH_HOST" )
chk "GHES remote picks its own host" "$got" "acme/widget|github.samsungds.net"

# 4. SHELL_COMMON names whichever tree resolved (tier 2, vendored).
got=$( CLAUDE_PLUGIN_ROOT="$ROOT" . "$TARGET" >/dev/null 2>&1 && printf '%s' "$SHELL_COMMON" )
chk "SHELL_COMMON exported" "$got" "$ROOT/lib/vendor/shell-common"

# 5. Unknown remote fails instead of silently falling back to origin, and
#    leaves GH_HOST untouched.
got=$( CLAUDE_PLUGIN_ROOT="$ROOT" GH_FLOW_TARGET_REMOTE=nosuchremote . "$TARGET" >/dev/null 2>&1
       printf '%s|%s' "$?" "${GH_HOST:-unset}" )
chk "unknown remote refused, GH_HOST untouched" "$got" "1|unset"

# 6. No CLAUDE_PLUGIN_ROOT and no dotfiles checkout: tier 5, fails loud.
got=$( unset CLAUDE_PLUGIN_ROOT; . "$TARGET" >/dev/null 2>&1; echo "$?" )
chk "no plugin root, no dotfiles: fails loud" "$got" "1"

# 7. Sourced under dash (POSIX sh, no bash/zsh dot-arg extension) — the shape
#    every non-bash/zsh harness runs. Uses ghes, not origin, so a regression
#    to positional args (silently dropped by dash) would be caught here too.
if command -v dash >/dev/null 2>&1; then
    got=$( CLAUDE_PLUGIN_ROOT="$ROOT" DOTFILES_ROOT=/nonexistent-dotfiles GH_FLOW_TARGET_REMOTE=ghes \
           dash -c ". \"$TARGET\" >/dev/null 2>&1 && printf '%s' \"\$GH_HOST\"" )
    chk "sourced under dash, non-default remote" "$got" "github.samsungds.net"
else
    echo "skip  dash not installed"
fi

exit "$FAIL"
