# gh-flow:waves — Planning (F-2, F-3, F-7, #64) and spawning (F-4)

## 1. List the target set

```
LIMIT=1000
GH_HOST="$TARGET_HOST" gh issue list --repo "$TARGET_REPO" \
  --state open --limit "$LIMIT" [--label "$LABEL"] [--author "$AUTHOR"] \
  --json number,title,labels,body --jq '[.[] | {number, title, labels: [.labels[].name],
    filed_by_run: [(.body // "") | match("(?:^|\n)Filed-by-run: waves #([0-9]+)[ \t\r]*(?=\n|$)"; "g")
      | .captures[0].string | tonumber]}]'
```

`filed_by_run` lists every tracking issue a `Filed-by-run:` line names, so the
query needs no `<T>` and runs before the tracking issue is chosen.

Then drop: numbers below `--from`, numbers outside `--issues`, anything labelled
`blocked`, anything carrying an exclude label (below), and issues this run
already finished or failed. A count equal to
`$LIMIT` means the list was truncated — say so, never claim a clean zero.

**Exclude labels** (dEitY719/gh-flow-skills#70 F-3) mark human-only work — a
runbook, another machine's local setup — that no PR can finish. Each
candidate's `labels` from the list above goes through `gh-flow:issue`'s
`lib/manual-gate.sh`, the SSOT for the verdict (set `GH_FLOW_EXCLUDE_LABELS`,
default `wontfix,not-implement,manual`):

```
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || case "<skill-base-dir>" in /*) CLAUDE_PLUGIN_ROOT=$(cd -P -- "<skill-base-dir>/../.." 2>/dev/null && pwd) ;; esac  # tier 2, agent-filled (#41)
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/skills/issue/lib/manual-gate.sh" ] ||
    { printf 'gh-flow:waves stopped — gh-flow plugin incomplete (skills/issue/lib/manual-gate.sh)\n'; exit 1; }
printf '%s\n' '<label 1>' '<label 2>' ... |   # one single-quoted word per label
    sh "$CLAUDE_PLUGIN_ROOT/skills/issue/lib/manual-gate.sh" 0
# -> "pass" | "excluded <label>"
```

Quote each label as its own single-quoted word (a `'` inside a name becomes
`'\''`): an unquoted `on hold` splits into two labels, and a `(`, `;` or `$` in
a name breaks or runs as shell.
The labels came from a list query that succeeded, so the lookup status is `0`;
a failed list query already stopped the run (below). An issue `--issues` names
explicitly is dropped the same way — naming it is not an override, there is no
`--force-manual` here — but always with its reason. Every dropped issue is one
report line `excluded (label): #<N> <label>` (`references/report-template.md`)
and is never dispatched, so a dependant of an excluded issue cannot start: it
is deferred with the three-part comment of `references/blocked.md`, label-less.

**This run's follow-ups are dropped too** (#64 F-3): an issue whose
`filed_by_run` contains `<T>` — its body carries the line `Filed-by-run: waves #<T>`,
`<T>` being this run's tracking issue (§5) — is not a target, unless `--issues`
names it explicitly (that is how the next run picks it up). Every issue this run
files carries the line: workers add it (`references/worker-brief.md`), and so
does the coordinator for a live failure (`references/barrier.md`). The excluded
numbers are reported under `filed this run` and in `Next:`. Because the marker
is on GitHub, a fresh session rebuilds the same exclusion (§6). Within a
session, also drop every number the run already knows it filed — workers'
`follow-ups:` and the coordinator's own live-failure issues — marker or not, so
a body line `gh-issue:issue-create` reworded cannot leak one back in. When the
tracking issue is not known yet on the first listing (it is the single epic of
the set), list, choose `<T>` by §5, then apply the drop. Requery is for issues
other people opened and dependencies that changed, not for this run's output.

**Run caps** (#64 F-4), per invocation: `--max-issues N` (default `20`) issues
dispatched to workers, `--max-waves W` (default `5`) waves started. A wave that
would pass `N` keeps the lowest numbers that fit; once either cap is reached no
further wave starts, and every target left is listed under `capped` and in
`Next:` — not processed, not failed.
A capped issue is listed only under `capped`, never also under `left open` or
`deferred` — its dependants too, since no wave starts to block them.

**`<T>` must stay the same across runs.** The marker names the tracking issue,
not one invocation, so a re-run that picks a different `<T>` (the epic closed,
a second epic appeared) cannot recognise the earlier follow-ups. Re-run with
`--track <T>`; the `Next:` command always passes it.

**A failure here stops the run before the wave starts** — a failed or
partial list query never falls through to an empty or stale target set, and
no wave is planned from it. Planning over an unknown state is how work gets
redone or lost.

## 2. Read each candidate

One `GH_HOST="$TARGET_HOST" gh issue view <N> --repo "$TARGET_REPO" --json body,comments` per
candidate, read once per plan. From each, extract:

- **Explicit dependencies** — `Depends on #M`, `Blocked by #M`, `#M 이 먼저`,
  `#M 먼저`, "이 이슈가 먼저다" (written on `#M`, pointing at this issue), and
  GitHub's `blockedBy` links (`GH_HOST="$TARGET_HOST" gh api graphql` on `issue.blockedBy`). Comments
  count as much as the body — a dependency added mid-run usually lands in one.
- **File paths** the body names (`src/...`, `app/routes/x.py`, ...).
- **Epic** — an issue whose body carries a child table / task list of `#N`
  references. An epic is not implemented; it is closed in Step 5 once every
  child is closed (`GH_HOST="$TARGET_HOST" gh issue close <N> --repo "$TARGET_REPO" --comment "<children and their PRs>"`).

## 3. Check what is already on main (pitfall 8)

For each candidate, grep the default branch for the routes, functions or files
the issue asks for. Anything already present is written into the worker brief as
**already on main**, and only the rest as **remaining scope**. Skipping this is
how a worker re-implements what an epic PR already shipped.

## 4. Build the waves

1. Edges: explicit dependencies. An edge to an issue that is closed, or outside
   the set and not open, is satisfied.
2. Cycles: print the cycle (`#A -> #B -> #A`), drop every issue on it from the
   plan, and list them in the report. Do not guess an order.
3. Layer: wave 1 = no unsatisfied edge; wave k = every edge points into waves
   `< k`.
4. File overlap: two issues in the same wave that name the same file are split —
   the higher number moves to the next wave — unless the overlap is only a
   generated file (`openapi.json`, `schema.d.ts`, lockfiles), which the workers
   regenerate after rebase instead (pitfall 6). Remaining overlaps go into each
   brief as **files overlapping sibling workers**. This only sees paths an
   issue names; an overlap nobody named surfaces later as a rebase conflict at
   the worker's sync step (`gh-resolve:conflict`), not as a silent clobber.
5. `--max-parallel K`: a wave larger than `K` keeps the `K` lowest numbers; the
   rest move to the next wave.

## 5. Record the plan (F-3)

One comment on the tracking issue (`--track N`, else the single epic in the set;
else the `<issue-url>` issue (`references/locate.md` §3); with none of these,
stop: `gh-flow:waves stopped — no tracking issue`):

```
<!-- gh-flow:waves plan -->
gh-flow:waves plan (<owner/repo> on <remote>) — rev <r>

| wave | issue | depends on | overlapping files | already on main |
|------|-------|------------|-------------------|-----------------|
| 1    | #189  | -          | app/routes/x.py   | GET /x          |

excluded: #A #B (cycle), #C (blocked), #D (filed this run), #E (label: manual)
```

Re-planning posts a **new** comment with `rev` + 1; never edit the old one.

## 6. Resume from GitHub alone

A fresh session re-invoked with the same command re-derives everything: closed
issues drop out of step 1, merged predecessors satisfy their edges, and the
newest `gh-flow:waves plan` comment on the tracking issue shows where the last
run was, and the `Filed-by-run: waves #<T>` lines re-derive which open issues
the run filed and must keep out (§1). An open issue that already has an open PR from an earlier run — one
query per plan, matched on `closes` — is not re-implemented:

```bash
GH_HOST="$TARGET_HOST" gh api graphql -F owner="${TARGET_REPO%%/*}" -F name="${TARGET_REPO#*/}" \
  -f query='query($owner:String!,$name:String!){repository(owner:$owner,name:$name){
    pullRequests(states:OPEN,first:100){pageInfo{hasNextPage}
      nodes{number headRefName closingIssuesReferences(first:25){nodes{number}}}}}}' \
  --jq '.data.repository.pullRequests | (.nodes[] | {number, headRefName,
    closes: [.closingIssuesReferences.nodes[].number]}), (select(.pageInfo.hasNextPage) | "TRUNCATED")'
```

Not `gh pr list --json closingIssuesReferences`: gh 2.45.0 rejects that field
(`Unknown JSON field`), so the resume rule broke on it (#41 F-7). A `TRUNCATED`
line means more than 100 open PRs — say so rather than treat the rest as absent.
Such an issue's brief says **existing PR #M** and the worker starts at the
reply step on a worktree checked out on that PR's branch. No state file.

## 7. Spawn (F-4)

Per wave, before any spawn — the first wave included — fast-forward the main
checkout (#64 F-6): check `git symbolic-ref --short HEAD` prints
`<default-branch>`, then `git pull --ff-only "$REMOTE" <default-branch>`. The
first wave has no barrier pull before it, and with `--no-merge` (or a wave that
merged nothing) the barrier does not pull at all, so this is what keeps a stale
local base from making the first wave's self-review re-review earlier merges.
After a barrier pull it is a no-op. Not on `<default-branch>`, local changes in
the way, or a diverged base stops the run:
`gh-flow:waves stopped — base not fast-forwardable (<reason>)` — local changes
in `MAIN` are never overwritten. The pull also updates `$REMOTE/<default-branch>`,
which `session:worktree-spawn` branches from. Then per issue:
`Skill(session:worktree-spawn, "--no-enter --task issue-<N> --base $REMOTE/<default-branch>")`
(explicit, so a non-`origin` remote or non-`main` default is honoured). Record the `Path:` and
`Branch:` it prints. `--no-enter` keeps the coordinator's cwd fixed — without it
Claude Code's `EnterWorktree` moves the session (dEitY719/session-skills#38). Do
**not** follow its `cd` either — the coordinator stays in the main checkout for the barrier. Branch naming is that
skill's.

Bootstrap, in the new worktree, first match wins:

1. `--bootstrap "<cmd>"` — run as given with the worktree as cwd.
2. `.claude/gh-flow-waves.sh` in the main checkout, only if `[ -f ]` proves it —
   `bash <main>/.claude/gh-flow-waves.sh <worktree-path>`. It is the repo's own
   code, at the same trust level as `--run`.
3. Nothing.

A spawn or bootstrap failure fails that issue (`[FAIL] spawn`) and the wave goes
on without it.
