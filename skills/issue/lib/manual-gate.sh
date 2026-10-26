#!/bin/sh
# lib/manual-gate.sh — the exclude-label gate shared by gh-flow:issue (Step 1.5),
# gh-flow:wave (before each spawn, and at descendant queueing) and
# gh-flow:waves (plan.md §1 drop list) (dEitY719/gh-flow-skills#70 F-1).
# One verdict, one place: an issue carrying an exclude label is human-only work
# (a runbook, another machine's local setup) and must be skipped BEFORE any
# worktree, worker or chain starts.
#
# EXECUTE it, never source it — the verdict is stdout, not an export:
#
#   labels=$(GH_HOST="$TARGET_HOST" gh issue view <N> --repo "$TARGET_REPO" \
#       --json labels --jq '.labels[].name' 2>/dev/null); rc=$?
#   verdict=$(printf '%s\n' "$labels" | sh "$gate" "$rc")
#
# A coordinator that already holds the labels (waves' list query) passes rc 0.
#
# Input   the issue's label names on stdin, one per line (CRLF tolerated).
# Args    $1 — exit status of the label lookup (default 0). Non-zero means the
#         labels are unknown: the verdict is `skip lookup-failed`, never
#         `pass` (NF-1 — starting a human-only issue costs more than skipping
#         one, so a failed lookup is not fail-open).
# Reads   GH_FLOW_EXCLUDE_LABELS — comma-separated exclude set (F-2). Unset
#         means the default `wontfix,not-implement,manual`; set-but-empty means
#         an empty set, i.e. exclude nothing, because an explicit override is
#         honoured as written. Spaces around each comma are trimmed, tabs and
#         CRs anywhere are dropped; spaces inside a label name are kept.
# Output  one line: `pass` | `excluded <label>` | `skip lookup-failed`.
#         `<label>` is the first label (in input order) that is in the set.
# Exit    0 on every verdict — exclusion is a routing decision, not an error.
#         The exit 2 belongs to the caller (gh-flow:issue Step 1.5).
#
# Matching is whole-name equality (F-1): `manual-later` is not `manual`, and a
# glob character in a label or in the set is compared literally. Non-ASCII
# names (`수동`) match byte for byte.
#
# Self-check: lib/manual-gate.selfcheck.sh

case ${1:-0} in
    0) ;;
    *) printf 'skip lookup-failed\n'; exit 0 ;;
esac

# Tabs/CRs (an env value sourced from a CRLF .env) would silently never match.
_mg_set=$(printf '%s' "${GH_FLOW_EXCLUDE_LABELS-wontfix,not-implement,manual}" | tr -d '\t\r')

set -f  # the set is split unquoted below; never let `*` glob against the cwd
IFS=,    # only the set split uses IFS; `read` below overrides it per call
_mg_cr=$(printf '\r')
while IFS= read -r _mg_label || [ -n "$_mg_label" ]; do
    _mg_label=${_mg_label%"$_mg_cr"}
    [ -n "$_mg_label" ] || continue
    for _mg_x in $_mg_set; do
        _mg_x=${_mg_x#"${_mg_x%%[! ]*}"}  # trim leading spaces
        _mg_x=${_mg_x%"${_mg_x##*[! ]}"}  # trim trailing spaces
        if [ -n "$_mg_x" ] && [ "$_mg_x" = "$_mg_label" ]; then
            printf 'excluded %s\n' "$_mg_label"
            exit 0
        fi
    done
done

printf 'pass\n'
