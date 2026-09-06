# gh-flow:drain — Blocked classification (F-4)

An issue that cannot be finished right now is **not closed and not retried**.
It is marked `blocked`, excluded from the following rounds, and gets one comment
carrying everything a later session needs.

## What counts as blocked

| Cause | Example |
|---|---|
| Time window | Market hours, a business-day cutoff, a scheduled maintenance freeze |
| Missing access | Credentials, a network allowlist entry, an unavailable API scope |
| User decision | Real money, a live account, a billing change, an irreversible migration |
| Waiting on someone | An unanswered upstream question, a pending third-party fix |
| Upstream issue open | The parent or the `Depends on #M` issue is not done |

Three failed `gh-flow:issue` attempts on the same issue **within one run** also
converts it to `blocked` (F-5), with the failure reason as the cause. The count
is not persisted across sessions (`references/constraints.md`).

## The comment

Three parts, always all three:

```
[blocked] gh-flow:drain — round <r>

(a) 왜 막혔는지: <cause, one or two lines, concrete>
(b) 무엇이 있으면 풀리는지: <the specific thing — a credential, an answer,
    a decision, #<M> closing, a clock reaching a time>
(c) 풀렸을 때 실행할 절차: <the exact command or steps, runnable as written>

판정 기준: <how a later session decides (b) is now satisfied>
```

`판정 기준` is what stops the next run from re-deciding the block by feel. It
should be checkable — "`#42` is closed", "`gh auth status` lists the host",
"the user replied on this issue" — not "when it seems ready".

**The label is mandatory, and it is the only thing the round loop can see.**
Step 2's exclusion reads the list query's `labels` projection, so a block
recorded only as a comment is invisible and the issue is retried every round:

```
GH_HOST="$TARGET_HOST" gh label create blocked --repo "$TARGET_REPO" \
  --color b60205 --description "gh-flow:drain — cannot proceed; see the newest comment" 2>/dev/null || true
GH_HOST="$TARGET_HOST" gh issue edit "$N" --repo "$TARGET_REPO" --add-label blocked
```

Use the repo's own blocked-equivalent label when it already has one rather than
inventing a second taxonomy — but there must be exactly one label, and it must
be applied. If the label write fails, report that issue as failed; do not leave
it unlabelled in the queue.

## Not blocked

- A PR is open and waiting for a human merge. That is `awaiting-merge` in the
  report, a normal default-run outcome, not a block (D-1).
- The work is merely hard, long, or unpleasant.
- A dependency that is itself in this round's queue — that just defers the issue
  to a later round.
