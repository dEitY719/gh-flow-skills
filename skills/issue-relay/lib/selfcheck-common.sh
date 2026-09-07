#!/usr/bin/env bash
# Shared plumbing for skills/issue-relay/lib/*.selfcheck.sh — source it,
# never execute it. Defines ROOT (repo root) and chk() (compare got vs
# want). Deliberately a per-skill copy of skills/issue/lib/selfcheck-common.sh
# rather than a cross-skill reference, so each skill's lib/ stays self-contained.
# shellcheck disable=SC2034  # ROOT/FAIL are used by the scripts that source this file
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
FAIL=0

chk() { # chk <label> <got> <want>
    if [ "$2" = "$3" ]; then
        echo "ok    $1"
    else
        echo "FAIL  $1: got '$2' want '$3'"
        FAIL=1
    fi
}
