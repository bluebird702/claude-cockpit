---
name: dev:design-api
description: 신규 API 설계 제안 또는 기존 API 검토
type: slash-command
category: dev
follows-standards:
  - standards/CLAUDE.md
  - standards/api/api-design.md
enforcement: required
---

# API 설계 검토 및 제안

> ⚠️ **Standards 준수 필수** — REST/GraphQL 판단 기준은 아래를 우선합니다.
> @standards/api/api-design.md · @standards/CLAUDE.md

새로운 API 엔드포인트를 설계하거나 기존 API를 검토합니다.

$ARGUMENTS
- 인자가 **API 설계 요청**이면 → 설계 제안
- 인자가 **기존 API**이면 → 검토 및 개선안

## 절차

### 1. 컨텍스트 파악
- 프로젝트의 API 설계 가이드라인 문서 확인 (`@standards/api/api-design.md`, CLAUDE.md)
- 기존 Controller/Router 코드에서 현재 API 패턴 파악

### 2. 설계 원칙 점검

| 항목 | 체크 |
|------|------|
| URL이 명사로 구성되는가 | 동사 금지, 리소스 중심 |
| HTTP 메서드가 적절한가 | GET 조회, POST 생성, PATCH 수정, DELETE 삭제 |
| 케밥 케이스 사용 | `kebab-case` |
| URL 깊이 3단계 이내 | `/api/v1/{resource}/{id}/{sub-resource}` |
| 보안 | URL에 토큰 노출 금지, 민감 작업 재인증 |

### 3. 설계 제안 형식

```http
METHOD /api/v1/{resource}
Headers: Authorization: Bearer {token}
Body: { ... }

Response: STATUS
Body: { ... }
```

### 4. 추가 검증
- Aggregate 경계 위반 여부 (DDD 프로젝트인 경우)
- N+1 쿼리 가능성
- 업계 표준 참고 (GitHub, Stripe API 등)

## 출력 형식

```markdown
## API 설계 제안

### 엔드포인트
### 설계 체크리스트
- [ ] 리소스명 명사, 케밥 케이스
- [ ] HTTP 메서드 적절
- [ ] URL 깊이 3단계 이내
- [ ] 보안 점검 통과

### 구현 순서
1. UseCase/Service 정의
2. Controller/Router 구현
3. 테스트 작성
4. API 문서 업데이트
```
