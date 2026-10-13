# gh-flow:waves — Report format (F-8)

Plain assistant text. Never a `Bash` heredoc, never `Write` — a marker on any
other channel is invisible to a Stop guard, so a correctly-worded report still
reads as an unfinished run. Same rule as the sibling skills in this repo.

## Per wave

```
gh-flow:waves wave <w>/<max-waves> (plan rev <r>, <i>/<max-issues> issues, <owner/repo> on <remote>)
  #<N>  PR #<P>  [OK] merged <oid7>   live [OK]
  #<N>  PR #<P>  [OK] pr-only         live [SKIP] --no-merge
  #<N>  PR #<P>  [FAIL] not merged    gh-pr:merge refused: <reason>
  #<N>  -        [FAIL] <step>        <reason>
  deferred  #<N> (waits on failed #<M>)
  triage    fixed-in-place <a>   declined <b>   follow-ups <c>
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
triage         fixed-in-place <a>  declined <b>  (sum of the workers' fixed-in-place: / declined: lines)
filed this run #<X> ... (each carries Filed-by-run: waves #<T>; not processed in this run)
capped         #<N> ... (--max-issues <N> | --max-waves <W> reached)

Next: <the single most useful command>
```

`filed this run` lists every issue the run filed — workers' `follow-ups:` and
live-failure issues — by number. Requery kept them out (`references/plan.md`
§1), so `Next:` names them as the command that continues them, together with
any `capped` targets, e.g.
`Next: /gh-flow:waves --issues 210,211 --track 180  (filed this run #210 #211)`.
`--issues` naming them is what lets the next run take them in. Leave out this
run's `--label` / `--from`: `--issues` intersects with them, and a follow-up
rarely carries the label.

`complete` means no actionable target is left: every target is closed, or is
blocked, failed, deferred on a failure, excluded as a cycle, filed this run,
capped, or (with `--no-merge`) awaits a human merge — each named under
`left open`, `filed this run` or `capped`.

## Stopped endings

Name the cause on the header line instead of `complete`; the final table
follows with whatever finished. One ending, one `Next:`:

- `gh-flow:waves stopped — gh-flow plugin incomplete (<missing path>)` — a
  sibling file (`gh-flow:issue`'s `references/target-binding.md` or
  `skills/issue/lib/target-binding.sh`,
  `gh-flow:wave`'s `references/triage.md`) cannot be read (#47).
  `Next:` depends on why. `CLAUDE_PLUGIN_ROOT` unset (a harness that does
  not export it, a symlinked skill): export it to the plugin dir, then
  re-run. Set, and the file is still absent: a single-skill install —
  install the whole `gh-flow` plugin (README "Install"), then re-run.
- `gh-flow:waves stopped — issue list failed (<reason>)` — `Next:` the fix
  (`gh auth status` on `$TARGET_HOST`, usually), then re-run.
- `gh-flow:waves stopped — checkout not found (<reason>)` — an `<issue-url>`
  run found no single main checkout (`references/locate.md`). `Next:` the
  printed `git clone` line, or `cd` into the one checkout meant, then re-run.
- `gh-flow:waves stopped — no tracking issue` — `Next:` the same command with
  `--track <N>`.
- `gh-flow:waves stopped — run failed (<reason>)` — `Next:` fix the `--run`
  command, restart the app, then re-run (resume picks up from GitHub).
- `gh-flow:waves stopped — pull failed (<reason>)` — `Next:` reconcile the main
  checkout by hand, then re-run.
- `gh-flow:waves stopped — base not fast-forwardable (<reason>)` — the
  pre-spawn `git pull --ff-only` refused (#64 F-6): the main checkout has local
  changes in the way, its base diverged from `<remote>/<base>`, or it is not on
  `<base>`. `Next:` commit or clean the main checkout's local changes,
  reconcile the diverged base by hand, or check out `<base>`, then re-run.
- `gh-flow:waves stopped — no progress (wave <w>)` — every issue of the wave
  failed. `Next:` the first failure's fix.

## The terminal strings are a hook contract

`gh-flow:waves complete` and `gh-flow:waves stopped —` are the terminal markers
a `Stop` / `SubagentStop` guard matches to decide a waves run really finished —
the role `gh-flow:issue complete (#<N>)` plays for the sibling skill
(`gh-flow:issue`'s `references/stop-guard.md` is the SSOT for that mechanism). Keep
both verbatim. No guard matches them yet; they are pinned ahead of it.
