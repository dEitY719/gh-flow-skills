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
# agy review, PR #20 BLOCKER — claimed an issue title with quotes/backticks/$
# reaches the consumer's `eval` unescaped. It never does: only this function's
# output (BRANCH_SETUP_LIB_ONLY=1 lets us call it directly here) is printed
# for eval, and [^a-z0-9]+ -> '-' strips every shell metacharacter first.
# shellcheck disable=SC2016  # single-quoted on purpose: must NOT expand
got=$(_bs_slugify 'hostile "title"; $(rm -rf /tmp/should-never-run) `id`')
chk "slugify: quotes/\$()/backticks/; never survive into the slug" "$got" "hostile-title-rm-rf-tmp-should-never-run-id"

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
    if [ "$3" = "999" ]; then
        # Hostile title fixture for test 6 below (agy review, PR #20
        # BLOCKER): quotes/backticks/$(...) that would run a command or
        # break eval's quoting if it ever reached the printed BRANCH= line
        # unescaped. It never does — only the sanitized slug does.
        printf '%s\n' 'hostile "title"; $(rm -rf /tmp/should-never-run) `id`'
    else
        echo "feat: sample issue title"
    fi
    exit 0
fi
echo "unexpected gh call: $*" >&2
exit 1
EOF
chmod +x "$TMP/bin/gh"

mkdir -p "$TMP/work"
git -C "$TMP/work" init -q

# The vendored tier is what a standalone plugin install exercises, so pin
# DOTFILES_ROOT at a path that cannot exist and CLAUDE_PLUGIN_ROOT at this
# checkout for every invocation below — an ambient `$HOME/dotfiles` or
# `$CLAUDE_PLUGIN_ROOT` on the machine running this self-check must never
# make it pass by accident (CI has neither).
export DOTFILES_ROOT=/nonexistent-dotfiles

# run <args...> — invoke branch-setup.sh from $TMP/work with the fake gh
# and hermetic plugin-root env, then eval its DEST_REPO=/... output.
run() {
    got=$(cd "$TMP/work" && PATH="$TMP/bin:$PATH" CLAUDE_PLUGIN_ROOT="$ROOT" bash "$TARGET" "$@" 2>"$TMP/err.log")
    eval "$got"
}

# --- 2. missing remote: hard error, no fallback -----------------------------
out=$(cd "$TMP/work" && CLAUDE_PLUGIN_ROOT="$ROOT" bash "$TARGET" nosuchremote 1 2>&1 >/dev/null)
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

run origin 42
chk "happy path: DEST_REPO from the remote URL" "${DEST_REPO:-}" "acme/widget"
chk "happy path: DEST_HOST from the remote URL" "${DEST_HOST:-}" "github.com"
chk "happy path: BASE_BRANCH auto-detected from the bare repo's HEAD" "${BASE_BRANCH:-}" "main"
chk "happy path: BRANCH is issue-<N>-<slug>" "${BRANCH:-}" "issue-42-feat-sample-issue-title"

# --- 4. --base skips detection, still fetches that branch -------------------
git -C "$TMP/seed" checkout -q -b develop
git -C "$TMP/seed" commit -q --allow-empty -m develop-work
git -C "$TMP/seed" push -q "$TMP/bare.git" develop

run origin 42 --base develop
chk "--base override: BASE_BRANCH is the given branch" "${BASE_BRANCH:-}" "develop"
git -C "$TMP/work" show-ref -q refs/remotes/origin/develop
chk "--base override: that branch was actually fetched" "$?" "0"

# --- 5. GHE remote: host follows the URL, not a hard-coded default ---------
git -C "$TMP/work" remote add ghes https://github.samsungds.net/acme/widget.git
git -C "$TMP/work" config --add "url.$TMP/bare.git.insteadOf" https://github.samsungds.net/acme/widget.git

run ghes 42
chk "GHE remote: DEST_HOST follows the remote URL" "${DEST_HOST:-}" "github.samsungds.net"

# --- 6. hostile issue title, full pipeline: gh -> TITLE -> slugify -> eval --
# agy review, PR #20 BLOCKER — same claim as test 1's unit case, but through
# the real `gh issue view` -> $TITLE -> _bs_slugify -> printf -> eval path an
# actual run takes, not just a direct function call.
run origin 999
chk "hostile title end-to-end: BRANCH carries only the sanitized slug" \
    "${BRANCH:-}" "issue-999-hostile-title-rm-rf-tmp-should-never-run-id"
[ -e /tmp/should-never-run ]
chk "hostile title end-to-end: the embedded command never ran" "$?" "1"

# --- 7. capture-then-eval propagates a failing run's exit status -----------
# codex review, PR #20 FOLLOW-UP: cover the *documented* invocation contract
# itself (references/branch-setup.md's `_bs_out=$(...) || exit 1; eval
# "$_bs_out"`), not just the raw script's own exit code (test 3 above). The
# bug this guards against: `eval "$(bash ...)" || exit 1` — a failing run
# prints nothing, so eval "" exits 0 and `||` never fires.
rc=0
_bs_out=$(cd "$TMP/work" && CLAUDE_PLUGIN_ROOT="$ROOT" bash "$TARGET" nosuchremote 1 2>/dev/null) || rc=1
eval "$_bs_out"
chk "capture-then-eval: a failing run's exit status reaches the caller" "$rc" "1"

exit "$FAIL"
