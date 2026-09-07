---
name: relay-merge
description: >-
  Relay a PR's commits from an isolated `origin` to `upstream` when a proxy
  blocks `git push` — probe first, then patch+gist with a `git am` apply-guide.
  Use for /gh-flow:relay-merge, "origin PR를 upstream 으로 릴레이",
  "push 막혀서 gist 로 넘겨줘".
license: MIT
allowed-tools: Bash, Read, Write, Grep, Glob
metadata:
  model_recommendation:
    tier: opus
    reason: "asymmetric-network branch logic + per-patch size/artifact reasoning + no-silent-truncation judgement; multi-step relay with irreversible gist/comment side effects"
    claude: prefer
    non_claude: advisory-only
---

# gh-flow:relay-merge — Patch+Gist Relay for Push-Blocked Upstream

## Role

머지된(또는 열린) PR 의 커밋을 **격리된 `origin`(사내 GHE) 에서 별개의 `upstream`(github.com) 으로** 넘긴다.
전제는 비대칭 네트워크 — 사내 프록시가 `git push upstream` 을 막지만 `gh api` 와 단일 파일 `gh gist create` 는 통한다.
먼저 push 가능 여부를 **실제로 프로브**해서, 정상 push 가 되면 `gh-pr:create` 에 위임하고 멈춘다(릴레이는 폴백이지 기본이
아니다). HTTP 403 / block-page 로 차단이 확인될 때만 릴레이 모드로 간다: 커밋당 `git format-patch` → 호출당 파일
1개 gist 업로드 → 목적지 이슈에 `git am` apply-guide 코멘트.

## Help

If arg #1 is `-h`, `--help`, or `help`, read `references/help.md` and
output its content verbatim, then stop. No API calls.

## Step 1: Preconditions — two mutually-exclusive input modes

Input is EITHER positional `<origin-PR#>` OR `--commits <base>..<head>` (both supplied → hard error, stop).
Shared flags: `--remote`, `--target-issue`, `--known-failures`, `--generated-patterns` (table: `references/help.md`).
- **PR mode**: `GH_HOST="$SOURCE_HOST" gh pr view <N> --repo "$SOURCE_REPO" --json number,state,url,headRefOid,baseRefName,mergeCommit,statusCheckRollup,reviewDecision`.
  Do **not** require `merged` — use the PR's current head/base commits.
- **`--commits` mode**: skip `gh pr view`; use the range directly. Git semantics — `base` EXCLUDED, `head`
  INCLUDED. No PR object exists, so Step 3's pre-flight uses the head SHA parsed from the arg.

Resolve `--remote` per `references/remote-resolution.md`; missing `upstream` with no explicit `--remote` → hard
error, never fall back to `origin`. Confirm the destination is reachable (`git fetch` / `git ls-remote`) first.
It also binds `SOURCE_REPO`/`SOURCE_HOST` + `DEST_REPO`/`DEST_HOST`, each pair from **one** remote URL. Two hosts
in one run → no global `GH_HOST`: every `gh` call carries its own side's host inline (dEitY719/dotfiles#1403 / dEitY719/dotfiles#1407).

## Step 2: Push-Capability Probe (branch point)

Run `lib/relay.sh probe <remote> <local-ref>` — a real throwaway-ref push, cleaned up from a `trap`, owning its own
one-retry-with-backoff. Rationale and block signals: `references/push-probe.md`.
- `blocked=no` → **SIMPLE PATH**: delegate to `gh-pr:create` (or an equivalent normal push + PR) and stop — relay mode is a fallback, not the default.
- `blocked=yes` (HTTP 403 / block-page marker) → continue to Step 3.
- Exit 2 (still inconclusive after the retry) → treat as not-blocked, take SIMPLE PATH. A `leftover_ref=` line
  means probe-ref cleanup failed twice — surface it in Step 8.

## Step 3: Determine Commit Range + Pre-flight

Resolve the range's base/head SHAs (from the PR, or parsed from `--commits`) and run the destination-divergence
sanity check in `references/patch-generation.md` → "Pre-flight" — it runs in **both** input modes. Warn up front
about structurally-known conflict categories instead of shipping patches that will fail `git am` on the far side.

## Step 4: Generate Patches

Run `lib/relay.sh patches <base>..<head> <outdir> [--generated-patterns <globs>]`. It enforces the
`RELAY_PATCH_MAX_BYTES` cutoff, generated-artifact exclusion and file-group pre-split, and exits 3 with the
no-silent-truncation `[FAIL]` instead of shipping a truncated patch. Rules: `references/patch-generation.md`.

## Step 5: Upload Gists (one file per call)

Run `lib/relay.sh upload <dest-host> <outdir>` — one `gh gist create` per patch, sequential, never
multi-file/parallel, one `order/description/web-url/raw-url` row printed per upload
(`references/gist-relay.md`). Exit 4 → stop; the rows already printed are the gists that exist.

## Step 6: Post the Apply-Guide Comment

Build the comment from `references/apply-guide-template.md`, which owns its wording and section order. Post to a
NEW destination issue (default) or `--target-issue <N>`; render `--known-failures` into its known-failures section.

## Step 7: Origin-side Cleanup (optional)

Only with explicit user confirmation, close a duplicate origin-side tracking
issue with a cross-reference comment. Never auto-close.

## Step 8: Report

Emit exactly one block from `references/report-template.md`: `[OK] relay mode`, `[OK] SIMPLE PATH`, or `[FAIL]
stopped at Step <k>`. Each carries a `Next:` line, and the `[FAIL]` block must list the gists already created.
The verdict marker is a contract — `gh-flow:issue-relay` Step 6 relays this output as-is.

## Constraints

See `references/constraints.md` for the full list. Hard rules: never fall
back to `origin` silently · never plain-`push`-then-relay (probe first) ·
never multi-file/parallel `gh gist create` · never silently truncate (only
generated artifacts stripped; oversized commits get file-group pre-split) ·
never auto-close an origin issue.

## Related Skills

`gh-pr:create` (SIMPLE PATH delegate when push works) · `gh-flow:issue-relay` (issue → branch → implement → this skill). Full argument/flag table: `references/help.md`.
