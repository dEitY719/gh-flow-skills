# gh-flow:issue-relay — Help

## Arguments

| # | Name | Default | Description |
|---|------|---------|-------------|
| 1 | `<issue-number>` or `-h`/`--help`/`help` | — | Issue already filed on the destination remote |
| flag | `--remote <name>` | `upstream` | Destination remote — same remote `gh-flow:relay-merge` targets at the end |
| flag | `--base <branch>` | auto-detect | Override the destination default branch (skips `git ls-remote --symref`) |

## Usage

```
/gh-flow:issue-relay 1346                          # branch off upstream's default branch, implement, verify, relay
/gh-flow:issue-relay 1346 --remote fork            # same, but destination remote is 'fork'
/gh-flow:issue-relay 1346 --base develop           # skip default-branch detection, base off 'develop'
/gh-flow:issue-relay -h                            # this help
```

## When to use this skill

- The issue is already filed on a remote you cannot `git push` to directly
  from this machine (corporate-proxy-blocked path to that remote), and you
  want the full "branch → implement → verify → relay" loop in one call
  instead of doing each step by hand.
- You expect to repeat this loop often for the same push-blocked
  destination (this is exactly the workflow issue dEitY719/dotfiles#1346 was filed to
  standardize).

## When NOT to use

- The issue is not filed yet — run `gh-issue:create <remote>` first.
- `git push <remote>` actually works from this machine — just use
  `gh-issue:implement` + `gh-pr:commit` + `gh-pr:create` (or `gh-flow:issue`)
  directly; this skill's value is specifically the relay handoff at the end.
- You already have a commit range ready and just want to relay it — call
  `gh-flow:relay-merge --commits <base>..<head>` directly instead of this whole
  chain.

## What this skill does

Chain: branch (`references/branch-setup.md`) → delegated implementation
(`references/worker-brief-checklist.md`) → Advisor verification
(`references/verification.md`) → `gh-flow:relay-merge` → report
(`references/report-template.md`). `SKILL.md`'s Steps 2-6 are the numbered
walkthrough; this file only points at it to avoid a second copy that can drift.

## What this skill will NOT do

See `references/constraints.md` for the full, current list (never fall back
to `origin`, never delegate with unresolved Open Questions, never auto-reset
a reused branch, never duplicate `gh-flow:relay-merge`'s job).

## Related skills

- `gh-flow:relay-merge` — the atomic relay step this skill delegates to at the
  end; call it directly when you already have a ready commit range.
- `gh-flow:issue` — the sibling composition skill for the *non*-relay case
  (destination remote is normally pushable): implement → commit → PR →
  quality gate, no patch/gist relay involved.
- `gh-issue:implement` — the atomic implementation step this skill's Worker
  delegation is modeled after (same "already on a feature branch" contract).
- `gh-issue:create` — files the issue this skill assumes already exists.
