#!/usr/bin/env bash
# Drift guard for the agent-filled tier-2 line (#41 F-6). A skill loaded
# through a plain symlink (~/.claude*/skills/<name> -> <checkout>/skills/<name>)
# runs with CLAUDE_PLUGIN_ROOT unset, so every pasted block that addresses
# "$CLAUDE_PLUGIN_ROOT/skills/..." first fills it from the skill's base dir.
# Bash calls share no variables, so each block needs its own copy — and a block
# that loses it is silent until someone runs from a symlink install.
#
#   bash tests/plugin-root-skill-base.sh
#
# 1. Every fenced block under skills/{issue,drain,waves} that splices
#    "$CLAUDE_PLUGIN_ROOT/skills/" carries the line, byte-identical.
# 2. The line, executed in every available POSIX-ish shell, resolves a
#    symlinked base dir to the REAL plugin root (`cd -P`), keeps a preset
#    value, and refuses a relative path (that would be $PWD, the retired tier 4).
set -euo pipefail
cd -- "$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
say() { printf '%s\n' "$*"; }

# The canonical line lives in the SSOT block; everything is compared to it.
canon=$(grep -m1 -F '"<skill-base-dir>/../.."' skills/issue/references/target-binding.md) ||
    { say 'FAIL  no tier-2 agent-filled line in skills/issue/references/target-binding.md'; exit 1; }

n=0
while IFS= read -r f; do
    # Emit one record per fenced block: "<start-line>\t<has-splice>\t<has-canon>".
    while IFS=$'\t' read -r start splice has; do
        [ "$splice" = 1 ] || continue
        n=$((n + 1))
        if [ "$has" = 1 ]; then say "ok    $f:$start"; else
            say "FAIL  $f:$start splices \$CLAUDE_PLUGIN_ROOT/skills/ without the tier-2 agent-filled line"
            fail=1
        fi
    done < <(awk -v canon="$canon" '
        /^```/ { if (inb) { print start "\t" sp "\t" hc; inb = 0 } else { inb = 1; start = NR; sp = 0; hc = 0 }; next }
        inb && index($0, "\"$CLAUDE_PLUGIN_ROOT/skills/") { sp = 1 }
        inb && $0 == canon { hc = 1 }' "$f")
done < <(git ls-files -- 'skills/issue/*.md' 'skills/drain/*.md' 'skills/waves/*.md')
[ "$n" -ge 5 ] || { say "FAIL  only $n splicing blocks found — the scan is broken, not the tree"; fail=1; }

# 2. Behaviour. The placeholder is substituted exactly as the agent would.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/real/skills/waves" "$TMP/home/skills"
ln -s "$TMP/real/skills/waves" "$TMP/home/skills/waves"
real=$(cd -P "$TMP/real" && pwd)
run() { # run <shell> <base-dir> [preset] -> resolved CLAUDE_PLUGIN_ROOT
    local line=${canon//<skill-base-dir>/$2}
    (cd "$TMP" && env -u CLAUDE_PLUGIN_ROOT ${3:+CLAUDE_PLUGIN_ROOT=$3} "$1" -c "$line
printf '%s' \"\${CLAUDE_PLUGIN_ROOT:-unset}\"")
}
for sh in bash sh dash zsh; do
    command -v "$sh" >/dev/null 2>&1 || continue
    got=$(run "$sh" "$TMP/home/skills/waves")
    [ "$got" = "$real" ] && say "ok    $sh: symlinked base dir -> real root" ||
        { say "FAIL  $sh: symlinked base dir gave '$got', want '$real'"; fail=1; }
    got=$(run "$sh" "$TMP/home/skills/waves" /preset)
    [ "$got" = /preset ] && say "ok    $sh: preset value kept" ||
        { say "FAIL  $sh: preset overwritten -> '$got'"; fail=1; }
    got=$(run "$sh" "home/skills/waves")
    [ "$got" = unset ] && say "ok    $sh: relative base dir refused" ||
        { say "FAIL  $sh: relative base dir resolved against \$PWD -> '$got'"; fail=1; }
done

exit "$fail"
