# gh-flow:relay-merge — Gist Upload (one file per call)

Step 5. Uploads each patch file from Step 4 as its own gist.

## The hard rule: one file, one call, sequential

`lib/relay.sh upload` is that loop — the rule is the code, not a reminder:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/relay-merge/lib/relay.sh" upload "$DEST_HOST" "$tmpdir"
```

## Which host the gists live on: the destination

`gh gist create` is not repo-scoped (`--repo` is not a valid flag), so the
`GH_HOST=` prefix is the *only* thing that decides which server the gist
lands on — and it must be `$DEST_HOST`, never the origin host.

The gist is not the payload's storage, it is the **hand-off channel**: the
apply-guide is posted on the destination and the destination-side reader
`curl`s the raw URL. A gist created on the isolated origin (internal GHE)
has a raw URL that host cannot serve to the outside, so the reader gets a
404 or an auth wall and the whole relay stalls at step 2 of the guide. The
asymmetric-network premise in SKILL.md says the same thing from the other
end: the proxy blocks `git push` to the destination but lets single-file
`gh gist create` through *to the destination host* — that is the one hole
this skill relays through. Put the gists where the reader is.

- **Exactly one file per `gh gist create` invocation.** Multi-file gist
  creation (`gh gist create a.patch b.patch ...`) is reported to **always**
  fail under this network policy, regardless of file count — so never batch.
- **Sequential, never parallel.** Parallel uploads risk rate-limit / abuse
  triggers on the same policy. Run one at a time.

## The output rows

`gh gist create` prints only the gist's web URL, but the apply-guide needs
the **raw** URL for `curl … | git am`, so `upload` resolves it from the gist
API (`gh api gists/<id> --jq '.files[].raw_url'`) — pointing at the exact
file rather than hand-constructing the URL — and prints one TSV row per
patch, in apply order:

```
<order>	<description>	<web-url>	<raw-url>
```

`<description>` is the patch's `Subject:` line (the commit subject), so the
destination reader knows what each patch does without opening it. `<order>`
is the patch's `NNNN` slot, or `NNNN-<k>` for a file-group sub-patch. These
rows are the Step 6 table verbatim.

## Failure handling

- **Transient/network failure** — `upload` retries that single gist once
  after a short backoff (same policy as the push probe). Still failing →
  exit 4.
- **Any other failure** — exit 4. No automatic retries beyond the one
  transient-error backoff.
- **Size-related failure on an individual file** — Step 4's exclusion did
  not clear the cutoff. Report which file and stop; do not force it through
  (no-silent-truncation rule, see `references/patch-generation.md`).

The rows already printed **are** the list of gists that exist — `upload`
prints as it goes for exactly this reason. Put them in the Step 8 `[FAIL]`
block's "gists already created" line and do not proceed to Step 6 with a
partial set; a partial apply-guide would be misleading.
