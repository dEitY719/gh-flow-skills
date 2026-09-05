---
name: issue
description: >-
  Chain one GitHub issue to a reviewed PR: implement → commit → PR → review →
  rebase-sync. Use for /gh-flow:issue, "이슈 #16 처음부터 PR까지
  자동으로", "이슈 구현하고 PR까지 한방에", "full flow on #42". Takes an issue
  number, not a spec (gh-flow:autopilot).
license: MIT
allowed-tools: Bash, Read, Grep, Agent
metadata:
  model_recommendation:
    tier: sonnet
    reason: "composite orchestration (implement→commit→PR→gate→reply→rebase); chain dispatcher with stop-on-error"
    claude: prefer
    non_claude: advisory-only
---

# gh-flow:issue — Issue → PR composition

## Role

이슈 번호 1건을 원자 스킬 6개(Step 2)로 체인 실행한다 — 구현은 **direct 모드 전용**이고,
plan/brainstorming 이 필요하면 `gh-issue:implement` 를 직접 부른다. **첫 단계 실패에서 즉시
중단하고 재개 지침이 담긴 리포트를 낸다**(이후 단계 자동 스킵). **전제조건**: 이미 전용
worktree 의 feature 브랜치 위.

## CRITICAL CONTRACT — read before editing

**Recurring failure mode: early-stop after Step 2.x.** Three layered guards
prevent it — (1) `--no-next-hint` on Step 2.1, (2) zero conversational text
between the six `Skill()` calls in Step 2, (3) the harness Stop/SubagentStop
guard in `dEitY719/dotfiles`, which tracks this skill's `gh-flow:issue`
markers (dEitY719/dotfiles#1434). **Do not remove any of them.** Only prose is
forbidden between the calls; the gate is delegated to Step 2.4. History and
detection contract: `references/critical-contract.md`, `references/stop-guard.md`.

## Step 1: Parse Args

Argument table (`<issue-number>`, `[remote]`) and the `-h`/`--help`/`help`
path — which prints `references/help.md` verbatim and stops, no API calls:
`references/help.md`. No `mode` arg — implementation is always `direct`.
Record `START_TS=$(date +%s)` for elapsed-time tracking in Step 2.6.

**Bind the GitHub target once, here (dEitY719/dotfiles#1403)** — resolve `GH_HOST` /
`TARGET_REPO` / `TARGET_HOST` / `REMOTE` from the `[remote]`'s URL, and thread
`[remote]` explicitly into 2.1–2.4 (dEitY719/dotfiles#1405). The two inline Bash steps (2.4.1,
2.6) re-derive their own target from the literal `<remote>` instead of trusting
that export to reach a later Bash call (dEitY719/dotfiles#1498). Block + rationale:
`references/target-binding.md`.

## Step 2: Chain the Skills

Invoke in order; each runs only if the previous succeeded. **Zero
conversational text between the calls — no recap, headers, or progress
bullets** (see CRITICAL CONTRACT). After each call, proceed to the next.

1. **Step 2.1 — gh-issue:implement** — `--no-next-hint` is load-bearing.
   `Skill(gh-issue:implement, "<N> direct <remote> --no-next-hint")`
2. **Step 2.2 — gh-pr:commit** (only if 2.1 succeeded) — `[remote]` pins the
   metrics/board target (dEitY719/dotfiles#1405). `Skill(gh-pr:commit, "<N> <remote>")`
3. **Step 2.3 — gh-pr:create** (only if 2.2 succeeded) — ensures `Closes #<N>`,
   pushes and opens the PR on `<remote>` (dEitY719/dotfiles#1405); extract `<PR_NUM>` from the PR
   URL. `Skill(gh-pr:create, "<N> <remote>")`
4. **Step 2.4 — gh-verify:review-all** (only if 2.3 succeeded; soft-fail) — one
   delegated call runs the post-PR quality gate (agy ∥ codex ∥ `/simplify`),
   commits + pushes any simplify change synchronously (so the tree is clean
   before the rebase steps), and defers `/gh-pr:reply <PR_NUM>` by 4 min. Detail:
   `references/quality-gate-step.md`.
   `Skill(gh-verify:review-all, "<PR_NUM> <remote> --defer-reply 4")`
5. **Step 2.4.1 — Wake merge-train dispatcher** (only if 2.3 succeeded, whatever
   2.4 returned; non-fatal, not a `Skill()` call) — fires `aicron run
   merge-train` backgrounded, and only when the literal `<remote>` resolves to
   the same repo URL as `$HOME/dotfiles`'s own `origin`; any other remote is a
   silent skip leaving no automated CI-fail remediation trigger at all
   (dEitY719/dotfiles#1498, dEitY719/dotfiles#1610). Detail: `references/merge-train-wake.md`.
6. **Step 2.5 — gh-resolve:conflict** (only if 2.4 succeeded) —
   rebase-resolve; a fresh PR usually prints "이미 충돌 없음 — skip".
   `Skill(gh-resolve:conflict, "<PR_NUM>")`
7. **Step 2.5.1 — gh-resolve:outdated** (only if 2.5 succeeded) — clean
   rebase-sync when the base moved forward with no conflicts; no-op if already
   up to date. `Skill(gh-resolve:outdated, "<PR_NUM>")`
8. **Step 2.6 — Post AI Metrics to Issue** (only if 2.5.1 succeeded;
   soft-fail) — aggregate flow-level metrics comment on the linked Issue.
   Full procedure: `references/ai-metrics-step.md`.

## Step 3: Report

Output format (templates + resume-hint logic): `references/report-template.md`.
Always end with the `[OK]`/`[FAIL]`/`[SKIP]` report as plain assistant text —
never via `Bash` heredoc or `Write` (dEitY719/dotfiles#1270).

## Constraints

`references/constraints.md` holds the full list: direct mode only, never retry or
skip a step, the soft-fail exceptions, simplify-commit-before-rebase, the early-stop guards, do-not-stop-mid-flow.

## Related Skills

Chained atoms: `gh-issue:implement` · `gh-pr:commit` · `gh-pr:create` ·
`gh-verify:review-all` · `gh-resolve:conflict` · `gh-resolve:outdated`. Spec-driven cousin: `gh-flow:autopilot`.
