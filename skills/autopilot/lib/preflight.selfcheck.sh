#!/usr/bin/env bash
# Self-check for lib/preflight.sh (#50). No network:
#
#   bash skills/autopilot/lib/preflight.selfcheck.sh
#
# Temp git repos (a bare "origin" plus a clone) drive the three arms:
# default-branch refusal, missing spec, and the happy path.
set -u
T="$(cd -- "$(dirname -- "$0")" && pwd)/preflight.sh"
FAIL=0
chk() { # chk <label> <got> <want>
    if [ "$2" = "$3" ]; then echo "ok    $1"; else echo "FAIL  $1: got '$2' want '$3'"; FAIL=1; fi
}

TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_NOSYSTEM=1 HOME="$TMP/home"
mkdir -p "$HOME"
git config --global user.email t@t && git config --global user.name t
git config --global init.defaultBranch main

git init -q --bare "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/w" 2>/dev/null
cd "$TMP/w" || exit 1
git commit -q --allow-empty -m init && git push -q origin HEAD:main 2>/dev/null
git remote set-head origin main

# 1. On the default branch: refused, exit 2, [FAIL] is the last line.
out=$(sh "$T" 2>&1); rc=$?
chk "default branch (rc)" "$rc" 2
chk "default branch (last line)" "$(printf '%s\n' "$out" | tail -n 1)" \
    "[FAIL] gh-flow:autopilot preflight: on the default branch 'main' — run from a feature branch in a dedicated worktree"

# 2. Feature branch, no spec anywhere / named spec missing: refused.
git checkout -q -b feat
out=$(sh "$T" 2>&1); rc=$?
chk "no spec (rc)" "$rc" 2
chk "no spec (out)" "$out" "branch=feat
default_branch=main
spec=none
[FAIL] gh-flow:autopilot preflight: no docs/superpowers/specs/*-design.md found — pass [spec-path]"
out=$(sh "$T" docs/missing.md 2>&1); rc=$?
chk "named spec missing (rc)" "$rc" 2
chk "named spec missing (last line)" "$(printf '%s\n' "$out" | tail -n 1)" \
    "[FAIL] gh-flow:autopilot preflight: spec not found: docs/missing.md"

# 3. Happy path: newest spec by name is auto-detected; an explicit one wins.
mkdir -p docs/superpowers/specs
: > docs/superpowers/specs/2026-01-02-a-design.md
: > docs/superpowers/specs/2026-03-04-b-design.md
out=$(sh "$T" 2>&1); rc=$?
chk "auto spec (rc)" "$rc" 0
chk "auto spec (out)" "$out" "branch=feat
default_branch=main
spec=$TMP/w/docs/superpowers/specs/2026-03-04-b-design.md"
out=$(sh "$T" docs/superpowers/specs/2026-01-02-a-design.md 2>&1); rc=$?
chk "explicit spec (rc)" "$rc" 0
chk "explicit spec (line)" "$(printf '%s\n' "$out" | tail -n 1)" \
    "spec=docs/superpowers/specs/2026-01-02-a-design.md"

# 4. Without origin/HEAD the default still resolves via origin/main.
git remote set-head origin -d
out=$(git checkout -q main && sh "$T" 2>&1); rc=$?
chk "no origin/HEAD falls back to origin/main" "$rc" 2

exit "$FAIL"
