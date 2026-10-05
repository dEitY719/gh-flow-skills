#!/bin/sh
# gh-flow:autopilot preconditions (#50), checked before Step 0a.
#
#   sh "$CLAUDE_PLUGIN_ROOT/skills/autopilot/lib/preflight.sh" [spec-path] [remote]
#
# (a) cwd is inside a git work tree on a named branch that is not <remote>'s
#     default branch (<remote> defaults to origin; default branch from
#     refs/remotes/<remote>/HEAD, else <remote>/main, else <remote>/master).
# (b) spec: [spec-path] must exist; without it, the newest
#     docs/superpowers/specs/*-design.md by name (references/help.md).
#
# Prints key=value lines: branch=, default_branch=, spec=<path|none>.
# Failure: last line `[FAIL] gh-flow:autopilot preflight: <reason>`, exit 2.
# "Installed atomic skills" is NOT checked here: the skill list belongs to the
# harness and a shell cannot see it — SKILL.md keeps it as a model judgment.
#
# Self-check: lib/preflight.selfcheck.sh
set -u

fail() {
    printf '[FAIL] gh-flow:autopilot preflight: %s\n' "$1"
    exit 2
}

spec_arg=${1:-}
remote=${2:-origin}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside a git work tree"
branch=$(git symbolic-ref --short -q HEAD) || fail "detached HEAD — check out a feature branch"
printf 'branch=%s\n' "$branch"

default=$(git symbolic-ref --short -q "refs/remotes/$remote/HEAD" 2>/dev/null) || default=
default=${default#"$remote"/}
if [ -z "$default" ]; then
    for b in main master; do
        git show-ref --verify -q "refs/remotes/$remote/$b" && { default=$b; break; }
    done
fi
[ -n "$default" ] || fail "cannot determine the default branch of remote '$remote'"
printf 'default_branch=%s\n' "$default"
[ "$branch" != "$default" ] || fail "on the default branch '$default' — run from a feature branch in a dedicated worktree"

if [ -n "$spec_arg" ]; then
    [ -f "$spec_arg" ] || { printf 'spec=none\n'; fail "spec not found: $spec_arg"; }
    spec=$spec_arg
else
    top=$(git rev-parse --show-toplevel)
    spec=
    for f in "$top"/docs/superpowers/specs/*-design.md; do  # glob order = name order
        [ -f "$f" ] && spec=$f
    done
    [ -n "$spec" ] || { printf 'spec=none\n'; fail "no docs/superpowers/specs/*-design.md found — pass [spec-path]"; }
fi
printf 'spec=%s\n' "$spec"
