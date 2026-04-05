---
name: ci:pr-enhance
description: 현재 브랜치 변경사항 자동 점검 및 PR 설명 초안 생성
type: slash-command
category: ci
follows-standards:
  - standards/CLAUDE.md
  - standards/coding/coding-guidelines.md
  - standards/testing/testing-guidelines.md
enforcement: required
---

# PR 리뷰 및 품질 향상

> ⚠️ **Standards 준수 필수** — 점검 항목은 standards 문서를 우선 참고합니다.
> @standards/coding/coding-guidelines.md · @standards/testing/testing-guidelines.md · @standards/api/api-design.md

현재 브랜치의 변경사항을 분석하여 PR 설명을 생성하고 품질 점검을 수행합니다.

$ARGUMENTS
- 인자가 **브랜치명**이면 → 해당 브랜치를 base로 사용
- 인자가 없으면 → 기본 브랜치 자동 감지 (`git symbolic-ref refs/remotes/origin/HEAD` 또는 main/master 순)

## 절차

### 1. 변경사항 분석
- `git log <base>..HEAD --oneline`
- `git diff <base>...HEAD --stat`
- `git diff <base>...HEAD`

### 2. 자동 점검

**필수 점검**
- 디버깅 코드 잔존 (console.log, println, debugger, TODO/FIXME)
- 하드코딩된 값 (시크릿, URL, 매직 넘버)
- 에러 핸들링 누락
- 테스트 커버리지 (새 코드에 대한 테스트 존재 여부)

**아키텍처 점검**
- 의존성 방향 위반 (domain → infrastructure 등)
- 계층 간 책임 혼재
- API 변경 시 하위 호환성

**보안 점검**
- SQL injection, XSS 가능성
- 인증/인가 누락
- 민감 데이터 로깅

### 3. 위험도 평가

| 기준 | Low | Medium | High |
|------|-----|--------|------|
| 변경 파일 수 | <5 | 5-15 | >15 |
| 변경 줄 수 | <100 | 100-500 | >500 |
| 인프라/설정 변경 | 없음 | 일부 | 핵심 |
| API 변경 | 없음 | 하위호환 | 브레이킹 |
| 보안 관련 코드 | 없음 | 간접 | 직접 |

### 4. PR 분할 제안

변경 파일 20개 초과 또는 변경 줄 수 1000줄 초과 시, 논리적 단위로 분할 방안을 제안합니다.

## 출력 형식

```markdown
## PR 분석 결과

### 요약
- **변경 규모**: X files, +Y/-Z lines
- **위험도**: [Low/Medium/High]
- **예상 리뷰 시간**: ~N분

### 점검 결과
| 항목 | 상태 | 상세 |

### 발견된 문제
(파일 경로, 줄 번호, 설명, 수정 제안)

### PR 설명 초안
## Summary
## What Changed
## Why
## Test Plan
## Checklist
```
