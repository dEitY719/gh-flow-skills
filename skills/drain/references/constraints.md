# gh-flow:drain — Constraints

- **Two termination conditions, both required.** Open issues 0 **and** deferred
  items 0. Neither alone ends the run.
- **Promotion is unconditional** (D-3). Severity, size and "next time" do not
  exempt an item. A pending promotion whose `gh-issue:create` fails stops the
  round — that error is the one this skill never swallows.
- **Never close an issue directly** (NF-3). Closure comes from a PR's
  `Closes #N` or a clean `gh-flow:issue` completion.
- **Never decide for the user.** A decision-shaped blocker is a comment
  (`references/blocked.md`), not a judgment call made on their behalf.
- **Default run merges nothing.** `--merge` is the one explicit exception and it
  delegates to `gh-pr:merge-train`, which owns its own approval and label gates.
  `gh-pr:merge-emergency` is never called by any path.
- **Never reimplement an atom** (NF-1). `gh-flow:issue`, `gh-issue:create` and
  `gh-pr:merge-train` own their steps — call them, never inline them.
- **State lives on GitHub** (NF-2). No progress file, no session-local ledger.
  A file-backed run breaks resume from a fresh session, and a file that
  disagrees with GitHub redoes finished work.
- **Own issues only** (D-4): `--author @me`.
- **Bind the target from one remote URL.** Every `gh` call carries
  `GH_HOST="$TARGET_HOST"` and `--repo "$TARGET_REPO"`
  (`../issue/references/target-binding.md`). A missing remote stops the run —
  falling back to `origin` silently sends the writes to the wrong repo.
- **The stop conditions live in `references/loop.md`.** Its table is the SSOT;
  do not restate them here. Two of them (`--max-rounds`, closed-0-plus-opened-0)
  are structural and fire on their own. The third — three failed attempts on one
  issue — is counted **within a single run only**, because NF-2 forbids
  persisting it; a resumed session starts that count at zero and relies on
  `--max-rounds` instead.
- **A per-issue failure never aborts the drain.** It fails that issue and the
  loop moves on. Only a listing failure, a promotion failure, or a stop
  condition ends the run.
- **The round table is not a final answer.** It is emitted between rounds and
  the next round starts immediately after it. A run that ends on a round table
  without a final report has stopped early. Note that unlike `gh-flow:issue` and
  `gh-flow:autopilot`, drain has **no Stop hook behind it** — no `gh-flow-drain`
  marker exists in `dEitY719/dotfiles` — so this rule is the only guard against
  that failure mode. Inside a single round, keep the chained `Skill()` calls
  free of conversational text.
