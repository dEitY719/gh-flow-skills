# gh-flow:drain — The round loop (SSOT)

One round is four steps. The loop runs rounds until a stop condition fires.

## Step order

### 1. List

```
LIMIT=1000
GH_HOST="$TARGET_HOST" gh issue list --repo "$TARGET_REPO" \
  --state open --author @me --limit "$LIMIT" \
  [--label "$LABEL"] --json number,title,body,labels \
  --jq '[.[] | {number, title,
                labels: [.labels[].name],
                deps: [.body | scan("Depends on #[0-9]+")]}]'
```

The `--jq` projection matters: `body` is needed only for the `Depends on #M`
lines, and without it every issue's full body lands in context on every round.

**A result count equal to `$LIMIT` means the list was truncated** — the backlog
may not be empty when the loop later says it is. Say so in the report and never
claim a clean zero on a truncated round.

A failure here **stops the run** before the round starts. Draining without
knowing the backlog's real state is how work gets redone or lost.

Zero results is a clean finish, not an error — including when `--label` matches
nothing.

### 2. Process

Ascending issue number, skipping any issue that is:

- labelled `blocked` — read off this round's own `labels` projection, which is
  why the label is **mandatory** rather than a nicety (`references/blocked.md`):
  a blocked issue whose only marker is a comment is invisible to the list query
  and gets retried forever, and a failed label write means the issue is reported
  as failed rather than quietly re-entering the queue, or
- already carried to a PR **by this run** — it stays open only because the
  default run merges nothing, and it is counted `awaiting-merge`, or
- deferred by a dependency: a `deps` entry `Depends on #M` whose `#M` is still
  open. `#M` counts as open iff it appears in this round's list; resolve any
  `#M` outside that list with one batched `gh issue list --json number` per
  round, never one `gh issue view` per line.

The first two exclusions are what keep a default run from re-implementing the
whole backlog on round 2: nothing merges, so every issue is still open when the
next listing runs. Dependencies come from the issue body only — no label
convention, no project field, nothing that has to be kept in sync by hand.

Each remaining issue: `Skill(gh-flow:issue, "<N> <remote>")`. That skill owns
implement, commit, PR, review gate and rebase-sync; this one does not reach
inside it.

A stopped `gh-flow:issue` marks **that issue** failed and moves to the next
issue. The drain does not abort. Three failures on the same issue **within this
run** converts it to `blocked` (`references/blocked.md`); the count is not
persisted (`references/constraints.md`).

### 3. Promote

`references/promotion.md`. This step is not optional and its failure is fatal to
the round.

### 4. Re-list

Back to step 1, with the newly filed issues included. With `--merge`, hand the
round's finished PRs to `Skill(gh-pr:merge-train, "<remote>")` **before**
re-listing, so the next round's list reflects what the merges closed.

## Stop conditions

| Condition | Result |
|---|---|
| Open issues 0 **and** deferred items 0 | Success. Report the final table. |
| Closed 0 **and** newly opened 0 in a round | No progress — stop immediately. Everything remaining is blocked, awaiting merge, or failing. |
| Every listed issue excluded by step 2 | Nothing actionable left. Stop; this is the normal ending of a default (no `--merge`) run, where each issue is open only because its PR awaits a human. |
| Round count reaches `--max-rounds` (default 5) | Stop and report what is left. |
| `gh issue list` fails | Stop before the round. |
| `gh-issue:create` fails while a promotion is pending | Stop the round and say so in the report. |

The no-progress condition is what makes the loop terminate structurally. It
does not depend on the agent noticing it is going in circles. Note what it is
**not**: a default run that carried every issue to a PR closes nothing and opens
nothing, and stopping there is correct, not a failure — the report counts those
issues `awaiting-merge`, and the exclusion row above is the condition that
actually fires first.

Deferred-items-0 is **established by step 3 each round, not tracked across
rounds**: promotion is unconditional and its failure is fatal, so the only way
the count is non-zero at a stop is the promotion-failed condition. Do not keep a
running tally — that is the ledger NF-2 forbids.

## Resumability

No state file. Everything the next round needs is on GitHub: open issues, their
labels, their comments, the PRs that link them. Re-invoking the skill in a new
session picks up from whatever the backlog looks like then, which is also why a
crashed run needs no cleanup.
