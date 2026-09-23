---
name: waves
description: >-
  Run a set of GitHub issues in dependency waves: per wave, one worktree and
  one background worker per issue carry it through gh-flow:issue to
  gh-pr:merge, then a serial gh-verify:live barrier. Use for /gh-flow:waves,
  "이슈들 의존성 웨이브로 병렬 처리", "순서 있는 건 나눠서 병렬로 구현하고 머지",
  "run these issues in parallel waves". One issue is gh-flow:issue; a serial
  backlog drain is gh-flow:drain.
license: MIT
allowed-tools: Bash, Read, Grep, Skill, Agent
compatibility:
  network: required
metadata:
  model_recommendation:
    tier: opus
    reason: "dependency planning, parallel worker dispatch, per-wave live barrier and re-planning judgment"
    claude: prefer
    non_claude: advisory-only
---

# gh-flow:waves — 의존성 웨이브 병렬 조율

## Role

이슈 집합을 **의존성 웨이브**로 편성하고, 웨이브 안에서는 이슈 1건 = worktree 1개 =
워커 1개로 병렬 실행한 뒤, 웨이브가 끝날 때마다 **검증 장벽**(main pull → 앱 재기동 →
PR 별 `gh-verify:live`)을 치고 대상을 재조회해 다음 웨이브로 간다. 새 로직은
**편성 · 병렬 · 장벽** 셋뿐이고 나머지는 원자 스킬 호출이다.
**전제조건**: 조율자는 저장소의 **main 체크아웃**(기본 브랜치)에서 돈다 — worktree 는 워커 몫.

**조율자는 `gh-flow:issue` 를 절대 직접 부르지 않는다** — `--help` 조회로도 부르지 않는다
(NF-1; stop guard 가 그 호출을 체인 시작으로 센다). 도움말이 필요하면
`../issue/references/help.md` 를 `Read` 한다.

## Step 1: Parse Args + Bind Target

`/gh-flow:waves [remote] [--from N] [--label L] [--issues 1,2,3] [--track N]
[--max-parallel 4] [--run "<cmd>"] [--bootstrap "<cmd>"] [--no-live] [--no-merge]`.
`-h`/`--help`/`help` 는 `references/help.md` 를 **그대로 출력하고 정지** — API 호출 없음.
인자 표와 기본값: `references/help.md`.

**대상 바인딩** — `../issue/references/target-binding.md` 의 **bash 블록만** 그대로 쓴다
(복사 금지, 같은 모양: `$CLAUDE_PLUGIN_ROOT` 를 가드하고 `[ -f ]` 로 파일을 증명한 뒤
`skills/issue/lib/target-binding.sh` 를 source — 기본값을 경로에 끼우는 형태 금지).
모든 `gh` 호출은 `GH_HOST="$TARGET_HOST" gh ... --repo "$TARGET_REPO"` (또는 `-R`).
없는 remote 는 `origin` 으로 떨어지지 말고 `git remote -v` 를 출력하고 정지한다.

## Step 2: Plan

대상 조회 → 이미 머지된 범위 확인(main 대조) → 명시 의존성 + 파일 겹침으로 웨이브 편성
→ 계획 표를 추적 이슈 코멘트로 기록. 조회 명령, 의존성 문구 목록, 에픽 판정, 순환 처리,
`--max-parallel` 분할, 추적 이슈 선택, **재개 규칙**: `references/plan.md` — 편성 전에 읽는다.
대상 조회 실패는 웨이브를 시작하지 않고 정지한다.

## Step 3: Wave Loop

웨이브 1개는 다섯 단계다. 단계 사이에 사용자 확인을 묻지 않는다(무인 기본).

1. **spawn** — 이슈마다 `Skill(session:worktree-spawn, "--task <slug>")` 1회, 출력된
   `Path:` 를 기록하고 조율자는 main 체크아웃에 남는다. 부트스트랩은 `--bootstrap` >
   `.claude/gh-flow-waves.sh` > 없음 순 — 스킬에 하드코딩 금지. 상세: `references/plan.md`.
2. **dispatch** — 이슈마다 백그라운드 `Agent`(model `opus`) **정확히 1개**, 프롬프트는
   `references/worker-brief.md` 템플릿을 채운 것. 한 worktree 에 워커 둘 금지(NF-2).
3. **collect** — 워커 완료 **알림**을 기다린다. 폴링·sleep 루프 금지. 워커 보고를 그대로
   믿지 않고 `mergeCommit.oid` 로 머지를 직접 확인한다(NF-3): `references/barrier.md`.
4. **barrier** — 그 웨이브의 모든 워커가 보고한 뒤에만: `git pull --ff-only` →
   `--run` → PR 별 `Skill(gh-verify:live, "<PR>")` **직렬**(NF-4). live 실패는
   `Skill(gh-issue:issue-create, "--no-ask ...")` 로 이슈화. 절차·SKIP 규칙: `references/barrier.md`.
5. **requery** — 대상을 다시 조회한다. 새 이슈나 바뀐 의존성이 있으면 Step 2 로 재계획하고
   새 계획 코멘트를 남긴다(pitfall 7). 없으면 다음 웨이브.

한 워커의 실패는 그 이슈만 `[FAIL]` + 이슈 코멘트로 끝나고 웨이브의 나머지는 계속된다.
실패한 선행을 기다리는 후행 이슈는 미루고 drain 의 `../drain/references/blocked.md`
형식으로 사유를 코멘트한다(복사 금지, 참조만).

## Step 4: Merge Policy

**조율자는 머지하지 않는다.** 워커가 `Skill(gh-pr:merge, ...)` 에만 위임하고 그 승인·
보호 게이트가 그대로 적용된다. raw `gh` 머지 명령 대체 경로는 없고 `gh-pr:merge-emergency`
는 어떤 경로로도 호출하지 않는다. `gh-pr:merge` 가 거절하면 그 이슈는 `[FAIL] not merged`,
PR 은 사람 판단으로 남는다. `--no-merge` 면 PR 까지만 만들고 장벽의 live 는 `[SKIP]`.

## Step 5: Close Epics + Report

자식이 모두 닫힌 에픽만 닫는다(`references/plan.md`). 웨이브마다 한 표, 종료 시 최종 표
(이슈 → PR → mergeCommit → live) + `Next:` 한 줄: `references/report-template.md`.
보고는 평문 어시스턴트 텍스트 — `Bash` heredoc 이나 `Write` 금지.

## Constraints

`references/constraints.md`: 조율자 NF-1, 워커 1개/worktree, oid 판정, 직렬 live,
상태는 GitHub 에만, 웨이브 표는 최종 답이 아니다, 이연 항목 승격(drain 참조).

## Related Skills

워커가 부르는 것: `gh-flow:issue` · `gh-pr:reply` · `gh-resolve:{ci-fail,outdated,conflict}` ·
`gh-pr:merge`. 조율자가 부르는 것: `session:worktree-spawn` · `gh-verify:live` ·
`gh-issue:issue-create`. 직렬 사촌: `gh-flow:drain`.
