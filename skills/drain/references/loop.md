# gh-flow:drain — The round loop (SSOT)

One round is four steps. The loop runs rounds until a stop condition fires.

## Step order

### 1. List

```
GH_HOST="$TARGET_HOST" gh issue list --repo "$TARGET_REPO" \
  --state open --author @me --limit 200 \
  [--label "$LABEL"] --json number,title,body,labels
```

A failure here **stops the run** before the round starts. Draining without
knowing the backlog's real state is how work gets redone or lost.

Zero results is a clean finish, not an error — including when `--label` matches
nothing.

### 2. Process

Ascending issue number. Dependencies come from the issue body only: a line
matching `Depends on #M` whose `#M` is still open defers that issue to a later
round. There is no other dependency source — no label convention, no project
field, nothing that has to be kept in sync by hand.

Each issue: `Skill(gh-flow:issue, "<N> <remote>")`. That skill owns
implement, commit, PR, review gate and rebase-sync; this one does not reach
inside it.

A stopped `gh-flow:issue` marks **that issue** failed and moves to the next
issue. The drain does not abort. Three failures on the same issue converts it to
`blocked` (`references/blocked.md`).

### 3. Promote

`references/promotion.md`. This step is not optional and its failure is fatal to
the round.

### 4. Re-list

Back to step 1, with the newly filed issues included.

## Stop conditions

| Condition | Result |
|---|---|
| Open issues 0 **and** deferred items 0 | Success. Report the final table. |
| Closed 0 **and** newly opened 0 in a round | No progress — stop immediately. Everything remaining is blocked, awaiting merge, or failing. |
| Round count reaches `--max-rounds` (default 5) | Stop and report what is left. |
| `gh issue list` fails | Stop before the round. |
| `gh-issue:create` fails while a promotion is pending | Stop the round and say so in the report. |

The no-progress condition is what makes the loop terminate structurally. It
does not depend on the agent noticing it is going in circles.

## Resumability

No state file. Everything the next round needs is on GitHub: open issues, their
labels, their comments, the PRs that link them. Re-invoking the skill in a new
session picks up from whatever the backlog looks like then, which is also why a
crashed run needs no cleanup.
