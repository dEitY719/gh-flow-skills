# gh-flow:wave — Lineage (F-3, F-4, NF-6)

## The marker

One line, alone, anywhere in an issue body:

```
Spawned-from: #<N>
```

`<N>` is the parent issue number in the same repo. Exactly this spelling: the
key `Spawned-from:`, one space, `#`, digits, nothing after. A mention in prose
("spawned from #58"), a cross-repo `owner/repo#58`, or a line with trailing text
is not a marker. One parent per issue — the first `Spawned-from:` line wins.

## Who writes it

- **The worker.** The brief is `gh-flow:waves`'s `references/worker-brief.md`
  with every `<...>` filled, and these deviations:
  - `description: "wave #<N>"`, and the opening line names `gh-flow:wave` and
    the issue's depth instead of a wave number.
  - **Files overlapping sibling workers**: `none` — one issue runs at a time.
  - **Already on main**: what the parent's merge already shipped, if any.
  - Procedure step 6 gets one sentence appended: *every issue you file carries
    the line `Spawned-from: #<N>` in its body, `<N>` being this issue.* That
    one sentence is what makes a follow-up a descendant; without it the
    follow-up is out of scope and the tree silently stops growing. Issues a
    sub-skill filed in steps 1-5 (`gh-flow:issue`, `gh-pr:reply`, ...) are
    the worker's too: before the final report, append the line with
    `gh issue edit` to any of them that lacks it, and list them all under
    `follow-ups:`.
  - The final report's first word is `wave-worker` and its `live check:` line
    names what `gh-verify:merged` should prove in a fresh clone.
- **The coordinator.** Every `Skill(gh-issue:issue-create, "--no-ask ...")` it
  makes — today only for a `gh-verify:merged` failure — puts
  `Spawned-from: #<N>` in the body, `<N>` being the issue whose PR failed. What
  to promote and why a failed creation is fatal are `gh-flow:drain`'s
  `references/promotion.md`; this file adds only the marker.

## Querying the children of `#<N>`

After issue `<N>` is done (or, for a root already closed, before anything else):

```
GH_HOST="$TARGET_HOST" gh issue list --repo "$TARGET_REPO" --state all \
  --limit 100 --search '"Spawned-from: #<N>" in:body' --json number
```

`--state all`, not `open`: a closed child (merged by an earlier run) is never
processed, but it must still be found to descend through it (see Resume).
Search is a coarse prefilter — it tokenizes and also matches prose. Each hit is
then confirmed by its body:

```
GH_HOST="$TARGET_HOST" gh issue view <C> --repo "$TARGET_REPO" --json body,state
```

and kept only when its **first** `Spawned-from:` line equals
`Spawned-from: #<N>` exactly (after stripping a trailing `\r`). An `OPEN` child
is queued for processing; a `CLOSED` one is queued only to have its own children
queried, and counts toward neither cap. A result count of 100 means the list was
truncated — name that parent in `Next:`, never claim the tree is complete.

Search indexing lags issue creation by seconds. View directly, and union with
the search hits, every number the run already knows is a child of `<N>`: the
worker report's `follow-ups: #X #Y` and every issue the coordinator itself filed
for `<N>` (a `gh-verify:merged` failure) — a just-filed child is never lost to
the index delay.

Either command failing stops the run:
`gh-flow:wave stopped — descendant query failed (<reason>)`. Queueing over an
unknown state is how a child gets dropped.

## Queueing

- Children of `<N>` at depth `d` are at depth `d + 1`. Over `--max-depth`, they
  go to overflow, not the queue.
- A number already processed, already queued, or the root is never queued again
  — a child that points back at an ancestor ends there (cycle).
- Order within one parent: ascending number. Across parents: breadth-first.
- The `--max-issues` cap is checked when an issue is popped: once the count is
  reached, the rest of the queue moves to overflow.
- A child of a failed issue is never queued; it gets the deferral comment
  (`references/constraints.md`).

## Resume

No progress file exists (NF-6). A fresh session re-invoked on the same root
re-derives the tree from GitHub alone: a closed root is skipped and only its
children are queried; a closed child is likewise skipped and descended through;
an open child is processed. An open issue that already has an open PR from an
earlier run — the query in `gh-flow:waves`'s `references/plan.md` §6 — gets
`Existing PR: #M` in its brief and the worker starts at the reply step, in a
worktree checked out on that PR's head branch (as `plan.md` §6 says), not a
fresh branch spawned from base.
