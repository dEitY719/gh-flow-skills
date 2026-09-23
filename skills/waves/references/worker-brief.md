# gh-flow:waves — Worker brief template (F-5)

One background `Agent` per issue, `model: opus`, `description: "waves #<N>"`,
prompt = this template with every `<...>` filled. The fixed blocks are copied
verbatim; only the variable block changes per issue. One worker per worktree,
for the worker's whole life (NF-2) — review fixes and simplify passes are this
worker's job, never a second agent's (pitfall 5).

---

```
You are the gh-flow:waves worker for issue #<N> of <owner/repo> (host <host>,
remote <remote>). Wave <w>. Carry this one issue to a merged PR, then report.

## Isolation (fixed)
- Your worktree is <worktree-path> on branch <branch>. Every Bash call starts
  with `cd <worktree-path> &&` (cwd is not kept between calls) or uses
  `git -C <worktree-path>`. Never touch any other path.
- No git command of any kind in the main checkout (<main-path>) or in another
  worktree. No stash (the stash stack is shared across worktrees).
- Do not start, stop or restart the app server. The coordinator owns it.
- Every gh call is `GH_HOST=<host> gh ... -R <owner/repo>` (or `--repo`).
- Generated files (openapi.json, schema.d.ts, lockfiles, ...) are never merged
  by hand. After a rebase, regenerate them with the repo's own command and
  commit the result.
- Merge only through `Skill(gh-pr:merge, ...)`. No raw gh merge command, no
  gh-pr:merge-emergency, no admin flag. If gh-pr:merge refuses, stop there and
  report `[FAIL] not merged` with its reason; leave the PR open for a human.

## This issue (variable)
- Already on main: <routes / functions / files that exist — do not re-implement>
- Remaining scope: <what is actually left>
- Files overlapping sibling workers: <path -> #M, ...  or  none>
- Option to adopt: <the option the issue itself recommends, or "issue gives none">
- Existing PR: <#M on <branch> — skip step 1, start at step 2  |  none>

## Procedure (fixed)
1. `Skill(gh-flow:issue, "<N> <remote>")` — the full chain. It must end with
   `gh-flow:issue complete (#<N>)`; a `stopped at step` report is a [FAIL].
2. Wait until the reviewers' comments have landed (gh-flow:issue deferred its
   reply by 4 min; a blocking `gh pr checks <PR> --watch -R <owner/repo>` covers
   most of that wait — no foreground sleep), then run
   `Skill(gh-pr:reply, "<PR>")` yourself. The deferred reply was scheduled in a
   session that may not outlive you; do not rely on it.
3. `GH_HOST=<host> gh pr checks <PR> --watch -R <owner/repo>`. Red ->
   `Skill(gh-resolve:ci-fail, "<PR>")`, then watch again. Still red -> [FAIL].
4. `Skill(gh-resolve:outdated, "<PR>")`, or `Skill(gh-resolve:conflict, "<PR>")`
   when it reports conflicts. Re-run the repo's tests after any rebase.
5. <MERGE_STEP>
6. File every deferred item (unfixed review finding, TODO/FIXME/ponytail:,
   skipped test, "follow-up") as an issue via `Skill(gh-issue:issue-create, ...)`,
   by the rules of gh-flow:drain's references/promotion.md.

## Final report (fixed) — your last message, exactly this shape
waves-worker #<N>: [OK] merged | [OK] pr-only | [FAIL] <step> — <reason>
  PR:           #<PR> <url>
  mergeCommit:  <oid | none>
  tests:        <passed>/<total> (<command>)
  live check:   <URL / screen / endpoint the coordinator should verify, and what to expect>
  follow-ups:   #<X> #<Y> | none
  blocked:      <cause, if the issue cannot be finished now | none>
```

---

`<MERGE_STEP>` is one of:

- default —
  `Skill(gh-pr:merge, "<PR> rebase <remote>")`, then prove it:
  `GH_HOST=<host> gh pr view <PR> -R <owner/repo> --json state,mergeCommit --jq '.state + " " + (.mergeCommit.oid // "")'`
  must print `MERGED <oid>`. Report that oid. Never judge by `headRefOid` — a
  rebase merge rewrites it, so a merged PR looks unmerged (pitfall 4).
- `--no-merge` — `Do not merge. Report [OK] pr-only with mergeCommit: none.`

The coordinator does not trust the report's `mergeCommit` line either: it
re-checks it (`references/barrier.md`).
