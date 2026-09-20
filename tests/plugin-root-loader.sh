#!/usr/bin/env bash
# Drift guard for the shell-common loader convention (#25). SSOT:
# https://github.com/dEitY719/harness-skills/blob/main/references/plugin-root.md
#
# Four sites in this repo paste or ship that loader: autopilot's and
# relay-merge's reference blocks, and the two lib scripts. Three upstream fixes
# are easy to lose on the next edit because each looks like a stylistic detail
# and none of them fails visibly when reverted:
#
#   harness-skills#36  `command -v <fn> >/dev/null 2>&1` answers "is this name
#                      runnable", not "did this load define a function". A PATH
#                      executable or an alias of the same name passes it. The
#                      proof compares command -v's OUTPUT to the bare name, and
#                      `unalias` sits beside `unset -f` because a live alias
#                      outranks a just-defined function in sh, dash and zsh.
#   harness-skills#37  `export SHELL_COMMON` must precede the `.`, because every
#                      vendored helper resolves its own siblings through
#                      ${SHELL_COMMON:-...} WHILE it is being sourced. The
#                      tier-5 arm `unset`s it, so the observable contract is
#                      unchanged: set if and only if a helper proved out.
#                      Leaving a failed tree exported is gh-resolve-skills#8.
#
# Reverting either is silent in every green test, which is why this file exists.
# Three assertions: the exit-status proof is gone tree-wide, every loader block
# still orders its six steps correctly, and the one loader that can be executed
# here actually behaves that way in a real shell.
#
#   bash tests/plugin-root-loader.sh
set -euo pipefail
cd -- "$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail=0

# Vendored trees are excluded throughout: this repo may not edit them (fix at
# the SSOT and re-copy), and gh_host.sh legitimately probes whether an optional
# helper is loaded, which is not a load proof.
# This file is excluded along with them, and for the opposite reason: it has to
# quote the markers in order to check for them, so it is the one file that
# matches every pattern below without carrying the defect.
mapfile -t tracked < <(git ls-files -- '*.md' '*.sh' \
	| grep -v -e '^lib/vendor/' -e '^tests/plugin-root-loader\.sh$')
[ "${#tracked[@]}" -gt 0 ] || { printf 'FAIL  no tracked files to scan\n'; exit 1; }

# 1. No tracked file may prove a load by exit status. Only `_`-prefixed names
#    are matched: `command -v git`/`dash >/dev/null` is a "is this tool
#    installed" test, a different question with a different correct answer.
if hits=$(grep -nE 'command -v _[A-Za-z0-9_]+ >/dev/null' "${tracked[@]}"); then
	printf 'FAIL  exit-status load proof is back — compare command -v'"'"'s OUTPUT to the bare name:\n'
	printf '%s\n' "$hits" | sed 's/^/        /'
	fail=1
fi

# 1b. No tracked file splices a caller-controlled default into a path — the
#     retired tier 4 (harness-skills#22). This is a DIFFERENT carrier from the
#     loader blocks above and that is exactly why it was missed: #35/#36/#37
#     audited blocks that load a VENDORED helper, while a plugin addressing its
#     OWN scripts by path was never looked at. Two of the four sites here were
#     `. "<default>/skills/issue/lib/target-binding.sh"`, so with the variable
#     unset the skill sourced that file out of the CURRENT WORKING DIRECTORY —
#     and gh-flow skills run inside the repository under review, which the user
#     may not control (dEitY719/gh-flow-skills#27).
#
#     Three spellings of the cwd default, not one: a $PWD-only alternation
#     passes the dot and command-substitution forms, which name the same
#     directory, and the dot form is the one that actually shipped here.
#
#     The whole tree, not just *.md and *.sh: the defect is a path, so it can
#     live in a JSON manifest or a JS entry point as easily as in a fence. This
#     is the gate harness-skills#59 is moving into the shared skill-check.yml;
#     keeping a copy here means the class cannot come back between runs of it.
#
#     This file states the pattern only as a regex, never as a literal, so it
#     does not match itself and needs no self-exclusion here — the regex text
#     has a `[` where the pattern needs an identifier character.
mapfile -t everything < <(git ls-files)
[ "${#everything[@]}" -gt 0 ] || { printf 'FAIL  no tracked files at all\n'; exit 1; }
if hits=$(grep -nE '\$\{[A-Za-z_][A-Za-z0-9_]*:?-(\$PWD|\$\(pwd\)|\.)?\}/' "${everything[@]}"); then
	printf 'FAIL  a caller-controlled default is spliced into a path (retired tier 4):\n'
	printf '%s\n' "$hits" | sed 's/^/        /'
	printf '        Guard the variable and prove the file instead; see\n'
	printf '        harness-skills/references/plugin-root.md, "There is no tier 4".\n'
	fail=1
