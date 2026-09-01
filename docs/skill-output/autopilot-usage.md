# autopilot 사용 결과

> **한 줄 요약** — 승인된 spec 파일 1개를 받아 계획·이슈·구현·PR·리뷰답변을 무승인으로 생성합니다.

```
spec (.md)  ──▶  /gh-flow:autopilot  ──▶  계획 + 이슈 + 커밋 + PR (머지는 사람 몫)
```

## 1. 실행한 명령

범용 형식: `/gh-flow:autopilot [spec-path] [--mode auto|sdd|inline] [remote]`

이번에 실제로 실행한 것 — help 경로와 Step 1 이전의 전제조건 검사:

```
/gh-flow:autopilot -h
git rev-parse --abbrev-ref HEAD          # 전제조건: feature 브랜치인가
ls -1 docs/superpowers/specs/*-design.md  # 전제조건: spec 자동 감지
```

## 2. 입력

- `skills/autopilot/references/help.md` (27줄, 1,112바이트) — `-h` 가 verbatim 출력하는 파일. API 호출 없음.
- spec 자동 감지 대상 경로: `docs/superpowers/specs/*-design.md`

## 3. 결과

전제조건 2개 중 1개 통과, 1개 실패:

```
$ git rev-parse --abbrev-ref HEAD
wt/feat/1                      # OK - 디폴트 브랜치(main)가 아닌 feature 브랜치
$ ls -1 docs/superpowers/specs/*-design.md
no matches found               # FAIL - 승인된 spec 없음 (exit 1)
```

spec 자동 감지가 실패했으므로 계약대로 **Step 0a 계획 단계에 진입하지 않고 정지**하고,
`[spec-path]` 를 요청한다. `[step:gh-flow-autopilot/plan] OK` 마커는 출력되지 않았다.

Step 0a~6 전체 실행은 이슈 생성·커밋·push·PR 개설을 수반하므로 이 문서 범위 밖이다.

가이드: [`../skill-guides/autopilot.md`](../skill-guides/autopilot.md)
