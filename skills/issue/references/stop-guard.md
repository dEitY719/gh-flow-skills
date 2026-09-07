# Stop hook — harness-level guard against gh-flow:issue early-stop

SSOT for the guard's detection contract. Other docs (`SKILL.md`,
`references/report-template.md`) state the *rule* for report authors and
point here for the *mechanism*.

## Why this exists

Models have repeatedly treated a sub-skill's own success block as a
turn-ending answer and stopped `gh-flow:issue` mid-chain (issue dEitY719/dotfiles#333,
dEitY719/dotfiles#383), even with the two prompt-layer mitigations this hook backstops.
Full history and the three-guard rule this hook is guard #3 of:
`references/critical-contract.md`.

The fix: a **Stop hook** that mechanically blocks turn-end while a
gh-flow:issue chain is mid-flight. The hook does not need the model's
cooperation; it intervenes after the model has already decided to stop.

## What it does

`claude/hooks/gh_issue_flow_stop_guard.py` is registered on **both**
`Stop` and `SubagentStop` in the tracked `claude/settings.json` SSOT
(`Stop` since dEitY719/dotfiles#584, `SubagentStop` since dEitY719/dotfiles#1434 — see the dedicated
section below). The legacy `_migrate_install_gh_issue_flow_stop_hook`
helper in `claude/setup.sh` is left in place as a defense-in-depth no-op
for installs whose live file still lacks the `Stop` entry.

On every Stop / SubagentStop event:

1. Read JSON from stdin (`hook_event_name`, `transcript_path`,
   `agent_transcript_path`, `stop_hook_active`, …) and **resolve which
   transcript to parse** — `agent_transcript_path` wins when present
   (dEitY719/dotfiles#1434, see below).
2. Bail out (allow stop) if any of these is true:
   - stdin is empty / not JSON / not a dict
   - `stop_hook_active == true` (we already blocked once in this chain)
   - the resolved transcript path is missing or unreadable (no fallback
     to the other key — dEitY719/dotfiles#1434)
3. **L1 — Boundary detection.** Walk the transcript JSONL backwards to
   find the most recent gh-flow:issue start. Four boundary surfaces
   are matched (defense in depth against Claude Code wrapper drift):
   - assistant `Skill(gh-flow:issue)` tool_use
   - user text starting with `/gh-flow:issue` (or `/gh-flow-issue`)
     at a line start
   - user text containing `<command-name>/gh-flow:issue</command-name>`
     (or colon namespace form) — the wrapper Claude Code emits for
     interactively-typed slash commands (dEitY719/dotfiles#607)
   - user text containing the SKILL prompt markers
     `Base directory for this skill: …/gh-flow:issue` or the H1 line
     `# gh-flow:issue — Issue → PR composition` (dEitY719/dotfiles#608, defensive
     anchors for future wrapper variants)
4. **L1.5 — Terminal-marker scan.** From the message *after* the
   boundary, scan only `role=assistant` text blocks (not `tool_result`,
   not user-role text) for any Step 3 terminal marker:
   - `gh-flow:issue complete (#`
   - `gh-flow:issue stopped at step`
   - (and the hyphen variants)
   This narrow scope is load-bearing. The SKILL.md body, delivered as
   a `role=user` text block when a slash command expands, literally
   contains those marker strings as Step 3 *instructions*. Scanning
   user text would silently false-match every real invocation and
   fail-open the hook (issue dEitY719/dotfiles#608, 5th regression).

   **Bash fallback channel (dEitY719/dotfiles#1270), pair-matched.** Assistant text is the
   canonical channel — `references/report-template.md` requires the Step 3
   report to be plain assistant text. But models sometimes print it
   through `Bash` (`cat <<'EOF' … EOF`, `printf`), in which case the
   report text only ever exists in the tool_use `input.command` string and
   in a `tool_result`, and the flow could never terminate. So the scan
   also accepts a `Bash` tool_use — but only when a **stricter** marker
   regex (one that requires a literal digit where the templates carry
   `<N>` / `<i>`) matches **both**:
   1. the tool_use's `input.command`, **and**
   2. the `tool_result` whose `tool_use_id` equals that tool_use's `id`
      — which must **additionally** carry a report *field* line, `PR
      URL:` (success form) or `Resume after fix:` (failure form) (dEitY719/dotfiles#1274).

   Condition 1 alone proves only that the model *mentioned* the marker:
   `cat <<'EOF' > /tmp/report.txt` redirects it into a file, and a marker
   in a shell comment never surfaces either. Condition 2 is what proves
   the report reached stdout — a redirect produces none, so no pair forms.
   Condition 2 alone is the dEitY719/dotfiles#608 hazard (SKILL.md read into a
   `tool_result`); that path can never satisfy condition 1, because the
   command doing the reading (`Read`, `cat SKILL.md`) carries no literal
   digit. **The pair is strictly narrower than either half**, so adding it
   does not reopen dEitY719/dotfiles#608. This lookup is the only place in the hook that
   reads a `tool_result` at all, and only for an id whose command already
   matched. A `Bash` block with no usable `id` is unpairable and never
   terminates.

   **Full report shape on the result side (dEitY719/dotfiles#1274).** The marker line alone
   used to be enough on the result side, which left one false positive:
   `grep "gh-flow:issue complete (#1270)" some.log` satisfies condition 1
   (literal-digit marker in the command) and condition 2 (grep echoes the
   matched line back), so a plain log search could terminate a live flow.
   The result must therefore also carry a report field line — a real Step
   3 report is multi-line and always has `PR URL:` or `Resume after fix:`,
   which one grepped line cannot reproduce. The requirement sits on the
   *result* only; the command side stays the plain marker match, so a
   heredoc still qualifies however its field line is quoted or built. When
   `tool_result.content` is a list of text blocks, the blocks are joined
   before matching — Claude Code may split one command's stdout, and a
   genuine report whose marker and field line land in different sub-blocks
   must still match. Residual risk left standing: a context grep that
   drags a real report's field line along with its marker line (`grep -A5
   "gh-flow:issue complete (#1270)" some.log` over a log holding a genuine
   past report) — far more contrived than the bare `grep` it replaces,
   which is the point. A **drift test** ties the field names to
   `references/report-template.md`, so renaming them there fails loudly
   instead of silently staling the hook.

   **Only `Bash` is scanned**: `Write`/`Edit` inputs legitimately carry
   real template text whenever the skill's own files are edited.
5. **Boundary expiry (dEitY719/dotfiles#1270).** Count *fresh* user prompts after the
   boundary. A user-role entry counts only when all of:
   - the **outer** transcript entry is not flagged `isMeta` — Claude Code
     stamps that on text it injects into the user channel itself and never
     on a human prompt. It sits on the entry, not on the inner `message`,
     so the counter reads role/content from `message` but the flag from
     the entry;
   - its text — collected with `include_tool_results=False`, then with
     every `<system-reminder>…</system-reminder>` span deleted — is
     non-empty. This is what excludes tool output: `tool_result` blocks
     contribute no text, so a tool-output-only message yields `""`. There
     is deliberately **no** "contains a tool_result ⇒ skip" rule — a
     human prompt bundled in the same turn as tool output must still
     count, or an abandoned flow could never expire;
   - it shows no *skill-expansion* marker (`Base directory for this
     skill:`, `<command-name>`, `<command-message>`,
     `<local-command-stdout>`, `is already loaded above`) and no
     *harness-injection* marker (`Stop hook feedback:`, `gh-flow:issue
     incomplete:`, `<task-notification>`, `[SYSTEM NOTIFICATION - NOT
     USER INPUT]`, `<local-command-caveat>`).

   At 3 or more (`GH_ISSUE_FLOW_STOP_GUARD_MAX_USER_TURNS`, `0`
   disables), the boundary is declared stale and the hook fails open.
   Without it a boundary lives for the rest of the session:
   `stop_hook_active` only breaks the loop *within* a turn and resets on
   the next user message, so an un-terminated flow would keep blocking
   unrelated turns.

   > The harness-injection markers exist because the counter used to
   > over-count catastrophically: on a real 2489-entry transcript it saw
   > 102 "fresh prompts" of which only 4 were human — 62 were this hook's
   > own `reason` re-injected as `Stop hook feedback: …` and 40 were
   > `<task-notification>` background-agent completions. The limit of 3
   > was hit at entry 322 with 1/6 sub-skills done, so the guard turned
   > itself off mid-flow. `gh-verify:review-all` (Step 2.4) fans out three
   > background agents, which made that the normal path (PR dEitY719/dotfiles#1272).
6. If no terminal marker is present, count the distinct sub-skill
   `Skill()` invocations after the boundary and pick the *next* one
   in the canonical chain.
7. Emit `{"decision":"block","reason":"…"}` on stdout. The `reason`
   tells the model exactly which Skill() call to make next, with the
   "no conversational text" rule restated.

When `GH_ISSUE_FLOW_STOP_GUARD_TRACE=1`, each decision logs a
`[stop-guard] … layer=L1|L1.5` line on stderr so the layer
attribution is greppable in post-mortems.

## Async-wait exception (dEitY719/dotfiles#1550)

Everything above treats "the model tried to stop with real work undone" as
abandonment. That is right except in one case: the model *delegated* the
undone work to a background/async `Agent` and is waiting for it — the
Advisor/Worker pattern the user's global `CLAUDE.md` mandates for multi-file
implementation. Following the policy therefore tripped both this hook and
its sister `skill_completion_guard.py` every time, and the only escape was
`GH_SKILL_GUARD_BYPASS=1`, which leaves no record of *why* the turn ended.

**The marker.** Right before ending such a turn, the model prints one
`(?m)^`-anchored line as plain assistant text:

```
[flow:async-wait] step=<skill>/<step> agent=<agent-id> reason=background-worker-delegated
```

`<skill>` is the hyphen-form skill name. For this outer guard `<step>` is
not parsed semantically — the marker's mere presence is the signal — while
`skill_completion_guard.py` matches it against a specific required step id.
`<agent-id>` and the literal `reason=` are recorded for audit only. This is
the marker's whole point over the bypass flag: the transcript says which
step, which agent, and on what grounds the turn ended.

**Assistant text only.** Unlike the sister hook's `[step:<skill>/<id>] OK`
scan — which *must* read `tool_result`, because those markers come out of a
`printf` in a Bash call — this marker is scanned with
`include_tool_results=False`, exactly like the L1.5 terminal-marker scan
above. Same dEitY719/dotfiles#608 reasoning: a `tool_result` carries arbitrary file content,
and both `gh_issue_flow_stop_guard.py` and this very document now contain
the marker line literally as documentation. Reading tool_results for it
would hand a free grace turn to any `Read` of either file. The asymmetry
between the two hooks is deliberate; do not "fix" it.

**Count-based, not agent-id-based.** The grace is a *streak*: markers found
after the last progress event, where progress for this hook means a
sub-skill `Skill()` invocation. Up to
`GH_ISSUE_FLOW_STOP_GUARD_ASYNC_WAIT_LIMIT` (default 2) consecutive markers
with no progress in between are allowed; from the next one the ordinary
block resumes, with the ordinary reason naming the next chain step. `0`
disables the grace entirely, so the first marker already blocks. A real
sub-skill call resets the count to zero, which is what stops a streak
accumulating across a whole flow.

The issue's own fix plan proposed comparing `agent=` across turns to detect
"no progress". That was rejected: it makes the guard depend on the model
reproducing one exact literal id string turn after turn — fragile in
precisely the situation the marker exists for, and a typo'd or regenerated
id would silently grant unlimited grace. A repeated marker with nothing else
happening in between is already sufficient evidence of stagnation, and needs
nothing from the model but the marker itself.

The check sits **after** the terminal-marker and stale-boundary decisions,
so both still take priority; the grace only ever changes the outcome on the
path that would otherwise block. The streak and limit are appended to the
existing L1.5 trace line.

The marker is a stop-gap for the wait, never a substitute for the real
completion signal: when the delegated work lands, the genuine step-emit
markers and the Step 3 report must still be produced normally.

## SubagentStop registration (dEitY719/dotfiles#1434)

A subagent's turn-end fires `SubagentStop`, not `Stop`. Without this
registration, a gh-flow:issue run inside a subagent — the issue-watcher
unattended dispatch (dEitY719/dotfiles#1389), where nobody is watching the
session — lost the harness layer entirely: the only one of the three guards
that does not need the model's cooperation. Just the two prompt-layer
mitigations remained, exactly the condition under which dEitY719/dotfiles#333 /
dEitY719/dotfiles#383 / dEitY719/dotfiles#1270 each recurred, leaving a
silently truncated chain with no error and no warning.

`Stop` and `SubagentStop` do not carry the same keys — notably,
`agent_transcript_path` (the subagent's own transcript) exists only on
`SubagentStop`, while `transcript_path` on that event names the **parent**
session's transcript. On `SubagentStop` the hook reads **only**
`agent_transcript_path`; on every other event it prefers
`agent_transcript_path` and falls back to `transcript_path`. If the chosen
file does not exist the hook fails open — it does not then try the other
key. A subagent must never be judged by its parent's flow state (the parent
could be mid-flow while the subagent does something unrelated, or the
reverse), so an unreadable transcript is the correct place to fail open.

Everything else — the four L1 boundary surfaces, the L1.5 terminal-marker
scan, boundary expiry, and every fail-open rail — applies verbatim once the
right transcript is selected; confirmed by execution that a block really
does continue a mid-flow subagent, the same mechanism as the `Stop` path.

Mechanism detail, the measured `Stop`/`SubagentStop` payload contract, and
the settings.json rollout path (tracked SSOT vs. each mode's live file) all
live with the hook itself in `dEitY719/dotfiles`
(`claude/hooks/gh_issue_flow_stop_guard.py`) — read there, not here, if you
are changing the registration rather than just using it.

## Safety rails

The hook runs on every Stop *and* SubagentStop event in the session,
not just gh-flow:issue ones, so misbehaviour would be very visible.
Defenses:

- **Fail-open everywhere.** Every code path that hits an unexpected
  state — bad JSON, missing file, no boundary, etc. — exits 0 with
  no output, which Claude Code interprets as "allow the stop."
- **Outermost `try/except`** in `__main__` catches any uncaught
  exception and exits 0.
- **`stop_hook_active` short-circuit.** When Claude Code re-fires Stop
  after a previous block, the field is set; the hook bails out so we
  never form an infinite Stop→block→Stop loop within a single chain.
- **Boundary expiry (dEitY719/dotfiles#1270).** A boundary that outlives 3 fresh user
  prompts is declared stale and the hook fails open — see step 5 above.
- **No state file, no network, no writes.** The hook only reads stdin
  and the transcript. There is nothing to corrupt.

## Disabling temporarily

Three escape hatches when debugging or when you genuinely want to
end a turn mid-flow:

1. **Comment the entries out** in `~/.claude/settings.json` (or
   whichever account-specific copy you use) — both the `Stop` and the
   `SubagentStop` one — and restart the session.
2. **Rename or `chmod -x`** the script — the hook command will fail to
   exec and Claude Code will treat that as a no-op (allow stop).
3. **Patch the script** to `print('{}'); return 0` at the top of
   `main()` for the duration of the debug session.

Re-install via `./setup.sh` to restore the default behaviour.

## Tests

`tests/integration/test_gh_issue_flow_stop_guard.py` in `dEitY719/dotfiles`
covers this hook's full detection contract against both `Stop` and
`SubagentStop` payloads: the four L1 boundary surfaces (and their
false-positive variants inside a `tool_result`), the L1.5 terminal-marker
scan including its `Bash` heredoc/`printf` fallback pairing (dEitY719/dotfiles#1270 /
dEitY719/dotfiles#1274) and every rejected false-positive shape, boundary
expiry (dEitY719/dotfiles#1270 F-2) with its harness-injection exclusions,
`SubagentStop` transcript resolution and registration, the async-wait grace
(dEitY719/dotfiles#1550), and all fail-open rails. A drift test ties the
report's field names to `references/report-template.md`, so renaming them
there fails the build instead of silently staling the hook.

Run from that repo: `pytest tests/integration/test_gh_issue_flow_stop_guard.py -v`.
The sister hook's tests (`skill_completion_guard.py`, same dEitY719/dotfiles#1550
async-wait mechanism) live in `tests/integration/test_skill_completion_guard.py`
there.
