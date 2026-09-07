# gh-flow:issue — Step 2.6: Post AI Metrics to Issue (soft-fail)

Runs only if Step 2.5.1 succeeded. Post a flow-level aggregate metrics
comment on the **linked GitHub Issue**. The PR body already carries the
per-step `<!-- ai-metrics:gh-pr -->` block written by `gh-pr:create`; this step
adds the total across all six sub-skills to the Issue so the Issue thread
is the single place to review full AI effort. (The post-PR quality gate
and deferred pr-reply are folded into Step 2.4 `gh-verify:review-all`, so its
row already covers that effort — there is no separate gate/schedule row.)
This step soft-fails — warn on any error but never block the flow.

The arithmetic, the human-time baseline lookup, the token-estimate rounding
and the `gh api` post are all mechanized in `lib/post-ai-metrics.sh` — its
own header documents inputs/outputs in full. What stays the executing
agent's job is the two judgment calls a fixed script cannot make:

a. Track per-step timing by recording `STEP_TS=$(date +%s)` at the start of
   each sub-skill and computing its elapsed minutes at the end — `IMPL_MIN`
   (2.1), `COMMIT_MIN` (2.2), `PR_MIN` (2.3), `REVIEW_MIN` (2.4),
   `CONFLICT_MIN` (2.5), `OUTDATED_MIN` (2.5.1). Pass `?` for any not yet
   measured.
b. Parse the conventional-commit prefix from the issue title fetched in
   Step 2.1 (`feat`, `fix`, `refactor`, `docs`, `chore`, `perf`, `test`;
   anything else is `misc`).
c. For `feat` only: infer size (`small`/`medium`/`large`) from the
   implementation scope — components touched, diff weight, architectural
   footprint (`gh-issue:create`'s `references/metrics-baseline.md`, same
   heuristic `gh-issue:create` itself applies). Pass `-` for every other
   type.
d. Character count of (issue body + implementation file reads) as
   `TOKEN_CHARS` — the script divides by 4, rounds to the nearest 500, and
   floors at 1000.

Then call the script once, from a single Bash call, with the literal
`<remote>` from Step 1 (never a live `$REMOTE` read — the same reasoning as
`references/target-binding.md`):

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/issue/lib/post-ai-metrics.sh" \
  "<remote>" "$ISSUE_NUMBER" "$START_TS" \
  "<issue-type>" "<feat-size-or-->" "$TOKEN_CHARS" \
  "$IMPL_MIN" "$COMMIT_MIN" "$PR_MIN" "$REVIEW_MIN" "$CONFLICT_MIN" "$OUTDATED_MIN"
```

Skips entirely under `GH_DISABLE_AI_METRICS=1` (issue dEitY719/dotfiles#399); the six
sub-skills already honour the same env var, so a disabled run leaves zero
ai-metrics artifacts on the issue or PR.

On failure the script itself prints
`[WARN] ai-metrics comment failed (<reason>) — continuing.` and exits 0 —
this step is soft-fail, so the flow continues regardless.

Self-check: `lib/post-ai-metrics.selfcheck.sh`.
