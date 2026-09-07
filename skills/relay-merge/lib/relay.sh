#!/usr/bin/env bash
# lib/relay.sh — gh-flow:relay-merge's deterministic pipeline (skill-check #6,
# Check 12). One subcommand per step, so the hard rules in
# references/constraints.md are machine-enforced instead of prose-enforced:
# probe-ref cleanup is a `trap`, "one file per gist call" is a loop, and
# "never silently truncate" is an exit code.
#
# EXECUTE it, never source it — plain argv to a subprocess, no eval contract:
#
#   bash "${CLAUDE_PLUGIN_ROOT}/skills/relay-merge/lib/relay.sh" probe   "$REMOTE" "$LOCAL"
#   bash "${CLAUDE_PLUGIN_ROOT}/skills/relay-merge/lib/relay.sh" patches "$BASE..$HEAD" "$tmpdir" [--generated-patterns <globs>]
#   bash "${CLAUDE_PLUGIN_ROOT}/skills/relay-merge/lib/relay.sh" upload  "$DEST_HOST" "$tmpdir"
#
# probe   <remote> <local-ref>
#   Real (non-dry-run) throwaway-ref push. Prints `blocked=no` or
#   `blocked=yes` on stdout and exits 0; exits 2 when still inconclusive
#   after its one backoff retry (caller treats that as not-blocked — see
#   references/push-probe.md). Deletes the probe ref from an EXIT trap, so
#   cleanup cannot be skipped; if both delete attempts fail it prints
#   `leftover_ref=<ref>` for the caller to surface.
#
# patches <base>..<head> <outdir> [--generated-patterns <glob,glob,...>]
#   git format-patch over the range, then enforces RELAY_PATCH_MAX_BYTES with
#   generated-artifact exclusion and file-group pre-split. Prints one TSV row
#   per resulting patch:
#     PATCH<TAB><order><TAB><bytes><TAB><path><TAB><subject>
#     EXCLUDED<TAB><order><TAB><stripped-path>
#   Exits 3 with the no-silent-truncation [FAIL] text when a single file's own
#   diff still exceeds the limit.
#
# upload  <dest-host> <outdir>
#   One `gh gist create` per patch file, sequential. Prints one TSV row per
#   uploaded patch as it goes:
#     <order><TAB><description><TAB><web-url><TAB><raw-url>
#   Exits 4 on the first failure, having already printed the rows that
#   succeeded (references/constraints.md → "Never post a partial apply-guide"
#   needs that list).
#
# Reads:   RELAY_PATCH_MAX_BYTES (default 40960), RELAY_BLOCK_REGEX,
#          RELAY_PROBE_BACKOFF (default 3)
# Self-check: lib/relay.selfcheck.sh

set -u

RELAY_PATCH_MAX_BYTES=${RELAY_PATCH_MAX_BYTES:-40960}
# ~1KB of From/Subject/date/diffstat header per patch, charged against the
# limit when bucketing so a group that just fits its files does not overflow.
RELAY_PATCH_HEADER_BYTES=1024
RELAY_DEFAULT_GENERATED_PATTERNS='**/generated/**,**/*.generated.*,openapi.json,package-lock.json,*.lock,**/dist/**,**/build/**'

die() { printf '[gh-flow:relay-merge] %s\n' "$1" >&2; exit "${2:-1}"; }

# --- probe -----------------------------------------------------------------

PROBE_REMOTE=""
PROBE_REF=""
PROBE_PUSHED=0

probe_cleanup() {
    [ "$PROBE_PUSHED" = 1 ] || return 0
    PROBE_PUSHED=0
    git push "$PROBE_REMOTE" --delete "$PROBE_REF" >/dev/null 2>&1 && return 0
    sleep 2
    git push "$PROBE_REMOTE" --delete "$PROBE_REF" >/dev/null 2>&1 && return 0
    printf 'leftover_ref=%s\n' "$PROBE_REF"
    printf '[gh-flow:relay-merge] destination %s still has branch %s — please delete it manually.\n' \
        "$PROBE_REMOTE" "$PROBE_REF" >&2
}

