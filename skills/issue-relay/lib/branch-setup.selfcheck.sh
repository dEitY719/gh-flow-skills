#!/usr/bin/env bash
# Self-check for lib/branch-setup.sh. No framework, no fixtures:
#
#   bash skills/issue-relay/lib/branch-setup.selfcheck.sh
#
# Runs against a throwaway git repo with a real local bare "remote" (via
# `url.<path>.insteadOf`, so `git fetch`/`git ls-remote` are fully offline
# while `git config --get remote.*.url` still reports the github-shaped URL
# the host/repo parser needs) and a fake `gh` in PATH. No network, no gh
# auth, no dotfiles checkout. Exits non-zero on the first regressed behaviour.
set -u

# shellcheck disable=SC1091  # path is resolved at runtime
. "$(dirname -- "$0")/selfcheck-common.sh"
TARGET="$ROOT/skills/issue-relay/lib/branch-setup.sh"

# --- 1. _bs_slugify unit tests (the non-determinism the audit flagged) -----
# shellcheck disable=SC1090
BRANCH_SETUP_LIB_ONLY=1 . "$TARGET"
got=$(_bs_slugify 'feat(skills): gh-flow:issue-relay 신설 + gh-flow:relay-merge push-probe 버그 수정')
chk "slugify: non-ascii/punctuation collapse to hyphens, cut to 50 chars" "$got" "feat-skills-gh-flow-issue-relay-gh-flow-relay-merg"
got=$(_bs_slugify 'Already-Hyphenated---Title!!')
chk "slugify: repeat separators collapse to one hyphen" "$got" "already-hyphenated-title"
got=$(_bs_slugify '  leading and trailing spaces  ')
chk "slugify: leading/trailing separators trimmed" "$got" "leading-and-trailing-spaces"
got=$(_bs_slugify "$(printf 'a%.0s' $(seq 1 80))")
chk "slugify: truncated to 50 chars" "$got" "$(printf 'a%.0s' $(seq 1 50))"
got=$(_bs_slugify 'idempotent-run')
got2=$(_bs_slugify 'idempotent-run')
chk "slugify: same title -> same slug across runs" "$got" "$got2"

# --- fixtures for the integration tests below -------------------------------
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT

git init -q --bare "$TMP/bare.git"
git -C "$TMP/bare.git" symbolic-ref HEAD refs/heads/main
mkdir -p "$TMP/seed"
git -C "$TMP/seed" init -q
git -C "$TMP/seed" config user.email a@b.c
git -C "$TMP/seed" config user.name test
git -C "$TMP/seed" commit -q --allow-empty -m init
git -C "$TMP/seed" branch -M main
git -C "$TMP/seed" push -q "$TMP/bare.git" main

mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'EOF'
#!/bin/sh
# Fake `gh` for the offline self-check: only understands the one call
# branch-setup.sh makes (`gh issue view <N> --repo <repo> --json title -q
# .title`), and just prints the raw title text `-q .title` would yield.
if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
    echo "feat: sample issue title"
    exit 0
fi
echo "unexpected gh call: $*" >&2
exit 1
EOF
chmod +x "$TMP/bin/gh"

mkdir -p "$TMP/work"
git -C "$TMP/work" init -q

# --- 2. missing remote: hard error, no fallback -----------------------------
out=$(cd "$TMP/work" && bash "$TARGET" nosuchremote 1 2>&1 >/dev/null)
rc=$?
case "$out" in
    "[gh-flow:issue-relay] remote 'nosuchremote' not found."*) msg_ok=yes ;;
    *) msg_ok=no ;;
esac
chk "missing remote: exits non-zero" "$rc" "1"
chk "missing remote: error names the remote, no silent fallback" "$msg_ok" "yes"

# --- 3. happy path: github.com remote, offline via insteadOf ----------------
git -C "$TMP/work" remote add origin https://github.com/acme/widget.git
git -C "$TMP/work" config --add "url.$TMP/bare.git.insteadOf" https://github.com/acme/widget.git

got=$(cd "$TMP/work" && PATH="$TMP/bin:$PATH" bash "$TARGET" origin 42 2>"$TMP/err.log")
eval "$got"
chk "happy path: DEST_REPO from the remote URL" "${DEST_REPO:-}" "acme/widget"
chk "happy path: DEST_HOST from the remote URL" "${DEST_HOST:-}" "github.com"
chk "happy path: BASE_BRANCH auto-detected from the bare repo's HEAD" "${BASE_BRANCH:-}" "main"
chk "happy path: BRANCH is issue-<N>-<slug>" "${BRANCH:-}" "issue-42-feat-sample-issue-title"

# --- 4. --base skips detection, still fetches that branch -------------------
git -C "$TMP/seed" checkout -q -b develop
git -C "$TMP/seed" commit -q --allow-empty -m develop-work
git -C "$TMP/seed" push -q "$TMP/bare.git" develop

got=$(cd "$TMP/work" && PATH="$TMP/bin:$PATH" bash "$TARGET" origin 42 --base develop 2>"$TMP/err.log")
eval "$got"
chk "--base override: BASE_BRANCH is the given branch" "${BASE_BRANCH:-}" "develop"
git -C "$TMP/work" show-ref -q refs/remotes/origin/develop
chk "--base override: that branch was actually fetched" "$?" "0"

# --- 5. GHE remote: host follows the URL, not a hard-coded default ---------
git -C "$TMP/work" remote add ghes https://github.samsungds.net/acme/widget.git
git -C "$TMP/work" config --add "url.$TMP/bare.git.insteadOf" https://github.samsungds.net/acme/widget.git

got=$(cd "$TMP/work" && PATH="$TMP/bin:$PATH" DOTFILES_ROOT=/nonexistent-dotfiles CLAUDE_PLUGIN_ROOT="$ROOT" \
      bash "$TARGET" ghes 42 2>"$TMP/err.log")
eval "$got"
chk "GHE remote: DEST_HOST follows the remote URL" "${DEST_HOST:-}" "github.samsungds.net"

exit "$FAIL"
