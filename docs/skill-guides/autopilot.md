# gh-flow:autopilot 스킬 가이드

## 한 줄 요약

승인된 spec 파일 1개를 받아 **구현 계획 문서 · 추적 이슈 · 구현 커밋 · 열린 PR · 리뷰 코멘트
답변**을 사용자 승인 체크인 없이 한 번에 산출한다. 머지는 하지 않는다.

## 언제 쓰고, 언제 안 쓰는가

| 상황 | 선택 |
|---|---|
| 승인된 spec 이 있고 이슈는 아직 없다 | `gh-flow:autopilot` — 이 스킬 |
| 이슈 번호가 이미 있다 | `gh-flow:issue` — 한 단계 뒤에서 시작한다 |
| spec 자체를 아직 쓰지 않았다 (Stage-A) | 이 스킬 범위 밖. brainstorming / spec 작성을 먼저 끝낸다 |
| 목적지 remote 가 push 차단 | `gh-flow:issue-relay` |

`issue` 와 `autopilot` 을 가르는 한 문장: **`issue` 는 이슈 번호를 받고, `autopilot` 은
spec 을 받는다.** `issue` 는 spec 을 지어내지 않고, `autopilot` 은 spec 을 건너뛰지 않는다.

## 호출 형식

```
/gh-flow:autopilot [spec-path] [--mode auto|sdd|inline] [remote]
/gh-flow:autopilot -h | --help | help
```

| 인자 | 기본값 | 설명 |
|---|---|---|
| `[spec-path]` | 최신 `docs/superpowers/specs/*-design.md` 자동 감지(+세션 교차확인) | 구현할 spec 파일 경로 |
| `--mode auto\|sdd\|inline` | `auto` | 구현 방식. `auto` 는 계획 복잡도로 자동 판정 |
| `[remote]` | `origin` | git remote 이름 |

## 동작 단계

Step 1 이전에 `START_TS` 를 기록하고 전제조건을 검사한다 — 전용 worktree 의 feature 브랜치
(디폴트 브랜치면 즉시 정지) · 승인된 spec 존재 · 원자 스킬 설치 확인. 이후 각 단계는 직전
단계 성공 시에만 진행하며, 완료 직후 `[step:gh-flow-autopilot/<id>] OK` 마커를 출력한다.

| 단계 | 위임 대상 | 하는 일 | 마커 id |
|---|---|---|---|
| 0a | `superpowers:writing-plans` | spec → `docs/superpowers/plans/YYYY-MM-DD-<topic>.md` | `plan` |
| 0b | `gh-issue:create --no-ask` | host-aware 추적 이슈 생성, `ISSUE_NUM`·URL 확보 | `issue` |
| 1 | (인라인 판정) | `auto` 면 계획을 읽어 sdd/inline 판정, `mode=... reason=...` 1줄 로그 | `mode` |
| 2 | `superpowers:subagent-driven-development` 또는 인라인 TDD | 구현 + 논리 단위 커밋. **Advisor 검증 비생략** — 테스트·typecheck·lint 직접 실행, 실패면 PR 진행 금지 | `implement` |
| 3 | `gh-pr:create <ISSUE_NUM>` | `Closes #ISSUE_NUM` 보장, PR URL 에서 `PR_NUM` 추출 | `pr` |
| 4 | `simplify <PR_NUM>` | 품질 픽스 적용·커밋·push | `simplify` |
| 5 | `gh-pr:reply <PR_NUM>` | 즉시 실행. 코멘트 없으면 no-op `[SKIP]` 보고 후에도 마커는 출력 | `pr-reply` |
| 6 | (리포트) | `[OK]`/`[FAIL]` 구조화 리포트 + AI metrics(soft-fail) | `report` |

`--no-ask` 는 미결 게이트가 무인 체인을 멈추지 않게 한다 (dEitY719/dotfiles#1446).

## 주의사항 / 제약

- **절대 금지**: PR 머지 · 디폴트 브랜치 push · `--force` / `--force-with-lease` push ·
  `--no-verify` · 테스트 실패 상태의 PR · spec 없는 자동 실행.
- **정지 규칙**: 어느 단계든 하드 실패면 그 지점에서 정지하고 재개 리포트를 출력한다.
  이후 단계는 자동 스킵된다. 중단 후 재개는 `session:restart`.
- **단계 간 승인·체크인이 없다.** 사용자가 사전에 위임한 것으로 간주하고 끝까지 달린다.
  그래서 spec 이 실제로 승인된 것인지가 이 스킬의 유일한 안전 게이트다.
- **체이닝된 `Skill()` 호출 사이 대화 텍스트 0.** 하위 스킬의 trailing hint 억제와 함께
  early-stop 회귀를 막는 3중 가드 중 둘이며, 세 번째는 `dEitY719/dotfiles` 의
  `claude/hooks/devx_autopilot_stop_guard.py` 다.
- **마커 문자열은 hook 계약이다.** `[step:gh-flow-autopilot/<id>] OK`,
  `[OK] gh-flow:autopilot`, `[FAIL] gh-flow:autopilot` 를 hook 수정 없이 바꾸면
  early-stop 회귀가 다시 열린다.
- **Stage-A 는 하지 않는다.** brainstorming, spec 작성, 릴리스, 디폴트 브랜치 작업 전부
  범위 밖이다.
