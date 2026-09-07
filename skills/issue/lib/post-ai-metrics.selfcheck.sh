#!/usr/bin/env bash
# Self-check for lib/post-ai-metrics.sh. No framework, no fixtures:
#
#   bash skills/issue/lib/post-ai-metrics.selfcheck.sh
#
# Stubs `gh` on PATH so it needs no real gh auth or network. Exits non-zero
# on the first behaviour that regressed.
set -u

# The ambient shell may already export DOTFILES_ROOT/SHELL_COMMON (a real
# dotfiles checkout) — unset both so target-binding.sh's fallback resolves
# against the synthetic CLAUDE_PLUGIN_ROOT below, not the caller's machine.
unset DOTFILES_ROOT SHELL_COMMON

ROOT=$(cd -- "$(dirname -- "$0")/../../.." && pwd)
TARGET="$ROOT/skills/issue/lib/post-ai-metrics.sh"
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
git -C "$TMP" init -q 2>/dev/null || { mkdir -p "$TMP"; git init -q "$TMP"; }
git -C "$TMP" remote add origin git@github.com:acme/widget.git
cd "$TMP" || exit 1

export CLAUDE_PLUGIN_ROOT="$ROOT"

# 1. GH_DISABLE_AI_METRICS=1 skips before any `gh` call — a `gh` on PATH
#    that errors on any invocation proves it was never invoked.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'EOF'
#!/bin/sh
echo "unexpected gh call under GH_DISABLE_AI_METRICS=1: $*" >&2
exit 1
EOF
chmod +x "$TMP/bin/gh"
out=$( GH_DISABLE_AI_METRICS=1 PATH="$TMP/bin:$PATH" \
       bash "$TARGET" origin 1 "$(date +%s)" feat medium 4000 1 2 3 4 5 6 2>&1 )
chk "GH_DISABLE_AI_METRICS=1: no output, no gh call" "$out" ""

# 2. Happy path: `gh` records its call args to a file so the body/host/repo
#    can be inspected.
cat > "$TMP/bin/gh" <<EOF
#!/bin/sh
echo "\$@" > "$TMP/gh-call-args"
EOF
chmod +x "$TMP/bin/gh"
START_TS=$(( $(date +%s) - 120 ))  # ~2 min ago
out=$( PATH="$TMP/bin:$PATH" bash "$TARGET" origin 42 "$START_TS" feat small 4000 5 6 7 8 9 10 2>&1 )
chk "happy path: no [WARN]" "$out" ""
CALL_ARGS=$(cat "$TMP/gh-call-args" 2>/dev/null)
case "$CALL_ARGS" in
    "api repos/acme/widget/issues/42/comments -X POST -f body="*)
        chk "happy path: correct endpoint" "match" "match" ;;
    *)
        chk "happy path: correct endpoint" "$CALL_ARGS" "api repos/acme/widget/issues/42/comments -X POST -f body=..." ;;
esac
case "$CALL_ARGS" in
    *"~4 h"*) chk "feat/small maps to 4h baseline" "match" "match" ;;
    *) chk "feat/small maps to 4h baseline" "$CALL_ARGS" "*~4 h*" ;;
esac
case "$CALL_ARGS" in
    *"~1000"*) chk "token estimate floors at 1000" "match" "match" ;;
    *) chk "token estimate floors at 1000" "$CALL_ARGS" "*~1000*" ;;
esac
case "$CALL_ARGS" in
    *"~5 min"*"~6 min"*"~7 min"*"~8 min"*"~9 min"*"~10 min"*)
        chk "per-step minutes threaded through" "match" "match" ;;
    *)
        chk "per-step minutes threaded through" "$CALL_ARGS" "*5/6/7/8/9/10 min rows*" ;;
esac

# 3. gh api failure is soft-fail: one [WARN] line, still exit 0.
cat > "$TMP/bin/gh" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$TMP/bin/gh"
out=$( PATH="$TMP/bin:$PATH" bash "$TARGET" origin 42 "$(date +%s)" fix - 4000 1 2 3 4 5 6 2>&1 )
exit_code=$?
case "$out" in
    "[WARN] ai-metrics comment failed"*) chk "gh api failure: warns" "match" "match" ;;
    *) chk "gh api failure: warns" "$out" "[WARN] ai-metrics comment failed (...)" ;;
esac
chk "gh api failure: exit 0 (soft-fail)" "$exit_code" "0"

# 4. Unresolvable target (bad remote) is also soft-fail: one [WARN] line,
#    still exit 0, and no `gh` call at all.
rm -f "$TMP/gh-call-args"
cat > "$TMP/bin/gh" <<EOF
#!/bin/sh
echo "\$@" > "$TMP/gh-call-args"
EOF
chmod +x "$TMP/bin/gh"
out=$( PATH="$TMP/bin:$PATH" bash "$TARGET" nosuchremote 42 "$(date +%s)" fix - 4000 1 2 3 4 5 6 2>&1 )
exit_code=$?
case "$out" in
    "[WARN] ai-metrics comment failed"*) chk "bad remote: warns" "match" "match" ;;
    *) chk "bad remote: warns" "$out" "[WARN] ai-metrics comment failed (...)" ;;
esac
chk "bad remote: exit 0 (soft-fail)" "$exit_code" "0"
chk "bad remote: no gh call" "$([ -f "$TMP/gh-call-args" ] && echo called || echo not-called)" "not-called"

exit "$FAIL"
