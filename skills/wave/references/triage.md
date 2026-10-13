# gh-flow:wave / gh-flow:waves — Triage (#62, #64)

What the worker does with each finding of its own run, and what the coordinator
does with a `gh-verify:merged` (wave) or `gh-verify:live` (waves) finding. This
file is the whole rule for both skills — the single copy; `gh-flow:waves` links
here and keeps none of its own. Neither defers to `gh-flow:drain`.

## Why wave differs from drain

`gh-flow:drain` exists to reach zero deferred items, so it files every
acknowledged finding at any severity. Wave carries one root issue, and every
issue a worker files with `Spawned-from:` becomes a node it must process next.
Filing every reviewer remark grew one root into 17 descendants, most of them
nits or out-of-scope remarks (#62). Wave therefore fixes or declines what it
can and files a child issue only for a real defect too large for this PR.
Waves has the same problem one level up: it re-queries every open issue each
wave and had no run caps, so a filed finding became next-wave work forever
(#64). It takes the same three branches.

## Child issue, per skill

- **wave** — a child issue carries the body line `Spawned-from: #<N>`, `<N>`
  being this issue (`references/lineage.md`), and is queued as a descendant
  within the caps.
- **waves** — a child issue (a *follow-up*) carries the body line
  `Filed-by-run: waves #<T>`, `<T>` being the run's tracking issue. It is
  listed under `filed this run` and `Next:` and is **not** processed in the
  same run: requery drops open issues carrying the marker for this `<T>`
  (`gh-flow:waves`'s `references/plan.md` §1).

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
  `Spawned-from: #<N>` (wave) or `Filed-by-run: waves #<T>` (waves) — see
  "Child issue, per skill".

"Trivial and out of scope" is never a child issue: a trivial remark about code
an earlier PR merged is that PR's matter, not this one's. A real defect is
different whatever its scope: this run is the only one that will see it, so it
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

## Coordinator: `gh-verify:merged` / `gh-verify:live` findings

The coordinator cannot fix a merged PR (it never runs the chain, NF-1).

- **Real defect** — a child issue via `Skill(gh-issue:issue-create, "--no-ask ...")`.
  Wave: with `Spawned-from: #<N>`, `<N>` being the issue whose PR failed; it
  is queued as a descendant within the caps. Waves: with
  `Filed-by-run: waves #<T>`; it is listed under `filed this run` and `Next:`,
  never picked up by this run's requery.
- **Trivial difference** (wording and the like) — stated in the verify skill's
  PR comment report only. No issue.

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

Waves, where a per-issue failure never aborts the run: a worker's first line
is `waves-worker #<N>: [FAIL] promotion — issue creation failed (<reason>)`,
recorded as that issue's failure with the item named in its `[FAIL]` comment;
a coordinator live-failure issue that cannot be filed is named under
`left open` with its PR and the finding, so the final report still carries it.
