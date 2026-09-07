# gh-flow:issue-relay — Destination Remote + Branch Setup

Detailed procedure for Step 2. The deterministic part — remote resolution,
default-branch detection, and slugifying the issue title into a branch name —
is `lib/branch-setup.sh`; this file covers the *why* plus the one part the
script deliberately leaves out: the reuse-or-reset conversation with the user.

```bash
eval "$(bash "${CLAUDE_PLUGIN_ROOT}/skills/issue-relay/lib/branch-setup.sh" "$REMOTE" "$N" [--base "$BASE"])" || exit 1
```

Prints `DEST_REPO=... DEST_HOST=... BASE_BRANCH=... BRANCH=...` for `eval`.
Its own header documents inputs/outputs in full (`skill-check` Check 12: this
used to be a prose command sequence, including hand-slugified branch-name
prose that could produce a different name on a second run of the same title —
now one deterministic script, unit-tested in
`lib/branch-setup.selfcheck.sh`).

Remote resolution inside the script mirrors `gh-flow:relay-merge`'s
`skills/relay-merge/references/remote-resolution.md` — same
default (`upstream`), same hard-error-on-missing-remote rule, same
never-fall-back-to-`origin` rule. It is issue-relay's own copy rather than a
shared implementation because `relay-merge` also accepts a raw-URL
destination with no configured remote, which this skill's `--remote <name>`
never takes.

`DEST_REPO`/`DEST_HOST` are required downstream: Step 3's issue fetch runs as
`GH_HOST="$DEST_HOST" gh issue view <N> --repo "$DEST_REPO" ...`, and
`gh-flow:relay-merge` re-resolves the same pair for its own calls. Never
export a single global `GH_HOST` in this flow — `origin` and the destination
are deliberately different hosts (dEitY719/dotfiles#1403 / dEitY719/dotfiles#1407).

## Branch naming: `issue-<N>-<title-slug>`

**Why issue-number-first, not `wt/<agent>/<N>`:** this session itself runs
on a worktree branch prefixed `issue-1346` (e.g. `wt/issue-1346/1`), so an
issue-number-first branch name greps consistently alongside it — searching
`issue-1346` finds both the worktree branch and this flow's working branch.
This is deliberately a *different* namespace from `session:worktree-spawn`'s
`wt/<agent>/<N>` convention — that one names a *worktree* (an agent-owned
sandbox), this one names a *working branch inside an existing worktree*
that will be pushed via relay. Do not conflate the two.

## Create or reuse

```bash
git checkout -b "$BRANCH" "$REMOTE/$BASE_BRANCH"
```

If a local branch with that exact name already exists, `checkout -b` fails.
Handle it instead of erroring out:

1. `LOCAL_TIP=$(git rev-parse "$BRANCH")` and
   `DEST_TIP=$(git rev-parse "$REMOTE/$BASE_BRANCH")`.
2. **`LOCAL_TIP == DEST_TIP`** — the branch is a clean, unmodified snapshot
   of the destination default branch. Just `git checkout "$BRANCH"`
   and continue; no confirmation needed.
3. **`LOCAL_TIP != DEST_TIP`** — check for unique work first:
   ```bash
   git log "$REMOTE/$BASE_BRANCH..$BRANCH" --oneline
   ```
   - **Any commits listed** — the branch has work not on the destination.
     **Never reset automatically.** Tell the user: "Branch `$BRANCH`
     has N unique commit(s) not on `$REMOTE/$BASE_BRANCH`: <list>. Reset
     to `$REMOTE/$BASE_BRANCH` (discarding them) or keep and continue on
     top of them?" — wait for the answer.
   - **No commits listed** — the branch is just a stale snapshot (destination
     moved forward, or a local no-op commit predates it with no unique diff
     content). Ask before touching it anyway ("branch `$BRANCH`
     is stale relative to `$REMOTE/$BASE_BRANCH` but has no unique
     commits — reset it?"), then on yes:
     ```bash
     git checkout "$BRANCH"
     git reset --hard "$REMOTE/$BASE_BRANCH"
     ```

Never silently pick a resolution for case 3 — both branches of it require
an explicit user answer before mutating anything.
