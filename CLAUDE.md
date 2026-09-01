# gh-flow-skills — Contributor Guidelines

This file is the AI context document for this repo. `AGENTS.md` is a symlink to
it, so Claude Code, Codex, Gemini CLI, and every other harness read the same
text. Edit `CLAUDE.md`; never replace the symlink with a second copy.

## What this repo is

A single-plugin skill marketplace. The plugin is named `gh-flow` and it owns one
axis of the GitHub workflow: **composition** — carrying a single issue all the
way to a reviewed PR in one run, by chaining the atomic skills that live in the
sibling repos of this family.

| Skill | Starts from | Role |
|-------|-------------|------|
| `issue` | An issue number | The ordinary chain: `gh-issue:implement` → `gh-pr:commit` → `gh-pr:create` → `gh-verify:review-all` → `gh-resolve:conflict` → `gh-resolve:outdated`, then a metrics report. Stops dead at the first failing step with a resume hint. |
| `autopilot` | An approved spec | One step earlier: writes the plan, files the issue, implements, opens the PR, answers review comments — with no approval checkpoints. Never merges. |
| `issue-relay` | An issue on a push-blocked remote | Branch, delegate the implementation, verify it, then hand the commits to `relay-merge`. |
| `relay-merge` | A PR whose `git push` a proxy blocks | Probe whether a normal push actually works; only when it is genuinely blocked, relay per-commit patches through a gist with a `git am` apply-guide. |

The four split along two axes: how much of the lifecycle they own (`issue`
starts at an issue, `autopilot` at a spec) and whether the destination remote is
reachable (`issue`/`autopilot`) or push-blocked (`issue-relay`/`relay-merge`).
Merging them would erase exactly the distinction that decides which one is safe
to run.

**These are compositions, not implementations.** Each step delegates to the
atomic skill that owns it — `gh-issue:implement`, `gh-pr:commit`,
`gh-pr:create`, `gh-verify:review-all`, `gh-resolve:conflict`,
`gh-resolve:outdated`, `gh-issue:create`. Do not reimplement an atom here. If a
step needs to change, it changes in the repo that owns it.

**None of them merges a PR.** `autopilot` stops at review on purpose; merging
stays a human decision.

