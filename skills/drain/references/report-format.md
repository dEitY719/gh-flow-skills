# gh-flow:drain — Report format (F-7)

Plain assistant text. Never a `Bash` heredoc, never `Write` — same rule as the
sibling skills in this repo.

## Per round

```
gh-flow:drain round <r>/<max>  (<owner/repo> on <remote>)
  closed      <n>   #<N> ...
  opened      <n>   #<N> ... (promoted)
  blocked     <n>   #<N> ...
  failed      <n>   #<N> ... (<reason>)
  awaiting-merge <n>   #<N> -> PR #<M>
```

A round table is a waypoint, not a final answer — the next round starts
immediately after it (`references/constraints.md`).

## Final

```
gh-flow:drain complete  (<owner/repo>, <r> rounds)
  open issues     <n>
  deferred items  <n>
  closed this run <n>
  opened this run <n>

왜 아직 0이 아닌가
  #<N> <title> — <one line: blocked cause / awaiting human merge>
  #<N> <title> — <one line>

Next: <the single most useful command>
```

`왜 아직 0이 아닌가` carries one line per remaining open issue. Every remaining
issue is either blocked (three failed attempts is one blocked cause, not a
separate category — `references/blocked.md`) or awaiting a human merge. No
remaining issues means the section reads `없음 — 열린 이슈 0, 이연 항목 0`.

## Ending, and the `Next:` that goes with it

When the run ends on something other than both-conditions-zero, name it on the
header line. One ending, one `Next:` — there is no second lookup table:

- Both conditions zero — `Next: /gh-pr:merge-train <remote>` when PRs await
  merge, otherwise nothing is left.
- `gh-flow:drain stopped — no progress (round <r>)` (closed 0 and opened 0) —
  `Next:` the `(c)` procedure from the blocking issue's comment when exactly one
  issue blocks, else `/gh-flow:drain <owner/repo> <remote> --max-rounds <n>`
  after clearing the named blockers.
- `gh-flow:drain stopped — max rounds (<max>)` — `Next:`
  `/gh-flow:drain <owner/repo> <remote> --max-rounds <n>`.
- `gh-flow:drain stopped — issue list failed (<reason>)` — `Next:` the fix for
  that failure (`gh auth status` on `$TARGET_HOST`, usually), then re-run.
- `gh-flow:drain stopped — promotion failed (<reason>)` — the fatal one
  (`references/promotion.md`). `Next:` `/gh-issue:create` for the named item,
  then re-run the drain.
