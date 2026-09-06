# Host Resolution (GHES / GitHub)

origin 시스템은 하드코딩하지 않고 SSOT 함수로 해석한다.

    # plugin-root resolution: https://github.com/dEitY719/harness-skills/blob/main/references/plugin-root.md
    _SC="${DOTFILES_ROOT:-$HOME/dotfiles}/shell-common"                              # tier 1
    if [ ! -f "$_SC/functions/gh_host.sh" ]; then
        [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || {                                        # tier 5
            printf '[gh-flow:autopilot] no shell-common under %s, and CLAUDE_PLUGIN_ROOT is unset. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
                "$_SC" >&2
            return 1 2>/dev/null || exit 1
        }
        _SC="$CLAUDE_PLUGIN_ROOT/lib/vendor/shell-common"                            # tier 2
    fi
    unset -f _gh_resolve_host 2>/dev/null || :
    [ -f "$_SC/functions/gh_host.sh" ] && . "$_SC/functions/gh_host.sh"
    command -v _gh_resolve_host >/dev/null 2>&1 || {                                 # tier 5
        printf '[gh-flow:autopilot] %s did not load a usable shell-common. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' \
            "$_SC" >&2
        return 1 2>/dev/null || exit 1
    }
    export SHELL_COMMON="$_SC"
    HOST="$(_gh_resolve_host)"        # internal→github.samsungds.net, 그 외→github.com

- 모든 `gh` 호출은 해석된 host 로 라우팅한다. gh CLI 는 `GH_HOST` 또는 repo 의 remote URL 로
  host 를 판단하므로, 이슈/PR 생성 전 대상 repo 가 그 host 에 있는지 remote 로 확인한다.
- owner/repo 파싱도 gh_host.sh 의 파서를 재사용(별도 정규식 복제 금지).
- setup-mode 판정은 `_dotfiles_setup_mode` 를 따른다(gh_host.sh 내부에서 처리).
- gh_host.sh 부재 → 위 블록이 시도한 경로를 밝히고 중단. 기타 setup 모드 → github.com fail-safe(회귀 0).

근거: gh_host.sh 파일 주석(dEitY719/dotfiles#703, dEitY719/dotfiles#704) — "미래 GHE 도메인 추가 시 이 파일만 수정".
