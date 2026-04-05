# 프로젝트 구조 가이드

> **⚠️ 참고**: 이 문서는 Kotlin/Spring 기반 마이크로서비스를 **예시 스택** 으로 작성됐습니다. 본인 스택(Node, Python, Go 등)에 맞춰 구조를 재해석하세요. 핵심 원칙(헥사고날 · 도메인 격리 · 테스트 위치) 은 언어 무관합니다.

> Gradle 멀티모듈 구조, 테스트 파일 위치, 아키텍처 리뷰 시 참고사항

## Gradle 멀티모듈 구조

Platform 서비스들(Account, Profile, Community, Social)은 **헥사고날 아키텍처 기반 멀티모듈** 구조입니다.

```
platform/{service}/
├── {service}-domain/              # 순수 도메인 (Kotlin stdlib만)
│   └── src/
│       ├── main/kotlin/           # 도메인 로직
│       └── test/kotlin/           # ✅ 도메인 테스트
├── {service}-app/                 # REST API, DI 설정
│   └── src/
│       ├── main/kotlin/           # Controller, Config
│       └── test/kotlin/           # ✅ API/통합 테스트
└── {service}-infrastructure/      # 외부 연동 (DB, Redis, Kafka)
    ├── postgresql/
    │   └── src/test/kotlin/       # ✅ DB 테스트
    ├── redis/
    │   └── src/test/kotlin/       # ✅ 캐시 테스트
    └── kafka/
        └── src/test/kotlin/       # ✅ 이벤트 테스트
```

### 도메인 모듈 내부 구조 {#hexagonal-domain}

`{service}-domain` 모듈의 표준 디렉토리 구조:

```
{service}-domain/src/main/kotlin/.../domain/
├── {aggregate}/              # Aggregate Root별 패키지
│   ├── {Aggregate}.kt        # Aggregate Root 엔티티
│   ├── {ValueObject}.kt      # Value Objects
│   └── repository/           # Repository 인터페이스
├── service/                  # 도메인 서비스 인터페이스
├── port/                     # Port 정의 (EventPublisher, ExternalClient 등)
└── event/                    # 도메인 이벤트 (sealed interface)
```

### 단일 모듈 서비스

| 서비스 | 구조 | 테스트 위치 |
|--------|------|------------|
| Gateway | 단일 모듈 | `src/test/kotlin/` |
| Mypedia API | Rails 표준 | `spec/` (RSpec) |
| Mypedia Frontend | Turborepo | `frontend/packages/*/src/**/*.test.ts` |
| Platform Frontend | Turborepo | `platform/frontend/packages/*/src/**/*.test.ts` |
| E2E | Playwright | `tests/` |

### Platform Frontend 디렉토리 구조 {#platform-frontend-structure}

```
platform/frontend/
├── packages/
│   ├── platform-js/      # @example/platform-js (API 클라이언트)
│   │   └── src/
│   │       ├── client.ts    # HTTP 클라이언트
│   │       ├── auth.ts      # 인증 API
│   │       └── types.ts     # 공통 타입
│   ├── shared/           # @example/shared (공통 유틸)
│   │   └── src/
│   │       ├── logger/
│   │       ├── errors/
│   │       └── storage/
│   └── ui-primitives/    # @example/ui (기본 UI 컴포넌트)
│       └── src/
│           ├── Button.tsx
│           └── Input.tsx
├── package.json          # Turborepo workspace
└── turbo.json
```

### Mypedia 전체 디렉토리 구조 {#mypedia-structure}

```
services/mypedia/
├── api/                  # Rails API 백엔드
│   ├── app/
│   │   ├── models/         # ActiveRecord 모델 (Book, Author, Review 등)
│   │   ├── controllers/    # API 컨트롤러
│   │   ├── services/       # 비즈니스 로직 (Yes24::Client 등)
│   │   └── jobs/           # 백그라운드 작업 (Yes24BookUpdateJob)
│   ├── spec/
│   │   ├── models/         # 모델 테스트
│   │   ├── requests/       # API 테스트
│   │   └── services/       # 서비스 테스트
│   └── config/             # Rails 설정
│
└── frontend/             # 프론트엔드 (Turborepo)
    ├── packages/
    │   └── api-js/         # @mypedia/api-js (Mypedia API 클라이언트)
    │       └── src/
    │           ├── books.ts
    │           ├── reviews.ts
    │           └── types.ts
    ├── web/                # @mypedia/web (Next.js)
    ├── mobile/             # @mypedia/mobile (Expo)
    ├── package.json
    └── turbo.json
```

## 테스트 파일 검색 패턴

### 올바른 Glob 패턴

```bash
# Platform 서비스 전체 테스트
platform/**/**/src/test/kotlin/**/*.kt

# 특정 서비스 테스트
platform/account/**/src/test/kotlin/**/*.kt
platform/profile/**/src/test/kotlin/**/*.kt
platform/community/**/src/test/kotlin/**/*.kt
platform/social/**/src/test/kotlin/**/*.kt

# Gateway (단일 모듈)
platform/gateway/src/test/kotlin/**/*.kt

# Mypedia (Rails)
services/mypedia/spec/**/*_spec.rb

# E2E
e2e/tests/**/*.spec.ts
```

### 잘못된 패턴 (피해야 함)

```bash
# ❌ 중간 모듈(domain, app, infrastructure) 누락
platform/*/src/test/**/*.kt

# ❌ 모듈명 하드코딩
platform/account/src/test/**/*.kt
```

## 서비스별 테스트 현황 요약

| 서비스 | 도메인 테스트 | API 테스트 | 인프라 테스트 |
|--------|-------------|-----------|-------------|
| **Account** | `account-domain/src/test/` (80+) | `account-app/api/src/test/` (30+) | `account-infrastructure/*/src/test/` |
| **Profile** | `profile-domain/src/test/` (15+) | `profile-app/src/test/` | - |
| **Community** | `community-domain/src/test/` (20+) | `community-app/src/test/` | - |
| **Social** | `social-domain/src/test/` (5+) | `social-app/api/src/test/` (3+) | - |
| **Gateway** | `src/test/` (25+) | - | - |
| **Mypedia** | `spec/models/` | `spec/requests/` | - |

## 아키텍처 리뷰 체크리스트

코드베이스 분석 시 다음 사항을 확인하세요:

### 1. 테스트 존재 여부 확인

```bash
# 먼저 멀티모듈 구조 확인
ls platform/{service}/

# 각 모듈별 테스트 디렉토리 확인
find platform/{service} -type d -name "test" -path "*/src/*"
```

### 2. 의존성 방향 검증

```
domain → (의존 없음, 순수 Kotlin)
app → domain
infrastructure → domain
```

### 3. 테스트 커버리지 목표

| 서비스 | Line Coverage | Mutation Score |
|--------|--------------|----------------|
| Account | 80%+ | 90%+ (Pitest) |
| Profile | 80%+ | 70%+ |
| Community | 80%+ | - |
| Social | 80%+ | - |
| Gateway | 60%+ | - |

---

**최종 업데이트**: 2025-12-26
