# CLAUDE.md (예시)

> **참고**: 이 파일은 cockpit 을 submodule 로 연결한 프로젝트에서 `CLAUDE.md` 를 어떻게 구성하는지 보여주는 **샘플** 입니다. 가상의 마이크로서비스 플랫폼을 기준으로 작성됐습니다.

## 프로젝트 개요

Example Platform 은 도서 관리 및 사용자 계정을 위한 마이크로서비스 기반 플랫폼입니다. API Gateway 를 통해 통신하며 중앙화된 인증 시스템을 사용합니다.

## 아키텍처

```
Frontend (Web/Mobile) → @example/platform-js
                ↓
        API Gateway (8080) ─── JWT 검증, Rate Limiting
                ↓
    ┌───────────┼───────────┬───────────┐
    ▼           ▼           ▼           ▼
 Account    Profile    Community    Social
  (8081)     (8082)      (8083)     (8084)
    │           │           │           │
    └───────────┴───────────┴───────────┘
                ↓
        Domain Services (App API: 3000)
```

**Platform 서비스**: Account (JWT/Tenant), Profile (Member), Community (Post/Comment), Social (Follow)
**인프라**: Vault (시크릿), Redis (토큰 블랙리스트/캐시), PostgreSQL 16

## 서비스 구성

| 서비스 | 스택 | 포트 |
|--------|------|------|
| Gateway | Kotlin, Spring Cloud Gateway | 8080 |
| Account | Kotlin, Spring Boot 3.4, 헥사고날 | 8081 |
| Profile | Kotlin, Spring Boot 3.4, RLS | 8082 |
| Community | Kotlin, Spring Boot 3.4 | 8083 |
| Social | Kotlin, Spring Boot 3.4 | 8084 |
| App API | Ruby on Rails 8.0 | 3000 |
| Frontend | Next.js 15, Expo | 3001 |
| E2E | Playwright | - |

## 빌드 및 테스트

> **상세 명령어**: 각 서비스 CLAUDE.md 의 `빠른 명령어` 섹션 참조

### 전체 스택
```bash
./ops/scripts/up.sh          # 스택 시작
./ops/scripts/down.sh        # 스택 종료
./ops/scripts/e2e-test.sh    # E2E 테스트
```

## 환경 설정

> ⚠️ 로컬 실행에 Docker 필수 (Redis, PostgreSQL). `docker-compose.yml` 참조

`.env.example` 을 `.env` 로 복사 후 설정:
- `JWT_SECRET` — 공유 JWT 서명 키 (최소 32자)
- `*_DB_PASSWORD` — 각 서비스 DB 비밀번호
- `REDIS_PASSWORD` — Redis 인증
- `RAILS_SECRET_KEY_BASE` — Rails 시크릿 (최소 128자)

## 인증 흐름

1. 사용자가 Account 서비스로 인증 → JWT 발급
2. App 요청은 API Gateway 를 통해 전달
3. Gateway 가 JWT 검증 후 헤더 전달: `X-Account-Id`, `X-User-Email`, `X-User-Name`
4. App API 는 헤더 기반 인증 사용 (자체 인증 없음)

## 📚 개발 문서 (docs/)

> ⚠️ **공통 개발 표준은 `brain/CLAUDE.md` 에서 자동 로딩됩니다** (cockpit submodule 연결 시).

### 프로젝트 전용
- ⚠️ **필수**: `docs/guidelines/project-structure.md`
- 참조: `docs/guidelines/README.md` | `docs/design/README.md` | `docs/adr/README.md`

## ⛔ 프로젝트 전용 정책

- **Domain 모듈에 Spring 의존성 금지** → `{service}-domain` 은 순수 Kotlin 만

## 📖 API 문서

외부 개발자용 Docusaurus 문서: `docs/site/` (`cd docs/site && npm run start`)

## 저장소 규칙

- 브랜치: `feature/`, `fix/`, `chore/` 접두사
- 커밋: Conventional Commits (`feat:`, `fix:`, `refactor:`)
- PR: 제목 70자 이하, 본문에 변경 사유 포함

---

**버전**: 1.4.0 | **업데이트**: 2026-03-16
