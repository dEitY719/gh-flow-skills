# gh-flow:drain — Help

## Arguments

| # | Name | Default | Description |
|---|------|---------|-------------|
| 1 | `[owner/repo]` or `-h`/`--help`/`help` | the current repo | Repository whose backlog is drained |
| 2 | `[remote]` | `origin` | Git remote whose URL binds `TARGET_HOST` + `TARGET_REPO`. A missing remote stops the run — there is no silent `origin` fallback |
| - | `--merge` | off | Hand each round's finished PRs to `gh-pr:merge-train` before re-listing. Off by default: merging is a human decision |
| - | `--max-rounds N` | `5` | Stop after N rounds and report what is left |
| - | `--label L` | none | Only drain issues carrying label `L`. Zero matches is a clean 0-issue finish, not an error |

Only issues authored by the invoking user are drained (`--author @me`).

## Usage

- `/gh-flow:drain` — drain the current repo's backlog on `origin`, no merging.
- `/gh-flow:drain dEitY719/foo upstream` — drain `foo`'s backlog entirely on `upstream`.
- `/gh-flow:drain --label bug --max-rounds 2` — two rounds over `bug`-labelled issues only.
- `/gh-flow:drain --merge` — same as the default, but each round hands the finished PRs to `gh-pr:merge-train`.
- `/gh-flow:drain -h` / `--help` / `help` — print this help.

## The termination condition

Two conditions, both required:

1. Zero open issues (after the label filter).
2. Zero deferred items — nothing found during the run that was written down
   somewhere other than a GitHub issue.

The second one is the point of the skill. "Zero open issues" is achievable by
not filing issues; every deferred item becomes an issue
(`references/promotion.md`), which raises the first number back up, so the two
can only be satisfied together by actually finishing the work.

## What one round does

List → Process → Promote → Re-list. Full semantics — the exclusions, the
dependency rule, the stop conditions: `references/loop.md`.

## What this skill will NOT do

- Merge a PR by default (`--merge` delegates to `gh-pr:merge-train`;
  `gh-pr:merge-emergency` is never called).
- Close an issue directly — closure comes from a PR's `Closes #N`.
- Drain someone else's issues.
- Decide anything that needs the user: a blocked issue stays open with the
  reason and the resume procedure in a comment (`references/blocked.md`).
- Keep progress in a file. GitHub is the state, so a fresh session resumes by
  simply being invoked again.
- Invent work from a spec — that is `gh-flow:autopilot`.

Full wording of each: `references/constraints.md`.