fi

# 2. Every loader block runs its six steps in order. Anchored on `unset -f _`,
#    which is what starts one, so a new loader site is covered the day it is
#    added rather than when someone remembers to list it here.
for f in "${tracked[@]}"; do
	grep -q 'unset -f _' "$f" || continue
	# One marker per line, in file order, then assert the expected sequence is
	# exactly what came out. Comparing the whole sequence (not "does X appear
	# before Y") is what catches a duplicated or dropped step too.
	seq=$(sed -E \
		-e 's/^[[:space:]]*unset -f _[A-Za-z0-9_]+ 2>\/dev\/null \|\| :$/UNSETF/' \
		-e 's/^[[:space:]]*unalias _[A-Za-z0-9_]+ 2>\/dev\/null \|\| :$/UNALIAS/' \
		-e 's/^[[:space:]]*export SHELL_COMMON=.*$/EXPORT/' \
		-e 's/^[[:space:]]*(\[ -f "[^"]+" \] && )?\. "\$[A-Za-z0-9_]+\/functions\/.*$/LOAD/' \
		-e 's/^[[:space:]]*(if )?\[ "\$\(command -v _[A-Za-z0-9_]+ 2>\/dev\/null\)" !?= _[A-Za-z0-9_]+ \].*$/PROOF/' \
		-e 's/^[[:space:]]*unset SHELL_COMMON$/UNSETVAR/' \
		"$f" | grep -E '^(UNSETF|UNALIAS|EXPORT|LOAD|PROOF|UNSETVAR)$' | tr '\n' ' ') || :
	# `|| :` is load-bearing: grep exits 1 when a block yields no marker at all,
	# and under `set -e` + `pipefail` that killed the whole run with no output —
	# a gate failing silently for the wrong reason, which is the class of bug
	# this file exists to catch. An empty `$seq` must reach the report below.
	want='UNSETF UNALIAS EXPORT LOAD PROOF UNSETVAR '
	[ "$seq" = "$want" ] || {
		printf 'FAIL  %s loader steps are out of order or incomplete\n' "$f"
		printf '        want: %s\n        got:  %s\n' "$want" "${seq:-<none>}"
		fail=1
	}
done

# 3. The mechanical checks above read text. This one runs it. target-binding.sh
#    is sourceable and self-contained, so it can be driven through the exact
#    failure the two fixes are about: a plugin root whose helper loads but
#    defines nothing, with a PATH executable of the function's name in the way.
#    It must refuse, and it must not leave SHELL_COMMON pointing at the tree it
#    just rejected.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP/root/lib/vendor/shell-common/functions" "$TMP/bin"
: > "$TMP/root/lib/vendor/shell-common/functions/gh_host.sh"
printf '#!/bin/sh\nprintf imposter\n' > "$TMP/bin/_gh_resolve_host"
chmod +x "$TMP/bin/_gh_resolve_host"

out=$(cd "$TMP" && env -u SHELL_COMMON HOME=/nonexistent DOTFILES_ROOT=/nonexistent \
	CLAUDE_PLUGIN_ROOT="$TMP/root" PATH="$TMP/bin:$PATH" \
	sh -c '. "$1" >/dev/null 2>&1; printf "rc=%s sc=%s" "$?" "${SHELL_COMMON-<unset>}"' \
	sh "$OLDPWD/skills/issue/lib/target-binding.sh" 2>/dev/null) || :
case "$out" in
	'rc=0 '*)
		printf 'FAIL  target-binding.sh accepted a shell-common that defined nothing (a PATH executable satisfied the proof): %s\n' "$out"
		fail=1 ;;
	*'sc=<unset>') ;;
	*)
		printf 'FAIL  target-binding.sh left the rejected tree exported: %s\n' "$out"
		fail=1 ;;
esac

[ "$fail" -ne 0 ] || printf 'ok    %s loader site(s): no exit-status proof, six steps in order, and a PATH imposter is refused with nothing exported; no caller-controlled default spliced into a path across %s tracked file(s)\n' \
	"$(grep -lE 'unset -f _' "${tracked[@]}" | wc -l | tr -d ' ')" "${#everything[@]}"
exit "$fail"
