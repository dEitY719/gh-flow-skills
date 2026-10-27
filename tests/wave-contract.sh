#!/usr/bin/env bash
# Guard for gh-flow:wave's pinned contract (#58), until a Stop hook matches it.
#
#   bash tests/wave-contract.sh
#
# 1. The terminal strings stay pinned in report-template.md (hook contract).
# 2. The coordinator never invokes gh-flow:issue (NF-1, #39): no
#    Skill(gh-flow:issue ...) call anywhere in skills/wave/.
# 3. No recursive self-invocation (F-6): no Skill(gh-flow:wave ...) call except
#    in a line that forbids it.
# 4. Triage, not promote-everything (#62): triage.md names its three branches,
#    the wave fill of the brief carries the fixed-in-place:/declined: report
#    lines and skills/wave/ never points at the deleted promotion.md. The waves
#    fill of the shared brief is pinned by tests/waves-contract.sh (#64).
# 5. Fresh base before each spawn (#62): pull --ff-only and its stopped ending.
# 6. Reuse mode + --no-enter spawn (#71): every worktree-spawn call in wave and
#    waves passes --no-enter, MAIN comes from --git-common-dir, and the two
#    reuse-mode endings stay pinned.
# 7. One verification point (#74): constraints say the merge passes
#    --no-post-verify (the brief checks are in waves-contract.sh).
set -euo pipefail
cd -- "$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
say() { printf '%s\n' "$*"; }

for s in 'gh-flow:wave complete' 'gh-flow:wave stopped —'; do
    grep -qF -- "$s" skills/wave/references/report-template.md ||
        { say "FAIL  '$s' missing from skills/wave/references/report-template.md"; fail=1; }
done

if grep -rnE 'Skill\(gh-flow:issue' skills/wave/; then
    say 'FAIL  skills/wave/ invokes gh-flow:issue (coordinator NF-1)'; fail=1
fi

if grep -rnE 'Skill\(gh-flow:wave' skills/wave/ | grep -vE '금지|never'; then
    say 'FAIL  skills/wave/ invokes itself recursively (F-6)'; fail=1
fi

t=skills/wave/references/triage.md
if [ -f "$t" ]; then
    for s in 'fix-in-place' 'declined' 'child issue' 'Spawned-from: #<N>'; do
        grep -qF -- "$s" "$t" || { say "FAIL  '$s' missing from $t"; fail=1; }
    done
else
    say "FAIL  $t missing"; fail=1
fi

b=skills/waves/references/worker-brief.md
for s in 'fixed-in-place:' 'declined:'; do
    grep -qF -- "$s" "$b" ||
        { say "FAIL  report line '$s' missing from the wave brief"; fail=1; }
done

if grep -rnF 'promotion.md' skills/wave/; then
    say "FAIL  skills/wave/ still points at the deleted promotion.md (#62)"; fail=1
fi

grep -qxF -- '6. <PROMOTION_RULE>' "$b" || { say "FAIL  '6. <PROMOTION_RULE>' missing from $b"; fail=1; }

grep -qF -- "by gh-flow:wave's references/triage.md" "$b" ||
    { say "FAIL  the wave fill in $b does not name gh-flow:wave's references/triage.md"; fail=1; }

for f in skills/wave/SKILL.md skills/wave/references/constraints.md; do
    grep -qF -- 'git symbolic-ref --short HEAD' "$f" ||
        { say "FAIL  the not-on-<base> check (symbolic-ref) missing from $f"; fail=1; }
done

grep -qF -- 'pull --ff-only' skills/wave/SKILL.md ||
    { say "FAIL  'pull --ff-only' missing from skills/wave/SKILL.md"; fail=1; }
grep -qF -- 'gh-flow:wave stopped — base not fast-forwardable' skills/wave/references/report-template.md ||
    { say 'FAIL  base not fast-forwardable ending missing from report-template.md'; fail=1; }

if grep -rnE 'Skill\(session:worktree-spawn, "' skills/wave/ skills/waves/ | grep -vF -- '"--no-enter '; then
    say 'FAIL  a worktree-spawn call above lacks --no-enter (#71)'; fail=1
fi
for f in skills/wave/SKILL.md skills/waves/references/plan.md; do
    grep -qF -- 'Skill(session:worktree-spawn, "--no-enter' "$f" ||
        { say "FAIL  --no-enter spawn missing from $f (#71)"; fail=1; }
done
for f in skills/wave/SKILL.md skills/wave/references/spawn.md skills/wave/references/lineage.md; do
    grep -qF -- '--git-common-dir' "$f" ||
        { say "FAIL  MAIN from --git-common-dir missing from $f (#71)"; fail=1; }
done
for s in 'gh-flow:wave stopped — running in an unrelated worktree' 'gh-flow:wave stopped — worktree not rebasable onto <base>'; do
    for f in skills/wave/references/report-template.md skills/wave/references/spawn.md; do
        grep -qF -- "$s" "$f" || { say "FAIL  '$s' missing from $f (#71)"; fail=1; }
    done
done

# The reuse-mode branch regex, from spawn.md with <N>=71: a table, not a grep.
re=$(sed -n 's/.*grep -Eqx "\(wt\/issue-<N>[^"]*\)".*/\1/p' skills/wave/references/spawn.md)
[ -n "$re" ] || { say 'FAIL  reuse-mode branch regex not found in spawn.md (#71)'; fail=1; }
re=${re//<N>/71}
for row in 'wt/issue-71/1:y' 'wt/claude/1-issue-71:y' 'wt/claude/1-issue-7:n' 'wt/issue-710/1:n' \
    'wt/claude/1-issue-171:n' 'wt/claude/1-issue-711:n' ':n' 'main:n'; do
    b=${row%:*}; want=${row##*:}
    printf '%s\n' "$b" | grep -Eqx "$re" && got=y || got=n
    [ "$got" = "$want" ] || { say "FAIL  branch '$b': reuse regex says $got, want $want (#71)"; fail=1; }
done

# One verification point (#74): the shared brief's --no-post-verify merge and
# the gh-pr:merge sweep over skills/wave/ + skills/waves/ live in waves-contract.sh.
grep -qF -- '--no-post-verify' skills/wave/references/constraints.md ||
    { say "FAIL  single verification point (--no-post-verify) missing from skills/wave/references/constraints.md (#74)"; fail=1; }

[ "$fail" = 0 ] && say 'OK    wave contract' || exit 1
