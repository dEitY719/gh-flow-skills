# gh-flow-skills

One-shot compositions that carry a GitHub issue all the way to a reviewed pull
request. A single-plugin marketplace: the plugin is `gh-flow`, and it owns the
**composition** axis of the GitHub workflow — chaining the atomic skills that
live in the sibling repos of this family, in the right order, with the right
stopping rules.

These are compositions, not implementations. Each step delegates to the skill
that owns it (`gh-issue:implement`, `gh-pr:commit`, `gh-pr:create`,
`gh-verify:review-all`, `gh-resolve:conflict`, `gh-resolve:outdated`). Nothing
here reimplements an atom, and **nothing here merges a PR by itself** — that
stays a human decision. There are two explicit exceptions, and neither merges
anything itself: `waves` and `wave` (which merge by default) have each worker delegate to `gh-pr:merge` —
the approval and label gates still apply. A `gh-pr:merge` refusal is
reported `[FAIL] not merged` and the PR is left for a human; `waves --no-merge`
and `wave --no-merge` merge nothing; `gh-pr:merge-emergency` is never called by any path.

## Skills

| Skill | Invoke | Starts from | What it does |
|-------|--------|-------------|--------------|
| `issue` | `/gh-flow:issue <N> [remote]` | An issue number | Implement, commit, open the PR, run the review gate, rebase-sync, post metrics. Stops dead at the first failing step with a resume hint. |
| `autopilot` | `/gh-flow:autopilot <spec>` | An approved spec | One step earlier: plan, file the issue, implement, open the PR, answer review comments — no approval checkpoints. Stops at review. |
| `waves` | `/gh-flow:waves [remote] [--from N] [--issues 1,2,3] [--run "<cmd>"] [--no-merge]` | A set of issues with dependencies, or the whole open backlog (default) | Plan dependency waves; per wave, one worktree and one background worker per issue carry it through `issue` to `gh-pr:merge`, then a serial `gh-verify:live` barrier. Re-plans every wave. |
| `wave` | `/gh-flow:wave <N> [remote] [--max-depth 3] [--max-issues 10] [--no-merge] [--no-verify]` | One issue and the follow-ups it spawns | Carry one issue through `issue`, `gh-pr:merge` and a fresh-clone `gh-verify:merged`, then only its descendants (open issues marked `Spawned-from: #<N>`), one at a time, depth- and count-capped. |

Pick by where you are starting. `issue` refuses to invent a spec; `autopilot`
refuses to skip one; `waves` takes a set whose order matters (by default the
whole open backlog) and refuses to
start the next wave until the last one is merged and verified; `wave` takes one
issue and refuses to touch any open issue that does not descend from it.

### `wave` vs `waves`

Same family, opposite shapes: `waves` fans a set of issues out in parallel and
gates every wave behind a live barrier; `wave` runs one issue and its own
descendants serially and verifies each merge from a fresh clone.

| | `wave` | `waves` |
|---|---|---|
| Scope | One issue plus only its descendants — open issues whose body carries `Spawned-from: #<N>`. No other open issue is touched. | A set of issues: the repo's open backlog, or `--issues` / `--label` / `--from`. |
| Execution | Serial — an internal queue, one issue at a time. | Parallel — per wave, one worktree and one background worker per issue, capped by `--max-parallel`. |
| What feeds the queue | Lineage only: any issue whose body carries `Spawned-from: #<N>` for an issue in the tree — filed during the run or already there — joins it. | A plan, computed up front from explicit dependency phrases plus file overlap, recorded on a tracking issue and re-queried after every wave. |
| Verification | Per merge: `gh-verify:merged` — a fresh clone of the merge commit. | Per wave: a barrier — pull main, restart the app (`--run`; absent, the live step is `[SKIP]`), then a serial `gh-verify:live` pass over the wave's PRs. |
| Caps | `--max-depth 3`, `--max-issues 10`; overflow is listed in `Next:`. | `--max-parallel 4` per wave; overflow moves to the next wave. `--max-issues 20`, `--max-waves 5` per run; the rest is listed in `Next:`. |
| One worker fails | That issue reports `[FAIL]`; its descendants are not processed and get a deferral comment; sibling branches continue. | That issue reports `[FAIL]`; its dependants are deferred with a blocked comment; the rest of the wave continues. |

