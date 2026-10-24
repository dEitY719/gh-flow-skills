# gh-flow:wave — Spawn (Step 2.1): main mode and reuse mode (#71)

The coordinator either starts in the repo's **main checkout** (main mode, the
original path) or inside a **linked worktree that already belongs to the root
issue** (reuse mode) — e.g. a session a watcher opened with
`gwt spawn --wt-name issue-<N>` (dEitY719/dotfiles#2281). Decide once, before
the first spawn, and keep the mode for the whole run.

**Requires** `session:worktree-spawn` from session-skills 0.1.8 or later
(dEitY719/session-skills#38: `--no-enter`, main-based sibling paths) and Git
2.31+ (`--path-format=absolute`; older Git returns a relative path and the
mode check below silently picks main mode).

## 0. Detect the mode and find `MAIN`

```sh
GIT_DIR_ABS=$(git rev-parse --path-format=absolute --git-dir)
GIT_COMMON=$(git rev-parse --path-format=absolute --git-common-dir)
MAIN=$(dirname "$GIT_COMMON")     # the real main checkout, from either mode
# shortcut: wrong for a submodule or bare-repo layout (common dir is not <main>/.git); use `git worktree list --porcelain`'s first entry if wave must run there
BR=$(git symbolic-ref --short HEAD 2>/dev/null || true)
```

`GIT_DIR_ABS` = `GIT_COMMON` is the main checkout (main mode). Different is a
linked worktree (reuse mode, if the branch matches — below). `MAIN` always
comes from `--git-common-dir`, never from the coordinator's cwd: in reuse mode
the cwd is the root worktree, and filling the brief's `<main-path>` with it
would point the worker's "no git in the main checkout" rule at the wrong path.

## 1. Main mode (unchanged path)

`git symbolic-ref --short HEAD` must print `<base>` (else stop, reason
`not on <base>`), then `git pull --ff-only <remote> <base>` (non-ff:
`gh-flow:wave stopped — base not fast-forwardable (<reason>)`), then per issue:

```
Skill(session:worktree-spawn, "--no-enter --task issue-<N> --base <remote>/<base>")
```

Record `Path:` / `Branch:`. `--no-enter` keeps the coordinator's cwd fixed —
without it Claude Code's `EnterWorktree` moves the session into the new
worktree and the next descendant's spawn fails (dEitY719/session-skills#38).

## 2. Reuse mode (linked worktree)

The branch must belong to the root issue `<N>`, in either naming form:

```sh
printf '%s\n' "$BR" | grep -Eqx "wt/issue-<N>/[^/]+|wt/[^/]+/[^/]*-issue-<N>"
```

`wt/issue-<N>/<k>` is gwt's form, `wt/<agent>/<k>-issue-<N>` is
`session:worktree-spawn`'s. No match (or detached HEAD):
`gh-flow:wave stopped — running in an unrelated worktree (<branch>)`.

On a match, print one warning line
(`[WARN] reuse mode: root #<N> runs in this worktree (<path>)`) and adopt the
current top-level (`git rev-parse --show-toplevel`) as the root issue's `Path:`.
For the root issue **skip** the `not on <base>` check, the pull and the spawn.
Instead check only that the branch can sit on top of `<remote>/<base>`:

```sh
git fetch <remote> <base>
git merge-base --is-ancestor <remote>/<base> HEAD ||
    git merge-tree --write-tree HEAD <remote>/<base> >/dev/null
```

Exit 1 (conflict): `gh-flow:wave stopped — worktree not rebasable onto <base>`.
Any other non-zero is not a conflict (`merge-tree --write-tree` needs Git 2.38+):
print a `[WARN]` line and go on — the worker's rebase step decides. A clean
merge only approximates a clean rebase; the worker's `gh-resolve:*` step is the
real proof. A dirty tree is a resume of the same issue: allow it with a
`[WARN]` line, never clean it. The merge-tree check covers committed state
only — uncommitted changes in a dirty resume are not part of it.

If the root already has an open PR (`references/lineage.md` "Resume"), its
`headRefName` must equal `$BR` — the worker resumes that PR in this worktree.
A different head branch is the unrelated-worktree stop above, with `<branch>`
= `$BR` (the report's `Next:` names the PR's own head branch).

The root worktree is then shared by the coordinator and the root's single
worker. The coordinator edits and commits nothing there — one worker per
worktree (NF-2) still holds; the coordinator only reads and runs `gh`.

**Descendants in reuse mode** get their own sibling worktree, never the root's:
`git fetch <remote> <base>`, then the same
`Skill(session:worktree-spawn, "--no-enter --task issue-<C> --base <remote>/<base>")`.
After dEitY719/session-skills#38 that skill computes the sibling path from the
main checkout even when called from inside a worktree. Never pull `MAIN`: it is
the user's checkout and may be on another branch; the fetch plus a remote-ref
base gives the same freshness. The printed `Path:` must not lie under the root
worktree (`git rev-parse --show-toplevel`): a nested path means a pre-#38
`session:worktree-spawn` — fail that issue `[FAIL] spawn`, never dispatch into it.

## 3. Both modes

- Bootstrap: `.claude/gh-flow-waves.sh` in `MAIN`, only if `[ -f ]` proves it —
  `bash <MAIN>/.claude/gh-flow-waves.sh <worktree-path>`; otherwise none (wave
  has no `--bootstrap`). The reused root worktree is not bootstrapped again.
- Never `cd` into a spawned worktree. The rest of the procedure is
  `gh-flow:waves`'s `references/plan.md` §7.
