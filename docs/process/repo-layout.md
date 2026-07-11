# 레포 레이아웃 — core / humans / docs 경계

> claude-cockpit 파일을 어디에 둘지 헷갈릴 때 보는 단일 기준. **트리거(어떻게 활성화되는가)** 로 나눈다.

## 3분할 (트리거 기준)

| 디렉토리 | 무엇 | 트리거 | 바꾸면 |
|----------|------|--------|--------|
| **core/** | 규범·기계 (`standards`, `hooks`, `mcp-shared`, `memory-seed`) | **자동** — 세션 시작 시 로드되거나 훅/스크립트로 실행 | 시스템 동작이 즉시 바뀜 |
| **humans/** | 사람이 부르는 확장 (`skills`=슬래시 커맨드, `subagents`=에이전트) | **명시 호출** — `/command`, 에이전트 호출 | 능력이 생기거나 사라짐 |
| **docs/** | 참조·기록·가이드 (`dev`, `process`, `writing`, `examples`) | **참조** — 사람이 읽거나 `@docs/...` 온디맨드 | 지식만 갱신, 동작 불변 |

> 한 줄: **core = 자동 강제 · humans = 호출 능력 · docs = 읽는 지식.**

## 결정 테스트 (파일 하나를 어디에?)

1. 매 세션 자동 로드되어 Claude 행동을 규정하나? → `core/standards/`
2. 훅·스크립트로 실행되나? → `core/{hooks,mcp-shared,memory-seed}`
3. 슬래시 커맨드나 에이전트로 **사람이 호출**하나? → `humans/{skills,subagents}`
4. 그 외(설명·프로세스·작성 가이드·예시·기록)인가? → `docs/`

## 중요한 제약: `core/standards/` 는 프로젝트로 배포된다

`core/standards/` 는 소비 프로젝트에 **`docs/standards/` (git submodule)** 로 마운트된다. 따라서:

- standards 안의 것은 **모든 프로젝트가 함께 받는다** (coding/testing/api/security 규칙 + templates).
- **여기서 파일을 빼면 프로젝트가 받는 표준이 바뀐다** — 이동은 신중히, 참조 경로(`@standards/...`)를 전수 갱신할 것.

## 회색지대와 해소

| 항목 | 성격 | 결론 |
|------|------|------|
| `core/standards/templates/` (`adr-template`, `CLAUDE.md.template`) | 산출물 골격(= docs 성격)이지만 **프로젝트로 배포되어야 함** | **core/standards 에 유지.** 단 **자동 로드하지 말고 온디맨드 참조** — 빈 템플릿을 매 세션 로드할 이유가 없다 |
| `docs/writing/*-guide.md` (commit / adr / doc-style / korean-tone) | 작성 시 참조하는 가이드 | **docs/writing 유지.** 항상 강제할 짧은 규칙이 생기면 그 **요약만** `core/standards` 로 승격(상세 튜토리얼은 docs) |

## 원칙 한 줄

> **"안 읽어도 규칙을 어기면 안 되는가?"** → 예면 **core**(강제).
> **"뭔가 만들 때 펼쳐보는 것"** → **docs**(참조).
> **"사람이 불러서 실행"** → **humans**.

---

**버전**: 1.0.0 | **최종 업데이트**: 2026-07-05
