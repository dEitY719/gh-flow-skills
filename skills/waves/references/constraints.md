# gh-flow:waves — Constraints

- **The coordinator never invokes `gh-flow:issue`** (NF-1) — not to run it, not
  for `--help`. The installed `gh_issue_flow_stop_guard.py` counts any such call
  as a chain start and blocks the coordinator's turn with `0/6 sub-skills
  invoked` (pitfall 1). Only workers call it, inside their own transcripts.
- **One worker per worktree, for its whole life** (NF-2). Review fixes,
  simplify, CI fixes and rebases are that worker's. A second agent in the same
  worktree is how one agent's `git reset` erased another's commits (pitfall 5).
- **Merge is judged by `mergeCommit.oid` only** (NF-3), re-checked by the
  coordinator, never by `headRefOid` and never by the worker's word.
- **Live verification is serial and wave-scoped** (NF-4): after every worker of
  the wave has reported, one PR at a time.
- **Merging is delegated, never performed** (NF-5). Workers merge only via
  `Skill(gh-pr:merge, ...)`, whose approval and protection gates apply. No raw
  gh merge command anywhere, no `gh-pr:merge-emergency` by any path. A refusal
  is `[FAIL] not merged`; its dependents are deferred. `--no-merge` merges
  nothing.
- **Never reimplement an atom.** Worktrees are `session:worktree-spawn`'s,
  the chain is `gh-flow:issue`'s, CI repair is `gh-resolve:ci-fail`'s, live
  verification is `gh-verify:live`'s, issue filing is `gh-issue:issue-create`'s.
- **No repo-specific commands in the skill.** Bootstrap and restart come from
  `--bootstrap`, `.claude/gh-flow-waves.sh`, and `--run`.
- **State lives on GitHub.** Plan comments, issues, PRs and their merge commits
  are the whole state; a fresh session resumes from them
  (`references/plan.md` §6). No progress file.
- **Re-query every wave** (F-7). The plan moves while it runs (pitfall 7); a
  plan computed once is wrong by wave 2.
- **Deferred items become issues.** Workers file them under
  `../../drain/references/promotion.md`'s rules; this skill references that
  file and does not restate it.
- **A per-issue failure never aborts the run.** Only a list failure, a missing
  tracking issue, a failed pull, a failed `--run`, or a wave in which every
  issue failed ends it.
- **Bind the target from one remote URL.** Every `gh` call carries
  `GH_HOST="$TARGET_HOST"` and `--repo`/`-R "$TARGET_REPO"`, in the coordinator
  and in every brief (`../../issue/references/target-binding.md`).
- **The wave table is not a final answer.** It is emitted between waves and the
  next one starts immediately. A run that ends on a wave table without a final
  report has stopped early — and no Stop hook guards this skill's own terminal
  strings yet, so this rule is the only guard.
