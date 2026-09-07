#!/usr/bin/env bash
# Self-check for lib/relay.sh. No framework, no fixtures:
#
#   bash skills/relay-merge/lib/relay.selfcheck.sh
#
# Runs against a throwaway git repo with a real local bare "remote" and a
# fake `gh` in PATH — no network, no gh auth, no gist ever created. Exits
# non-zero on the first regressed behaviour.
set -u

# shellcheck disable=SC1091  # path is resolved at runtime
. "$(dirname -- "$0")/selfcheck-common.sh"
TARGET="$ROOT/skills/relay-merge/lib/relay.sh"

TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT

W="$TMP/work"
git init -q "$W"
git -C "$W" config user.email a@b.c
git -C "$W" config user.name test
git -C "$W" commit -q --allow-empty -m base
BASE=$(git -C "$W" rev-parse HEAD)

# blob <lines> — deterministic filler whose diff size is ~40 bytes/line.
blob() { yes 'lorem ipsum dolor sit amet consectetur adipis' | head -"$1"; }

# --- 1. patches: one whole patch per commit when everything fits -----------
echo hello >"$W/a.txt"
git -C "$W" add a.txt && git -C "$W" commit -q -m 'feat: add a'
echo world >"$W/b.txt"
git -C "$W" add b.txt && git -C "$W" commit -q -m 'feat: add b'

out=$(cd "$W" && bash "$TARGET" patches "$BASE..HEAD" "$TMP/o1" 2>"$TMP/err")
chk "patches: exit 0 on a range that fits" "$?" "0"
chk "patches: one PATCH row per commit" "$(printf '%s\n' "$out" | grep -c '^PATCH')" "2"
chk "patches: order labels are the format-patch slots" \
    "$(printf '%s\n' "$out" | awk -F'\t' '/^PATCH/ {printf "%s ", $2}')" "0001 0002 "
chk "patches: subject column is the commit subject" \
    "$(printf '%s\n' "$out" | awk -F'\t' '/^PATCH/ && $2=="0002" {print $5}')" "feat: add b"
chk "patches: no EXCLUDED rows when nothing was stripped" \
    "$(printf '%s\n' "$out" | grep -c '^EXCLUDED')" "0"

# --- 2. patches: empty range is an error, not a silent no-op ---------------
(cd "$W" && bash "$TARGET" patches "HEAD..HEAD" "$TMP/o2" >/dev/null 2>&1)
chk "patches: empty commit range exits non-zero" "$?" "1"

# --- 3. patches: generated-artifact exclusion shrinks an oversized patch ---
# The lock file is the bulk; stripping it must bring the patch under the cap
# and report the stripped path so Step 6 can record a regeneration command.
FROM3=$(git -C "$W" rev-parse HEAD)
blob 600 >"$W/package-lock.json"
blob 20 >"$W/small.py"
git -C "$W" add package-lock.json small.py && git -C "$W" commit -q -m 'chore: relock'

out=$(cd "$W" && RELAY_PATCH_MAX_BYTES=20000 bash "$TARGET" patches "$FROM3..HEAD" "$TMP/o3" 2>"$TMP/err")
rc=$?
chk "artifact exclusion: exit 0" "$rc" "0"
chk "artifact exclusion: the lock file is reported as stripped" \
    "$(printf '%s\n' "$out" | awk -F'\t' '/^EXCLUDED/ {print $3}')" "package-lock.json"
chk "artifact exclusion: still one whole patch, not a split" \
    "$(printf '%s\n' "$out" | awk -F'\t' '/^PATCH/ {print $2}')" "0001"
grep -q 'package-lock' "$(printf '%s\n' "$out" | awk -F'\t' '/^PATCH/ {print $4}')"
chk "artifact exclusion: the stripped diff is really gone from the patch" "$?" "1"

# --- 4. patches: file-group pre-split of an oversized non-artifact commit --
FROM4=$(git -C "$W" rev-parse HEAD)
blob 200 >"$W/big1.py"
blob 200 >"$W/big2.py"
git -C "$W" add big1.py big2.py && git -C "$W" commit -q -m 'feat: two big files'

out=$(cd "$W" && RELAY_PATCH_MAX_BYTES=14000 bash "$TARGET" patches "$FROM4..HEAD" "$TMP/o4" 2>"$TMP/err")
chk "pre-split: exit 0" "$?" "0"
chk "pre-split: one sub-patch per file group" \
    "$(printf '%s\n' "$out" | awk -F'\t' '/^PATCH/ {printf "%s ", $2}')" "0001-1 0001-2 "
