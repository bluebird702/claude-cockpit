# REST API 설계 가이드라인

> **목적**: 일관되고 확장 가능한 RESTful API 설계 원칙 및 표준 정의

---

## 설계 철학 (Foundations)

> 아래가 **"왜"** 다. 이 문서의 규칙은 여기서 파생된다.

- **계약 우선(Contract-first)**: 스펙(OpenAPI/스키마)이 진실. 코드보다 계약을 먼저 합의하고, 계약이 문서·mock·테스트를 생성한다.
- **소비자 중심 · 최소 놀람(POLS)**: 서버 편의가 아니라 **호출자의 사용성**을 위해 설계. 예측 가능·일관.
- **진화 가능성 > 완벽함**: 하위호환을 깨지 말 것. **추가는 안전, 삭제·의미 변경은 새 버전**. Deprecation은 예고(§버저닝).
- **재시도 안전(멱등성)**: 네트워크는 실패한다. GET/PUT/DELETE는 멱등, POST는 `Idempotency-Key`로 안전하게(§고급 패턴).
- **안전 기본값(Secure by default)**: 인증·rate-limit·최소 노출이 기본. 토큰은 URL 금지, 민감 작업은 재인증(§보안).
- **오류도 API다**: 기계가 분기할 `code`는 **안정적 계약**. 일관된 에러 포맷·taxonomy(§응답·고급 패턴).

---

## 핵심 설계 원칙

### 1. 리소스 중심 (Resource-Oriented)
- URL은 **명사**만 사용 (동사 금지)
- HTTP 메서드로 **행위** 표현
- URL에 동작을 포함하지 않음

```http
# ✅ Good
GET    /api/v1/users/{userId}
POST   /api/v1/accounts
PATCH  /api/v1/users/{userId}/profile

# ❌ Bad
GET    /api/v1/getUser?id={userId}
POST   /api/v1/createAccount
POST   /api/v1/users/{userId}/updateProfile
```

### 2. HTTP 메서드 의미론
| 메서드 | 의미 | 멱등성 | 사용 예시 |
|--------|------|--------|----------|
| GET | 조회 | Yes | 리소스 조회 |
| POST | 생성 | No | 새 리소스 생성, 액션 실행 |
| PUT | 전체 교체 | Yes | 리소스 전체 교체 |
| PATCH | 부분 수정 | No | 리소스 일부 속성만 수정 |
| DELETE | 삭제 | Yes | 리소스 삭제 |

**PATCH vs PUT 선택 기준:**
```http
# PATCH: 일부 필드만 수정 (권장)
PATCH /api/v1/users/{userId}/profile
Body: { "displayName": "새 이름" }  # bio는 변경 안 됨

# PUT: 전체 리소스 교체
PUT /api/v1/users/{userId}/profile
Body: { "displayName": "새 이름", "bio": "...", ... }  # 모든 필드 필요
```

**권장**: 일반적으로 **PATCH** 사용

### 3. URL 네이밍 규칙

#### 3.1 케이스 (Case)
- **케밥 케이스(kebab-case)** 사용
- camelCase, snake_case, PascalCase 금지

```http
# ✅ Good
/api/v1/social-links
/api/v1/profile-images
/api/v1/password-resets

# ❌ Bad
/api/v1/socialLinks
/api/v1/profile_images
/api/v1/PasswordResets
```

#### 3.2 복수형 vs 단수형
| 상황 | 형태 | 예시 |
|------|------|------|
| 컬렉션 리소스 | 복수형 | `/users`, `/accounts` |
| 단일 리소스 (컬렉션 내) | 복수형 경로 + ID | `/users/{userId}` |
| 단일 리소스 (고유) | 단수형 | `/profile-image`, `/email` |
| 하위 컬렉션 | 복수형 | `/accounts/{id}/social-links` |

#### 3.3 계층 구조
- 최대 3단계까지 권장
- 관계가 명확한 경우에만 중첩 사용

```http
# ✅ Good (2-3 depth)
/api/v1/accounts/{accountId}/social-links
/api/v1/users/{userId}/profile

# ⚠️ 주의 (4 depth) → 평탄화 권장
/api/v1/social-links/{linkId}/permissions
```

### 4. 버저닝 (Versioning)
- URL 경로에 버전 명시: `/api/v1/`, `/api/v2/`
- 헤더 버저닝 사용 금지 (명시성 부족)

**Deprecation 정책:**
- 새 버전 출시 후 최소 **12개월** 이전 버전 유지
- Deprecation 헤더로 사전 경고

---

## 표준 엔드포인트 패턴

### 1. 인증 (Authentication)
**예외**: RPC 스타일 허용 (업계 표준)

```http
POST   /api/v1/auth/login
POST   /api/v1/auth/logout
POST   /api/v1/auth/refresh
GET    /api/v1/auth/verify
POST   /api/v1/auth/social/{provider}
```

