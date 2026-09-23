# gh-flow:waves — Planning (F-2, F-3, F-7) and spawning (F-4)

## 1. List the target set

```
LIMIT=1000
GH_HOST="$TARGET_HOST" gh issue list --repo "$TARGET_REPO" \
  --state open --limit "$LIMIT" [--label "$LABEL"] \
  --json number,title,labels --jq '[.[] | {number, title, labels: [.labels[].name]}]'
```

Then drop: numbers below `--from`, numbers outside `--issues`, anything labelled
`blocked`, and issues this run already finished or failed. A count equal to
`$LIMIT` means the list was truncated — say so, never claim a clean zero.

**A failure here stops the run before the wave starts** (same rule as
`../../drain/references/loop.md`). Planning over an unknown state is how work
gets redone or lost.

## 2. Read each candidate

One `GH_HOST="$TARGET_HOST" gh issue view <N> --repo "$TARGET_REPO" --json body,comments` per
candidate, read once per plan. From each, extract:

- **Explicit dependencies** — `Depends on #M`, `Blocked by #M`, `#M 이 먼저`,
  `#M 먼저`, "이 이슈가 먼저다" (written on `#M`, pointing at this issue), and
  GitHub's `blockedBy` links (`GH_HOST="$TARGET_HOST" gh api graphql` on `issue.blockedBy`). Comments
  count as much as the body — a dependency added mid-run usually lands in one.
- **File paths** the body names (`src/...`, `app/routes/x.py`, ...).
- **Epic** — an issue whose body carries a child table / task list of `#N`
  references. An epic is not implemented; it is closed in Step 5 once every
  child is closed (`GH_HOST="$TARGET_HOST" gh issue close <N> --repo "$TARGET_REPO" --comment "<children and their PRs>"`).

## 3. Check what is already on main (pitfall 8)

For each candidate, grep the default branch for the routes, functions or files
the issue asks for. Anything already present is written into the worker brief as
**already on main**, and only the rest as **remaining scope**. Skipping this is
how a worker re-implements what an epic PR already shipped.

## 4. Build the waves

1. Edges: explicit dependencies. An edge to an issue that is closed, or outside
   the set and not open, is satisfied.
2. Cycles: print the cycle (`#A -> #B -> #A`), drop every issue on it from the
   plan, and list them in the report. Do not guess an order.
3. Layer: wave 1 = no unsatisfied edge; wave k = every edge points into waves
   `< k`.
4. File overlap: two issues in the same wave that name the same file are split —
   the higher number moves to the next wave — unless the overlap is only a
   generated file (`openapi.json`, `schema.d.ts`, lockfiles), which the workers
   regenerate after rebase instead (pitfall 6). Remaining overlaps go into each
   brief as **files overlapping sibling workers**. This only sees paths an
   issue names; an overlap nobody named surfaces later as a rebase conflict at
   the worker's sync step (`gh-resolve:conflict`), not as a silent clobber.
5. `--max-parallel K`: a wave larger than `K` keeps the `K` lowest numbers; the
   rest move to the next wave.

## 5. Record the plan (F-3)

One comment on the tracking issue (`--track N`, else the single epic in the set;
with neither, stop: `gh-flow:waves stopped — no tracking issue`):

```
<!-- gh-flow:waves plan -->
gh-flow:waves plan (<owner/repo> on <remote>) — rev <r>

| wave | issue | depends on | overlapping files | already on main |
|------|-------|------------|-------------------|-----------------|
| 1    | #189  | -          | app/routes/x.py   | GET /x          |

excluded: #A #B (cycle), #C (blocked)
```

Re-planning posts a **new** comment with `rev` + 1; never edit the old one.

## 6. Resume from GitHub alone

A fresh session re-invoked with the same command re-derives everything: closed
issues drop out of step 1, merged predecessors satisfy their edges, and the
newest `gh-flow:waves plan` comment on the tracking issue shows where the last
run was. An open issue that already has an open PR from an earlier run — one
`GH_HOST="$TARGET_HOST" gh pr list --repo "$TARGET_REPO" --state open --json number,headRefName,closingIssuesReferences`
per plan, matched on `closingIssuesReferences[].number` — is not
re-implemented: its brief says **existing PR #M** and the worker starts at the
reply step on a worktree checked out on that PR's branch. No state file.

## 7. Spawn (F-4)

Per wave, first `git fetch "$REMOTE" <default-branch>` in the main checkout —
the previous wave's merges are on the remote, and `session:worktree-spawn`
branches from a local ref that is stale until fetched. Then per issue:
`Skill(session:worktree-spawn, "--task issue-<N> --base $REMOTE/<default-branch>")`
(explicit, so a non-`origin` remote or non-`main` default is honoured). Record the `Path:` and
`Branch:` it prints. Do **not** follow its `cd` (or `EnterWorktree`) — the
coordinator stays in the main checkout for the barrier. Branch naming is that
skill's.

Bootstrap, in the new worktree, first match wins:

1. `--bootstrap "<cmd>"` — run as given with the worktree as cwd.
2. `.claude/gh-flow-waves.sh` in the main checkout, only if `[ -f ]` proves it —
   `bash <main>/.claude/gh-flow-waves.sh <worktree-path>`. It is the repo's own
   code, at the same trust level as `--run`.
3. Nothing.

A spawn or bootstrap failure fails that issue (`[FAIL] spawn`) and the wave goes
on without it.
