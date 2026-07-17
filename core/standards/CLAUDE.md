# Standards

> 이 문서는 Claude Code 가 세션 시작 시 자동 로드합니다. 모든 작업은 아래 표준을 따릅니다.

표준은 **5개 도메인**(개발 / 기획 / 프로덕트 / 경영 / AI)으로 나뉩니다. 작업 성격에 맞는 표준만 필요하면 됩니다.

## 🧭 철학 (Philosophy) — 모든 표준의 최종 심판 기준

규칙끼리 충돌하면 이 문서가 이깁니다. 포크 시 이 파일만 교체하면 나머지 체계를 그대로 상속합니다.

- @philosophy.md — 우선순위(보안>재현성>생산성>깔끔함)·판단 원칙·운영 원칙·AI 원칙

## 🛠 개발 (Engineering)

모든 코드 작성·리뷰에 **필수 적용**.

- @hard-won-conventions.md — **실사고에서 배운 edge 관례. 일반 표준과 긴장하면 이쪽 우선.**
- @coding/coding-guidelines.md — 언어별 스타일, Clean Architecture, 조건문 패턴
- @engineering/reliability.md — **대규모(2000만↑) 전제의 신뢰성·확장성 기준** — 스케일 티어(prototype/production/hyperscale)·데이터 접근·회복탄력성·멱등성·관측성·launch-readiness
- @testing/testing-guidelines.md — 테스트 프레임워크, AAA/BDD, Mocking 전략
- @api/api-design.md — REST API 설계 원칙, 보안, DDD 매핑
- @writing/commit-message.md — 커밋 메시지 형식·type·AI 에이전트 커밋 규칙
- @writing/ai-attribution.md — AI 협업 표기 (커밋 외 코멘트·문서·PR 글)
- `templates/adr-template.md` — ADR 템플릿 (ADR 작성 시 참조 · 빈 골격이라 자동 로드하지 않고 온디맨드)

## 📐 기획 (Planning)

기능 스펙·요구사항 정리 작업 시 적용.

- @planning/prd-guidelines.md — 1-페이지 PRD 형식, In/Out of Scope, 롤백 기준

## 🎯 프로덕트 (Product)

지표 정의·리서치·전략 작업 시 적용.

- @product/metrics.md — North Star / Goal / Guardrail 프레임, 활성화·리텐션 정의

## 🏢 경영 (Management) — 회사 레벨 가로지르는 규칙

모든 프로젝트에 **공통 적용**.

- @management/security.md — 시크릿, 의존성, 로그, 사고 대응
- @management/decision-log.md — ADR 프로세스 (언제/어떻게 쓰는가)

## 🤖 AI (AI Collaboration)

AI 에이전트와 함께 일하는 모든 작업에 적용.

- @ai/agent-workflow.md — 위임 원칙, 검증 게이트, 백그라운드 에이전트 운영
- @ai/ai-usage.md — Claude·외부 AI 전송 가능 데이터 경계, 프롬프트 인젝션 방어

---

## 공통 정책

- **응답 언어**: 모든 응답은 **한글** (코드 변수명/함수명은 영어)
- **커버리지 임계값 조정 금지** → 테스트 추가로 해결
- **Domain 모듈에 프레임워크 의존성 금지** → 순수 언어 코드만
- **지표 없는 기능 런치 금지** → @product/metrics.md
- **Out of Scope 없는 PRD 금지** → @planning/prd-guidelines.md
- **PII 로깅 금지** → @management/security.md, @ai/ai-usage.md
