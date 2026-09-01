# issue-relay 사용 결과

> **한 줄 요약** — push 차단된 remote 의 이슈 번호를 받아 브랜치·검증된 커밋·릴레이 인계를 생성합니다.

```
이슈 번호 (#N) + 차단된 remote  ──▶  /gh-flow:issue-relay  ──▶  apply-guide 코멘트 (또는 PR)
```

## 1. 실행한 명령

범용 형식: `/gh-flow:issue-relay <issue-number> [--remote <name>] [--base <branch>]`

이번에 실제로 실행한 것 — help 경로와 Step 2 의 목적지 remote 해석:

```
/gh-flow:issue-relay -h
git remote -v
git remote get-url upstream     # Step 2: 기본 --remote 해석
```

## 2. 입력

- `skills/issue-relay/references/help.md` (79줄, 3,979바이트) — `-h` 가 verbatim 출력하는 파일. API 호출 없음.
- 이 worktree 에 등록된 remote 목록.

## 3. 결과

Step 2 목적지 해석에서 정지:

```
$ git remote -v
origin  git@github.com:dEitY719/gh-flow-skills.git (fetch)
origin  git@github.com:dEitY719/gh-flow-skills.git (push)
$ git remote get-url upstream
error: No such remote 'upstream'   (exit 2)
```

기본 `--remote upstream` 이 존재하지 않는다. 계약상 **`origin` 으로 폴백하지 않고 하드
에러로 정지**하는 지점이며, Step 3 의 Worker 위임에는 도달하지 않는다.

Step 3~6(구현 위임 · Advisor 검증 · `gh-flow:relay-merge` 호출)은 커밋과 gist 게시를
수반하므로 이 문서 범위 밖이다.

가이드: [`../skill-guides/issue-relay.md`](../skill-guides/issue-relay.md)