### 2. 기본 CRUD 리소스

```http
POST   /api/v1/{resources}              # 생성 → 201 Created
GET    /api/v1/{resources}/{id}          # 조회 → 200 OK
GET    /api/v1/{resources}?page=0&size=20  # 목록 → 200 OK
PATCH  /api/v1/{resources}/{id}          # 부분 수정 → 200 OK
PUT    /api/v1/{resources}/{id}          # 전체 교체 → 200 OK
DELETE /api/v1/{resources}/{id}          # 삭제 → 204 No Content
```

### 3. 현재 사용자 (Authenticated User)

**패턴**: `/users/me`를 shortcut으로 사용

```http
GET   /api/v1/users/me
GET   /api/v1/users/me?include=account,personal-info
PATCH /api/v1/users/me/profile
PATCH /api/v1/users/me/email
PATCH /api/v1/users/me/password
PUT   /api/v1/users/me/profile-image
```

### 4. 독립적인 워크플로우 리소스

비밀번호 재설정, 이메일 인증 등은 최상위 리소스로 분리:

```http
# 비밀번호 재설정
POST /api/v1/password-resets
POST /api/v1/password-resets/{resetId}/confirmations

# 이메일 인증
POST /api/v1/email-verifications
POST /api/v1/email-verifications/{verificationId}/confirmations
```

---

## 보안 가이드라인

### 1. 토큰 처리
**URL에 토큰 노출 금지** (서버 로그, 브라우저 히스토리, Referer 헤더 유출)

```http
# ❌ 절대 금지
PUT /api/v1/password-resets/{token}

# ✅ 올바른 방법 (토큰을 Body에)
POST /api/v1/password-resets/{resetId}/confirmations
Body: { "token": "secret_token", "newPassword": "..." }
```

### 2. 민감한 작업 재인증

```http
# 이메일 변경 시 비밀번호로 재인증
PATCH /api/v1/users/me/email
Body: { "email": "new@example.com", "password": "current_password" }

# 비밀번호 변경 시 현재 비밀번호 필수
PATCH /api/v1/users/me/password
Body: { "currentPassword": "old_password", "newPassword": "new_password" }
```

### 3. Rate Limiting
엔드포인트별 차등 제한 적용:

| 엔드포인트 | 제한 | 이유 |
|------------|------|------|
| `POST /auth/login` | 5 req/min per IP | 브루트 포스 방지 |
| `POST /password-resets` | 3 req/hour per email | 스팸 방지 |
| `POST /email-verifications` | 5 req/hour per account | 이메일 폭탄 방지 |

---

## 쿼리 파라미터 가이드라인

### 1. 페이징 (Pagination)
**표준 파라미터**: `page`, `size`

```json
{
  "content": [ ... ],
  "page": {
    "number": 0,
    "size": 20,
    "totalElements": 150,
    "totalPages": 8
  }
}
```

**기본값**: `page`: 0 (0-indexed), `size`: 20, 최대 `size`: 100

### 2. 정렬 (Sorting)

```http
GET /api/v1/users?sort=createdAt,desc
GET /api/v1/users?sort=status,asc&sort=createdAt,desc
```

### 3. 필터링 (Filtering)

```http
GET /api/v1/accounts?status=ACTIVE
GET /api/v1/accounts?emailVerified=true
GET /api/v1/users?search=홍길동
```

### 4. 리소스 포함 (Include)
**표준 파라미터**: `include` (쉼표 구분)

```http
GET /api/v1/users/me?include=account,personal-info,social-links
```

---

## 응답 형식 가이드라인

### 1. 성공 응답
| 코드 | 의미 | 사용 상황 |
|------|------|----------|
| `200 OK` | 성공 (응답 본문 있음) | 조회, 수정 |
| `201 Created` | 리소스 생성 성공 | 생성 + Location 헤더 |
| `202 Accepted` | 비동기 처리 수락 | 비동기 작업 |
| `204 No Content` | 성공 (응답 본문 없음) | 삭제 |

### 2. 에러 응답

```json
{
  "code": "VALIDATION_ERROR",
  "message": "Validation failed",
  "errors": [
    { "field": "email", "message": "이메일 형식이 올바르지 않습니다" }
  ]
}
```

**필드**: `code` (필수, 클라이언트 분기용), `message` (필수, 디버깅용 영문), `errors` (선택, 유효성 검증 시)

**포함하지 않는 필드**: `status`, `error`, `path`, `timestamp`

### 3. 표준 에러 코드

