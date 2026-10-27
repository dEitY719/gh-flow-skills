# gh-flow:waves — Help

## Arguments

| # | Name | Default | Description |
|---|------|---------|-------------|
| 1 | `[remote]` or `-h`/`--help`/`help` | `origin` | Git remote whose URL binds `TARGET_HOST` + `TARGET_REPO`. Passed to every worker. A missing remote stops the run — no silent `origin` fallback |
| 1 | `<issue-url>` | none | `https://<host>/<owner>/<repo>/issues/<N>` instead of a remote: locate that repo's main checkout in the cwd or up to two levels below it, bind its matching remote, sweep every open issue that is neither `blocked` nor exclude-labelled, and default the tracking issue to `<N>`. `references/locate.md` |
| - | `--from N` | none | Lower bound: open issues numbered below `N` are skipped |
| - | `--label L` | none | Only issues carrying label `L` |
| - | `--author A` | none | Only issues opened by `A` (`@me` for yourself), passed to `gh issue list --author`. Use it on a shared repo: without it every open issue is implemented and, by default, merged |
| - | `--issues 1,2,3` | none | Exactly these issues. Combines with the filters above as an intersection |
| - | `--track N` | the single epic in the set, else the `<issue-url>` issue | Issue that receives the plan comment and every re-plan comment. With no `--track`, not exactly one epic and no `<issue-url>`, the run stops before planning |
| - | `--max-parallel K` | `4` | At most `K` workers (and worktrees) per wave. Overflow moves to the next wave |
| - | `--max-issues N` | `20` | Most issues dispatched to workers in one run. The rest are not processed and are listed under `Next:` |
| - | `--max-waves W` | `5` | Most waves started in one run. The rest are not processed and are listed under `Next:` |
| - | `--run "<cmd>"` | none | Barrier's app restart command, run in the main checkout (e.g. `make run`). Absent: the live step is `[SKIP]` |
| - | `--bootstrap "<cmd>"` | `.claude/gh-flow-waves.sh` if present | Per-worktree setup (symlink `.venv`/`.env`, `bun install`, ...), run inside each new worktree. Never hardcoded in the skill |
| - | `--no-live` | off | Skip `gh-verify:live` at every barrier (the pull still runs) — the merge then omits `--no-post-verify`, so `gh-pr:merge`'s own post-merge verify runs instead; the same holds with no `--run` |
| - | `--no-merge` | off | Workers stop at a green, synced PR; nothing merges and every live step is `[SKIP]` |

With no `--from` / `--label` / `--author` / `--issues`, the target set is every open issue in
the repo that is not labelled `blocked` — with or without an `<issue-url>`.
Issues carrying an exclude label (human-only work; `GH_FLOW_EXCLUDE_LABELS`,
default `wontfix,not-implement,manual`) are always dropped, even when
`--issues` names them, and each is reported as `excluded (label): #<N> <label>`
(`references/plan.md` §1, dEitY719/gh-flow-skills#70). There is no
`--force-manual` here — run such an issue by hand with
`/gh-flow:issue <N> --force-manual`.
Either way, issues this run filed (body line `Filed-by-run: waves #<T>`, `<T>`
the tracking issue) are left out unless `--issues` names them; they are listed
under `filed this run` and in `Next:` (`references/plan.md` §1).

## Environment

| Variable | Default | Effect |
|---|---|---|
| `GH_FLOW_EXCLUDE_LABELS` | `wontfix,not-implement,manual` | Comma-separated exclude set applied at planning (`references/plan.md` §1). Replaces the default wholesale; the empty string excludes nothing. Exact names only. Shared with `gh-flow:issue` / `gh-flow:wave` through `gh-flow:issue`'s `lib/manual-gate.sh` |

## Usage

- `/gh-flow:waves --from 178 --run "make run"` — every open issue from #178 up, in waves, self-merged, live-verified after each wave.
- `/gh-flow:waves upstream --issues 189,190,193 --track 180 --no-merge` — plan and open PRs only, on `upstream`; the plan goes on #180.
- `/gh-flow:waves --label backend --max-parallel 2 --bootstrap "ln -s ../app/.env .env"` — two workers at a time, with a per-worktree setup command.
- `/gh-flow:waves https://github.com/acme/app/issues/28` — from a folder of clones: find `app`'s main checkout, sweep its open issues, plan on #28.
- `/gh-flow:waves https://github.com/acme/app/issues/28 --issues 28,30` — the same, but only #28 and #30.
- `/gh-flow:waves --label backend --max-issues 6 --max-waves 2` — at most six issues over at most two waves; the rest go to `Next:`.
- `/gh-flow:waves -h` / `--help` / `help` — print this help.

## What one wave does

`git pull --ff-only` the base → spawn worktrees → dispatch one background
worker per issue → collect completion notifications → barrier (pull, `--run`,
serial `gh-verify:live`) → re-query and re-plan. Plan rules:
`references/plan.md`. Worker brief: `references/worker-brief.md`. Barrier:
`references/barrier.md`.

## What this skill writes to GitHub

The plan table (a comment on the tracking issue, a new one per re-plan), a
`[FAIL]` comment on an issue whose worker failed, a deferral comment on an issue
whose predecessor failed, issues filed for real-defect live failures (via
`gh-issue:issue-create`, each with `Filed-by-run: waves #<T>`), and closing
comments on finished epics. PRs, replies and merges are written by the workers'
own sub-skills.

## What this skill will NOT do

- Call `gh-flow:issue` from the coordinator — not even for `--help`. Workers do.
- Merge by any path except a worker's `Skill(gh-pr:merge, ...)`. A refusal is
  reported `[FAIL] not merged` and the PR is left for a human.
  `gh-pr:merge-emergency` is never called.
- Put two workers in one worktree, or run live verification in parallel.
- Keep progress in a file. GitHub is the state; re-invoking resumes.

Full wording of each: `references/constraints.md`.
