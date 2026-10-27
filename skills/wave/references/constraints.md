# gh-flow:wave — Constraints

- **The coordinator never invokes `gh-flow:issue`** (NF-1) — not to run it, not
  for `--help`. The installed `gh_issue_flow_stop_guard.py` counts any such call
  as a chain start (#39, the same reason as `gh-flow:waves`). Only the worker
  calls it, inside its own transcript.
- **One worker per worktree, for its whole life** (NF-2). Review fixes, CI fixes
  and rebases are that worker's; a second agent in the same worktree is never
  dispatched.
- **Merge is judged by `mergeCommit.oid` only** (NF-3), re-checked by the
  coordinator on GitHub, never by `headRefOid` and never by the worker's word.
  The procedure is `gh-flow:waves`'s `references/barrier.md` "Collect".
- **Merging is delegated, never performed** (NF-4). The worker merges only via
  `Skill(gh-pr:merge, ...)`, whose approval and protection gates apply. No raw
  gh merge command anywhere, no `gh-pr:merge-emergency` by any path. A refusal
  is `[FAIL] not merged`, the PR stays for a human, and that issue's
  descendants are not processed. `--no-merge` merges nothing. The merge passes
  `--no-post-verify`: `gh-verify:merged` is the one post-merge check
  (`gh-flow:waves`'s `references/worker-brief.md` `<MERGE_STEP>`, #74).
- **Only marked descendants are processed** (F-3). An open issue enters the
  queue only through an exact `Spawned-from: #<N>` line whose `<N>` is an issue
  already in this run's tree (`references/lineage.md`). Every other open issue
  in the repo is out of scope, however related it looks.
- **Exclude labels are skipped before spawn** (dEitY719/gh-flow-skills#70 F-4,
  NF-1). The root and every descendant go through `gh-flow:issue`'s
  `lib/manual-gate.sh` before a worktree exists — never an inline re-derived
  match. An excluded or unreadable root stops the run
  (`gh-flow:wave stopped — excluded label (<label>)` / `label lookup failed`);
  an excluded or unreadable descendant is skipped with its subtree and named
  under `excluded` and `Next:`. Never fail-open, never `--force-manual` in a
  brief.
- **No recursion** (F-6). Descendants run in one internal breadth-first queue;
  `Skill(gh-flow:wave, ...)` is never called. Caps and termination are decided in
  that one loop.
- **Caps are hard** (F-7). A child deeper than `--max-depth` or past
  `--max-issues` is not processed; it is listed under `Next:`. A processed
  number is never queued twice (cycles).
- **Serial.** One issue at a time; the next spawn waits for the previous merge
  and verify, so it branches from the updated base. Parallel runs are
  `gh-flow:waves`'s.
- **A failed issue stops its subtree, not the run.** Worker failure or merge
  refusal: `[FAIL]` plus one comment on the issue —
  `[FAIL] gh-flow:wave #<N> (depth <d>) — <step>: <reason>. PR: #<PR> | none.`
  (not `barrier.md`'s `gh-flow:waves wave <w>` wording) — a deferral comment
  on each of its descendants in the three-part form of `gh-flow:waves`'s
  `references/blocked.md` ((a) parent `#<N>` failed, (b) `#<N>` merged,
  (c) re-run `/gh-flow:wave <root>`), and the siblings go on. No `blocked`
  label for this case — the open, unmerged parent re-derives it on resume.
  The one exception is a worker's `[FAIL] manual` (human-only work): that issue
  also gets the `manual` label, soft-failing, by `gh-flow:waves`'s
  `references/blocked.md` "Human-only work" (dEitY719/gh-flow-skills#70 F-6).
- **Verify failures follow triage** (F-5). A real defect `gh-verify:merged`
  finds is filed with `gh-issue:issue-create --no-ask` carrying
  `Spawned-from: #<N>`, and queued as a descendant within the caps; a trivial
  difference stays in the verify report comment (`references/triage.md`).
- **A failed marker-issue creation is fatal.** If `gh-issue:issue-create` fails
  for a verify finding or a worker's child issue, stop:
  `gh-flow:wave stopped — promotion failed (<reason>)` — an item that is never
  filed vanishes from the tree (`references/triage.md`).
- **Triage, not promote-everything** (#62). Workers fix in place, decline with a
  reason, or file a child issue only for a large real defect, under
  `references/triage.md`, and report `fixed-in-place:` / `declined:`. There is
  no every-item promotion rule anywhere in the plugin since #65.
- **Fresh base before each spawn** (#62). The coordinator runs
  `git pull --ff-only <remote> <base>` in the main checkout, never a bare fetch,
  so a stale local base cannot make a worker re-review earlier merges. Not
  fast-forwardable: `gh-flow:wave stopped — base not fast-forwardable (<reason>)`
  — local changes in the main checkout are never overwritten. The pull moves
  only the checked-out branch, so first `git symbolic-ref --short HEAD` must
  print `<base>`; any other branch is the same stop, reason `not on <base>`.
  Reuse mode is the one exception (#71): started inside the root issue's own
  linked worktree, the coordinator never pulls `MAIN` (the user's checkout,
  maybe on another branch) — it runs `git fetch <remote> <base>` and spawns
  from `<remote>/<base>` instead (`references/spawn.md`).
- **Spawn never moves the coordinator** (#71). Every spawn is
  `Skill(session:worktree-spawn, "--no-enter --task issue-<N> --base <remote>/<base>")`;
  without `--no-enter` Claude Code's `EnterWorktree` moves the session and the
  next descendant's spawn fails (dEitY719/session-skills#38).
- **Reuse only the root issue's own worktree** (#71). A linked worktree
  (`--git-dir` differs from `--git-common-dir`) is adopted as the root's
  `Path:` only when its branch is `wt/issue-<N>/<k>` or
  `wt/<agent>/<k>-issue-<N>`; any other branch stops the run with
  `gh-flow:wave stopped — running in an unrelated worktree (<branch>)`, and a
  branch that cannot sit on `<remote>/<base>` with
  `gh-flow:wave stopped — worktree not rebasable onto <base>`. A dirty tree is
  a resume: warn, never clean. The coordinator edits and commits nothing in
  the shared root worktree (NF-2), and descendants always get a sibling
  worktree. `MAIN`, and the brief's `<main-path>`, come from
  `--git-common-dir`, never from the cwd.
- **Never reimplement an atom.** Worktrees are `session:worktree-spawn`'s,
  the chain is `gh-flow:issue`'s, merging is `gh-pr:merge`'s, fresh-clone
  verification is `gh-verify:merged`'s, issue filing is `gh-issue:issue-create`'s.
- **State lives on GitHub** (NF-6). Issues, PRs, merge commits, comments and
  `Spawned-from:` markers are the whole state. No progress file; a fresh
  session resumes from the root issue (`references/lineage.md` "Resume").
- **Bind the target from one remote URL** (NF-5). Every `gh` call carries
  `GH_HOST="$TARGET_HOST"` and `--repo`/`-R "$TARGET_REPO"`, in the coordinator
  and in the brief (`gh-flow:issue`'s `references/target-binding.md`).
- **The whole plugin must be installed** (#47). A missing sibling file stops the
  run with `gh-flow:wave stopped — gh-flow plugin incomplete (<missing path>)`.
- **A per-issue table is not a final answer.** The next issue starts right after
  it. A run that ends without `gh-flow:wave complete` or `gh-flow:wave stopped —`
  has stopped early — no Stop hook guards these strings yet; `tests/wave-contract.sh`
  only keeps them pinned, so at run time this rule is the only guard.
