# gh-flow-skills

One-shot compositions that carry a GitHub issue all the way to a reviewed pull
request. A single-plugin marketplace: the plugin is `gh-flow`, and it owns the
**composition** axis of the GitHub workflow — chaining the atomic skills that
live in the sibling repos of this family, in the right order, with the right
stopping rules.

These are compositions, not implementations. Each step delegates to the skill
that owns it (`gh-issue:implement`, `gh-pr:commit`, `gh-pr:create`,
`gh-verify:review-all`, `gh-resolve:conflict`, `gh-resolve:outdated`). Nothing
here reimplements an atom, and **nothing here merges a PR** — that stays a human
decision. `drain --merge` is the one explicit exception, and even it only
delegates to `gh-pr:merge-train`, whose approval and label gates still apply.

## Skills

| Skill | Invoke | Starts from | What it does |
|-------|--------|-------------|--------------|
| `issue` | `/gh-flow:issue <N> [remote]` | An issue number | Implement, commit, open the PR, run the review gate, rebase-sync, post metrics. Stops dead at the first failing step with a resume hint. |
| `autopilot` | `/gh-flow:autopilot <spec>` | An approved spec | One step earlier: plan, file the issue, implement, open the PR, answer review comments — no approval checkpoints. Stops at review. |
| `issue-relay` | `/gh-flow:issue-relay <N> <remote>` | An issue on a push-blocked remote | Branch, delegate the implementation, verify it, then hand the commits to `relay-merge`. |
| `relay-merge` | `/gh-flow:relay-merge <PR>` | Commits bound for a push-blocked remote | Probe whether push actually works; only when it is genuinely blocked, relay per-commit patches through a gist with a `git am` apply-guide. |
| `drain` | `/gh-flow:drain [owner/repo] [remote]` | A repo's open backlog | Run the whole backlog through `issue`, one issue at a time, promoting every deferred item to a new issue. Ends only when open issues and deferred items are both zero. |

Pick by where you are starting and whether the destination accepts a push.
`issue` refuses to invent a spec; `autopilot` refuses to skip one; neither relay
skill runs when a plain `git push` works; `drain` starts from a backlog that
already exists and refuses to finish while anything found along the way is
sitting in a ledger instead of an issue.

### Visual guides and worked examples (GitHub Pages)

- `issue` — [visual guide](https://deity719.github.io/gh-flow-skills/skill-guides/issue.html) · [usage example](https://deity719.github.io/gh-flow-skills/skill-output/issue-usage.html) (issue number to reviewed PR)
- `autopilot` — [visual guide](https://deity719.github.io/gh-flow-skills/skill-guides/autopilot.html) · [usage example](https://deity719.github.io/gh-flow-skills/skill-output/autopilot-usage.html) (approved spec to plan, issue and PR)
- `issue-relay` — [visual guide](https://deity719.github.io/gh-flow-skills/skill-guides/issue-relay.html) · [usage example](https://deity719.github.io/gh-flow-skills/skill-output/issue-relay-usage.html) (issue on a push-blocked remote to a relayed handoff)
- `relay-merge` — [visual guide](https://deity719.github.io/gh-flow-skills/skill-guides/relay-merge.html) · [usage example](https://deity719.github.io/gh-flow-skills/skill-output/relay-merge-usage.html) (commit range to gist patches and an apply-guide)

Each page is generated from a Markdown source under
[`docs/skill-guides/`](docs/skill-guides) and [`docs/skill-output/`](docs/skill-output).

## Requirements

| Need | Why |
|------|-----|
| `git` | All five commit, push, or format patches. |
| `gh`, authenticated per host | Every skill binds `TARGET_HOST` + `TARGET_REPO` from the remote URL and prefixes each API call with `GH_HOST=` (dEitY719/dotfiles#1403), so GitHub Enterprise remotes work — but only if `gh` is logged into that host. `gh` reports no error when it lands on the wrong host, so this is not optional. |
| A dedicated worktree on a feature branch | `issue` and `autopilot` refuse to run on the repo's default branch, and neither creates the worktree for you. |
| The atomic skill plugins | `gh-issue`, `gh-pr`, `gh-verify`, `gh-resolve`. These are compositions; the steps they call live in those repos. |

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
| `issue-relay` | full | full, verify by hand | full | full | full | full |
| `relay-merge` | full | full, confirm in chat | full | full (Antigravity: confirm in chat) | full, confirm in chat | full, confirm in chat |
| `drain` | full | manual chain | manual chain | manual chain | manual chain | manual chain |

*manual chain* — without a `Skill` tool, print the ordered list of atomic skills
the chain would have invoked, run what is plain shell, and stop at the first
step that genuinely needs another skill. Do not inline a reimplementation of an
atom: the atom is what owns its own safety rules.

*confirm in chat* — `relay-merge` must stop and ask before relaying an oversized
patch. Kimi (`AskUserQuestion`) and Gemini CLI (`ask_user`) have a structured
question tool; Codex, Hermes, Antigravity, and OpenCode do not, so ask in the
conversation and wait for a real reply. An auto-approve session setting is not
the user's answer.

*verify by hand* — `issue-relay` and `autopilot` delegate implementation to a
subagent. Read the diff and run the repo's lint and tests yourself; a worker's
completion report is not evidence.

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
matching hook change and the regression comes straight back.

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
│   ├── issue-relay/SKILL.md  + references/ + evals/
│   ├── relay-merge/SKILL.md  + references/
│   └── drain/SKILL.md        + references/ + evals/
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
(`claude/skills/{gh-issue-flow,devx-autopilot,gh-issue-relay-flow,gh-relay-merge}`)
as a content snapshot at source commit
`96c90bc8d961d51d9c3286dae730e8b928afdfc8` — no history rewriting. The dotfiles
originals are gone: `claude/skills/` was deleted there in Phase 4-1 of that
repo's migration plan (dEitY719/dotfiles#1410 NF-1 / NF-3, tracking issue
dEitY719/dotfiles#1678).

The old prefixes were stripped on the way in: `/gh:issue-flow` became
`/gh-flow:issue`, `/devx:autopilot` became `/gh-flow:autopilot`,
`/gh:issue-relay-flow` became `/gh-flow:issue-relay`, and `/gh:relay-merge`
became `/gh-flow:relay-merge`. The plugin name already supplies the namespace at
invocation time.

`drain` has no dotfiles ancestor — it was written here (issue #13), after a
session that reached "zero open issues" while four unresolved items lived only
in a closing comment.

## License

MIT. See [`LICENSE`](LICENSE).
