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
  descendants are not processed. `--no-merge` merges nothing.
- **Only marked descendants are processed** (F-3). An open issue enters the
  queue only through an exact `Spawned-from: #<N>` line whose `<N>` is an issue
  already in this run's tree (`references/lineage.md`). Every other open issue
  in the repo is out of scope, however related it looks.
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
  on each of its descendants in the three-part form of `gh-flow:drain`'s
  `references/blocked.md` ((a) parent `#<N>` failed, (b) `#<N>` merged,
  (c) re-run `/gh-flow:wave <root>`), and the siblings go on. No `blocked`
  label for this case — the open, unmerged parent re-derives it on resume.
- **Verify failures become marked issues** (F-5). `gh-verify:merged` failing is
  filed with `gh-issue:issue-create --no-ask` carrying `Spawned-from: #<N>`, and
  queued as a descendant within the caps.
- **A failed marker-issue creation is fatal.** If `gh-issue:issue-create` fails
  for a verify failure or a promotion, stop:
  `gh-flow:wave stopped — promotion failed (<reason>)`. The rule and its reason
  are `gh-flow:drain`'s `references/promotion.md` "Failure is fatal" — an item
  that vanishes there vanishes from the tree too.
- **Deferred items become issues.** Workers file them under `gh-flow:drain`'s
  `references/promotion.md` rules, with the lineage marker; this skill
  references that file and does not restate it.
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
