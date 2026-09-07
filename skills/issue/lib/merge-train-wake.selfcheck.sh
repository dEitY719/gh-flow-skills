#!/usr/bin/env bash
# Self-check for lib/merge-train-wake.sh. No framework, no fixtures:
#
#   bash skills/issue/lib/merge-train-wake.selfcheck.sh
#
# Uses a throwaway git repo and a throwaway $HOME so it needs no network, no
# gh auth, and never touches the real $HOME/dotfiles. Exits non-zero on the
# first behaviour that regressed.
set -u

# The ambient shell may already export DOTFILES_ROOT/SHELL_COMMON (a real
# dotfiles checkout) — unset both so the tiered fallback under test is
# exercised against the synthetic $HOME below, not the caller's own machine.
unset DOTFILES_ROOT SHELL_COMMON

ROOT=$(cd -- "$(dirname -- "$0")/../../.." && pwd)
TARGET="$ROOT/skills/issue/lib/merge-train-wake.sh"
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

# Synthetic "$HOME/dotfiles" — matching origin URL.
mkdir -p "$TMP/home/dotfiles"
git -C "$TMP/home/dotfiles" init -q
git -C "$TMP/home/dotfiles" remote add origin git@github.com:acme/widget.git

# The session's own worktree.
mkdir -p "$TMP/work"
git -C "$TMP/work" init -q
git -C "$TMP/work" remote add origin git@github.com:acme/widget.git
git -C "$TMP/work" remote add fork git@github.com:someone-else/widget.git

# A working aicron.sh stub that records it was called.
mkdir -p "$TMP/home/dotfiles/shell-common/tools/custom"
AICRON="$TMP/home/dotfiles/shell-common/tools/custom/aicron.sh"
cat > "$AICRON" <<EOF
#!/bin/sh
echo "\$@" > "$TMP/aicron-called"
EOF
chmod +x "$AICRON"

cd "$TMP/work" || exit 1

# 1. Matching remote (origin == $HOME/dotfiles's own origin) fires aicron,
#    in the background, with no stdout/stderr.
rm -f "$TMP/aicron-called"
got=$( HOME="$TMP/home" bash "$TARGET" origin 2>&1 )
sleep 0.2
chk "matching remote: no output" "$got" ""
chk "matching remote: aicron launched" "$(cat "$TMP/aicron-called" 2>/dev/null)" "run merge-train"

# 2. Non-matching remote (fork, different URL) is a silent skip — no call,
#    no output.
rm -f "$TMP/aicron-called"
got=$( HOME="$TMP/home" bash "$TARGET" fork 2>&1 )
sleep 0.2
chk "non-matching remote: no output" "$got" ""
chk "non-matching remote: aicron not launched" "$([ -f "$TMP/aicron-called" ] && echo called || echo not-called)" "not-called"

# 3. Matching remote but aicron.sh missing at the expected path: one [WARN]
#    line, still exit 0.
rm -f "$TMP/aicron-called"
mkdir -p "$TMP/home2/dotfiles"
git -C "$TMP/home2/dotfiles" init -q
git -C "$TMP/home2/dotfiles" remote add origin git@github.com:acme/widget.git
got=$( HOME="$TMP/home2" bash "$TARGET" origin 2>&1 )
exit_code=$?
case "$got" in
    "[WARN]"*"aicron not found"*) chk "missing aicron: warns" "match" "match" ;;
    *) chk "missing aicron: warns" "$got" "[WARN] aicron not found ..." ;;
esac
chk "missing aicron: exit 0" "$exit_code" "0"

# 4. Missing required arg fails loud rather than silently no-op-ing.
( bash "$TARGET" ) >/dev/null 2>&1
chk "missing remote arg: non-zero exit" "$?" "1"

exit "$FAIL"
