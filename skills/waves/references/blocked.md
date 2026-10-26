# gh-flow:waves / gh-flow:wave — Blocked classification

Moved here from the former `drain` skill (removed in #65); `gh-flow:waves`
and `gh-flow:wave` both link to this file and keep no copy.

An issue that cannot be finished right now is **not closed and not retried**.
It is marked `blocked`, excluded from the rest of the run, and gets one comment
carrying everything a later session needs.

## What counts as blocked

| Cause | Example |
|---|---|
| Time window | Market hours, a business-day cutoff, a scheduled maintenance freeze |
| Missing access | Credentials, a network allowlist entry, an unavailable API scope |
| User decision | Real money, a live account, a billing change, an irreversible migration |
| Waiting on someone | An unanswered upstream question, a pending third-party fix |
| Upstream issue open | The parent or the `Depends on #M` issue is not done |

## The comment

Three parts, always all three:

```
[blocked] gh-flow:<waves|wave> — <wave w | depth d>

(a) 왜 막혔는지: <cause, one or two lines, concrete>
(b) 무엇이 있으면 풀리는지: <the specific thing — a credential, an answer,
    a decision, #<M> closing, a clock reaching a time>
(c) 풀렸을 때 실행할 절차: <the exact command or steps, runnable as written>

판정 기준: <how a later session decides (b) is now satisfied>
```

`판정 기준` is what stops the next run from re-deciding the block by feel. It
should be checkable — "`#42` is closed", "`gh auth status` lists the host",
"the user replied on this issue" — not "when it seems ready".

**The label is mandatory for a real block, and it is what a re-run can see.**
`gh-flow:waves`'s list query (`plan.md` §1) reads the `labels` projection, so a
block recorded only as a comment is invisible and the issue is retried on the
next run (`gh-flow:wave` uses only the label-less deferral form below, and the
`manual` label of "Human-only work"):

```
GH_HOST="$TARGET_HOST" gh label create blocked --repo "$TARGET_REPO" \
  --color b60205 --description "gh-flow — cannot proceed; see the newest comment" 2>/dev/null || true
GH_HOST="$TARGET_HOST" gh issue edit "$N" --repo "$TARGET_REPO" --add-label blocked
```

Use the repo's own blocked-equivalent label when it already has one rather than
inventing a second taxonomy — but there must be exactly one label, and it must
be applied. If the label write fails, report that issue as failed; do not leave
it unlabelled in the queue.

A dependant deferred only because its predecessor or parent failed in this run
takes the three-part comment **without** the label: the open, unmerged
predecessor already re-derives the dependency on resume (`barrier.md`,
`gh-flow:wave`'s `references/constraints.md`).

## Human-only work — the `manual` label (dEitY719/gh-flow-skills#70 F-6)

A worker that reports `[FAIL] manual — <reason>` found that no PR can finish
the issue (a runbook, another machine's local setup). The coordinator —
`gh-flow:waves` or `gh-flow:wave` — then labels the issue `manual` instead of
`blocked`, so the exclude-label gate (`gh-flow:issue`'s `lib/manual-gate.sh`)
drops it before any worktree on every later run, and posts the three-part
comment above with the worker's `blocked:` text as (c). Unlike `blocked`, this
is a **soft** failure: the `manual` label is provisioned per repo by
dEitY719/gh-setup-skills#23 and may not exist yet, so a failed create or add is
one `[WARN]` and the comment is still posted:

```
GH_HOST="$TARGET_HOST" gh label create manual --repo "$TARGET_REPO" \
  --color c5def5 --description "human-only work - gh-flow skips it" 2>/dev/null || true
GH_HOST="$TARGET_HOST" gh issue edit "$N" --repo "$TARGET_REPO" --add-label manual ||
  printf '[WARN] #%s: manual label not applied (soft)\n' "$N"
GH_HOST="$TARGET_HOST" gh issue comment "$N" --repo "$TARGET_REPO" --body-file <file>
```

A repo whose `GH_FLOW_EXCLUDE_LABELS` does not contain `manual` will not skip
it on the next run; the comment is what still explains the stop. The issue is
reported `[FAIL] manual` (under `left open` / in the tree table), its
dependants or descendants are deferred as for any failure.

## Not blocked

- A PR is open and waiting for a human merge (`--no-merge`, or a
  `gh-pr:merge` refusal). That is a normal outcome in the report, not a block.
- The work is merely hard, long, or unpleasant.
- A dependency that is itself in this run's plan — that just puts the issue in
  a later wave.
