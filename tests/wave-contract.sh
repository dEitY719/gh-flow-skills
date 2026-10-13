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
#    lines, skills/wave/ never points at drain's promotion.md, and the shared
#    brief keeps the waves fill of <PROMOTION_RULE> byte-identical.
# 5. Fresh base before each spawn (#62): pull --ff-only and its stopped ending.
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
    say "FAIL  skills/wave/ still points at drain's promotion.md (#62)"; fail=1
fi

grep -qxF -- '6. <PROMOTION_RULE>' "$b" || { say "FAIL  '6. <PROMOTION_RULE>' missing from $b"; fail=1; }
# The waves fill, as whole lines: the pre-#62 step 6, byte for byte.
for s in '6. File every deferred item (unfixed review finding, TODO/FIXME/ponytail:,' \
         '   skipped test, "follow-up") as an issue via `Skill(gh-issue:issue-create, ...)`,' \
         "   by the rules of gh-flow:drain's references/promotion.md."; do
    grep -qxF -- "$s" "$b" || { say "FAIL  waves fill line '$s' missing from $b"; fail=1; }
done

grep -qF -- 'pull --ff-only' skills/wave/SKILL.md ||
    { say "FAIL  'pull --ff-only' missing from skills/wave/SKILL.md"; fail=1; }
grep -qF -- 'gh-flow:wave stopped — base not fast-forwardable' skills/wave/references/report-template.md ||
    { say 'FAIL  base not fast-forwardable ending missing from report-template.md'; fail=1; }

[ "$fail" = 0 ] && say 'OK    wave contract' || exit 1