over=$(printf '%s\n' "$out" | awk -F'\t' '/^PATCH/ && $3 > 14000 {print $2}')
chk "pre-split: every sub-patch is under the cap" "$over" ""
seq4=$(cd "$TMP/o4" && for p in *.patch; do printf '%s ' "$(printf '%s' "$p" | sed -E 's/^([0-9]+-[0-9]+).*/\1/')"; done)
chk "pre-split: sub-patches sort in apply order" "$seq4" "0001-1 0001-2 "
git -C "$W" checkout -q -b amtest "$FROM4"
(cd "$W" && git am -q "$TMP"/o4/*.patch >/dev/null 2>&1)
chk "pre-split: the sub-patches still git-am cleanly, in order" "$?" "0"
git -C "$W" checkout -q - && git -C "$W" branch -qD amtest

# --- 5. patches: a single oversized file stops the run, never truncates ----
FROM5=$(git -C "$W" rev-parse HEAD)
blob 600 >"$W/huge.py"
git -C "$W" add huge.py && git -C "$W" commit -q -m 'feat: one huge file'

(cd "$W" && RELAY_PATCH_MAX_BYTES=14000 bash "$TARGET" patches "$FROM5..HEAD" "$TMP/o5" >"$TMP/o5.out" 2>"$TMP/err")
chk "no-truncation: exits 3 rather than shipping a truncated patch" "$?" "3"
grep -q '^\[FAIL\]' "$TMP/err"
chk "no-truncation: stderr carries the [FAIL] verdict marker" "$?" "0"
grep -q 'Refusing to truncate' "$TMP/err"
chk "no-truncation: stderr says why" "$?" "0"
grep -q 'huge.py' "$TMP/err"
chk "no-truncation: stderr names the offending path" "$?" "0"

# --- 6. probe: push works -> blocked=no, and the probe ref is cleaned up ---
git init -q --bare "$TMP/bare.git"
git -C "$W" remote add dest "$TMP/bare.git"

out=$(cd "$W" && RELAY_PROBE_BACKOFF=0 bash "$TARGET" probe dest HEAD 2>/dev/null)
chk "probe: exit 0 when the push succeeds" "$?" "0"
chk "probe: reports blocked=no" "$(printf '%s\n' "$out" | head -1)" "blocked=no"
chk "probe: the throwaway ref is deleted by the trap, not left behind" \
    "$(git -C "$TMP/bare.git" for-each-ref --format='%(refname)' 'refs/heads/relay-probe-*')" ""
chk "probe: nothing but the probe ref was ever pushed" \
    "$(git -C "$TMP/bare.git" for-each-ref --format='%(refname)' | tr '\n' ' ')" ""

# --- 7. probe: a block signal is classified, anything else is inconclusive -
# RELAY_BLOCK_REGEX is the knob push-probe.md documents; pointing it at the
# error this offline fixture really produces exercises the same branch a
# corporate 403 block page would.
out=$(cd "$W" && RELAY_PROBE_BACKOFF=0 \
    RELAY_BLOCK_REGEX='does not appear to be a git repository' \
    bash "$TARGET" probe "$TMP/nonexistent" HEAD 2>/dev/null)
chk "probe: a matching block signal exits 0 with blocked=yes" "$?" "0"
chk "probe: reports blocked=yes" "$out" "blocked=yes"

(cd "$W" && RELAY_PROBE_BACKOFF=0 bash "$TARGET" probe "$TMP/nonexistent" HEAD >/dev/null 2>&1)
chk "probe: a non-block failure is inconclusive (exit 2), never a false block" "$?" "2"

# --- 8. upload: one file per gh gist create, sequential, rows as it goes ---
mkdir -p "$TMP/bin"
cat >"$TMP/bin/gh" <<'EOF'
#!/bin/sh
# Fake `gh` for the offline self-check. Logs its own argv so the caller can
# assert the one-file-per-call rule, and answers only the two calls
# relay.sh upload makes.
printf '%s\n' "$*" >>"$GH_CALL_LOG"
if [ "$1" = "gist" ] && [ "$2" = "create" ]; then
    echo "https://gist.github.com/tester/$(basename "$3" .patch)"
    exit 0
fi
if [ "$1" = "api" ]; then
    echo "https://gist.githubusercontent.com/tester/${2#gists/}/raw/x.patch"
    exit 0
fi
echo "unexpected gh call: $*" >&2
exit 1
EOF
chmod +x "$TMP/bin/gh"

export GH_CALL_LOG="$TMP/gh.log"
: >"$GH_CALL_LOG"
out=$(cd "$W" && PATH="$TMP/bin:$PATH" bash "$TARGET" upload github.com "$TMP/o1" 2>"$TMP/err")
chk "upload: exit 0" "$?" "0"
chk "upload: one row per patch" "$(printf '%s\n' "$out" | wc -l)" "2"
chk "upload: row is order/description/web-url/raw-url" \
    "$(printf '%s\n' "$out" | awk -F'\t' 'NR==2 {print $1"|"$2"|"NF}')" "0002|feat: add b|4"
chk "upload: exactly one file per gh gist create call" \
    "$(grep -c '^gist create [^ ]*\.patch --desc ' "$GH_CALL_LOG")" "2"
chk "upload: no multi-file gist call" \
    "$(grep -c '\.patch [^-]*\.patch' "$GH_CALL_LOG")" "0"

: >"$GH_CALL_LOG"
(cd "$W" && PATH="$TMP/bin:$PATH" bash "$TARGET" upload github.com "$TMP/empty-dir" >/dev/null 2>&1)
chk "upload: an empty patch dir is an error, not a silent success" "$?" "1"

exit "$FAIL"
