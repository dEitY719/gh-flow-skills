# gh-flow:issue — Step 3: Report

**Emit this report as plain assistant text.** Do not print it through a
tool — no `Bash` heredoc (`cat <<'EOF'`), no `printf`, no `Write`/`Edit`.
Any other channel may be invisible to the harness Stop guard, which then
blocks the turn. The guard's detection contract is the SSOT in
`references/stop-guard.md` (dEitY719/dotfiles#1270).

If all steps succeeded:

```
gh-flow:issue complete (#<N>)
  [SKIP] Step 1.5: origin gate          (claude - trusted)
  [OK] Step 1: gh-issue:implement       (<n files changed>, <n tests passed>)
  [OK] Step 2: gh-pr:commit                (<sha> "<subject>")
  [OK] Step 3: gh-pr:create                    (PR #<M>)
  [OK] Step 4: gh-verify:review-all       (agy+codex+simplify, reply in 4 min)
  [OK] Step 4.1: merge-train wake       (dispatcher fired)
  [OK] Step 5: gh-resolve:conflict   (no conflicts / resolved)
  [OK] Step 5.1: gh-resolve:outdated (up to date / rebased)
  [OK] Step 6: ai-metrics               (~X tokens · ~M h · ~L min)
  PR URL: <pr-url>
```

Step 1.5 (origin trust gate, dEitY719/gh-flow-skills#36) is not one of the six
steps and never appears in the `<i>/6` index — it either lets the chain start or
stops it before Step 1 runs:
- `[SKIP] Step 1.5: origin gate  (<harness> - trusted)` — a member of the trust
  set wrote the issue, so no review ran.
- `[SKIP] Step 1.5: origin gate  (--trust-origin)` — the gate was skipped wholesale.
- `[OK] Step 1.5: origin gate  (<harness> - reviewed)` — untrusted or unknown
  origin, validity review PASSed.
- `[BLOCK] Step 1.5: origin gate  (<harness> - N check(s) failed)` — see the
  block report below. Nothing after it ran.

Step 4 (`gh-verify:review-all`) is soft-fail — its row uses `[SKIP]`/`[WARN]`
for the gate's degraded cases (the delegated skill reports the per-lane
detail):
- `[SKIP] Step 4: gh-verify:review-all  (agy/codex absent)` — no CLI.
- `[SKIP] Step 4: gh-verify:review-all  (simplify: no change)` — clean tree, no commit.
- `[WARN] Step 4: gh-verify:review-all  (<reason>)` — review/simplify error, continued.

If Step 2.6 soft-failed, show `[WARN] Step 6: ai-metrics  (skipped — <reason>)` instead.

Step 4.1 (merge-train wake, dEitY719/dotfiles#1482) is also soft-fail — never a `stopped at`
report, never counted in the `<i>/6` step index. It fires in the background
and is not awaited, so its own exit code is never observed:
- `[SKIP] Step 4.1: merge-train wake  (remote != origin)` — `<remote>`'s URL
  didn't match `$HOME/dotfiles`'s own `origin`; the dispatcher only tracks
  that one remote (dEitY719/dotfiles#1498).
- `[WARN] Step 4.1: merge-train wake  (aicron.sh missing)` — the one
  synchronously-checked failure path on the `origin` path.

If a step failed:

```
gh-flow:issue stopped at step <i>/6 (<skill-name>)
  [OK] Step 1: gh-issue:implement  (<summary>)
  [FAIL] Step <i>: <skill-name>       (<failure reason>)
  [SKIP] Steps <i+1>..6               (not reached)

Resume after fix:
  /<commands to finish>
```

Resume hint logic:
- Failed at step 1 → `/gh-issue:implement <N>` (user decides retry).
- Failed at step 2 → `/gh-pr:commit <N> <remote> && /gh-pr:create <N> <remote>`.
- Failed at step 3 → `/gh-pr:create <N> <remote>`.
- Failed at step 4 → `/gh-verify:review-all <PR_NUM> <remote> --defer-reply 4`.
- Failed at step 5 → `/gh-resolve:conflict <PR_NUM>`.
- Failed at step 5.1 → `/gh-resolve:outdated <PR_NUM>`.

The quality gate now lives inside Step 4 (`gh-verify:review-all`), which is
soft-fail and never produces a `stopped at` report — it only contributes
`[OK]`/`[SKIP]`/`[WARN]` rows to the success template above.

## Block report (Step 1.5 BLOCK, exit 2)

A BLOCK is not a `stopped at step <i>/6` — the chain never started. Emit this
instead, as plain assistant text, and post the same body as the issue comment
(`references/origin-trust-gate.md` → "On BLOCK"):

```
gh-flow:issue blocked at Step 1.5 (#<N>) - origin gate
  origin: Harness(<harness>) - untrusted   [or: no origin line / fetch failed]
  violated:
    <k>. <checklist item name> - <one-line evidence from the issue body>
    <k>. <checklist item name> - <one-line evidence from the issue body>
  no files edited, no commit, no PR.

Next: <이슈 수정 후 /gh-flow:issue <N> 재실행>
      | <분리 등록 후 재실행>
      | </gh-flow:issue <N> --trust-origin — 위험을 인수하고 그대로 진행>
```

One numbered line per violated check (the numbers are the six in
`references/origin-trust-gate.md`), each with its own one-line rationale, and
exactly one next action per available route (F-7). If the block comment could
not be posted, add `  [WARN] block comment failed (<reason>)` above `Next:` —
the report and the exit code are unchanged.