When to use which:

- **`wave`** — finish one issue *and the follow-ups it spawns*, nothing else.
  Worked example: refactor issue #42 is implemented and merged; the fresh-clone
  verification finds a regression, so a `Spawned-from: #42` issue is filed.
  `wave` pulls that child into the same pipeline automatically and stops when
  the tree is done — fifty other open issues are irrelevant and untouched.
  Verification is `merged` because `wave` takes no `--run` and never starts an
  app; proving the merge commit behaves in a clean checkout is the whole claim.
- **`waves`** — burn down a backlog whose order matters. Worked example: epic #9
  tracks twelve issues in three layers — schema changes (#10, #11), the API work
  that depends on them (#20 to #23), the UI work that depends on those (#30 to
  #35). `/gh-flow:waves --issues 9,10,11,20,21,22,23,30,31,32,33,34,35 --run
  "make run" --max-parallel 6` limits the set to that tree (with no `--issues`,
  `--label` or `--from`, the set is every open issue in the repo). Assuming no
  two issues of a layer touch the same file — file overlap would push one of
  them a wave later — it plans wave 1 = {#10, #11}, wave 2 = {#20 to #23}, wave
  3 = {#30 to #35}, and records the plan on #9, the single epic in the set. At
  the default `--max-parallel 4`, #34 and #35 would spill into a fourth wave.
  Each wave's members run in parallel worktrees. Between waves a live barrier
  pulls main, restarts the app and verifies every PR live, so the next layer
  starts from a base that is both merged and running. The run re-queries the
  target set before planning each next wave, and closes #9 once all its
  children have landed.

A backlog with no ordering to exploit is still `waves`: every issue lands in
the first wave (split by `--max-parallel`). `--track <T> --max-parallel 1
--max-waves 20 --no-merge` runs it serially without merging — `--track` because
a plain backlog has no single epic to plan on, `--max-waves` because each
one-issue wave counts against its default of `5`; `--max-issues` (default `20`)
still caps one run, so a larger backlog takes several runs or a higher cap.
Unlike the former `drain`, `waves` merges by default and does not filter by
author unless you pass `--author @me`, and it does not skip an issue whose PR
from an earlier `--no-merge` run is still open — merge or close those first.

### Visual guides and worked examples (GitHub Pages)

- `issue` — [visual guide](https://deity719.github.io/gh-flow-skills/skill-guides/issue.html) · [usage example](https://deity719.github.io/gh-flow-skills/skill-output/issue-usage.html) (issue number to reviewed PR)
- `autopilot` — [visual guide](https://deity719.github.io/gh-flow-skills/skill-guides/autopilot.html) · [usage example](https://deity719.github.io/gh-flow-skills/skill-output/autopilot-usage.html) (approved spec to plan, issue and PR)

Each page is generated from a Markdown source under
[`docs/skill-guides/`](docs/skill-guides) and [`docs/skill-output/`](docs/skill-output).

## Requirements

| Need | Why |
|------|-----|
| `git` | All four commit and push. |
| `gh`, authenticated per host | Every skill binds `TARGET_HOST` + `TARGET_REPO` from the remote URL and prefixes each API call with `GH_HOST=` (dEitY719/dotfiles#1403), so GitHub Enterprise remotes work — but only if `gh` is logged into that host. `gh` reports no error when it lands on the wrong host, so this is not optional. |
| A dedicated worktree on a feature branch | `issue` and `autopilot` refuse to run on the repo's default branch, and neither creates the worktree for you. `waves` and `wave` are the inverse: they run from the main checkout and create one worktree per issue via `session:worktree-spawn`. |
| The atomic skill plugins | `gh-issue`, `gh-pr`, `gh-verify`, `gh-resolve` (and `session` for `waves` and `wave`). These are compositions; the steps they call live in those repos. |
| The whole `gh-flow` plugin, not one skill directory | `waves` and `wave` read `gh-flow:issue`'s `references/` (`waves` also `gh-flow:wave`'s; `wave` also `gh-flow:waves`'s) and source `skills/issue/lib/target-binding.sh`. A harness that installs a single skill directory (a Hermes GitHub tap, `npx skills add`) leaves those files missing, so a lone `waves` or `wave` stops at target binding with `gh-flow:<skill> stopped — gh-flow plugin incomplete (<missing path>)`. The shared contracts are not vendored into each skill on purpose: copies drift (#45, #47). |

## Install

### Claude Code

```
/plugin marketplace add dEitY719/gh-flow-skills
/plugin install gh-flow@gh-flow-skills
```

### Codex

```
codex plugin install dEitY719/gh-flow-skills
```

### Kimi CLI

```
kimi plugin install dEitY719/gh-flow-skills
```

### Hermes Agent

```
hermes plugins install dEitY719/gh-flow-skills
```

### OpenCode

See [`.opencode/INSTALL.md`](.opencode/INSTALL.md).

### Gemini CLI / Antigravity

```
gemini extensions install https://github.com/dEitY719/gh-flow-skills
```

Antigravity (`agy`) shares `~/.gemini`, so it inherits the install.

## Harness support

Every step these skills take is `git`, `gh`, or a local file edit, so the work
itself ports cleanly. What does not port is the thing that makes them
compositions: `Skill()`. `issue` and `autopilot` are ordered chains of other
skills, and a harness without a skill-invocation tool cannot run them as
written. Every gap and its workaround is documented per harness in
[`harness-skills/references/`](https://github.com/dEitY719/harness-skills/tree/main/references);
read the one file for the harness you are on.

| Skill | Claude Code | Codex | Kimi | Gemini / Antigravity | Hermes | OpenCode |
|-------|:-----------:|:-----:|:----:|:--------------------:|:------:|:--------:|
| `issue` | full | manual chain | manual chain | manual chain | manual chain | manual chain |
| `autopilot` | full | manual chain | manual chain | manual chain | manual chain | manual chain |
| `waves` | full | manual chain | manual chain | manual chain | manual chain | manual chain |
| `wave` | full | manual chain | manual chain | manual chain | manual chain | manual chain |

*manual chain* — without a `Skill` tool, print the ordered list of atomic skills
the chain would have invoked, run what is plain shell, and stop at the first
step that genuinely needs another skill. Do not inline a reimplementation of an
atom: the atom is what owns its own safety rules.

## The early-stop contract

`issue` and `autopilot` share one recurring failure mode: the model writes a
"done so far" summary between two chained calls, and that summary reads as a
final answer, so the run ends with the chain half-finished. It has recurred
five times across the history of these skills.

Three layered guards prevent it, and all three are load-bearing:

1. `--no-next-hint` on `issue`'s first delegated call, so the sub-skill's own
   `Next:` line never appears.
2. Zero conversational text between the chained `Skill()` calls.
3. A harness `Stop` / `SubagentStop` hook, which lives in
   [`dEitY719/dotfiles`](https://github.com/dEitY719/dotfiles)
   (`claude/hooks/gh_issue_flow_stop_guard.py`,
   `claude/hooks/devx_autopilot_stop_guard.py`) and blocks the turn while a
   chain is still in flight.

The consequence for anyone editing this repo: the terminal report strings and
step markers are a **hook contract, not prose**. `gh-flow:issue complete (#<N>)`,
`gh-flow:issue stopped at step <i>/6`, `[step:gh-flow-autopilot/<id>] OK`,
`[OK] gh-flow:autopilot`, `[FAIL] gh-flow:autopilot` — change one without the
matching hook change and the regression comes straight back. `waves`'s and
`wave`'s terminal strings (`gh-flow:waves complete` / `gh-flow:waves stopped —`, `gh-flow:wave complete` /
`gh-flow:wave stopped —`) are pinned the same way, ahead of the guards that will
match them. And neither `waves`'s nor `wave`'s coordinator ever
invokes `gh-flow:issue` itself, not even for `--help` — the installed guard
counts that call as a chain start and blocks the coordinator's turn.

Those hooks accept **only** this repo's `gh-flow:*` namespace. The
pre-migration `gh:issue-flow` / `devx-autopilot` form was dropped in Phase 4 of
that repo's migration (dEitY719/dotfiles#1410) and now appears in neither hook.

## Shared assets

This repo owns none. Two things belong to
[`dEitY719/harness-skills`](https://github.com/dEitY719/harness-skills) and are
linked, never copied:

1. **Per-harness tool mappings** — `references/*-tools.md` there. One tool
   rename must stay one edit, not fifteen.
2. **The reusable CI workflow** — `.github/workflows/skill-check.yml` there.
   This repo's `validate.yml` calls it with `plugin-name: gh-flow` and nothing
   else, so a check added upstream applies here on the next run.

## Layout

Every harness manifest sits at the repo root and points at one flat `./skills/`
directory:

```
gh-flow-skills/
├── skills/
│   ├── issue/SKILL.md        + references/ + evals/
│   ├── autopilot/SKILL.md    + references/
│   ├── waves/SKILL.md        + references/ + evals/
│   └── wave/SKILL.md         + references/ + evals/
├── .claude-plugin/{marketplace,plugin}.json   Claude Code
├── .codex-plugin/plugin.json                  Codex
├── .kimi-plugin/plugin.json                   Kimi CLI
├── .hermes-plugin/{plugin.yaml,__init__.py}   Hermes Agent
├── .opencode/plugins/gh-flow.js + INSTALL.md  OpenCode
├── .agents/plugins/marketplace.json           Antigravity
├── gemini-extension.json + GEMINI.md          Gemini CLI
├── package.json
├── CLAUDE.md + AGENTS.md -> CLAUDE.md
├── README.md · LICENSE
└── .github/workflows/validate.yml
```

Only Claude Code understands a nested `plugins/<name>/skills/` layout. The other
five harnesses resolve manifests at the repo root, so nesting would silently cut
this plugin down to Claude-Code-only. CI fails if a `plugins/` directory exists
at all.

## CI

`.github/workflows/validate.yml` calls the reusable `skill-check` workflow in
`harness-skills` with `plugin-name: gh-flow`. It enforces, among other things:

- `skills/<name>/` matches the bare `name:` in that skill's frontmatter, and
  that name carries no `:`.
- `SKILL.md` stays at or under 100 lines — detail belongs in `references/`.
- Skill descriptions sum to at most 5,440 characters (Codex's context budget),
  with a 1,024-character per-description cap.
- Every manifest agrees on the version.
- No emoji anywhere in tracked text.

## Provenance

The original four skills were extracted from
[`dEitY719/dotfiles`](https://github.com/dEitY719/dotfiles)
(`claude/skills/{gh-issue-flow,devx-autopilot}` and two relay skills)
as a content snapshot at source commit
`96c90bc8d961d51d9c3286dae730e8b928afdfc8` — no history rewriting. The dotfiles
originals are gone: `claude/skills/` was deleted there in Phase 4-1 of that
repo's migration plan (dEitY719/dotfiles#1410 NF-1 / NF-3, tracking issue
dEitY719/dotfiles#1678). The two relay skills were deleted in #55: their push
probe fired a real `git push`, which is itself the violation on a PC class where
any push toward github.com is forbidden, and everywhere else they reduced to
`issue`.

The old prefixes were stripped on the way in: `/gh:issue-flow` became
`/gh-flow:issue` and `/devx:autopilot` became `/gh-flow:autopilot`. The plugin
name already supplies the namespace at invocation time.

`drain` (written here in #13) was folded into `waves` and deleted in #65.

`waves` has no dotfiles ancestor — it was written here (issue #39), after
a session that planned four dependency waves, spawned the worktrees and wrote
the same worker brief four times by hand.

`wave` was written here too (issue #58): `waves` re-queries every open issue in
the repo each wave, so carrying one issue and only its own follow-ups to merged
and fresh-clone-verified had no home.

## License

MIT. See [`LICENSE`](LICENSE).