cmd_probe() {
    [ $# -eq 2 ] || die "usage: relay.sh probe <remote> <local-ref>"
    PROBE_REMOTE=$1
    local local_ref=$2
    # Block signals only (references/push-probe.md). Connection resets,
    # timeouts and DNS failures are inconclusive, never a confirmed block.
    local block_re=${RELAY_BLOCK_REGEX:-'HTTP 403|403 Forbidden|block(ed)?|proxy|forbidden|corporate policy|access denied'}
    PROBE_REF="refs/heads/relay-probe-$(date -u +%s)-$$"
    trap probe_cleanup EXIT INT TERM

    local out rc attempt
    for attempt in 1 2; do
        [ "$attempt" = 2 ] && sleep "${RELAY_PROBE_BACKOFF:-3}"
        out=$(git push "$PROBE_REMOTE" "$local_ref:$PROBE_REF" 2>&1)
        rc=$?
        if [ "$rc" -eq 0 ]; then
            PROBE_PUSHED=1
            echo "blocked=no"
            return 0
        fi
        printf '%s\n' "$out" >&2
        if printf '%s' "$out" | grep -Eqi "$block_re"; then
            echo "blocked=yes"
            return 0
        fi
    done
    die "push probe inconclusive after one retry (no block signal, non-zero rc)" 2
}

# --- patches ---------------------------------------------------------------

# commit_diff_bytes <sha> <path> — size of one file's diff inside one commit.
# diff-tree, not `diff <sha>^ <sha>`, so a root commit works too.
commit_diff_bytes() {
    git diff-tree -p --no-commit-id --no-color --no-ext-diff -r "$1" -- "$2" | wc -c
}

cmd_patches() {
    [ $# -ge 2 ] || die "usage: relay.sh patches <base>..<head> <outdir> [--generated-patterns <globs>]"
    local range=$1 outdir=$2
    shift 2
    local patterns=$RELAY_DEFAULT_GENERATED_PATTERNS
    while [ $# -gt 0 ]; do
        case "$1" in
            --generated-patterns) patterns=${2:?"--generated-patterns needs a value"}; shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done

    local -a exspec=() inspec=()
    local pat
    while IFS= read -r pat; do
        [ -n "$pat" ] || continue
        exspec+=(":(exclude,glob)$pat")
        inspec+=(":(glob)$pat")
    done <<<"${patterns//,/$'\n'}"

    mkdir -p "$outdir" || die "cannot create $outdir"

    local n=0 sha subject patch bytes
    while IFS= read -r sha; do
        [ -n "$sha" ] || continue
        n=$((n + 1))
        local order
        order=$(printf '%04d' "$n")
        patch=$(git format-patch -1 "$sha" --start-number "$n" -o "$outdir") \
            || die "git format-patch failed for $sha"
        subject=$(sed -n 's/^Subject: \[PATCH[^]]*\] //p' "$patch" | head -1)
        bytes=$(wc -c <"$patch")
        if [ "$bytes" -le "$RELAY_PATCH_MAX_BYTES" ]; then
            emit_patch "$order" "$bytes" "$patch" "$subject"
            continue
        fi

        # 1. Generated-artifact exclusion.
        local -a stripped=()
        local f
        while IFS= read -r f; do
            [ -n "$f" ] && stripped+=("$f")
        done < <(git diff-tree --no-commit-id --name-only -r "$sha" -- "${inspec[@]+"${inspec[@]}"}")
        if [ ${#stripped[@]} -gt 0 ]; then
            rm -f "$patch"
            patch=$(git format-patch -1 "$sha" --start-number "$n" -o "$outdir" -- . "${exspec[@]}") \
                || die "git format-patch failed for $sha (artifact exclusion)"
            bytes=$(wc -c <"$patch")
            for f in "${stripped[@]}"; do
                printf 'EXCLUDED\t%s\t%s\n' "$order" "$f"
            done
            if [ "$bytes" -le "$RELAY_PATCH_MAX_BYTES" ]; then
                emit_patch "$order" "$bytes" "$patch" "$subject"
                continue
            fi
        fi

        # 2. File-group pre-split over what is left.
        rm -f "$patch"
        split_commit "$sha" "$n" "$order" "$subject" "$outdir" "${exspec[@]+"${exspec[@]}"}"
    done < <(git rev-list --reverse "$range")

    [ "$n" -gt 0 ] || die "commit range '$range' is empty"
}

emit_patch() { # <order> <bytes> <path> <subject>
    printf 'PATCH\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"
}

# split_commit <sha> <n> <order> <subject> <outdir> [exclude-pathspecs...]
# Greedy first-fit bucketing of the commit's remaining files into groups that
# each stay under the limit, one independently `git am`-able sub-patch per
# group. `git format-patch -1 <sha> -- <paths>` clones the original commit's
# From/Subject/date/author headers onto every sub-patch.
split_commit() {
    local sha=$1 n=$2 order=$3 subject=$4 outdir=$5
    shift 5
    local -a exspec=("$@")
    local budget=$((RELAY_PATCH_MAX_BYTES - RELAY_PATCH_HEADER_BYTES))

    local -a files=() sizes=()
    local f sz
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        sz=$(commit_diff_bytes "$sha" "$f")
        if [ "$sz" -gt "$budget" ]; then
            fail_oversized "$order" "$sz" "$f"
        fi
        files+=("$f")
        sizes+=("$sz")
    done < <(git diff-tree --no-commit-id --name-only -r "$sha" -- . "${exspec[@]+"${exspec[@]}"}")

    [ ${#files[@]} -gt 0 ] || die "commit $sha has no non-artifact files left to split"

    local -a group=()
    local acc=0 k=0 i
    for ((i = 0; i < ${#files[@]}; i++)); do
        if [ ${#group[@]} -gt 0 ] && [ $((acc + sizes[i])) -gt "$budget" ]; then
            k=$((k + 1))
            write_group "$sha" "$n" "$order" "$k" "$subject" "$outdir" "${group[@]}"
            group=()
            acc=0
        fi
        group+=("${files[i]}")
        acc=$((acc + sizes[i]))
    done
    k=$((k + 1))
    write_group "$sha" "$n" "$order" "$k" "$subject" "$outdir" "${group[@]}"
}

# write_group <sha> <n> <order> <k> <subject> <outdir> <files...>
# Renamed to NNNN-<k>-<name>.patch so the sub-patches sort between this
# commit's slot and the next one — apply order stays unambiguous.
write_group() {
    local sha=$1 n=$2 order=$3 k=$4 subject=$5 outdir=$6
    shift 6
    local patch dest bytes
    patch=$(git format-patch -1 "$sha" --start-number "$n" -o "$outdir" -- "$@") \
        || die "git format-patch failed for $sha (file group $k)"
    dest="$outdir/${order}-${k}-$(basename "$patch" | cut -d- -f2-)"
    mv "$patch" "$dest"
    bytes=$(wc -c <"$dest")
    [ "$bytes" -le "$RELAY_PATCH_MAX_BYTES" ] || fail_oversized "${order}-${k}" "$bytes" "$*"
    emit_patch "${order}-${k}" "$bytes" "$dest" "$subject"
}

fail_oversized() { # <order> <bytes> <path>
    cat >&2 <<EOF
[FAIL] ${1}-*.patch is $2 bytes (> RELAY_PATCH_MAX_BYTES=$RELAY_PATCH_MAX_BYTES):
a single file's diff exceeds the limit even after file-group pre-split, and
its bulk is not a recognized generated artifact.
Offending path(s): $3
Refusing to truncate — arbitrary truncation would corrupt the applied commit.
Options: add its path to --generated-patterns if it IS generated, or split
the origin commit into smaller commits and re-run.
EOF
    exit 3
}

# --- upload ----------------------------------------------------------------

cmd_upload() {
    [ $# -eq 2 ] || die "usage: relay.sh upload <dest-host> <outdir>"
    local dest_host=$1 outdir=$2
    local patch base order desc url gist_id raw

    shopt -s nullglob
    local -a patches=("$outdir"/*.patch)
    shopt -u nullglob
    [ ${#patches[@]} -gt 0 ] || die "no *.patch files in $outdir"

    # One file per call, sequential — never a multi-file gist, never parallel
    # (references/constraints.md). The loop is the enforcement.
    for patch in "${patches[@]}"; do
        base=$(basename "$patch")
        order=$(printf '%s' "$base" | sed -E 's/^([0-9]+(-[0-9]+)?)-.*/\1/')
        desc=$(sed -n 's/^Subject: \[PATCH[^]]*\] //p' "$patch" | head -1)
        [ -n "$desc" ] || desc=$base

        url=$(gist_create "$dest_host" "$patch" "$base") || exit 4
        gist_id=${url##*/}
        raw=$(GH_HOST="$dest_host" gh api "gists/$gist_id" --jq '.files[].raw_url' 2>&1) || {
            printf '[gh-flow:relay-merge] could not resolve the raw URL for %s (%s): %s\n' \
                "$base" "$url" "$raw" >&2
            exit 4
        }
        printf '%s\t%s\t%s\t%s\n' "$order" "$desc" "$url" "$raw"
    done
}

# gist_create <dest-host> <patch> <base> — one transient retry, then stop.
gist_create() {
    local out attempt
    for attempt in 1 2; do
        [ "$attempt" = 2 ] && sleep 2
        out=$(GH_HOST="$1" gh gist create "$2" --desc "relay: $3" 2>&1) \
            && { printf '%s\n' "$out" | grep -o 'https://[^[:space:]]*' | tail -1; return 0; }
    done
    printf '[gh-flow:relay-merge] gist upload failed for %s after one retry: %s\n' "$3" "$out" >&2
    return 1
}

# --- dispatch --------------------------------------------------------------

[ $# -ge 1 ] || die "usage: relay.sh <probe|patches|upload> ..."
SUB=$1
shift
case "$SUB" in
    probe) cmd_probe "$@" ;;
    patches) cmd_patches "$@" ;;
    upload) cmd_upload "$@" ;;
    *) die "unknown subcommand: $SUB (expected probe, patches or upload)" ;;
esac
