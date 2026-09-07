#!/bin/sh
# lib/post-ai-metrics.sh — gh-flow:issue Step 2.6 (soft-fail): post the
# flow-level aggregate ai-metrics comment on the linked Issue. Mechanizes the
# arithmetic and template rendering; issue-type parsing and (for `feat`) size
# inference stay the executing agent's job — both need reading the issue
# title/diff, not a fixed lookup. Full procedure: references/ai-metrics-step.md.
#
# Usage:
#   post-ai-metrics.sh <remote> <issue-number> <start-ts> <issue-type> \
#       <feat-size> <token-chars> <impl-min> <commit-min> <pr-min> \
#       <review-min> <conflict-min> <outdated-min>
#
# <remote>       literal value from Step 1's own arg parsing — never a live
#                $REMOTE env read (a Bash tool call is not guaranteed to
#                inherit an earlier call's exports, dEitY719/dotfiles#1498).
# <issue-type>   one of feat|fix|refactor|docs|chore|perf|test|misc, parsed
#                by the agent from the issue title's conventional-commit
#                prefix; unrecognized values fall back to misc.
# <feat-size>    small|medium|large, only meaningful when <issue-type>=feat
#                (agent's size inference); pass `-` otherwise.
# <token-chars>  character count of (issue body + implementation file reads);
#                this script divides by 4, rounds to the nearest 500, floors
#                at 1000.
# <*-min>        elapsed minutes for each of the six sub-skills, or `?` for
#                any not yet measured — passed straight into the template.
#
# Requires TARGET_REPO/TARGET_HOST via lib/target-binding.sh, sourced here
# fresh from <remote> rather than trusting an earlier call's exports
# (dEitY719/dotfiles#1498, PR dEitY719/dotfiles#1539 review).
# Skips entirely under GH_DISABLE_AI_METRICS=1 (dEitY719/dotfiles#399).
#
# Exit 0 always (soft-fail) — prints "[WARN] ai-metrics comment failed
# (<reason>) — continuing." on any error instead of blocking the flow.
#
# Self-check: lib/post-ai-metrics.selfcheck.sh
set -u

_LIB_DIR=$(cd -- "$(dirname -- "$0")" && pwd)

REMOTE=${1:?remote required}
ISSUE_NUMBER=${2:?issue number required}
START_TS=${3:?start-ts required}
ISSUE_TYPE=${4:-misc}
FEAT_SIZE=${5:--}
TOKEN_CHARS=${6:-4000}
IMPL_MIN=${7:-?}
COMMIT_MIN=${8:-?}
PR_MIN=${9:-?}
REVIEW_MIN=${10:-?}
CONFLICT_MIN=${11:-?}
OUTDATED_MIN=${12:-?}

if [ "${GH_DISABLE_AI_METRICS:-0}" = "1" ]; then
    exit 0
fi

_TB_LOG=$(mktemp)
# shellcheck disable=SC1091  # path is resolved at runtime
if ! GH_FLOW_TARGET_REMOTE="$REMOTE" . "$_LIB_DIR/target-binding.sh" 2>"$_TB_LOG"; then
    printf '[WARN] ai-metrics comment failed (%s) — continuing.\n' "$(tr '\n' ' ' < "$_TB_LOG" | sed 's/ *$//')"
    rm -f "$_TB_LOG"
    exit 0
fi
rm -f "$_TB_LOG"

ELAPSED=$(( ($(date +%s) - START_TS) / 60 ))

# Human-time baseline (gh-issue:create's references/metrics-baseline.md).
case "$ISSUE_TYPE" in
    feat)
        case "$FEAT_SIZE" in
            small) HUMAN_H=4 ;;
            large) HUMAN_H=24 ;;
            *) HUMAN_H=8 ;; # medium is the default for a non-trivial feat
        esac
        ;;
    fix) HUMAN_H=2 ;;
    refactor) HUMAN_H=4 ;;
    docs) HUMAN_H=1 ;;
    chore) HUMAN_H=0.5 ;;
    perf) HUMAN_H=3 ;;
    test) HUMAN_H=2 ;;
    *) HUMAN_H=2 ;; # misc / unrecognized
esac

TOKENS=$(awk -v c="$TOKEN_CHARS" 'BEGIN {
    t = c / 4
    r = int((t + 250) / 500) * 500
    if (r < 1000) r = 1000
    printf "%d", r
}')

# Body goes through a temp file (`-f body=@file`), not an inline
# interpolated `-f body="..."` argument — agy review of PR #4: an inline
# value composed from several separately-sourced fields is exactly the
# shape that breaks if any of them ever starts with `@` (gh's own
# from-file marker) or otherwise collides with `-f`'s value parsing.
# `@file` sidesteps that class entirely rather than trying to enumerate
# which characters are currently safe.
_BODY_FILE=$(mktemp)
trap 'rm -f "$_BODY_FILE"' EXIT
cat > "$_BODY_FILE" <<EOF
### gh-flow:issue 완료

| 단계 | AI 소요 |
|------|---------|
| gh-issue:implement | ~${IMPL_MIN} min |
| gh-pr:commit | ~${COMMIT_MIN} min |
| gh-pr:create | ~${PR_MIN} min |
| gh-verify:review-all (gate + pr-reply) | ~${REVIEW_MIN} min |
| gh-resolve:conflict | ~${CONFLICT_MIN} min |
| gh-resolve:outdated | ~${OUTDATED_MIN} min |
| **합계** | **~$ELAPSED min** |

예상 사람 시간: ~$HUMAN_H h · 토큰: ~$TOKENS

---
<details>
<summary>AI Metrics · tokens=~$TOKENS · human_h=~$HUMAN_H · ai_min=~$ELAPSED</summary>

<!-- ai-metrics:gh-flow-issue -->
AI Metrics tokens=~$TOKENS human_h=~$HUMAN_H ai_min=~$ELAPSED
<!-- /ai-metrics:gh-flow-issue -->

</details>
EOF

if ! GH_HOST="$TARGET_HOST" gh api "repos/$TARGET_REPO/issues/$ISSUE_NUMBER/comments" \
    -X POST \
    -f body="@$_BODY_FILE" >/dev/null 2>&1
then
    printf '[WARN] ai-metrics comment failed (gh api post to issue #%s failed) — continuing.\n' "$ISSUE_NUMBER"
fi
exit 0
