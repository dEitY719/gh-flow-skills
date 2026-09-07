# gh-flow:relay-merge — Help

## Arguments

Input is EITHER the positional `<origin-PR#>` OR `--commits <base>..<head>`
— the two are mutually exclusive (supplying both is a hard error).

| # | Name | Default | Description |
|---|------|---------|-------------|
| 1 | `<origin-PR#>` or `-h`/`--help`/`help` | — | PR on `origin` whose commit range is the relay payload (merged or open) |
| flag | `--commits <base>..<head>` | — | Alternate input mode: relay this git range directly, skipping `gh pr view`. Standard git semantics — `base` EXCLUDED, `head` INCLUDED |
| flag | `--remote <name-or-URL>` | `upstream` | Destination remote. Name (resolved via `git remote get-url`) or raw URL |
| flag | `--target-issue <N>` | new issue | Post the apply-guide to this existing destination issue/PR instead of creating a new one |
| flag | `--known-failures <entries>` | none (section omitted) | Comma-separated `<path>[::<test-or-check>]` entries for lint/test failures already confirmed pre-existing and unrelated on the origin side. Rendered verbatim into the apply-guide's "Known unrelated pre-existing failures" section |
| flag | `--generated-patterns <globs>` | built-in list | Comma-separated globs marking generated artifacts to strip from oversized patches |

`--known-failures` entry format: a bare `<path>` marks the whole file's
current failures as known; `<path>::<test-or-check>` narrows it to one named
test/check so a file that holds both a pre-existing failure and a new
regression does not suppress investigation of the regression. Prefer the
qualified form whenever the runner reports a test/check name.

## Usage

```
/gh-flow:relay-merge 168                              # relay origin PR #168 to upstream
/gh-flow:relay-merge --commits abc123..def456         # relay a raw git range (no PR lookup)
/gh-flow:relay-merge 168 --remote fork                # relay to remote named 'fork'
/gh-flow:relay-merge 168 --remote https://github.com/org/repo.git
/gh-flow:relay-merge 168 --target-issue 42            # post guide to existing issue #42
/gh-flow:relay-merge --commits abc123..def456 --known-failures 'tests/test_a.py::test_legacy,tests/flaky.bats'
/gh-flow:relay-merge 168 --generated-patterns '**/gen/**,*.lock'
/gh-flow:relay-merge -h                               # this help
```

## When to use this skill

- You work in `origin` (an isolated internal network, e.g. corporate GHE)
  and need a merged/open PR's commits to reach a separate `upstream`
  (e.g. github.com).
- The network path is **asymmetric**: `git fetch upstream` works, but
  `git push upstream <branch>` is blocked by a corporate proxy (HTTP 403
  block page). `gh api` single REST calls work; single-file
  `gh gist create` works.

## When NOT to use

- `git push upstream` actually works. Use `/gh-pr:create` directly — this skill's
  Step 2 probe will detect that and delegate to it anyway.
- Both remotes are the same host / no asymmetric block exists.

## What the skill does

Resolve range + destination remote → probe push (works → `gh-pr:create`,
stop) → format-patch → one gist per patch → apply-guide comment → report.
Step-by-step: `SKILL.md` Steps 1-8, which is the only copy.

## Constants (tunable)

- `RELAY_PATCH_MAX_BYTES` = **40960** (40KB) — fixed safe per-file gist
  size cutoff. Empirically ~35KB is known-good and ~62KB known-bad; there
  is no confirmed safe threshold between them, so 40KB is the conservative
  named constant. Not auto-detected — tune here if real limits change.
- Default `--generated-patterns`: `**/generated/**`, `**/*.generated.*`,
  `openapi.json`, `package-lock.json`, `*.lock`, `**/dist/**`, `**/build/**`.

## What this skill will NOT do

The hard constraints — no silent `origin` fallback, no push-then-relay, no
multi-file/parallel gist, no silent truncation, no auto-close of an origin
issue — with their rationale: `references/constraints.md`.

## Related skills

- `gh-pr:create` — the SIMPLE PATH delegate when push actually works.
- `gh-flow:issue` — conventions for posting issue comments / metrics.
- `gh-issue:implement` — source of the "resolve remote, never silent
  fallback" pattern reused in `references/remote-resolution.md`.
