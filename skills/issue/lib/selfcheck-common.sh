#!/usr/bin/env bash
# Shared plumbing for skills/issue/lib/*.selfcheck.sh — source it, never
# execute it. Defines ROOT (repo root) and chk() (compare got vs want),
# identical across all three self-checks before this file existed.
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
