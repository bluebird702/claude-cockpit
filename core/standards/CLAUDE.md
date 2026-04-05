# Standards

> 이 문서는 Claude Code 가 세션 시작 시 자동 로드합니다. 모든 작업은 아래 표준을 따릅니다.

표준은 **4개 도메인**으로 나뉩니다. 작업 성격에 맞는 표준만 필요하면 됩니다.

## 🛠 개발 (Engineering)

모든 코드 작성·리뷰에 **필수 적용**.

- @coding/coding-guidelines.md — 언어별 스타일, Clean Architecture, 조건문 패턴
- @testing/testing-guidelines.md — 테스트 프레임워크, AAA/BDD, Mocking 전략
- @api/api-design.md — REST API 설계 원칙, 보안, DDD 매핑
- @templates/adr-template.md — 아키텍처 결정 기록 템플릿

## 📐 기획 (Planning)

기능 스펙·요구사항 정리 작업 시 적용.

- @planning/prd-guidelines.md — 1-페이지 PRD 형식, In/Out of Scope, 롤백 기준

## 🎯 프로덕트 (Product)

지표 정의·리서치·전략 작업 시 적용.

- @product/metrics.md — North Star / Goal / Guardrail 프레임, 활성화·리텐션 정의

## 🏢 경영 (Management) — 회사 레벨 가로지르는 규칙

모든 프로젝트에 **공통 적용**.

- @management/security.md — 시크릿, 의존성, 로그, 사고 대응
- @management/ai-usage.md — Claude·외부 AI 전송 가능 데이터 경계
- @management/decision-log.md — ADR 프로세스 (언제/어떻게 쓰는가)

---

## 공통 정책

- **응답 언어**: 모든 응답은 **한글** (코드 변수명/함수명은 영어)
- **커버리지 임계값 조정 금지** → 테스트 추가로 해결
- **Domain 모듈에 프레임워크 의존성 금지** → 순수 언어 코드만
- **지표 없는 기능 런치 금지** → @product/metrics.md
- **Out of Scope 없는 PRD 금지** → @planning/prd-guidelines.md
- **PII 로깅 금지** → @management/security.md, @management/ai-usage.md
