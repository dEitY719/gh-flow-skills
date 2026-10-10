# gh-flow:wave — Report format (F-8)

Plain assistant text. Never a `Bash` heredoc, never `Write` — a marker on any
other channel is invisible to a Stop guard, so a correctly-worded report still
reads as an unfinished run. Same rule as the sibling skills in this repo.

## Per issue

```
gh-flow:wave #<N> (depth <d>, <i>/<max-issues>, <owner/repo> on <remote>)
  PR #<P>  [OK] merged <oid7>   verify [OK]
  queued   #<C> #<D>   overflow #<E> (depth > <max-depth>)
```

A per-issue block is a waypoint, not a final answer — the next issue starts
immediately after it (`references/constraints.md`).

## Final

```
gh-flow:wave complete  (<owner/repo>, root #<R>, <n> issues, depth <d>)

| issue | parent | PR | mergeCommit | merged-verify |
|-------|--------|----|-------------|---------------|
| #58   | -      | #61 | a1b2c3d | [OK] |
| #62   | #58    | #64 | e4f5a6b | [FAIL] filed #65 |
| #65   | #62    | #66 | c7d8e9f | [OK] |
| #63   | #58    | #67 | -       | [FAIL] not merged — gh-pr:merge refused: <reason> |

filed this run #<X> ... (each with its Spawned-from parent)
deferred       #<C> (parent #<M> failed)
overflow       #<E> (depth > <max-depth>) #<F> (> <max-issues> issues)

Next: <overflow and failed issue numbers, as the command that continues them>
```

Rows are in processing order, so the `parent` column draws the tree. A root
already closed at start has the row `| #<R> | - | - | - | [SKIP] closed |`.
`merged-verify` is `[OK]`, `[FAIL] filed #<X>`, `[SKIP] --no-verify`,
`[SKIP] --no-merge`, or `[FAIL] <step>` when there was no merge to verify.

`Next:` names every overflow and every failed issue by number — e.g.
`Next: /gh-flow:wave 62 --max-depth 1  (overflow #70 #71; failed #63: merge refused, awaits human)`.
With neither, it reads `Next: none — tree complete`.

`complete` means the queue is empty: every queued issue merged and verified
(or left as a green PR under `--no-merge`), failed (named, its subtree
deferred), or moved to overflow — each named above. A truncated child query
(`references/lineage.md`) is named in `Next:` too.
A root with no work and no children is `complete` with zero issues.

## Stopped endings

Name the cause on the header line instead of `complete`; the final table follows
with whatever finished. One ending, one `Next:`:

- `gh-flow:wave stopped — gh-flow plugin incomplete (<missing path>)` — a
  sibling file (`gh-flow:issue`'s `references/target-binding.md` or
  `skills/issue/lib/target-binding.sh`, a `gh-flow:waves` / `gh-flow:drain`
  reference) cannot be read (#47). `CLAUDE_PLUGIN_ROOT` unset: export it to the
  plugin dir, then re-run. Set, and the file still absent: install the whole
  `gh-flow` plugin (README "Install"), then re-run.
- `gh-flow:wave stopped — target mismatch (<url> vs <remote>)` — `Next:` the
  same command with the remote that points at the URL's repo.
- `gh-flow:wave stopped — descendant query failed (<reason>)` — `Next:` the fix
  (`gh auth status` on `$TARGET_HOST`, usually), then re-run on the root.
- `gh-flow:wave stopped — promotion failed (<reason>)` — a marker issue could
  not be filed. `Next:` `/gh-issue:issue-create` for the named item with its
  `Spawned-from:` line, then re-run on the root.

## The terminal strings are a hook contract

`gh-flow:wave complete` and `gh-flow:wave stopped —` are the terminal markers a
`Stop` / `SubagentStop` guard matches to decide a wave run really finished — the
role `gh-flow:issue complete (#<N>)` plays for the sibling skill
(`gh-flow:issue`'s `references/stop-guard.md` is the SSOT for that mechanism).
Keep both verbatim. No guard matches them yet; they are pinned ahead of it, the
same way `gh-flow:waves`'s and `gh-flow:drain`'s are.
