#!/usr/bin/env bash
# Runs every skills/*/lib/*.selfcheck.sh, so the helpers under skills/*/lib
# are gated by CI rather than by remembering to run them by hand. Each
# script is self-contained: no network, no gh auth, no dotfiles checkout.
#
# CI entry point: `.github/workflows/validate.yml` calls the reusable
# workflow dEitY719/harness-skills/.github/workflows/skill-check.yml, whose
# "Repo self-checks pass (tests/)" step discovers every tracked `tests/*.sh`
# and runs it — that step is what executes this file. `validate.yml`
# therefore carries no step of its own; see the comment on its `uses:` line.
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
shopt -s nullglob
for f in skills/*/lib/*.selfcheck.sh; do
    echo "== $f"
    bash "$f"
done
