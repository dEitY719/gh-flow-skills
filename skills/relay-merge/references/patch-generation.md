# gh-flow:relay-merge — Patch Generation, Size Cutoff, Artifact Exclusion

Steps 3-4. Runs only after Step 2 confirmed the push is blocked.

## Pre-flight (Step 3): destination divergence sanity check

Resolve the real commit range first, then resolve `$DEST_DEFAULT` — the
destination's default branch (e.g. `git ls-remote --symref "$REMOTE" HEAD`)
— once. Where `HEAD_SHA` comes from depends on Step 1's input mode:

```bash
# PR mode:      reuse the headRefOid captured by Step 1's gh pr view (no re-fetch)
# --commits mode: no PR object exists — use the head SHA parsed from <base>..<head>
HEAD_SHA=$HEAD_REF_OID                                          # PR mode
BASE_SHA=$(git merge-base "$REMOTE/$DEST_DEFAULT" "$HEAD_SHA")   # or the PR's recorded base
```

For a merged PR use the merge commit's parents; for an open PR use the
current head and the PR's base. In `--commits <base>..<head>` mode the range
is exactly git's `<base>..<head>` (base excluded, head included) — use it
directly, no `gh pr view`. Either way the range is `BASE..HEAD`.

Before generating anything, compare the files this PR touches against the
destination's current default branch:

```bash
# Step 1 already fetched "$REMOTE"; re-fetch only if the branch may have moved.
git diff --name-only "$BASE_SHA" "$HEAD_SHA"        # files the PR changes
# for each, check it exists / is compatible on $REMOTE/$DEST_DEFAULT
```

If a touched file falls into a **structurally-known divergence category** —
env-specific config blocks, files that deliberately differ between the
internal and external variants — warn the user up front:

```
[WARN] <path> is known to diverge between internal/external variants.
Its patch will likely fail `git am` on the destination.
```

Surface these before uploading, so the user can decide, rather than
silently shipping patches that fail on the far side.

## Generate patches (Step 4)

One call runs the whole cutoff pipeline — format-patch, size check, artifact
exclusion, file-group pre-split — so the rules below are enforced by exit
codes rather than by the model remembering them:

```bash
# Reuse the $tmpdir initialized in Step 2's push-probe — do not re-create it.
bash "${CLAUDE_PLUGIN_ROOT}/skills/relay-merge/lib/relay.sh" \
  patches "$BASE_SHA..$HEAD_SHA" "$tmpdir" [--generated-patterns '<globs>']
```

One `.patch` file per commit, each independently `git am`-able, numbered so
apply order is unambiguous (`0001-*.patch`, `0002-*.patch`, ...).

It prints one TSV row per resulting patch, and Steps 6 and 8 read them:

| Row | Columns | Used by |
|---|---|---|
| `PATCH` | order, bytes, path, commit subject | the apply-guide table, the Step 8 gist count |
| `EXCLUDED` | order, stripped path | the regeneration notes (below) |

An order label of `NNNN-<k>` means that commit was file-group pre-split.
Exit 3 is the no-silent-truncation stop.

## Size cutoff

Named, greppable constant — tune it in `lib/relay.sh` (or override
`RELAY_PATCH_MAX_BYTES` in the environment) if empirical limits change:

```
RELAY_PATCH_MAX_BYTES=40960   # 40KB. ~35KB known-good, ~62KB known-bad on
                              # the observed gist policy; no confirmed safe
                              # value between them, so 40KB is conservative.
```

Under the cutoff → ship as-is. Over → artifact exclusion.

## Generated-artifact exclusion

`--generated-patterns` (comma-separated globs) overrides the built-in
default list:

```
**/generated/**  **/*.generated.*  openapi.json  package-lock.json  *.lock  **/dist/**  **/build/**
```

For an oversized patch, matching paths are dropped via `:(exclude,glob)`
pathspec and the commit's patch is regenerated without them; each dropped
path comes back as an `EXCLUDED` row.

Record a regeneration note for each `EXCLUDED` path so the destination can
rebuild it — e.g. `openapi.json` → `make codegen`, a lockfile →
`npm install`. These notes go into the apply-guide comment (Step 6).

## File-group pre-split (oversized non-artifact commit)

When a patch is **still** over `RELAY_PATCH_MAX_BYTES` after artifact
exclusion **and** the excess is *not* attributable to a recognized
generated-artifact pattern — it's just a large real code change in one
commit — that single commit is pre-split into multiple sub-patches by file
group. This runs **before** the no-silent-truncation FAIL below; the FAIL
fires only when pre-split itself cannot get every sub-patch under the limit.

Files are greedily bucketed so each group's cumulative diff stays under the
limit (charging ~1KB of per-patch header overhead), and one independent
sub-patch is generated per group. `git format-patch -1 <SHA>` with a
pathspec clones the original commit's `From`/`Subject`/date/author headers
onto each sub-patch (git's default for `-1` + pathspec — verified), so every
sub-patch stays independently `git am`-able.

Sub-patches keep the commit's `NNNN` slot and add a sub-index, so they sort
between it and the next commit: `NNNN-1-<name>.patch`, `NNNN-2-<name>.patch`.
`git am` order follows the order the apply-guide lists them, so the guide
must render them as "commit N의 1/2, 2/2" (Step 6 /
`references/apply-guide-template.md`) so a human applying in order knows
they belong to one commit.

A single **file** whose own diff alone exceeds the limit cannot be
file-group-split — it hits the FAIL below (no arbitrary truncation).

## No silent truncation

If a patch is **still** over `RELAY_PATCH_MAX_BYTES` after excluding
recognized generated artifacts **and** after the file-group pre-split above
— i.e. a single **file's** own diff alone exceeds the limit and cannot be
split further — nothing is truncated. `relay.sh patches` exits **3** with
this on stderr, and the skill stops (Step 8's `[FAIL]` block):

```
[FAIL] <NNNN>-*.patch is <size> bytes (> RELAY_PATCH_MAX_BYTES=40960):
a single file's diff exceeds the limit even after file-group pre-split, and
its bulk is not a recognized generated artifact.
Offending path(s): <paths>
Refusing to truncate — arbitrary truncation would corrupt the applied commit.
Options: add its path to --generated-patterns if it IS generated, or split
the origin commit into smaller commits and re-run.
```

Arbitrary content truncation corrupts the commit `git am` reconstructs;
only recognized generated-artifact diffs are ever dropped, and only
whole-file groups are ever pre-split.
