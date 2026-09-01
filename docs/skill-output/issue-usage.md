# issue 사용 결과

> **한 줄 요약** — 이슈 번호 1건을 받아 리뷰 게이트를 통과한 열린 PR 을 생성합니다.

```
이슈 번호 (#N)  ──▶  /gh-flow:issue  ──▶  리뷰된 PR + [OK]/[FAIL] 리포트
```

## 1. 실행한 명령

범용 형식: `/gh-flow:issue <issue-number> [remote]`

이번에 실제로 실행한 것 — help 경로와 Step 1 타깃 바인딩, 그리고 Step 2.1 진입 검사:

```
/gh-flow:issue -h
git remote get-url origin
GH_HOST=github.com gh issue view 1 --repo dEitY719/gh-flow-skills --json number,title,state
```

## 2. 입력

- `skills/issue/references/help.md` (64줄, 4,796바이트) — `-h` 가 verbatim 출력하는 파일. API 호출 없음.
- `origin` = `git@github.com:dEitY719/gh-flow-skills.git` — Step 1 이 타깃을 바인딩하는 원본.

## 3. 결과

Step 1 이 바인딩한 실제 값:

```
TARGET_HOST=github.com
TARGET_REPO=dEitY719/gh-flow-skills
BRANCH=wt/feat/1
```

Step 2.1 진입 실패 — 바인딩된 타깃에 이슈가 하나도 없다:

```
$ gh issue view 1 --repo dEitY719/gh-flow-skills
GraphQL: Could not resolve to an issue or pull request with the number of 1. (repository.issue)
$ gh issue list --repo dEitY719/gh-flow-skills --state all --limit 10
(빈 출력, exit 0)
```

계약대로 첫 실패 지점에서 정지했다 — 재시도 없음, 이후 단계 자동 스킵. 전체 체인
(2.1~2.6)은 커밋·push·PR 개설을 수반하므로 이 문서 범위에서는 실행하지 않았다.

가이드: [`../skill-guides/issue.md`](../skill-guides/issue.md)
