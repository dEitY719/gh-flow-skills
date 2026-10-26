#!/usr/bin/env bash
# Self-check for lib/manual-gate.sh. No framework, no fixtures:
#
#   bash skills/issue/lib/manual-gate.selfcheck.sh
#
# Labels arrive on stdin, the lookup status as $1 — no network, no gh auth.
set -u

# shellcheck disable=SC1091  # path is resolved at runtime
. "$(dirname -- "$0")/selfcheck-common.sh"
TARGET="$ROOT/skills/issue/lib/manual-gate.sh"

# The ambient shell may export a consumer's own set — unset it so the DEFAULT
# is what the unset-case assertions exercise.
unset GH_FLOW_EXCLUDE_LABELS

gate() { sh "$TARGET" "$@"; }

# 1. Default set: wontfix, not-implement, manual — exact names only.
chk "manual excluded" "$(printf 'bug\nmanual\n' | gate)" "excluded manual"
chk "wontfix excluded" "$(printf 'wontfix\n' | gate)" "excluded wontfix"
chk "not-implement excluded" "$(printf 'not-implement\n' | gate)" "excluded not-implement"
chk "TODO not in default" "$(printf 'TODO\n' | gate)" "pass"
chk "no labels pass" "$(printf '' | gate)" "pass"
chk "first match in label order" "$(printf 'wontfix\nmanual\n' | gate)" "excluded wontfix"

# 2. Whole-name equality: substrings, prefixes, case variants do not match.
chk "manual-later not manual" "$(printf 'manual-later\n' | gate)" "pass"
chk "semi-manual not manual" "$(printf 'semi-manual\n' | gate)" "pass"
chk "Manual case differs" "$(printf 'Manual\n' | gate)" "pass"

# 3. Non-ASCII label names match byte for byte.
chk "Korean label excluded" \
    "$(GH_FLOW_EXCLUDE_LABELS='수동,manual' gate <<<'수동')" "excluded 수동"
chk "Korean substring not matched" \
    "$(GH_FLOW_EXCLUDE_LABELS='수동' gate <<<'수동작업')" "pass"
chk "label with inner space" \
    "$(GH_FLOW_EXCLUDE_LABELS='on hold , manual' gate <<<'on hold')" "excluded on hold"

# 4. GH_FLOW_EXCLUDE_LABELS overrides the default (F-2).
chk "env replaces default" \
    "$(GH_FLOW_EXCLUDE_LABELS='TODO' gate <<<'manual')" "pass"
chk "env widens set" \
    "$(GH_FLOW_EXCLUDE_LABELS='wontfix,not-implement,manual,TODO' gate <<<'TODO')" "excluded TODO"
chk "empty env excludes nothing" \
    "$(GH_FLOW_EXCLUDE_LABELS='' gate <<<'manual')" "pass"
chk "empty set entries ignored" \
    "$(GH_FLOW_EXCLUDE_LABELS=',,manual,' gate <<<'manual')" "excluded manual"

# 5. Lookup failure skips — never fail-open (NF-1).
chk "lookup failure skips" "$(printf '' | gate 1)" "skip lookup-failed"
chk "lookup failure skips even with labels" "$(printf 'bug\n' | gate 4)" "skip lookup-failed"
chk "lookup rc 0 is evaluated" "$(printf 'bug\n' | gate 0)" "pass"

# 6. Glob characters are literal, CRLF is stripped, a missing final newline
#    still counts.
# Run the glob case where `*` WOULD expand (a dir holding a file named
# `manual`), so removing `set -f` turns this red.
_gd=$(mktemp -d)
: >"$_gd/manual"
chk "glob in set is literal" "$(cd "$_gd" && GH_FLOW_EXCLUDE_LABELS='*' gate <<<'manual')" "pass"
rm -rf "$_gd"
chk "tab/CR in env stripped" "$(GH_FLOW_EXCLUDE_LABELS=$'\tmanual\r' gate <<<'manual')" "excluded manual"
chk "glob label is literal" "$(printf '*\n' | gate)" "pass"
chk "CRLF stripped" "$(printf 'manual\r\n' | gate)" "excluded manual"
chk "no trailing newline" "$(printf 'manual' | gate)" "excluded manual"

# 7. Exit 0 on every verdict (header contract).
printf 'manual\n' | gate >/dev/null
chk "excluded verdict: exit 0" "$?" "0"
printf '' | gate 1 >/dev/null
chk "skip verdict: exit 0" "$?" "0"

exit "$FAIL"
