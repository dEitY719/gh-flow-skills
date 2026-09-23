# gh-flow:waves — Collect and barrier (F-6, NF-3, NF-4)

## Collect

Wait for each worker's completion notification. Do not poll: no `sleep` loop,
no repeated status reads — the harness notifies when a background agent ends.
A notification is a report, not evidence. For every worker that reported
`[OK] merged`, re-check on GitHub:

```
GH_HOST="$TARGET_HOST" gh pr view <PR> --repo "$TARGET_REPO" \
  --json state,mergeCommit --jq '.state + " " + (.mergeCommit.oid // "")'
```

`MERGED <oid>` is the only merged verdict (NF-3). `headRefOid` is never used —
after a rebase merge it is not on the default branch, and judging by it marked a
merged PR unmerged (pitfall 4). A report whose PR is not `MERGED` is recorded as
`[FAIL] not merged`, whatever the worker said.

Per failed worker: one comment on its issue —
`[FAIL] gh-flow:waves wave <w> — <step>: <reason>. PR: #<PR> | none.` — and the
issue is excluded from later waves of this run. Its dependents are deferred:
one comment each in the three-part form of
`../../drain/references/blocked.md` ((a) predecessor `#M` failed, (b) `#M`
merged, (c) re-run `/gh-flow:waves ...`). No `blocked` label for this case — the
open, unmerged predecessor already re-derives the dependency on resume. A worker
that reports a real `blocked:` cause (credentials, a user decision, ...) gets the
full `blocked.md` treatment, label included.

If a deferred `/gh-pr:reply` cron fires in the coordinator's session, do not run
it: the reply belongs to the issue's worker (NF-2), and the coordinator never
runs git against a worktree.

## Barrier

Starts only when **every** worker of the wave has reported. Never mid-wave.

1. **Pull** — in the main checkout:
   `git pull --ff-only "$REMOTE" <default-branch>`. Then prove every merged oid
   landed: `git merge-base --is-ancestor <oid> HEAD` per PR. A non-fast-forward
   or a missing oid stops the run — the checkout is not what was merged.
2. **Run** — `--run "<cmd>"` in the main checkout, once. A command that serves
   in the foreground is started in the background; readiness is proven by
   `gh-verify:live`, which checks the serving checkout is the target commit.
   A failure prints one line of cause, marks every live step `[SKIP]`, and
   **stops the run** — no further wave accumulates on unverified merges:
   `gh-flow:waves stopped — run failed (<reason>)`.
3. **Live** — one `Skill(gh-verify:live, "<PR>")` per merged PR of this wave,
   **serially** (one server, NF-4). Hand it the worker's `live check` line as the
   point to verify. A live failure is filed with
   `Skill(gh-issue:issue-create, "--no-ask <PR, what failed, what was expected>")`;
   the next re-query picks it up.

## SKIP rules

| Condition | Pull | Run | Live |
|---|---|---|---|
| default, `--run` given | yes | yes | yes |
| no `--run` | yes | `[SKIP]` | `[SKIP] no --run` |
| `--no-live` | yes | as given | `[SKIP] --no-live` |
| `--no-merge` | no | no | `[SKIP] --no-merge` |
| `--run` failed | yes | `[FAIL]` | `[SKIP]`, run stops |
| wave merged nothing | no | no | `[SKIP] nothing merged` |

Only merged PRs are verified; failed or `pr-only` issues are not.
