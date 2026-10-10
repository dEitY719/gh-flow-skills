# gh-flow:wave — Help

## Arguments

| # | Name | Default | Description |
|---|------|---------|-------------|
| 1 | `<issue-number>` or `<issue-url>` or `-h`/`--help`/`help` | required | The root issue. A URL (`https://<host>/<owner>/<repo>/issues/<N>`) must name the same host and repo the `[remote]` binds; a mismatch prints both and stops. Run from that repo's main checkout — unlike `gh-flow:waves`, there is no checkout search |
| 2 | `[remote]` | `origin` | Git remote whose URL binds `TARGET_HOST` + `TARGET_REPO`. Passed to every worker. A missing remote stops the run — no silent `origin` fallback |
| - | `--max-depth D` | `3` | Deepest descendant generation processed (root = 0). A child deeper than `D` is not processed and is listed under `Next:` |
| - | `--max-issues K` | `10` | Most issues processed in one run, root included. The rest of the queue is listed under `Next:` |
| - | `--no-merge` | off | Workers stop at a green, synced PR; nothing merges and every verify step is `[SKIP] --no-merge` |
| - | `--no-verify` | off | Skip `gh-verify:merged` after each merge |

## Usage

- `/gh-flow:wave 58` — #58 to a merged, fresh-clone-verified PR, then every issue spawned from it (and from those), up to depth 3 and 10 issues.
- `/gh-flow:wave https://github.com/acme/lib/issues/58 upstream` — the same, bound to `upstream`.
- `/gh-flow:wave 58 --max-depth 1 --max-issues 4` — the root and its direct children only, at most four issues.
- `/gh-flow:wave 58 --no-merge` — PRs only; nothing merges, nothing verifies.
- `/gh-flow:wave -h` / `--help` / `help` — print this help.

## What one issue goes through

spawn a worktree → dispatch one background worker (`gh-flow:issue` → `gh-pr:reply`
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
- Call `gh-flow:issue` from the coordinator — not even for `--help`. Workers do.
- Call itself recursively. Descendants run in one internal queue loop.
- Merge by any path except a worker's `Skill(gh-pr:merge, ...)`. A refusal is
  reported `[FAIL] not merged` and the PR is left for a human.
  `gh-pr:merge-emergency` is never called.
- Run two issues at once, or put two workers in one worktree.
- Keep progress in a file. GitHub is the state; re-invoking on the root resumes.

Full wording of each: `references/constraints.md`.
