# Installing gh-flow for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed
- `git` and the GitHub CLI (`gh`), authenticated against every host you open PRs
  on. Every skill binds `TARGET_HOST` / `TARGET_REPO` from the remote URL and
  prefix each API call with `GH_HOST=`, so a GHES remote works — but only if
  `gh` is logged into that host.
- A dedicated worktree of the target repo, already on a feature branch. These
  skills do not create it, and `issue` refuses to run on the default branch.
- The atomic skills these compose, installed from their own repos: `gh-issue`,
  `gh-pr`, `gh-verify`, `gh-resolve`. This plugin carries compositions, not
  copies of the steps they delegate.

## Installation

Add the plugin to the `plugin` array in your `opencode.json` (global or
project-level):

```json
{
  "plugin": ["gh-flow-skills@git+https://github.com/dEitY719/gh-flow-skills.git"]
}
```

Restart OpenCode. The plugin installs through OpenCode's plugin manager and
registers every skill under `./skills/`.

OpenCode uses its own plugin install. If you also use Claude Code, Codex, or
another harness, install this plugin separately for each one.

## Usage

Use OpenCode's native `skill` tool:

```
use skill tool to list skills
use skill tool to load issue
```

## Tool mapping

The authoritative OpenCode tool mapping for every `dEitY719/*-skills` repo lives
in the sibling repo `harness-skills`, at
[`references/opencode-tools.md`](https://github.com/dEitY719/harness-skills/blob/main/references/opencode-tools.md).
This repo owns no copy — one tool rename must stay one edit. Read it when a
skill names a tool you do not recognise. Short version:

- "Read a file" -> `read`
- "Create a file" / "edit a file" -> `apply_patch`
- "Run a shell command" -> `bash` (this is how every `git` and `gh` call is made)
- "Search file contents" / "find files by name" -> `grep`, `glob`
- "Create a todo" -> `todowrite`
- "Dispatch a subagent" -> `task` with `subagent_type: "general"` (or
  `"explore"` for read-only exploration)
- "Invoke a skill" -> OpenCode's native `skill` tool

Two gaps matter here:

- `issue` and `autopilot` delegate implementation to a subagent. Verify the
  result yourself — read the diff and run the repo's lint and tests. A worker's
  completion report is not evidence.
- OpenCode has no structured question tool. `relay-merge` must stop and ask
  before relaying an oversized patch: ask in the conversation and wait for a
  real answer.

## Safety contracts

- No skill here merges a pull request. `autopilot` stops at review on purpose.
- `issue` stops at the first failing step and prints a resume hint — it never
  retries and never skips.
- Emit zero conversational text between the chained skill calls of `issue` and
  `autopilot`, and emit their terminal report lines verbatim as plain assistant
  text. Both are contracts with a harness Stop hook, not style preferences.
- `relay-merge` probes push first and relays only when push is genuinely
  blocked. It never truncates an oversized patch silently.

## Troubleshooting

### Plugin not loading

1. Check logs: `opencode run --print-logs "hello" 2>&1 | grep -i gh-flow`
2. Verify the plugin line in your `opencode.json`
3. Make sure you are running a recent version of OpenCode

### Skills not found

1. Use the `skill` tool to list what was discovered
2. Check that the plugin is loading (see above)

### A chain stops one step in

The atomic skill it delegates to is not installed. `issue` and `autopilot` call
`gh-issue:*`, `gh-pr:*`, `gh-verify:*`, and `gh-resolve:*` — install those
plugins too.

### Every `gh` call fails immediately

`gh` is not authenticated for the host the remote points at. Run
`gh auth login --hostname <host>`. The skills fail loudly rather than falling
back to `github.com`.

## Getting Help

Report issues: https://github.com/dEitY719/gh-flow-skills/issues
