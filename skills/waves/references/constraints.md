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
  nothing. The merge passes `--no-post-verify`: `gh-verify:live` is the one
  post-merge check (`references/worker-brief.md` `<MERGE_STEP>`, #74).
- **Never reimplement an atom.** Worktrees are `session:worktree-spawn`'s,
  the chain is `gh-flow:issue`'s, CI repair is `gh-resolve:ci-fail`'s, live
  verification is `gh-verify:live`'s, issue filing is `gh-issue:issue-create`'s.
- **No repo-specific commands in the skill.** Bootstrap and restart come from
  `--bootstrap`, `.claude/gh-flow-waves.sh`, and `--run`.
- **State lives on GitHub.** Plan comments, issues, PRs and their merge commits
  are the whole state; a fresh session resumes from them
  (`references/plan.md` §6). No progress file.
- **Re-query every wave** (F-7). The plan moves while it runs (pitfall 7); a
  plan computed once is wrong by wave 2. Requery serves only issues others
  opened and changed dependencies (#64 F-3).
- **This run's follow-ups stay out of this run** (#64 F-3). Every issue the run
  files — a worker's `follow-ups:`, a coordinator live-failure issue — carries
  the body line `Filed-by-run: waves #<T>` (`<T>` = the tracking issue), and
  requery drops open issues carrying it for this `<T>` unless `--issues` names
  them (`references/plan.md` §1). They are listed by number under
  `filed this run` and in `Next:`. The marker, not session memory, is the
  record, so a resume from GitHub alone excludes the same set.
- **Triage, not promote-everything** (#64 F-1). Workers fix in place, decline
  with a reason, or file a follow-up only for a large real defect, under
  `gh-flow:wave`'s `references/triage.md` (shared, not copied), and report
  `fixed-in-place:` / `declined:`. A live failure is filed only for a real
  defect; a trivial difference stays in the `gh-verify:live` PR comment report
  (F-5). There is no every-item promotion rule in the plugin since #65.
- **Exclude labels never start** (dEitY719/gh-flow-skills#70 F-3, F-6). An
  issue carrying a label in `GH_FLOW_EXCLUDE_LABELS` (default
  `wontfix,not-implement,manual`) is dropped at planning — `--issues` is no
  override — by `gh-flow:issue`'s `lib/manual-gate.sh`, never an inline match,
  and reported `excluded (label): #<N> <label>`. A worker's `[FAIL] manual`
  gets the `manual` label and the three-part comment; a missing label is a
  `[WARN]`, never a skipped comment (`references/blocked.md`).
- **Run caps** (#64 F-4). `--max-issues N` (default `20`) bounds the issues
  dispatched to workers, `--max-waves W` (default `5`) the waves started, both
  per invocation. A cap reached leaves the rest unprocessed and listed in
  `Next:`.
- **Fresh base before every spawn** (#64 F-6). The coordinator runs
  `git pull --ff-only "$REMOTE" <base>` in `MAIN` before each wave's spawn —
  the first wave included — never a bare fetch. Not on `<base>` or not
  fast-forwardable: `gh-flow:waves stopped — base not fast-forwardable (<reason>)`
  — local changes in `MAIN` are never overwritten. Why and how:
  `references/plan.md` §7.
- **The coordinator works against `MAIN`** — the cwd, or with an `<issue-url>`
  the checkout `references/locate.md` found. Every coordinator Bash call starts
  `cd "<MAIN>" &&` (or uses `git -C`); locating it is read-only and never
  clones.
- **A per-issue failure never aborts the run.** Only an incomplete plugin
  install (#47), a list failure, a missing checkout, a missing tracking issue, a base not fast-forwardable, a failed pull, a failed `--run`, or a wave in which every
  issue failed ends it.
- **Bind the target from one remote URL.** Every `gh` call carries
  `GH_HOST="$TARGET_HOST"` and `--repo`/`-R "$TARGET_REPO"`, in the coordinator
  and in every brief (`gh-flow:issue`'s `references/target-binding.md`).
- **The wave table is not a final answer.** It is emitted between waves and the
  next one starts immediately. A run that ends on a wave table without a final
  report has stopped early — and no Stop hook guards this skill's own terminal
  strings yet, so this rule is the only guard.
