# gh-flow:relay-merge — Report Templates

Step 8's output. Pick exactly one block — the run took exactly one of the
three paths. `gh-flow:issue-relay` relays this verbatim into its own Step 6,
so the `[OK]` / `[FAIL]` marker is a contract, not decoration.

## Relay mode ([OK])
    [OK] gh-flow:relay-merge — relay mode
    - destination:  <issue-url>
    - apply-guide:  <comment-url>
    - patches:      <N> gists  (<K> split: <artifact-exclusion | file-group | none>)
    - range:        <base>..<head>
    Next: apply on the destination per the guide, or hand the comment URL to
    the destination-side operator

`<K> split` counts patches `lib/relay.sh patches` reported with an
`EXCLUDED` row (artifact exclusion) or a `NNNN-<k>` order label (file-group
pre-split); `none` when every commit shipped as one whole patch.

## SIMPLE PATH ([OK]) — push works, relay not needed
    [OK] gh-flow:relay-merge — SIMPLE PATH (push works, relay not needed)
    - delegated to: gh-pr:create
    - PR:           <pr-url>
    Next: review and merge the PR normally

Add a `- warning:` line when `lib/relay.sh probe` printed `leftover_ref=` —
the probe ref survived both delete attempts and needs a manual delete.

## Failure ([FAIL]) — stops at the failing step
    [FAIL] gh-flow:relay-merge — stopped at Step <k>
    - reason:  <error, surfaced unmodified>
    - gists already created: <web URLs, one per line, or none>
    Next: <resume guidance>

The gist list is mandatory whenever Step 5 had started:
`references/constraints.md` → "Never post a partial apply-guide" requires the
skill to stop rather than post an incomplete guide, and this list is what
makes that stop recoverable — the operator can see what already exists
instead of re-uploading duplicates. `lib/relay.sh upload` prints its rows as
it goes for exactly this reason, so the rows already on stdout are the list.

Stop-on-error causes, verbatim as the `- reason:` line:
- Step 1: both input modes supplied, or the requested `--remote` does not
  exist (never falls back to `origin`) or is unreachable
- Step 4: `lib/relay.sh patches` exit 3 — a single file's own diff exceeds
  `RELAY_PATCH_MAX_BYTES` even after file-group pre-split
  (`references/patch-generation.md` → "No silent truncation")
- Step 5: `lib/relay.sh upload` exit 4 — a gist upload failed after its one
  transient retry
- Step 6: the destination issue/comment write failed
