# Dev Standards

> 프로젝트 공통 개발 표준 및 가이드라인

## 문서 목록

| 문서 | 설명 | 대상 |
|------|------|------|
| [코딩 가이드라인](coding/coding-guidelines.md) | 언어별 코딩 스타일, 아키텍처 원칙, 조건문 패턴 | 모든 개발자 |
| [테스트 가이드라인](testing/testing-guidelines.md) | 테스트 프레임워크, 패턴, Mocking 전략 | 모든 개발자 |
| [API 설계 가이드](api/api-design.md) | REST API 설계 원칙 및 표준 | 백엔드 개발자 |
| [ADR 템플릿](templates/adr-template.md) | Architecture Decision Record 작성 템플릿 | 모든 개발자 |

## 사용 방법

### Git Submodule로 추가

```bash
# 프로젝트에 submodule 추가
git submodule add git@github.com:abillity/dev-standards.git docs/standards

# submodule 포함하여 clone
git clone --recurse-submodules <repo-url>

# 기존 clone에서 submodule 초기화
git submodule update --init --recursive
```

### 업데이트

```bash
# 최신 버전으로 업데이트
cd docs/standards
git pull origin main
cd ../..
git add docs/standards
git commit -m "chore: update dev-standards submodule"
```

## 프로젝트별 확장

이 문서는 **공통 기준**입니다. 프로젝트별로 추가 규칙이 필요하면:

1. 프로젝트의 `docs/guidelines/` 에 프로젝트 전용 문서 작성
2. 공통 문서를 `@docs/standards/...` 로 참조
3. 프로젝트 전용 커버리지 목표, 서비스별 규칙 등은 프로젝트 문서에 기술

## 기여 방법

1. 변경 제안 → PR 생성
2. 팀 리뷰 및 논의
3. 승인 후 병합
4. 각 프로젝트에서 submodule 업데이트

---

**버전**: 1.0.0 | **최종 업데이트**: 2026-03-16
