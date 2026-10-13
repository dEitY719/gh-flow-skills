# gh-flow:wave — Triage (#62)

What the worker does with each finding of its own run, and what the coordinator
does with a `gh-verify:merged` finding. This file is the wave's whole rule; it
does not defer to `gh-flow:drain`.

## Why wave differs from drain

`gh-flow:drain` exists to reach zero deferred items, so it files every
acknowledged finding at any severity. Wave carries one root issue, and every
issue a worker files with `Spawned-from:` becomes a node it must process next.
Filing every reviewer remark grew one root into 17 descendants, most of them
nits or out-of-scope remarks (#62). Wave therefore fixes or declines what it
can and files a child issue only for a real defect too large for this PR.

## What gets triaged

Every review finding (any reviewer, bots included), every `TODO` / `FIXME` /
`ponytail:` the run left, every skipped test, every "follow-up" the run names.

## The three branches

Each item takes exactly one, decided during the worker's `gh-pr:reply` step and
before its merge step — a fix made after the merge cannot land in this PR:

- **fix-in-place** — commit the fix in this PR, and cite that commit in the
  `gh-pr:reply` reply to the finding. No issue. Applies when either
  - (a) the item is trivial (nit, wording, small hardening, an added edge-case
    test) **and** within this PR's scope, or
  - (b) the item is a real defect or BLOCKER **and** small.
- **declined** — reply with the reason in `gh-pr:reply` and stop there. No
  issue. Applies when the item is trivial **and** out of this PR's scope, or
  the finding is wrong.
- **child issue** — only for a real defect or BLOCKER **and** large. File it via
  `Skill(gh-issue:issue-create, "--no-ask ...")` with the body line
  `Spawned-from: #<N>`, `<N>` being this issue (`references/lineage.md`).

"Trivial and out of scope" is never a child issue: a trivial remark about code
an earlier PR merged is that PR's matter, not this one's. A real defect is
different whatever its scope: wave is the only run that will see it, so it
takes (b) or a child issue even when it sits in earlier-merged code.

## Small or large

An approximate aid, not a hard gate. A fix is **small** when it

- stays inside the directories (modules, packages, skills) this PR already
  touched,
- needs no new helper, no new test harness or shim and no new doc or
  reference file, and
- adds roughly 50 non-test diff lines or fewer. Test lines do not count:
  never drop a test to keep a fix small.

Exceeding any one makes it **large**.

## Report

The worker's final report adds two lines after `follow-ups:`:

```
  fixed-in-place: <finding -> commit> ... | none
  declined:       <finding: reason> ... | none
```

`follow-ups:` lists the child issues only. A decision that filed no issue is
still traceable through these two lines and the `gh-pr:reply` replies.

## Coordinator: `gh-verify:merged` findings

The coordinator cannot fix a merged PR (it never runs the chain, NF-1).

- **Real defect** — a child issue via `Skill(gh-issue:issue-create, "--no-ask ...")`
  with `Spawned-from: #<N>`, `<N>` being the issue whose PR failed. It is
  queued as a descendant within the caps.
- **Trivial difference** (wording and the like) — stated in the
  `gh-verify:merged` PR comment report only. No issue.

## A failed creation is fatal

A child issue that cannot be filed vanishes from the tree: nothing else records
it, and the descendant query cannot find what was never created. So a failed
`gh-issue:issue-create` is never skipped:

- in a worker, the report's first line is exactly
  `wave-worker #<N>: [FAIL] promotion — issue creation failed (<reason>)`,
  naming the item — the step word `promotion` is what the coordinator matches;
- in the coordinator — its own creation failing, or a worker report whose
  failed step is `promotion` (never handled as an ordinary step failure) — the
  run stops: `gh-flow:wave stopped — promotion failed (<reason>)`.
