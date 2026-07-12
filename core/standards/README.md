# Standards

> 프로젝트 공통 표준 및 가이드라인 — **개발 / 기획 / 프로덕트 / 경영 / AI** 5도메인 + 철학.

## 문서 목록

### 🧭 철학 (Philosophy)

| 문서 | 설명 |
|------|------|
| [philosophy.md](philosophy.md) | **제작자 철학 — 모든 표준의 최종 심판 기준. 포크 시 이 파일만 교체** |

### 🛠 개발 (Engineering)

| 문서 | 설명 |
|------|------|
| [hard-won-conventions.md](hard-won-conventions.md) | **실사고에서 배운 edge 관례(해자). 일반 표준보다 우선** |
| [coding/coding-guidelines.md](coding/coding-guidelines.md) | 언어별 스타일, Clean Architecture, 조건문 패턴 |
| [testing/testing-guidelines.md](testing/testing-guidelines.md) | 테스트 프레임워크, AAA/BDD, Mocking |
| [api/api-design.md](api/api-design.md) | REST API 설계 원칙, 보안, DDD 매핑 |
| [writing/commit-message.md](writing/commit-message.md) | 커밋 메시지 형식·type·AI 에이전트 커밋 규칙 |
| [writing/ai-attribution.md](writing/ai-attribution.md) | AI 협업 표기 (커밋 외 코멘트·문서·PR 글) |
| [templates/adr-template.md](templates/adr-template.md) | ADR 작성 템플릿 |

### 📐 기획 (Planning)

| 문서 | 설명 |
|------|------|
| [planning/prd-guidelines.md](planning/prd-guidelines.md) | 1-페이지 PRD 형식, Out of Scope, 롤백 기준 |

### 🎯 프로덕트 (Product)

| 문서 | 설명 |
|------|------|
| [product/metrics.md](product/metrics.md) | North Star / Goal / Guardrail, 활성화·리텐션 정의 |

### 🏢 경영 (Management)

회사 레벨 가로지르는 규칙 — 1인 창업 기준으로 최소 3개.

| 문서 | 설명 |
|------|------|
| [management/security.md](management/security.md) | 시크릿, 의존성, 로그, 사고 대응 |
| [management/decision-log.md](management/decision-log.md) | ADR 프로세스 |

### 🤖 AI (AI Collaboration)

| 문서 | 설명 |
|------|------|
| [ai/agent-workflow.md](ai/agent-workflow.md) | 위임 원칙, 검증 게이트, 백그라운드 에이전트 운영 |
| [ai/ai-usage.md](ai/ai-usage.md) | Claude·외부 AI 전송 가능 데이터 경계, 프롬프트 인젝션 방어 |

## 사용 방법

- **자동 로드**: Claude Code 세션 시작 시 `core/CLAUDE.md` → `core/standards/CLAUDE.md` 체인으로 자동 로드됩니다.
- **프로젝트별 확장**: 프로젝트 루트 `CLAUDE.md` 에서 공통 표준을 `@standards/...` 로 참조하고, 프로젝트 전용 규칙만 추가 작성.

## 확장 원칙

1. **1인 기준 최소 유지** — 지금 필요하지 않은 표준은 만들지 않습니다.
2. **5도메인 경계 유지** — 새 문서는 engineering / planning / product / management / ai 중 하나로 귀속.
3. **1페이지 선호** — 스크롤이 필요하면 분할 신호.
4. **체크리스트 필수** — 모든 가이드는 마지막에 실행 체크리스트 포함.

---

**최종 업데이트**: 2026-07-12
