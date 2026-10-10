---
name: wave
# Check 16: the last sentence is load-bearing — one letter from gh-flow:waves, so it names the split
description: >-
  Carry one GitHub issue through gh-flow:issue, gh-pr:merge and a fresh-clone
  gh-verify:merged, then only its descendants (open issues marked
  "Spawned-from: #<N>"), serially, depth- and count-capped. Use for
  /gh-flow:wave, "이 이슈 하나 머지하고 검증까지, 파생 이슈만 이어서",
  "carry this issue and its follow-ups to merged". One issue + its
  descendants; a set of issues in dependency waves is gh-flow:waves.
license: MIT
allowed-tools: Bash, Read, Grep, Skill, Agent
compatibility:
  network: required
metadata:
  model_recommendation:
    tier: opus
    reason: "serial descendant-queue loop, per-issue worker dispatch, oid judgment and fresh-clone verify triage"
    claude: prefer
    non_claude: advisory-only
---

# gh-flow:wave — 이슈 1건 + 자손 트리, 직렬

## Role

이슈 **1건**을 `gh-flow:issue` → `gh-pr:merge` → `gh-verify:merged`(머지 커밋 fresh clone 재검증)
까지 보내고, 그 과정에서 파생된 **자손 이슈만**(본문에 `Spawned-from: #<부모>` 마커) 같은
파이프라인으로 다시 처리한다. 레포의 다른 열린 이슈는 절대 건드리지 않는다. `gh-flow:waves`
의 "단일 이슈 + 자손 트리 · 직렬 · fresh-clone 검증" 판이다 — 이슈 집합의 의존성 웨이브 ·
병렬 · live 장벽은 `waves` 몫이다. 새 로직은 **자손 큐 · 상한** 둘뿐이고 나머지는 원자 스킬 호출이다.
**전제조건**: 조율자는 저장소의 **main 체크아웃**(기본 브랜치)에서 돈다 — worktree 는 워커 몫.
**gh-flow 플러그인 전체 설치** 필수(#47).

**조율자는 `gh-flow:issue` 를 절대 직접 부르지 않는다** — `--help` 조회로도 부르지 않는다
(NF-1; stop guard 가 그 호출을 체인 시작으로 센다, #39). 도움말은 `gh-flow:issue` 의 `references/help.md` 를 `Read`.

## Step 1: Parse Args + Bind Target

`/gh-flow:wave <issue-number|issue-url> [remote] [--max-depth 3] [--max-issues 10] [--no-merge] [--no-verify]`.
`-h`/`--help`/`help` 는 `references/help.md` 를 **그대로 출력하고 정지** — API 호출 없음.

**대상 바인딩** — `gh-flow:issue` 의 `references/target-binding.md` 의 **bash 블록만** 그대로 쓴다
(복사 금지, SSOT). 모든 `gh` 호출은 `GH_HOST="$TARGET_HOST" gh ... --repo "$TARGET_REPO"`.
없는 remote 는 `origin` 으로 떨어지지 말고 `git remote -v` 를 출력하고 정지한다. 이슈 URL 의
host/repo 가 바인딩과 다르면 둘 다 출력하고 정지한다. 형제 스킬 파일(`target-binding.md`/`.sh`,
`waves`·`drain` 의 references)이 없으면 `gh-flow:wave stopped — gh-flow plugin incomplete (<missing path>)`.

## Step 2: Queue Loop (BFS, 직렬)

큐 = `[(ROOT, depth 0)]`. 반복은 **내부 큐 루프**다 — `Skill(gh-flow:wave, ...)` 재귀 자기호출 금지.
이슈 1건마다 아래 다섯 단계, 단계 사이에 사용자 확인을 묻지 않는다(무인 기본).
루트가 이미 닫혀 있으면 1~4 를 건너뛰고 5 만 한다 — 자손이 없으면 `complete`.

1. **spawn** — `git fetch <remote> <base>` 후 `Skill(session:worktree-spawn, "--task issue-<N> --base <remote>/<base>")`
   1회. `Path:` 를 기록하고 조율자는 main 체크아웃에 남는다(`cd` 를 따라가지 않는다).
   직전 머지가 반영된 base 에서 시작하려는 것이다. 절차: `gh-flow:waves` 의 `references/plan.md` §7.
2. **dispatch** — 백그라운드 `Agent`(model `opus`) **정확히 1개**. 프롬프트는 `gh-flow:waves` 의
   `references/worker-brief.md` 템플릿을 채운 것 — wave 의 채움·차이(계보 마커 지시 포함):
   `references/lineage.md`. 한 worktree 에 워커 둘 금지(NF-2).
3. **collect** — 완료 **알림**을 기다린다(폴링·sleep 금지). 워커 보고를 믿지 않고
   `mergeCommit.oid` 로 머지를 직접 확인한다(NF-3) — 절차는 `gh-flow:waves` 의 `references/barrier.md` "Collect".
4. **verify** — 머지된 PR 마다 `Skill(gh-verify:merged, "<PR>")`. 실패는
   `Skill(gh-issue:issue-create, "--no-ask ...")` 로 이슈화하되 본문에 `Spawned-from: #<N>` 한 줄
   (F-5) — 그 이슈는 자손으로 큐에 들어간다. `--no-verify`/`--no-merge` 면 `[SKIP]`.
5. **descend** — `Spawned-from: #<N>` 마커를 가진 이슈만 조회해 큐에 넣는다(닫힌 것은 통과만). 조회 명령,
   정확한 줄 매칭, 순환 처리, 재개 규칙: `references/lineage.md` — 첫 조회 전에 읽는다.
   조회 실패는 정지한다(상태를 모른 채 진행 금지).

**상한** — 자식 깊이가 `--max-depth` 를 넘거나 처리 수가 `--max-issues` 에 닿으면 그 이슈는
처리하지 않고 overflow 로 모아 최종 `Next:` 에 번호로 나열한다(F-7).

**실패 전파** — 워커 실패나 `gh-pr:merge` 거절은 그 이슈만 `[FAIL]` + 이슈 코멘트로 끝난다.
그 이슈의 자손은 처리하지 않고 `gh-flow:drain` 의 `references/blocked.md` 3단 형식으로 사유를
코멘트한다(참조만). 형제 자손은 계속 처리한다.

## Step 3: Merge Policy

**조율자는 머지하지 않는다.** 워커가 `Skill(gh-pr:merge, ...)` 에만 위임하고 그 승인·보호
게이트가 그대로 적용된다. raw `gh` 머지 명령 대체 경로는 없고 `gh-pr:merge-emergency` 는
어떤 경로로도 호출하지 않는다. 거절은 `[FAIL] not merged`, PR 은 사람 판단으로 남는다.
`--no-merge` 면 PR 까지만 만들고 verify 는 `[SKIP]`.

## Step 4: Report

종료 시 트리 표(부모 → 자식) × PR → mergeCommit → merged-verify + `Next:` 한 줄(overflow ·
실패 이슈): `references/report-template.md`. 마지막은 `gh-flow:wave complete` 또는
`gh-flow:wave stopped —` (훅 계약). 평문 어시스턴트 텍스트 — `Bash` heredoc 이나 `Write` 금지.

## Constraints

`references/constraints.md`: 조율자 NF-1, 워커 1개/worktree, oid 판정, 머지 위임, 마커 자손만,
상한, 마커 이슈 생성 실패는 치명, 상태는 GitHub 에만, 이연 항목 승격(drain 참조), 플러그인 전체 설치.

## Related Skills

워커가 부르는 것: `gh-flow:issue` · `gh-pr:reply` · `gh-resolve:{ci-fail,outdated,conflict}` ·
`gh-pr:merge`. 조율자가 부르는 것: `session:worktree-spawn` · `gh-verify:merged` ·
`gh-issue:issue-create`. 이슈 집합 · 병렬 · live 장벽: `gh-flow:waves`. 백로그 전체: `gh-flow:drain`.