The skills were extracted from `dEitY719/dotfiles`
(`claude/skills/{gh-issue-flow,devx-autopilot,gh-issue-relay-flow,gh-relay-merge}`)
as a content snapshot at source commit
`96c90bc8d961d51d9c3286dae730e8b928afdfc8` — no history rewriting. The dotfiles
copies remain in place; they are removed in Phase 4 of that repo's migration
plan (#1410 NF-1 / NF-3). This is the last repo of Phase 3 (tracking issue
#1678).

The `gh-issue-flow` / `devx-autopilot` prefixes were stripped on the way in. The
plugin name already supplies the namespace at invocation time, so
`/gh:issue-flow` became `/gh-flow:issue` and `/devx:autopilot` became
`/gh-flow:autopilot` (#1410 §4, issue #1678 F-2). Do not reintroduce the
prefixes or the old dash-form aliases.

## Both name forms are live during the transition (D-12)

The two Stop hooks that keep `issue` and `autopilot` from ending a run early
live in `dEitY719/dotfiles`, not here:
`claude/hooks/gh_issue_flow_stop_guard.py` and
`claude/hooks/devx_autopilot_stop_guard.py`. Until dotfiles Phase 4 they accept
**both** namespaces — this repo's `gh-flow:issue` / `gh-flow-autopilot` markers
and the pre-migration `gh:issue-flow` / `devx-autopilot` ones — because the
dotfiles originals are still installed and its automation
(`shell-common/functions/gh_flow.sh`,
`shell-common/tools/custom/issue_watcher_cron.sh`) still dispatches the old
slash commands (#1678 D-12).

The consequence for this repo: **the terminal report strings and step markers in
`skills/issue/references/report-template.md` and `skills/autopilot/SKILL.md` are
a hook contract, not prose.** `gh-flow:issue complete (#<N>)`,
`gh-flow:issue stopped at step <i>/6`, `[step:gh-flow-autopilot/<id>] OK`,
`[OK] gh-flow:autopilot`, `[FAIL] gh-flow:autopilot` — changing any of them
without the matching hook change re-opens the early-stop regression those hooks
exist to prevent (dotfiles #333, #383, and four later recurrences).

## Layout: root manifests, one flat `skills/`

This repo deliberately does **not** use the nested `plugins/<name>/skills/`
"mono" layout. Every harness manifest sits at the repo root and points at a
single flat `./skills/` directory:

```
.claude-plugin/{marketplace,plugin}.json   Claude Code
.codex-plugin/plugin.json                  Codex
.kimi-plugin/plugin.json                   Kimi CLI
.hermes-plugin/{plugin.yaml,__init__.py}   Hermes Agent
.opencode/plugins/gh-flow.js               OpenCode
.agents/plugins/marketplace.json           Antigravity
gemini-extension.json + GEMINI.md          Gemini CLI
skills/<name>/SKILL.md                     the skills themselves
```

Only Claude Code understands the nested mono layout. The other five harnesses
resolve manifests at the repo root and a skills tree at `./skills/`, so nesting
would silently cut this plugin down to Claude-Code-only. **Do not move the
manifests under a `plugins/` directory.** CI fails if `plugins/` exists at all.

The OpenCode entry point's filename is load-bearing: it must be
`.opencode/plugins/<plugin-name>.js`, so `gh-flow.js`. `package.json`'s `main`
points at the same path.

## Shared assets live elsewhere — link, never copy

This repo owns none. Both belong to `dEitY719/harness-skills`:

**1. Per-harness tool mappings** (`references/*-tools.md` there, dotfiles #1410
F-5). Do not create a `references/` directory at this repo's root — the only
`references/` here are the per-skill ones under `skills/<name>/`. If a doc here
needs a mapping, link to
`https://github.com/dEitY719/harness-skills/blob/main/references/<harness>-tools.md`.
One tool rename must stay one edit, not fifteen (NF-2). The single sanctioned
mirror is the condensed summary inside `.kimi-plugin/plugin.json`'s
`skillInstructions`, because Kimi CLI cannot read a reference file at load time;
keep it short and keep it pointing upstream.

**2. The reusable CI workflow** (`.github/workflows/skill-check.yml` there,
D-10). This repo's `validate.yml` calls it with `plugin-name: gh-flow` and
nothing else. Do not fork it into a standalone workflow — a check added upstream
should apply here on the next run, which is the whole point.

## Rules for changing skills

- **Skill directory name is the identity.** `skills/<name>/` must match the
  `name:` field in that skill's `SKILL.md` frontmatter, and that field is the
  **bare** name (`issue`), never namespaced (`gh-flow:issue`). CI fails on a `:`
  in the name and on any mismatch with the directory. The harness supplies the
  `gh-flow:` prefix at invocation time.
- **Invocation form in prose is namespaced.** Body text referring to a skill in
  this repo as a command writes `/gh-flow:issue`.
- **Cross-repo references keep their own namespace.** `gh-issue:implement`,
  `gh-issue:create`, `gh-pr:commit`, `gh-pr:create`, `gh-verify:review-all`,
  `gh-resolve:conflict`, `gh-resolve:outdated`, and `session:restart` live in
  other repos of this family; `gh:pr-reply`, `gh:pr-merge-train`, and
  `devx:schedule` are still in `dEitY719/dotfiles` under their old names. Leave
  each exactly as written; only siblings inside `skills/` take the `gh-flow:`
  prefix.
- **Progressive disclosure.** `SKILL.md` stays at or under 100 lines (CI
  enforces it) and names which `references/` file to read and when. Detail lives
  in `references/`. All four are within a line or two of the limit — when a step
  grows, move prose out; never delete a safety rule to buy lines.
- **Description budget.** CI sums every skill description and fails past 5,440
  characters — Codex's context budget — with a per-description cap of 1,024.
  Keep the "not this, that" disambiguation: `issue` takes an issue number and
  `autopilot` takes a spec, and that one sentence is what keeps them apart.
- **Honour each skill's safety contract.** These are acceptance criteria, not
  advice:
  - No skill here merges a PR. `autopilot` stops at review by design.
  - `issue` stops at the first failing step and prints a resume hint. It never
    retries a step and never skips one. The soft-fail exceptions
    (`gh-verify:review-all`, the merge-train wake, the metrics comment) are
    enumerated in `skills/issue/references/constraints.md`; do not add a third
    kind of exception without updating that file.
  - **Zero conversational text between the chained `Skill()` calls** of `issue`
    and `autopilot`, and `--no-next-hint` on `issue`'s first call. Both are
    mechanical guards against the early-stop failure mode, not style advice.
  - `relay-merge` probes whether `git push` actually works before relaying, and
    hands off to `gh-pr:create` when it does. The patch+gist relay is a
    fallback, never the default. It never truncates an oversized patch silently.
  - Neither relay skill rewrites history on the destination remote.
- **Host pinning is not optional.** Every skill binds `TARGET_HOST` +
  `TARGET_REPO` from the remote URL before any `gh` call and prefixes each call
  with `GH_HOST=` (#1403). Dropping the prefix sends a GHES repo's request to
  `github.com`, and `gh` reports no error when it lands on the wrong host — the
  divergence surfaces later as a "missing" issue or PR.

## Version bumps

The version appears in seven manifests: `.claude-plugin/marketplace.json`
(`plugins[0].version`), `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`,
`.kimi-plugin/plugin.json`, `.hermes-plugin/plugin.yaml`,
`gemini-extension.json`, and `package.json`. CI checks that they agree — bump
all of them together. Versioning is independent per repo (#1410 D-9); this repo
does not move in lockstep with its siblings.

## No emojis

Anywhere in this repo. Token efficiency, and CI rejects them (it flags any
codepoint at or above `U+1F000`, plus `U+FE0F`). The dotfiles `ai-metrics`
footer exception (#317 F-2) does **not** travel with the skills — the migrated
copies render that footer as plain text.
