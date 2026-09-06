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

Three failed `gh-flow:issue` attempts on the same issue also converts it to
`blocked` (F-5), with the failure reason as the cause.

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

Add the repo's blocked-equivalent label if it has one; do not invent a new
label taxonomy here.

## Not blocked

- A PR is open and waiting for a human merge. That is `awaiting-merge` in the
  report, a normal default-run outcome, not a block (D-1).
- The work is merely hard, long, or unpleasant.
- A dependency that is itself in this round's queue — that just defers the issue
  to a later round.
