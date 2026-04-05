---
name: ci:flaky
description: 최근 CI 실행에서 플레이키 테스트 후보를 찾습니다 (flaky-test-hunter 에이전트 호출)
type: slash-command
category: ci
follows-standards:
  - standards/CLAUDE.md
  - standards/testing/testing-guidelines.md
enforcement: required
---

# 플레이키 테스트 탐지

> ⚠️ **Standards 준수 필수**
> @standards/CLAUDE.md · @standards/testing/testing-guidelines.md

`flaky-test-hunter` 서브에이전트에 위임합니다. 이 파일은 얇은 래퍼입니다.

## Step 1: 사전 조건
- `gh` CLI 가 설치·인증되어 있어야 합니다 (`gh auth status`).
- 현재 디렉토리가 GitHub 레포여야 합니다.

## Step 2: 에이전트 호출
`flaky-test-hunter` 서브에이전트를 호출하고, `$ARGUMENTS` 를 다음 변수로 전달:
- `LIMIT` (기본 50) — 조회할 최근 run 수
- `BRANCH` (기본 main) — 기준 브랜치

## Step 3: 결과 후처리
에이전트의 출력을 그대로 표시하고, 마지막에 "다음 단계" 블록 추가:

```markdown
## 다음 단계
- Top 1 후보만 먼저 수정: `/dev:reproduce <테스트 이름>`
- 격리 실행: `<testrunner> <file> --repeat 20`
- 원인 확정 후 PR: `/ci:pr-enhance`
```

**금지**: 에이전트 결과를 재판단하거나 임의로 요약 축소하지 말 것. 에이전트 출력이 SSOT.
