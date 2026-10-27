# gh-flow:wave — Help

## Arguments

| # | Name | Default | Description |
|---|------|---------|-------------|
| 1 | `<issue-number>` or `<issue-url>` or `-h`/`--help`/`help` | required | The root issue. A URL (`https://<host>/<owner>/<repo>/issues/<N>`) must name the same host and repo the `[remote]` binds; a mismatch prints both and stops. Run from that repo's main checkout, or from inside the root issue's own worktree (reuse mode, `references/spawn.md`) — unlike `gh-flow:waves`, there is no checkout search |
| 2 | `[remote]` | `origin` | Git remote whose URL binds `TARGET_HOST` + `TARGET_REPO`. Passed to every worker. A missing remote stops the run — no silent `origin` fallback |
| - | `--max-depth D` | `3` | Deepest descendant generation processed (root = 0). A child deeper than `D` is not processed and is listed under `Next:` |
| - | `--max-issues K` | `10` | Most issues processed in one run, root included. The rest of the queue is listed under `Next:` |
| - | `--no-merge` | off | Workers stop at a green, synced PR; nothing merges, every verify step is `[SKIP] --no-merge`, and only the root runs — its descendants are listed under `Next:` |
| - | `--no-verify` | off | Skip `gh-verify:merged` after each merge — the merge then omits `--no-post-verify`, so `gh-pr:merge`'s own post-merge verify runs instead |

## Environment

| Variable | Default | Effect |
|---|---|---|
| `GH_FLOW_EXCLUDE_LABELS` | `wontfix,not-implement,manual` | Comma-separated exclude set. The root, or any descendant, carrying one of these labels is skipped before a worktree is made: the root ends the run with `gh-flow:wave stopped — excluded label (<label>)`, a descendant is listed under `excluded` and `Next:`. A failed label lookup skips the same way. Shared with `gh-flow:issue` / `gh-flow:waves` (`gh-flow:issue`'s `lib/manual-gate.sh`) |

## Usage

- `/gh-flow:wave 58` — #58 to a merged, fresh-clone-verified PR, then every issue spawned from it (and from those), up to depth 3 and 10 issues.
- `/gh-flow:wave https://github.com/acme/lib/issues/58 upstream` — the same, bound to `upstream`.
- `/gh-flow:wave 58 --max-depth 1 --max-issues 4` — the root and its direct children only, at most four issues.
- `/gh-flow:wave 58 --no-merge` — root PR only; nothing merges, nothing verifies, no descent.
- `/gh-flow:wave 58` from inside `wt/issue-58/1` (or `wt/claude/1-issue-58`) — reuse mode: the root runs in that worktree, descendants in sibling worktrees; the main checkout is never pulled.
- `/gh-flow:wave -h` / `--help` / `help` — print this help.

## What one issue goes through

spawn a worktree (or, in reuse mode, adopt the root issue's current one) → dispatch one background worker (`gh-flow:issue` → `gh-pr:reply`
→ CI and rebase sync → `gh-pr:merge`) → collect its notification and re-check
`mergeCommit.oid` → `gh-verify:merged` → query its `Spawned-from: #<N>` children
and queue them. One issue at a time, breadth-first.

## What this skill writes to GitHub

A `[FAIL]` comment on an issue whose worker failed or whose merge was refused, a
deferral comment on each descendant of such an issue, issues filed for
`gh-verify:merged` failures (via `gh-issue:issue-create`, carrying the lineage
marker). PRs, replies, follow-up issues and merges are written by the workers'
own sub-skills.

## What this skill will NOT do

- Touch an open issue without a `Spawned-from:` line pointing into this run's tree.
- Start an issue carrying an exclude label, or one whose labels cannot be read.
  There is no `--force-manual` here; that flag belongs to a hand-run `/gh-flow:issue`.
- Call `gh-flow:issue` from the coordinator — not even for `--help`. Workers do.
- Call itself recursively. Descendants run in one internal queue loop.
- Merge by any path except a worker's `Skill(gh-pr:merge, ...)`. A refusal is
  reported `[FAIL] not merged` and the PR is left for a human.
  `gh-pr:merge-emergency` is never called.
- Run two issues at once, or put two workers in one worktree.
- Keep progress in a file. GitHub is the state; re-invoking on the root resumes.

Full wording of each: `references/constraints.md`.
