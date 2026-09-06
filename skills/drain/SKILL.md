---
name: drain
description: >-
  Drain a repo's open backlog to zero honestly — each issue through
  gh-flow:issue, every deferred finding promoted to a new issue instead of a
  ledger line. Use for /gh-flow:drain, "이슈를 다 처리해라", "백로그 0으로",
  "이연 항목도 이슈로 등록하고 0이 될 때까지", "drain the backlog to zero".
  Starts from an existing backlog, not a spec (gh-flow:autopilot).
license: MIT
allowed-tools: Bash, Read, Grep, Skill
metadata:
  model_recommendation:
    tier: opus
    reason: "backlog-wide round loop; per-issue promotion and blocked-classification judgment"
    claude: prefer
    non_claude: advisory-only
---

# gh-flow:drain — 백로그를 정직하게 0으로

## Role

종료 조건은 **둘**이다 — 열린 이슈 0 **그리고** 이연 항목 0. 앞만 보면 "이슈를
만들지 않는 것"이 승리 전략이 된다. 이 스킬은 그 경로를 막으려고 존재한다.

열린 이슈를 번호 오름차순으로 한 건씩 `gh-flow:issue` 에 넘기고, 그 라운드에서 나온
이연·미해결을 예외 없이 `gh-issue:create` 로 승격한 뒤 목록을 다시 조회한다.
**전제조건**: `gh-flow:issue` 와 같다 — 전용 worktree 의 feature 브랜치 위.

## Step 1: Parse Args + Bind Target

`/gh-flow:drain [owner/repo] [remote] [--merge] [--max-rounds N] [--label L]`.
인자 표와 `-h`/`--help`/`help` 경로(= `references/help.md` 를 그대로 출력하고 정지,
API 호출 없음): `references/help.md`.

**대상 바인딩** — 하나의 remote URL 에서 `TARGET_HOST` + `TARGET_REPO` 를 뽑고 모든
`gh` 호출을 `GH_HOST="$TARGET_HOST" gh ... --repo "$TARGET_REPO"` 로 실행한다.
바인딩 블록은 형제 스킬의 SSOT 를 그대로 쓴다 — `../issue/references/target-binding.md`
의 **bash 블록만** 해당하고(복사하지 말 것), 그 파일의 `gh-flow:issue` Step 2.4.1/2.6
설명은 여기 적용되지 않는다. **없는 remote 는 조용히 `origin` 으로 떨어지지 말고**
`git remote -v` 를 출력하고 정지한다.

`[owner/repo]` 는 스위치가 아니라 **가드**다 — remote 슬러그와 다르면 둘 다 출력하고
정지한다. `--author @me` 로 본인 이슈만 본다(D-4). 두 규칙의 근거와 이 스킬이
GitHub 에 쓰는 것(승격 이슈 · `blocked` 라벨 · 차단 코멘트): `references/help.md`.

## Step 2: Round Loop

라운드 1건은 **조회 → 처리 → 승격(Step 3) → 재조회** 4단계다. 정확한 명령,
제외 규칙(`blocked` · 이번 런에서 이미 PR 을 만든 이슈 · `Depends on #M`), 정지
조건은 `references/loop.md` 가 SSOT — 라운드를 시작하기 전에 읽는다.

`gh issue list` 실패는 라운드를 시작하지 않고 정지한다(상태를 모른 채 진행 금지).
반대로 한 이슈의 실패는 그 이슈만 실패로 기록하고 다음 이슈로 넘어간다 — 드레인
전체를 중단하지 않는다.

## Step 3: Promotion — 이 스킬의 핵심

그 라운드에서 찾았지만 그 라운드에서 고치지 않은 것은 **예외 없이 전부**
`Skill(gh-issue:create, ...)` 로 이슈화한다. ledger·PR 코멘트·종료 코멘트에만 적고
넘어가는 것은 **금지**다. 대상 목록은 기억이 아니라 아티팩트(미해결 리뷰 스레드,
diff 의 `TODO`/`ponytail:`, skip/xfail 된 테스트)에서 열거한다 — 목록·제외 기준·
승격 실패가 왜 치명적인지 전부 `references/promotion.md`.

## Step 4: Blocked 처리

지금 닫을 수 없는 사유가 확인된 이슈는 **닫지 않는다.** `blocked` 로 분류해 다음
라운드부터 제외하고, (a) 왜 막혔는지 (b) 무엇이 있으면 풀리는지 (c) 풀렸을 때 실행할
절차를 코멘트로 남긴다. 분류 기준과 코멘트 템플릿: `references/blocked.md`.

## Step 5: Merge Policy

기본은 **머지하지 않는다.** `--merge` 를 명시할 때만, 그 라운드의 재조회 **전에**
`Skill(gh-pr:merge-train, "<remote>")` 에 위임한다(승인·라벨 게이트는 그 스킬 소유).
**`gh-pr:merge-emergency` 는 어떤 경로로도 호출하지 않는다.** 기본 종료 상태에 남는
"사람 머지를 기다리는 PR" 은 보고서가 `awaiting-merge` 로 따로 센다.

## Step 6: Report

라운드마다 한 표(닫음 / 새로 엶 / 차단 / 실패), 종료 시 최종 표 + `왜 아직 0이
아닌가` 항목별 한 줄 + `Next:` 한 줄. 템플릿: `references/report-format.md`.
보고는 평문 어시스턴트 텍스트로 낸다 — `Bash` heredoc 이나 `Write` 금지.

## Constraints

`references/constraints.md`: 임의 종료 금지, 상태는 GitHub 에만, 승격 면제 없음,
라운드/실패 상한, 라운드 표는 최종 답이 아니다.

## Related Skills

위임 대상: `gh-flow:issue` (이슈 1건 체인) · `gh-issue:create` (승격) ·
`gh-pr:merge-train` (`--merge` 일 때만). 스펙에서 시작하는 사촌:
`gh-flow:autopilot`.
