# gh-flow:issue 스킬 가이드

## 한 줄 요약

이슈 번호 1건을 받아 **리뷰 게이트까지 통과한 열린 Pull Request 1개**와, 어느 단계까지
갔는지를 담은 `[OK]`/`[FAIL]` 리포트를 산출한다. 머지는 하지 않는다.

## 언제 쓰고, 언제 안 쓰는가

| 상황 | 선택 |
|---|---|
| 목적지 remote 에 이슈가 이미 있고, `git push` 가 정상 동작한다 | `gh-flow:issue` — 이 스킬 |
| 이슈가 아직 없고 승인된 spec 만 있다 | `gh-flow:autopilot` — 한 단계 앞에서 시작해 이슈까지 만든다 |
| 목적지 remote 가 프록시로 push 차단되어 있다 | `gh-flow:issue-relay` |
| 커밋 전에 변경을 직접 검토하고 싶다 / plan·brainstorming 모드가 필요하다 | 원자 스킬을 따로 호출: `gh-issue:implement` + `gh-pr:commit` + `gh-pr:create` |

이 스킬은 구현을 **direct 모드로만** 돌린다. plan/brainstorming 이 필요하면 이 스킬이 아니라
`gh-issue:implement` 를 직접 부르는 것이 맞다.

## 호출 형식

```
/gh-flow:issue <issue-number> [remote]
/gh-flow:issue -h | --help | help
```

| # | 인자 | 기본값 | 설명 |
|---|---|---|---|
| 1 | `<issue-number>` | — | 구현할 GitHub 이슈 번호 |
| 2 | `[remote]` | `origin` | 이슈를 소유한 git remote. 하위 스킬 전부에 그대로 전달되어 implement / commit / PR / review 가 모두 이 remote 를 향한다 (#1405) |

`-h` 경로는 `references/help.md` 를 그대로 출력하고 멈춘다 — API 호출이 전혀 없다.

## 동작 단계

Step 1 에서 remote URL 로부터 `TARGET_HOST` / `TARGET_REPO` 를 한 번 바인딩하고(#1403),
`START_TS` 를 기록한다. 이후 Step 2 에서 원자 스킬 6개를 순서대로 체인한다 — 각 단계는 직전
단계가 성공했을 때만 실행된다.

| 단계 | 위임 대상 | 하는 일 |
|---|---|---|
| 2.1 | `gh-issue:implement <N> direct <remote> --no-next-hint` | 이슈를 읽고 파일 수정 + 테스트 실행 |
| 2.2 | `gh-pr:commit <N> <remote>` | 레포 스타일의 커밋 생성, ai-metrics/보드 동기화 |
| 2.3 | `gh-pr:create <N> <remote>` | 브랜치 push + PR 개설, `Closes #<N>` 보장, `PR_NUM` 추출 |
| 2.4 | `gh-verify:review-all <PR_NUM> <remote> --defer-reply 4` | 품질 게이트(agy ∥ codex ∥ `/simplify`) 병렬 실행, simplify 변경은 동기 커밋+push, `gh-pr:reply` 는 4분 뒤로 예약. **soft-fail** |
| 2.4.1 | `aicron run merge-train` (Bash, 비치명) | merge-train 디스패처 백그라운드 기동. `<remote>` 가 `$HOME/dotfiles` 의 `origin` 과 같은 URL 일 때만 |
| 2.5 | `gh-resolve:conflict <PR_NUM>` | 리베이스로 충돌 해소. 신규 PR 이면 보통 skip |
| 2.5.1 | `gh-resolve:outdated <PR_NUM>` | base 가 앞서갔을 때 clean 리베이스 sync |
| 2.6 | (인라인 Bash) | 이슈에 flow 단위 AI metrics 코멘트. **soft-fail** |

Step 3 은 `[OK]`/`[FAIL]`/`[SKIP]` 리포트를 **평문 assistant 텍스트로** 출력한다 —
`Bash` heredoc 이나 `Write` 로 내보내지 않는다 (#1270).

## 주의사항 / 제약

- **전제조건**: 이미 전용 worktree 의 feature 브랜치 위에 있고 working tree 가 깨끗해야 한다.
  이 스킬은 worktree 도 브랜치도 만들지 않는다.
- **첫 실패에서 즉시 중단.** 재시도 없음, 건너뛰기 없음. 부분 진행은 롤백하지 않는다 —
  commit 이 성공하고 PR 이 실패했으면 커밋은 남는다. 리포트의 재개 힌트로 수동 재개한다.
- **soft-fail 예외는 정확히 3개** — `gh-verify:review-all`, merge-train wake, metrics 코멘트.
  네 번째를 추가하려면 `skills/issue/references/constraints.md` 를 함께 고쳐야 한다.
- **체인된 `Skill()` 호출 사이에 대화 텍스트를 넣지 않는다**, 그리고 2.1 의 `--no-next-hint`
  를 제거하지 않는다. 둘 다 early-stop 회귀를 막는 기계적 가드이며 스타일 조언이 아니다.
  세 번째 가드인 하네스 Stop hook 은 `dEitY719/dotfiles` 에 있다.
- **리포트 문자열은 hook 계약이다.** `gh-flow:issue complete (#<N>)` /
  `gh-flow:issue stopped at step <i>/6` 는 Stop guard 가 파싱하는 종료 마커다.
- **CI 실패는 해결하지 않는다.** 갓 만든 PR 은 체크가 아직 보고되지 않았다. `$HOME/dotfiles`
  의 `origin` 이 아닌 remote 에는 자동 CI-fail 재처리 트리거가 아예 없으므로
  `/gh-pr:merge-train <remote>` 를 직접 돌려야 한다 (#1610).
- **머지하지 않는다.** 리뷰와 머지는 사람 몫이다.
