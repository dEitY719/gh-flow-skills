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

[ "$fail" = 0 ] && say 'OK    wave contract' || exit 1