| 코드 | 의미 | 예시 code |
|------|------|-----------|
| `400` | Bad Request | `VALIDATION_ERROR` |
| `401` | Unauthorized | `UNAUTHORIZED`, `TOKEN_EXPIRED` |
| `403` | Forbidden | `FORBIDDEN`, `INSUFFICIENT_ROLE` |
| `404` | Not Found | `ACCOUNT_NOT_FOUND` |
| `409` | Conflict | `EMAIL_ALREADY_EXISTS` |
| `422` | Unprocessable Entity | `INVALID_PASSWORD_FORMAT` |
| `429` | Too Many Requests | `RATE_LIMIT_EXCEEDED` |

---

## DDD와 API 매핑

### 1. Aggregate와 엔드포인트 일치

각 Aggregate Root마다 독립적인 엔드포인트:

```
/api/v1/accounts/{accountId}              → Account Aggregate
/api/v1/accounts/{accountId}/social-links → Account의 하위 엔티티
/api/v1/users/{userId}                    → User Aggregate
```

### 2. 트랜잭션 경계
**원칙**: 1 API 호출 = 1 Aggregate 수정

```http
# ✅ Good (단일 Aggregate 수정)
PATCH /api/v1/users/{userId}/profile

# ❌ Bad (여러 Aggregate 수정)
POST /api/v1/users/{userId}/change-everything
```

---

## 응답 필드 네이밍

**camelCase 사용** (JSON 표준)

```json
{
  "userId": "usr_123",
  "displayName": "홍길동",
  "profileImageUrl": "https://...",
  "createdAt": "2025-11-22T10:00:00Z",
  "emailVerified": true
}
```

### ID 네이밍
**타입 접두사 사용** (가독성): `acc_{uuid}`, `usr_{uuid}`, `reset_{uuid}`

---

## 고급 패턴

### 멱등성 (Idempotency-Key)

생성(POST) 재시도 안전을 위해 `Idempotency-Key: <uuid>` 헤더를 수용한다. 같은 키 + 같은 요청 → **같은 결과**(중복 생성 방지). 키→응답을 일정 시간(예: 24h) 저장하고, 키 재사용 시 저장된 응답을 반환.

```http
POST /api/v1/payments
Idempotency-Key: 4f1a...   # 클라이언트가 재시도해도 결제 1회만
```

### 페이징 — offset vs cursor

- **소규모·랜덤 접근**: `page`/`size` (§쿼리 파라미터).
- **대규모·실시간 목록**: **커서 기반** (`?cursor=<opaque>&size=`). offset의 깊은 페이지 성능 저하와 삽입/삭제 시 항목 누락·중복을 회피한다. 응답에 `nextCursor` 포함(없으면 마지막 페이지).

### 프로토콜 선택

| 프로토콜 | 언제 |
|----------|------|
| **REST** | 리소스 CRUD·공개 API 기본 |
| **GraphQL** | 클라이언트가 필드 조합, over/under-fetch 심할 때(BFF) |
| **gRPC** | 내부 서비스 간 저지연·스트리밍·강타입 계약 |

> 흔한 조합: **외부 경계 = REST**, **내부 서비스 간 = gRPC**.

### 에러 코드 taxonomy

`code`는 **안정적 enum**(변경 시 하위호환 깨짐 — 새 버전 필요). HTTP 상태와 정합, 메시지는 사람용(영문), `errors[]`는 필드 검증.

| 그룹 | 예시 code | HTTP |
|------|-----------|------|
| 없음 | `ACCOUNT_NOT_FOUND` | 404 |
| 중복 | `EMAIL_ALREADY_EXISTS` | 409 |
| 검증 | `VALIDATION_ERROR` | 400/422 |
| 인증 | `UNAUTHORIZED`, `TOKEN_EXPIRED` | 401 |
| 인가 | `FORBIDDEN`, `INSUFFICIENT_ROLE` | 403 |
| 제한 | `RATE_LIMIT_EXCEEDED` | 429 |

---

## 체크리스트

### 설계
- [ ] 리소스 이름이 명사인가?
- [ ] 케밥 케이스를 사용했는가?
- [ ] 복수형/단수형이 올바른가?
- [ ] HTTP 메서드가 적절한가?
- [ ] URL 깊이가 3단계 이내인가?
- [ ] 버전이 명시되어 있는가?

### 보안
- [ ] 토큰을 URL에 노출하지 않았는가?
- [ ] 민감한 작업에 재인증을 요구하는가?
- [ ] Rate Limiting이 적용되어 있는가?

### 구현
- [ ] Aggregate 경계를 위반하지 않았는가?
- [ ] N+1 쿼리 문제가 없는가?
- [ ] 에러 응답이 표준 포맷을 따르는가?

---

**버전**: 1.1.0 | **최종 업데이트**: 2026-07-05

> 변경(1.1.0): **설계 철학(Foundations)**(계약 우선·소비자 중심·진화 가능성·멱등성·안전 기본값) + **고급 패턴**(Idempotency-Key·커서 페이징·프로토콜 선택·에러 taxonomy) 추가.
