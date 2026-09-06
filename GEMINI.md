# gh-flow — skill index

Five skills for one job: carrying a GitHub issue all the way to a reviewed pull
request in a single run. Each lives in this extension's `skills/` directory.
They are explicitly invoked, never ambient: load the one that matches your
starting point by reading its `SKILL.md`, then follow it. Do not load all five.

| Skill | Read | Use when |
|-------|------|----------|
| `issue` | `@./skills/issue/SKILL.md` | You have an issue number and a feature branch. Chains implement, commit, PR, review gate, and rebase-sync, then reports metrics. Stops at the first failing step with a resume hint. |
| `autopilot` | `@./skills/autopilot/SKILL.md` | You have an approved spec, not an issue. Writes the plan, files the issue, implements, opens the PR, answers review comments — no approval checkpoints. Never merges. |
| `issue-relay` | `@./skills/issue-relay/SKILL.md` | The issue lives on a destination remote whose `git push` is blocked. Branch, delegate the implementation, verify it, then hand off to `relay-merge`. |
| `relay-merge` | `@./skills/relay-merge/SKILL.md` | You have commits to move to a push-blocked remote. Probes push first; relays per-commit patches through a gist with a `git am` apply-guide only when push is genuinely blocked. |
| `drain` | `@./skills/drain/SKILL.md` | You have a whole open backlog, not one issue. Runs each issue through `issue` and promotes every deferred item to a new issue; ends only when open issues and deferred items are both zero. |

Pick by where you are starting and whether the destination accepts a push, not
by which sounds most thorough. `issue` refuses to invent a spec; `autopilot`
refuses to skip one. Neither relay skill runs when a plain push works. `drain`
starts from a backlog that already exists.

Each skill's `references/` directory holds the detail it loads on demand.
`SKILL.md` says which file to read and when — do not read `references/` up
front.

## What each skill needs

- `git`, and `gh` authenticated for the host the remote points at. Each skill
  binds `TARGET_HOST` + `TARGET_REPO` from the remote URL **before any `gh`
  call** and prefixes every call with `GH_HOST=` (#1403). A GHES remote resolves
  to the wrong server without that prefix, and `gh` reports no error when it
  does — so never drop it.
- A dedicated worktree already checked out on a feature branch. `issue` refuses
  to run on the repo's default branch and does not create the worktree for you.
- The atomic skills these compose (`gh-issue:*`, `gh-pr:*`, `gh-verify:*`,
  `gh-resolve:*`) installed from their own repos. These are compositions; they
  do not carry copies of the steps they delegate.

## Tool mapping for Gemini CLI

The skills speak in actions. On Gemini CLI these resolve to:

- "Read a file" -> `read_file` / `read_many_files`
- "Create a file" / "edit a file" -> `write_file`, `replace`
- "Run a shell command" -> `run_shell_command` (this is how every `git` and `gh`
  call is made)
- "Search file contents" -> `grep_search`
- "Find files by name" -> `glob`
- "Create a todo" -> `write_todos`
- "Ask the user" -> `ask_user`
- "Dispatch a subagent" -> `invoke_agent` with `agent_name: "generalist"`

The full mapping, including every capability gap and its workaround, lives in
the sibling repo: `https://github.com/dEitY719/harness-skills/blob/main/references/gemini-tools.md`.
This repo owns no copy. Read it when a skill names a tool you do not recognise.
On Antigravity read `antigravity-tools.md` in that same directory instead —
`agy` shares `~/.gemini` but not Gemini CLI's tool names.

## Capability gaps on Gemini CLI

- **These five skills are compositions, and Gemini has no skill-invocation
  tool.** `issue` and `autopilot` are ordered chains of other skills; without a
  `Skill` equivalent they cannot run as written. Print the ordered list of
  atomic skills the chain would have invoked, run what is plain shell, and stop
  at the first step that genuinely needs another skill. Do not inline a
  reimplementation of an atom — the atom is what owns its safety rules.
- `issue-relay` and `autopilot` delegate implementation to a subagent. Use
  `invoke_agent`, then verify the result yourself: read the diff and run the
  repo's lint and tests. A worker's completion report is not evidence.
- On Antigravity, `ask_user` does not exist — ask in the conversation and wait
  for a real reply before relaying an oversized patch.

## Safety rules

- **No skill here merges a pull request.** `autopilot` stops at review on
  purpose; merging is a human decision.
- `issue` stops at the first failing step and prints a resume hint. It never
  retries a step and never skips one. Its three soft-fail exceptions are
  enumerated in `skills/issue/references/constraints.md`.
- **Emit zero conversational text between the chained skill calls** of `issue`
  and `autopilot`. A self-authored progress report between calls reads as a
  final answer and ends the run early — that is the exact failure mode both
  skills are built to prevent, and it has recurred five times.
- The terminal report lines (`gh-flow:issue complete (#<N>)`,
  `[OK] gh-flow:autopilot`, `[step:gh-flow-autopilot/<id>] OK`) are a contract
  with a harness Stop hook, not decoration. Emit them verbatim, as plain
  assistant text — never through a shell heredoc or a file write.
- `relay-merge` probes whether `git push` works before relaying, and hands off
  to `gh-pr:create` when it does. The relay is a fallback, never the default. It
  never truncates an oversized patch silently.
