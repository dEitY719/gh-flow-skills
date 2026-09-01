# relay-merge 사용 결과

> **한 줄 요약** — 커밋 범위를 받아 gist 패치와 `git am` apply-guide 코멘트를 생성합니다.

```
커밋 범위 (base..head)  ──▶  /gh-flow:relay-merge  ──▶  gist 패치 + apply-guide 코멘트
```

## 1. 실행한 명령

범용 형식: `/gh-flow:relay-merge <origin-PR#> | --commits <base>..<head> [flags]`

이번에 실제로 실행한 것 — help 경로와 Step 1 의 목적지 remote 해석:

```
/gh-flow:relay-merge -h
git remote -v
git remote get-url upstream     # Step 1: 기본 --remote 해석
```

## 2. 입력

- `skills/relay-merge/references/help.md` (101줄, 5,798바이트) — `-h` 가 verbatim 출력하는 파일. API 호출 없음.
- 이 worktree 에 등록된 remote 목록.

## 3. 결과

Step 1 목적지 해석에서 정지:

```
$ git remote -v
origin  git@github.com:dEitY719/gh-flow-skills.git (fetch)
origin  git@github.com:dEitY719/gh-flow-skills.git (push)
$ git remote get-url upstream
error: No such remote 'upstream'   (exit 2)
```

`upstream` 이 없고 명시적 `--remote` 도 없으므로 계약대로 하드 에러로 정지했다 —
`origin` 폴백은 일어나지 않는다. Step 2 의 push 가능성 프로브에는 도달하지 않았다.

Step 2 프로브는 실제 throwaway ref 를 목적지에 push 하고, Step 5~6 은 gist 를 만들고
목적지 이슈에 코멘트를 단다. 모두 외부 쓰기이므로 이 문서 범위 밖이다.

가이드: [`../skill-guides/relay-merge.md`](../skill-guides/relay-merge.md)
