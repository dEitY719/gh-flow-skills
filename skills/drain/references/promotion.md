# gh-flow:drain — Promotion rules (F-3.3)

The rule: **anything found during the run that will not be fixed during the run
becomes a GitHub issue before the round ends.** A ledger line, a PR comment, an
Epic closing comment, a session note — none of those count.

## What gets promoted

- A reviewer finding that was acknowledged and not fixed, at any severity.
- Anything written as "후속", "별건", "나중에", "follow-up", "later".
- A `TODO` / `FIXME` left in the diff.
- A `# ponytail:` comment naming a deliberate ceiling and its upgrade path.
- A test that was skipped, xfailed, or narrowed to make the round pass.
- A limitation discovered while implementing that the issue did not mention.

## What does not

- Something actually fixed in that round's PR.
- A reviewer finding judged wrong, when the reply says why. The reply is the
  record; a rejected finding is resolved, not deferred.
- A pre-existing failure the round did not touch and did not make worse —
  `gh-issue:implement` refuses to fix those by design, so it is not this run's
  deferral. Promote it if the round is what surfaced it as a real defect.

## Enumerate the list; do not recall it

"Zero deferred items" counted from memory is the same gameable number as "zero
open issues" — the agent controls both. Build the list from artifacts instead,
per round, with the `Bash`/`Grep` this skill already allows:

- Unresolved review threads on the round's PRs —
  `gh api graphql` on `reviewThreads(isResolved: false)`.
- `grep -nE 'TODO|FIXME|ponytail:'` over the round's diff.
- Skipped / xfail counts from the round's test output.
- `grep -iE '후속|별건|나중에|follow-up|later'` over the PR body and its comments.

Promotion is then the set difference between that list and the issues already
filed this round — a number the run can show its work for.

## Severity is a label, not a filter

"It is only a minor" does not exempt anything (D-3). Triviality is expressed by
the label on the new issue, never by the decision not to file it. The incident
that produced this skill had four deferred items in a closing comment; one of
them had already become a real defect by the time anyone looked.

## How

`Skill(gh-issue:create, ...)` per item, with enough body that a fresh session
can act on it: what was found, where (file, PR number, review comment link), why
it was deferred, and what "done" looks like.

## Failure is fatal

If a promotion is pending and `gh-issue:create` fails, **stop the round and say
so in the report.** Swallowing a promotion failure reproduces exactly the
accident this skill exists to prevent — the item disappears while the backlog
number keeps looking good. Every other error in this skill is recoverable; this
one is not.
