# gh-flow:waves — Help

## Arguments

| # | Name | Default | Description |
|---|------|---------|-------------|
| 1 | `[remote]` or `-h`/`--help`/`help` | `origin` | Git remote whose URL binds `TARGET_HOST` + `TARGET_REPO`. Passed to every worker. A missing remote stops the run — no silent `origin` fallback |
| - | `--from N` | none | Lower bound: open issues numbered below `N` are skipped |
| - | `--label L` | none | Only issues carrying label `L` |
| - | `--issues 1,2,3` | none | Exactly these issues. Combines with the filters above as an intersection |
| - | `--track N` | the single epic in the set | Issue that receives the plan comment and every re-plan comment. With no `--track` and not exactly one epic, the run stops before planning |
| - | `--max-parallel K` | `4` | At most `K` workers (and worktrees) per wave. Overflow moves to the next wave |
| - | `--run "<cmd>"` | none | Barrier's app restart command, run in the main checkout (e.g. `make run`). Absent: the live step is `[SKIP]` |
| - | `--bootstrap "<cmd>"` | `.claude/gh-flow-waves.sh` if present | Per-worktree setup (symlink `.venv`/`.env`, `bun install`, ...), run inside each new worktree. Never hardcoded in the skill |
| - | `--no-live` | off | Skip `gh-verify:live` at every barrier (the pull still runs) |
| - | `--no-merge` | off | Workers stop at a green, synced PR; nothing merges and every live step is `[SKIP]` |

With no `--from` / `--label` / `--issues`, the target set is every open issue in
the repo that is not labelled `blocked`.

## Usage

- `/gh-flow:waves --from 178 --run "make run"` — every open issue from #178 up, in waves, self-merged, live-verified after each wave.
- `/gh-flow:waves upstream --issues 189,190,193 --track 180 --no-merge` — plan and open PRs only, on `upstream`; the plan goes on #180.
- `/gh-flow:waves --label backend --max-parallel 2 --bootstrap "ln -s ../app/.env .env"` — two workers at a time, with a per-worktree setup command.
- `/gh-flow:waves -h` / `--help` / `help` — print this help.

## What one wave does

spawn worktrees → dispatch one background worker per issue → collect completion
notifications → barrier (pull, `--run`, serial `gh-verify:live`) → re-query and
re-plan. Plan rules: `references/plan.md`. Worker brief:
`references/worker-brief.md`. Barrier: `references/barrier.md`.

## What this skill writes to GitHub

The plan table (a comment on the tracking issue, a new one per re-plan), a
`[FAIL]` comment on an issue whose worker failed, a deferral comment on an issue
whose predecessor failed, issues filed for live failures (via
`gh-issue:issue-create`), and closing comments on finished epics. PRs, replies
and merges are written by the workers' own sub-skills.

## What this skill will NOT do

- Call `gh-flow:issue` from the coordinator — not even for `--help`. Workers do.
- Merge by any path except a worker's `Skill(gh-pr:merge, ...)`. A refusal is
  reported `[FAIL] not merged` and the PR is left for a human.
  `gh-pr:merge-emergency` is never called.
- Put two workers in one worktree, or run live verification in parallel.
- Keep progress in a file. GitHub is the state; re-invoking resumes.

Full wording of each: `references/constraints.md`.
