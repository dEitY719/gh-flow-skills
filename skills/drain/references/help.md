# gh-flow:drain — Help

## Arguments

| # | Name | Default | Description |
|---|------|---------|-------------|
| 1 | `[owner/repo]` or `-h`/`--help`/`help` | the current repo | Repository whose backlog is drained |
| 2 | `[remote]` | `origin` | Git remote whose URL binds `TARGET_HOST` + `TARGET_REPO`. A missing remote stops the run — there is no silent `origin` fallback |
| - | `--merge` | off | Delegate merging to `gh-pr:merge-train` after each round. Off by default: merging is a human decision |
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
not filing issues, and an agent optimizing the first number alone will reach it
while real defects sit in a ledger. Every deferred item becomes an issue
(`references/promotion.md`), which raises the first number back up — so the two
conditions can only be satisfied together by actually finishing the work.

## What one round does

1. **List** — `gh issue list --state open --author @me` on the bound target.
2. **Process** — ascending issue number, one `Skill(gh-flow:issue, "<N> <remote>")`
   each. An issue whose body has an open `Depends on #M` waits for the next round.
3. **Promote** — every deferred or unresolved item from that round becomes a new
   issue via `Skill(gh-issue:create, ...)`.
4. **Re-list** — including the issues just filed.

Full loop semantics, including the stop conditions: `references/loop.md`.

## What this skill will NOT do

- Merge a PR by default. Only `--merge` merges, and only through
  `gh-pr:merge-train`. `gh-pr:merge-emergency` is never called.
- Close an issue directly. Closure happens through a PR's `Closes #N` or a
  normal `gh-flow:issue` completion — never by this skill's own hand.
- Drain someone else's issues.
- Decide anything that needs the user. A blocked issue stays open with the
  reason and the resume procedure in a comment (`references/blocked.md`).
- Keep progress in a file. GitHub is the state, so a fresh session resumes by
  simply being invoked again.
- Invent work from a spec — that is `gh-flow:autopilot`.
