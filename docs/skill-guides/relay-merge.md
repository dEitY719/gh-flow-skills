# gh-flow:relay-merge 스킬 가이드

## 한 줄 요약

커밋 범위 하나를 받아, push 가 실제로 되면 **평범한 PR** 을, 프록시로 막혀 있으면 **커밋당
gist 패치 + 목적지 이슈에 붙은 `git am` apply-guide 코멘트**를 산출한다.

## 언제 쓰고, 언제 안 쓰는가

| 상황 | 선택 |
|---|---|
| 격리된 `origin`(사내 GHE)의 커밋을 별개 `upstream`(github.com)으로 넘겨야 하고, 네트워크가 **비대칭**이다 — `git fetch upstream` 은 되는데 `git push upstream` 이 프록시 403 으로 막힌다 | `gh-flow:relay-merge` — 이 스킬 |
| `git push upstream` 이 실제로 된다 | `gh-pr:create`. 어차피 이 스킬 Step 2 프로브가 감지해서 거기로 위임한다 |
| 두 remote 가 같은 호스트라 비대칭 차단이 없다 | 이 스킬은 불필요 |
| 이슈 번호에서 시작해 구현까지 함께 하고 싶다 | `gh-flow:issue-relay` (마지막에 이 스킬을 호출한다) |

## 호출 형식

```
/gh-flow:relay-merge <origin-PR#> [flags]
/gh-flow:relay-merge --commits <base>..<head> [flags]
/gh-flow:relay-merge -h | --help | help
```

입력은 위치 인자 `<origin-PR#>` **또는** `--commits <base>..<head>` 중 하나다 — 둘 다 주면
하드 에러다.

| 인자 | 기본값 | 설명 |
|---|---|---|
| `<origin-PR#>` | — | 릴레이 payload 가 될 커밋 범위를 가진 `origin` PR (머지됐든 열려 있든) |
| `--commits <base>..<head>` | — | PR 조회를 건너뛰고 git 범위를 직접 릴레이. git 표준 의미 — `base` 제외, `head` 포함 |
| `--remote <name-or-URL>` | `upstream` | 목적지 remote. 이름 또는 raw URL |
| `--target-issue <N>` | 새 이슈 | apply-guide 를 새 이슈 대신 기존 이슈/PR 에 게시 |
| `--known-failures <entries>` | 없음 | `<path>[::<test-or-check>]` 쉼표 목록. origin 쪽에서 이미 확인된 무관한 기존 실패를 apply-guide 의 해당 섹션에 그대로 렌더 |
| `--generated-patterns <globs>` | 내장 목록 | 초과 패치에서 벗겨낼 생성 산출물 glob 목록 |

## 동작 단계

| 단계 | 하는 일 |
|---|---|
| 1 | 두 입력 모드 중 하나로 범위 확정. `--remote` 해석(없으면 하드 에러, `origin` 폴백 금지), 도달 가능성 확인. `SOURCE_REPO`/`SOURCE_HOST` 와 `DEST_REPO`/`DEST_HOST` 를 각각 remote URL **하나씩**에서 바인딩 |
| 2 | **push 가능성 프로브** — dry-run 이 아닌 실제 throwaway ref push, 성공 시 즉시 ref 삭제. push 가 되면 `gh-pr:create` 로 위임하고 **정지**. 403/block-page 로 차단이 확인될 때만 Step 3 으로. 일시적/불명확이면 짧은 백오프 후 1회 재시도, 그래도 불명확하면 not-blocked 로 보고 SIMPLE PATH |
| 3 | base/head SHA 확정 + 목적지 divergence pre-flight. **두 입력 모드 모두에서** 실행 |
| 4 | 커밋당 `git format-patch`. 초과분 중 생성 산출물이 본체면 그 diff 를 빼고 재생성(재생성 명령을 기록), 산출물이 아닌 초과 커밋은 파일 그룹 단위로 사전 분할 |
| 5 | 패치를 단일 파일 `gh gist create` 로 **순차** 업로드. 실패 시 즉시 정지 |
| 6 | apply-guide 코멘트 게시 — gist 표 + `git am` 절차 + 재생성 명령 + `--known-failures` 섹션 |
| 7 | (선택) 명시적 확인이 있을 때만, 중복된 origin 쪽 추적 이슈를 상호참조 코멘트와 함께 close |
| 8 | 목적지 이슈/코멘트 URL, gist 개수, 분할 여부, SIMPLE PATH 였는지를 보고 |

## 상수 (조정 가능)

- `RELAY_PATCH_MAX_BYTES` = **40960** (40KB) — gist 파일당 안전 컷오프. 경험적으로 ~35KB 는
  known-good, ~62KB 는 known-bad 이고 그 사이에 확인된 안전선이 없어 보수적으로 40KB 를
  명명 상수로 고정했다. 자동 감지하지 않는다.
- 기본 `--generated-patterns`: `**/generated/**`, `**/*.generated.*`, `openapi.json`,
  `package-lock.json`, `*.lock`, `**/dist/**`, `**/build/**`.

## 주의사항 / 제약

- **릴레이는 폴백이지 기본이 아니다.** 항상 먼저 프로브한다 — 그냥 push 해보고 실패하면
  릴레이하는 순서가 아니다.
- **`origin` 으로 조용히 폴백하지 않는다.**
- **multi-file gist 를 만들지 않고, gist 업로드를 병렬로 돌리지 않는다.**
- **패치를 조용히 잘라내지 않는다.** 인식된 생성 산출물만 벗겨내고, 초과 커밋은 파일 그룹으로
  사전 분할한다. 단일 파일 하나의 diff 가 한계를 넘을 때만 스킬이 멈춘다.
- **origin 쪽 이슈를 명시적 확인 없이 close 하지 않는다.**
- **목적지 remote 에 history 를 rewrite 하지 않는다.**
- 두 호스트가 한 실행에 공존하므로 전역 `GH_HOST` 를 두지 않는다 — 모든 `gh` 호출이 자기
  쪽 호스트를 인라인으로 달고 나간다 (dEitY719/dotfiles#1403 / dEitY719/dotfiles#1407).
