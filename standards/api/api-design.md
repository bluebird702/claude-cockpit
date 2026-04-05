# REST API 설계 가이드라인

> **목적**: 일관되고 확장 가능한 RESTful API 설계 원칙 및 표준 정의

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

**버전**: 1.0.0 | **최종 업데이트**: 2026-03-16
