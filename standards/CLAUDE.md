# Dev Standards

> 이 문서는 submodule로 포함된 프로젝트에서 Claude Code가 자동으로 읽습니다.

## ⚠️ 필수 가이드라인

모든 코드 작성 시 아래 문서를 **반드시** 따릅니다.

- @coding/coding-guidelines.md - 언어별 코딩 스타일, 아키텍처 원칙, 조건문 패턴
- @testing/testing-guidelines.md - 테스트 프레임워크, 패턴, Mocking 전략
- @api/api-design.md - REST API 설계 원칙 및 표준

## 참조

- @templates/adr-template.md - ADR 작성 시 이 템플릿 사용

## 공통 정책

- **커버리지 임계값 조정 금지** → 테스트 추가로 해결
- **Domain 모듈에 프레임워크 의존성 금지** → 순수 언어 코드만
- **응답 언어**: 모든 응답은 **한글** (코드 변수명/함수명은 영어)
