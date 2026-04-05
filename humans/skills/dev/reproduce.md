---
name: dev:reproduce
description: 버그 리포트를 최소 재현 테스트로 변환
type: slash-command
category: dev
follows-standards:
  - standards/CLAUDE.md
  - standards/testing/testing-guidelines.md
enforcement: required
---

# dev:reproduce — 버그 → 최소 재현 테스트

> ⚠️ **Standards 준수 필수**
> @standards/CLAUDE.md · @standards/testing/testing-guidelines.md

버그 리포트(이슈 본문, Slack 메시지, Sentry 스택)를 입력 받아 **실행 가능한 최소 재현 테스트**를 작성합니다. 수정은 하지 않습니다 — 재현만.

$ARGUMENTS
- 이슈 번호: `gh issue view N` 로 본문 자동 조회
- 자유 텍스트: 그대로 증상 기술
- Sentry 이슈 URL: WebFetch 로 스택 조회

## Step 1: 증상 정리
입력을 **증상 / 기대 동작 / 실제 동작 / 환경**으로 정규화합니다. 빠진 정보가 있으면 "?" 로 표시하고 테스트에 TODO 주석으로 남깁니다.

## Step 2: 재현 지점 특정
- 스택 트레이스가 있으면 가장 위 애플리케이션 프레임의 파일:라인 부터
- 없으면 에러 메시지를 `Grep` 으로 검색 (최대 3개 후보)
- 테스트 파일 위치 추정 (같은 디렉토리의 `*.test.*` 또는 `tests/` 대칭 경로)

## Step 3: 최소 재현 테스트 작성
원칙:
- **한 가지만 주장** (AAA 패턴, Act 1줄 목표)
- 외부 의존성 최소화 (DB/네트워크는 가능하면 in-memory 또는 mock)
- **실패하는 상태로 커밋** 가능해야 함 (red → green 확인 가능)
- 테스트 이름은 `test_<버그>_reproduces_<증상>` 또는 `it("reproduces #<issue>")`
- 파일 경로는 기존 디렉토리 컨벤션 준수 (이웃 테스트 1개 먼저 읽기)

## Step 4: 실행 확인
생성 즉시 해당 테스트만 실행해서 **실패**하는지 확인:
```bash
# 예: vitest / pytest / go test
vitest run path/to/file.test.ts -t "reproduces"
```

실패 메시지가 리포트의 증상과 일치하면 재현 성공.

## Step 5: 출력

```markdown
## 재현 테스트 작성 완료

- **버그**: [1줄]
- **재현 위치**: `src/foo/bar.ts:88`
- **테스트 파일**: `src/foo/bar.test.ts` (신규 it 블록)
- **실행 결과**: 🔴 FAIL — "expected 200, got 500"

### 다음 단계
- 원인 분석: `/review:code src/foo/bar.ts`
- 수정 후 이 테스트가 🟢 로 바뀌어야 완료
```

**금지 사항**: 수정 커밋, 버그 픽스. 이 스킬은 오직 "실패하는 테스트를 남기는 것" 까지입니다.
