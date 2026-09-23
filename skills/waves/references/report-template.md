# gh-flow:waves — Report format (F-8)

Plain assistant text. Never a `Bash` heredoc, never `Write` — a marker on any
other channel is invisible to a Stop guard, so a correctly-worded report still
reads as an unfinished run. Same rule as the sibling skills in this repo.

## Per wave

```
gh-flow:waves wave <w> (plan rev <r>, <owner/repo> on <remote>)
  #<N>  PR #<P>  [OK] merged <oid7>   live [OK]
  #<N>  PR #<P>  [OK] pr-only         live [SKIP] --no-merge
  #<N>  PR #<P>  [FAIL] not merged    gh-pr:merge refused: <reason>
  #<N>  -        [FAIL] <step>        <reason>
  deferred  #<N> (waits on failed #<M>)
  filed     #<X> (live failure) #<Y> (follow-up from #<N>)
  barrier   pull [OK]  run [OK|SKIP|FAIL]  live <k>/<m>
```

A wave table is a waypoint, not a final answer — the requery and the next wave
start immediately after it (`references/constraints.md`).

## Final

```
gh-flow:waves complete  (<owner/repo>, <w> waves, plan rev <r>)

| issue | PR | mergeCommit | live |
|-------|----|-------------|------|
| #189  | #204 | a1b2c3d | [OK] |

epics closed   #<E> ...
left open      #<N> — <one line: [FAIL] not merged, awaits human | deferred on #M | blocked: cause | cycle>
filed this run #<X> ...

Next: <the single most useful command>
```

`complete` means no actionable target is left: every target is closed, or is
blocked, failed, deferred on a failure, excluded as a cycle, or (with
`--no-merge`) awaits a human merge — each named under `left open`.

## Stopped endings

Name the cause on the header line instead of `complete`; the final table
follows with whatever finished. One ending, one `Next:`:

- `gh-flow:waves stopped — issue list failed (<reason>)` — `Next:` the fix
  (`gh auth status` on `$TARGET_HOST`, usually), then re-run.
- `gh-flow:waves stopped — no tracking issue` — `Next:` the same command with
  `--track <N>`.
- `gh-flow:waves stopped — run failed (<reason>)` — `Next:` fix the `--run`
  command, restart the app, then re-run (resume picks up from GitHub).
- `gh-flow:waves stopped — pull failed (<reason>)` — `Next:` reconcile the main
  checkout by hand, then re-run.
- `gh-flow:waves stopped — no progress (wave <w>)` — every issue of the wave
  failed. `Next:` the first failure's fix.

## The terminal strings are a hook contract

`gh-flow:waves complete` and `gh-flow:waves stopped —` are the terminal markers
a `Stop` / `SubagentStop` guard matches to decide a waves run really finished —
the role `gh-flow:issue complete (#<N>)` plays for the sibling skill
(`../../issue/references/stop-guard.md` is the SSOT for that mechanism). Keep
both verbatim. No guard matches them yet; they are pinned ahead of it, the same
way `gh-flow:drain`'s are.
