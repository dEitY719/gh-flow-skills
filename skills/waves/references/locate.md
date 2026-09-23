# gh-flow:waves — Issue-URL invocation (#41)

`/gh-flow:waves https://<host>/<owner>/<repo>/issues/<N> [flags]` — run from the
repo's main checkout **or from any directory above it** (a folder of clones,
itself not a git repo). Only a first positional of the form
`http(s)://<host>/<owner>/<repo>/issues/<N>` takes this path; anything else is
the `[remote]` name exactly as before (NF-1), and none of this file applies.

## 1. Locate the main checkout (F-1, F-2) — read-only

```bash
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || case "<skill-base-dir>" in /*) CLAUDE_PLUGIN_ROOT=$(cd -P -- "<skill-base-dir>/../.." 2>/dev/null && pwd) ;; esac  # tier 2, agent-filled (#41)
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] &&                                               # tier 2
    [ -f "$CLAUDE_PLUGIN_ROOT/skills/waves/lib/locate-checkout.sh" ]; then           # proof
    bash "$CLAUDE_PLUGIN_ROOT/skills/waves/lib/locate-checkout.sh" "<issue-url>" || exit 2
else                                                                                 # tier 5
    printf '[gh-flow:waves] cannot locate skills/waves/lib/locate-checkout.sh under CLAUDE_PLUGIN_ROOT (%s). On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
        "${CLAUDE_PLUGIN_ROOT:-unset}" >&2
    exit 1
fi
```

`<skill-base-dir>` is explained in `../../issue/references/target-binding.md`.
Search order, remote matching and the linked-worktree exclusion are in the
script's header; it does no git write, not even a fetch (NF-2). Its self-check,
`lib/locate-checkout.selfcheck.sh`, covers every arm below.

- **Exit 0** prints `MAIN=`, `REMOTE=`, `HOST=`, `REPO=`, `ISSUE=`. Record them
  as literal values — later Bash calls do not inherit this one's variables.
- **Exit 2** prints one reason: not an issue URL, no match (with the
  `git clone` line to run — never run it for the user), only linked worktrees
  matched, or 2+ main checkouts (their paths). End with
  `gh-flow:waves stopped — checkout not found (<reason>)`.

## 2. Bind the target from `MAIN` (F-3)

Every coordinator Bash call from here on starts with `cd "<MAIN>" &&` (or uses
`git -C "<MAIN>"`): the target binding, every fetch/pull/merge-base, the
barrier's pull and `--run`, and the Bash call right before each
`Skill(session:worktree-spawn, ...)` — that skill resolves the repo from the
cwd. The binding is the unchanged block from
`../../issue/references/target-binding.md` with `<remote>` = the `REMOTE` value.
Afterwards `TARGET_HOST`/`TARGET_REPO` must equal `HOST`/`REPO`
(case-insensitive); a mismatch stops with the same `checkout not found` line.

## 3. Scope and tracking issue (F-4, F-5)

- **Target set** = every open issue of `REPO` not labelled `blocked` — the plain
  `plan.md` §1 listing. The URL's issue is not special: it is planned by its
  dependencies like any other, and drops out naturally when closed.
  `--issues`, `--from` and `--label` narrow the set exactly as without a URL.
- **Tracking issue** = `--track N` if given, else the single epic in the set,
  else `ISSUE` — the run does not stop for a missing tracking issue. A closed
  `ISSUE` still takes the plan comment, with one `[WARN] tracking issue #<N> is
  closed` line in the report.
