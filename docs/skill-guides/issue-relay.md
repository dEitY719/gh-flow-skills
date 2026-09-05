# gh-flow:issue-relay 스킬 가이드

## 한 줄 요약

push 로 막힌 목적지 remote 에 **이미 등록된** 이슈 1건을 받아, 로컬 feature 브랜치와 검증된
커밋들, 그리고 그 커밋을 목적지에 적용할 수 있는 **`git am` apply-guide 코멘트**(또는 push 가
멀쩡하면 그냥 PR)를 산출한다.

## 언제 쓰고, 언제 안 쓰는가

| 상황 | 선택 |
|---|---|
| 이슈가 push 차단된 목적지 remote 에 이미 있고, "브랜치 → 구현 → 검증 → 릴레이" 루프를 한 번에 돌리고 싶다 | `gh-flow:issue-relay` — 이 스킬 |
| 이슈가 아직 등록되지 않았다 | 먼저 `gh-issue:create <remote>` |
| `git push <remote>` 가 실제로 동작한다 | `gh-flow:issue` (또는 원자 스킬들). 이 스킬의 가치는 끝단의 릴레이 인계뿐이다 |
| 커밋 범위가 이미 준비되어 있고 릴레이만 필요하다 | `gh-flow:relay-merge --commits <base>..<head>` 를 직접 호출 |

## 호출 형식

```
/gh-flow:issue-relay <issue-number> [--remote <name>] [--base <branch>]
/gh-flow:issue-relay -h | --help | help
```

| 인자 | 기본값 | 설명 |
|---|---|---|
| `<issue-number>` | — | 목적지 remote 에 이미 등록된 이슈 번호 (양의 정수) |
| `--remote <name>` | `upstream` | 목적지 remote. 끝에서 `gh-flow:relay-merge` 가 겨냥할 바로 그 remote |
| `--base <branch>` | 자동 감지 | 목적지 기본 브랜치 override (`git ls-remote --symref` 생략) |

## 동작 단계

Step 1 에서 인자를 파싱하고 `BASE_TS` 를 기록한다. Steps 2~5 는 순서대로, 각각 직전 단계가
성공했을 때만 실행된다 — 실패하면 즉시 체인을 멈추고 그 단계 고유의 안내를 낸다.

| 단계 | 참조 | 하는 일 |
|---|---|---|
| 2 | `references/branch-setup.md` | `--remote` 해석(없으면 하드 에러, `origin` 폴백 금지), `DEST_REPO`+`DEST_HOST` 를 그 remote URL 하나에서 바인딩, 목적지 기본 브랜치 감지 + fetch, `issue-<N>-<title-slug>` 브랜치 생성 또는 재사용 판단 |
| 3 | `references/worker-brief-checklist.md` | 이슈 본문·코멘트 수집, 미결 Open Questions 를 사용자와 먼저 해소, 자립적 브리프를 만들어 opus Worker 서브에이전트에 위임. 직전에 `BASE_SHA` 기록 |
| 4 | `references/verification.md` | Worker 의 완료 보고를 믿지 않고 Advisor 가 `git diff <BASE_SHA>..HEAD` 를 직접 읽고, 대상 레포의 lint/test 를 찾아 실행. 실패하면 브리프를 날카롭게 다듬어 재위임 |
| 5 | — | `HEAD_SHA` 기록 후 `Skill(gh-flow:relay-merge, "--commits <BASE_SHA>..<HEAD_SHA> --target-issue <N> --remote <remote> [--known-failures ...]")` 를 **그대로** 호출 |
| 6 | — | `gh-flow:relay-merge` 의 Step 8 출력을 그대로 중계 + 체인 전체의 `[OK]`/`[FAIL]` 1줄 + 다음 행동을 지목하는 `Next:` 줄 |

목적지는 구조상 `origin` 과 다른 호스트이므로 전역 `GH_HOST` 를 두지 않는다. 목적지 `gh`
호출은 전부 `GH_HOST="$DEST_HOST" gh ... --repo "$DEST_REPO"` 형태다 (dEitY719/dotfiles#1403 / dEitY719/dotfiles#1407).

## 주의사항 / 제약

- **`origin` 으로 폴백하지 않는다.** 요청한 `--remote` 가 없으면 하드 에러다.
- **이슈 등록은 범위 밖이다.** 목적지에 이슈가 없으면 `gh-issue:create <remote>` 를 먼저.
- **미결 Open Questions 가 남은 채로 구현을 위임하지 않는다.**
- **재사용 브랜치를 자동 reset 하지 않는다.** 목적지 기본 브랜치에 없는 고유 커밋이 있으면
  반드시 먼저 묻는다.
- **`gh-flow:relay-merge` 의 책임을 복제하지 않는다.** 패치 생성, 크기 컷오프, gist 업로드,
  apply-guide 게시는 전부 그 스킬 안에 있다.
- **목적지 remote 에 history 를 rewrite 하지 않는다.**
