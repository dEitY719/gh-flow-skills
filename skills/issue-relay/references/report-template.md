# Report Templates

Step 6 relays `gh-flow:relay-merge`'s own Step 8 output first (destination
comment URL, gist count, SIMPLE PATH vs. relay mode), then this chain summary.

## Success ([OK])
    [OK] gh-flow:issue-relay complete (#<N>)
    - Branch:  <BRANCH>  (created | reused, unmodified | reused on top of unique commits)
    - Worker:  delegated, diff <BASE_SHA>..<HEAD_SHA>
    - Verify:  Advisor lint/test <pass | pass with --known-failures: <entries>>
    - Relay:   <SIMPLE PATH (pushed directly) | relayed via gist, apply-guide posted>
    Next: <apply-guide comment URL (relay mode) | created PR URL (SIMPLE PATH)>

## Failure ([FAIL]) — stops at the failing step
    [FAIL] gh-flow:issue-relay stopped at Step <k> (<step name>)
    - Completed: Step 2..<k-1> (<one-line summary>)
    - Reason:    <one of the stop-on-error causes below>
    Next: <resume hint — re-run after answering the question, or after fixing
    the sharper-brief re-delegation, or the surfaced relay-merge error>

Stop-on-error causes (Step 1's policy), verbatim as the `- Reason:` line:
- Step 2: `lib/branch-setup.sh` itself failed — missing/unparseable `--remote`,
  undetectable default branch, unfetchable base branch, or an unfetchable
  issue title (its own stderr line is the reason, surfaced unmodified); or the
  branch-reuse question was left unanswered (case 3 in
  `references/branch-setup.md` "Create or reuse")
- Step 3: unresolved Open Question(s) on the issue — resolve them, then re-run
- Step 4: Advisor verification failed — re-delegated with a sharper brief per
  `references/verification.md`; report which attempt this was
- Step 5: `gh-flow:relay-merge`'s own error, surfaced unmodified
