#!/usr/bin/env bash
# Guard for gh-flow:waves's pinned contract (#64), until a Stop hook matches it.
#
#   bash tests/waves-contract.sh
#
# 1. The terminal strings stay pinned in report-template.md (hook contract).
# 2. The coordinator never invokes gh-flow:issue (NF-1, #39): no
#    Skill(gh-flow:issue ...) call anywhere in skills/waves/ outside the worker
#    brief, whose workers are the only callers.
# 3. Triage, not promote-everything (F-1, F-2): the waves fill of the brief
#    names gh-flow:wave's shared references/triage.md and carries the
#    fixed-in-place:/declined: report lines; skills/waves/ never points at
#    the deleted promotion.md; triage.md is the single copy and covers waves.
# 4. This run's follow-ups stay out of requery (F-3): the Filed-by-run marker
#    is written by workers and the coordinator and dropped by plan.md §1.
# 5. Run caps (F-4): --max-issues / --max-waves with their defaults.
# 6. Live failures follow triage (F-5): real defect only.
# 7. Fresh base before every spawn (F-6): pull --ff-only and its stopped ending.
# 8. drain is gone (#65): skills/drain/ absent, no live reference to it under
#    skills/, and blocked.md lives here and is what wave and waves point at.
set -euo pipefail
cd -- "$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
say() { printf '%s\n' "$*"; }
need() { # need <file> <fixed string> <what>
    grep -qF -- "$2" "$1" || { say "FAIL  $3: '$2' missing from $1"; fail=1; }
}

r=skills/waves/references
for s in 'gh-flow:waves complete' 'gh-flow:waves stopped —'; do
    need "$r/report-template.md" "$s" 'terminal string'
done

if grep -rnE 'Skill\(gh-flow:issue' skills/waves/ | grep -v "^$r/worker-brief.md:"; then
    say 'FAIL  skills/waves/ coordinator invokes gh-flow:issue (NF-1)'; fail=1
fi

b=$r/worker-brief.md
t=skills/wave/references/triage.md
grep -qxF -- '6. <PROMOTION_RULE>' "$b" || { say "FAIL  '6. <PROMOTION_RULE>' missing from $b"; fail=1; }
need "$b" "gh-flow:wave's references/triage.md (shared by wave and waves)" 'waves fill'
for s in 'fixed-in-place:' 'declined:' 'Filed-by-run: waves #<T>'; do
    # The waves fill is the paragraph that opens with the gh-flow:waves bullet.
    awk '/^- `gh-flow:waves` — /{on=1} /^- `gh-flow:wave` — /{on=0} on' "$b" | grep -qF -- "$s" ||
        { say "FAIL  waves fill in $b lacks '$s'"; fail=1; }
done
if grep -rnF 'promotion.md' skills/waves/; then
    say "FAIL  skills/waves/ still points at the deleted promotion.md (#64)"; fail=1
fi
[ ! -e "$r/triage.md" ] || { say "FAIL  $r/triage.md is a second copy of $t"; fail=1; }
for s in 'gh-flow:wave / gh-flow:waves' 'Filed-by-run: waves #<T>' 'gh-verify:live'; do
    need "$t" "$s" 'shared triage'
done
need "$r/constraints.md" "gh-flow:wave\`'s \`references/triage.md\`" 'constraints triage'

for f in "$r/plan.md" "$r/barrier.md" "$r/report-template.md" "$r/constraints.md" "$r/help.md"; do
    need "$f" 'Filed-by-run: waves #<T>' 'requery marker'
done
need "$r/plan.md" 'Filed-by-run: waves #([0-9]+)[ \t\r]*(?=\n|$)' 'requery drop'
need "$r/plan.md" 'unless `--issues`' 'requery drop override'
need "$r/report-template.md" 'filed this run' 'final report'
need "$r/report-template.md" 'capped' 'final report'

for s in '`--max-issues N` | `20`' '`--max-waves W` | `5`'; do
    need "$r/help.md" "$s" 'run cap'
done
need skills/waves/SKILL.md '[--max-issues 20] [--max-waves 5]' 'usage line'
need "$r/constraints.md" '`--max-issues N` (default `20`)' 'run cap'
need "$r/constraints.md" '`--max-waves W` (default `5`)' 'run cap'

need "$r/barrier.md" 'only a **real defect** is filed' 'live triage'
need "$r/barrier.md" '**trivial difference**' 'live triage'

for f in skills/waves/SKILL.md "$r/plan.md" "$r/constraints.md"; do
    need "$f" 'git pull --ff-only "$REMOTE"' 'pre-spawn pull'
    need "$f" 'gh-flow:waves stopped — base not fast-forwardable (<reason>)' 'pre-spawn stop'
done
need "$r/plan.md" 'the first wave included' 'first-wave pull'
need "$r/report-template.md" 'gh-flow:waves stopped — base not fast-forwardable (<reason>)' 'stopped ending'

# Run plan.md's own marker regex, not a copy, on sample bodies: CRLF, null
# body, #18 vs #180, trailing text after the number.
re=$(sed -n 's/.*match("\(.*\)"; "g").*/\1/p' "$r/plan.md")
if [ -z "$re" ]; then
    say "FAIL  marker regex not found in $r/plan.md"; fail=1
elif command -v jq >/dev/null; then
    got=$(jq -rc --arg re "$re" '[.[] | [(.body // "") | match($re; "g")
        | .captures[0].string | tonumber]]' <<'JSON'
[{"body":"x\nFiled-by-run: waves #180\r\ny"},{"body":null},
 {"body":"Filed-by-run: waves #18"},{"body":"Filed-by-run: waves #180 extra"}]
JSON
)
    [ "$got" = '[[180],[],[18],[]]' ] ||
        { say "FAIL  marker regex in $r/plan.md: got $got, want [[180],[],[18],[]]"; fail=1; }
fi

[ ! -e skills/drain ] || { say 'FAIL  skills/drain/ still exists (#65)'; fail=1; }
if grep -rnE 'gh-flow:drain|skills/drain' skills/; then
    say 'FAIL  skills/ still points at the deleted gh-flow:drain (#65)'; fail=1
fi
[ -f "$r/blocked.md" ] || { say "FAIL  $r/blocked.md missing (#65)"; fail=1; }
for f in skills/waves/SKILL.md "$r/barrier.md" skills/wave/SKILL.md skills/wave/references/constraints.md; do
    need "$f" 'references/blocked.md' 'blocked form'
done
need "$r/plan.md" 'A failure here stops the run before the wave starts' 'list-query stop'

[ "$fail" = 0 ] && say 'OK    waves contract' || exit 1
