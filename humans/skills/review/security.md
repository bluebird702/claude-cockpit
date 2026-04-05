---
name: review:security
description: OWASP Top 10·시크릿·인증/인가·프레임워크 보안 설정 심층 리뷰
type: slash-command
category: review
follows-standards:
  - standards/CLAUDE.md
  - standards/coding/coding-guidelines.md
enforcement: required
---

# 보안 리뷰

> ⚠️ **Standards 준수 필수** — 보안 판단 기준은 standards를 우선합니다.
> @standards/coding/coding-guidelines.md · @standards/api/api-design.md · @standards/CLAUDE.md

프로젝트 코드를 정적 분석하여 OWASP Top 10, 시크릿 노출, 인증/인가 누락, 프레임워크 보안 설정 결함을 탐지합니다.

$ARGUMENTS
- `deep` — 심층 모드 (취약 코드 + 수정 코드)
- **파일/디렉토리 경로** — 해당 범위만 스캔
- 인자 없음 → 프로젝트 전체 스캔
- 예: `/review:security`, `/review:security deep src/api`

## Step 1: 컨텍스트 파악

- 사용 언어 및 프레임워크 식별
- 인증/인가 관련 코드 위치 (filter, middleware, guard 등)
- 외부 입력 진입점 (Controller, API endpoint, form handler, webhook)
- 비밀 관리 방식 (env, vault, KMS)

## Step 2: 체크리스트

### A. OWASP Top 10 (10항목)
| # | 카테고리 | 탐지 대상 |
|---|---------|----------|
| 1 | Injection | SQL/command/LDAP/ORM/NoSQL injection, 문자열 결합 쿼리 |
| 2 | 인증 결함 | 하드코딩 credential, 약한 해시(MD5/SHA1), 세션 관리 미흡, 토큰 만료 없음 |
| 3 | 민감 데이터 노출 | 로그에 PII/비밀번호, 평문 저장, 약한 암호화, HTTPS 미강제 |
| 4 | XXE | 안전하지 않은 XML 파서, DTD 허용 |
| 5 | 접근 제어 | 인가 검사 누락, IDOR, 경로 순회, 권한 상승 |
| 6 | 보안 설정 오류 | DEBUG 모드, CORS 와일드카드, 불필요 포트 노출, 기본 자격증명 |
| 7 | XSS | innerHTML 직접 주입, 미이스케이프 템플릿, React 위험 HTML prop, URL 파라미터 반영 |
| 8 | 역직렬화 | 안전하지 않은 역직렬화, yaml.load 미지정 로더, Java ObjectInputStream |
| 9 | 취약 컴포넌트 | 알려진 취약 버전 사용 (요약만, 상세는 `/review:deps`) |
| 10 | 로깅 부족 | 인증 실패/권한 변경 미로깅, 감사 로그 부재 |

### B. 시크릿 탐지 (5항목)
| # | 항목 | 점검 내용 |
|---|------|----------|
| 11 | 하드코딩 시크릿 | API 키, 토큰, 비밀번호 리터럴 |
| 12 | .env 추적 | `.env`, `.env.*`의 Git 추적 여부 |
| 13 | 프라이빗 키 | `.pem`, `.p12`, `id_rsa` 등 포함 |
| 14 | 패턴 매칭 | `(password\|secret\|token\|key\|api_key)\s*[=:]\s*['"][^'"]+['"]` |
| 15 | Git 히스토리 잔존 | 과거 커밋에 노출된 시크릿 (옵션) |

### C. 프레임워크별 추가 점검
| 프레임워크 | 항목 |
|-----------|------|
| Spring Boot | CSRF 설정, SecurityFilterChain, actuator 노출, `@PreAuthorize` 누락 |
| Rails | mass assignment, strong params, CSRF 토큰, 원시 SQL 남용 |
| Next.js/React | 위험 HTML 주입 prop, SSR 데이터 노출, API route 인가, middleware |
| Express | helmet, rate limiting, CORS 설정, body 크기 제한 |
| Django | CSRF middleware, `SECRET_KEY` 관리, `DEBUG=False`, ALLOWED_HOSTS |

## Step 3: 에이전트 위임

`pr-review-toolkit:silent-failure-hunter` 에이전트에게 위임. 프롬프트에 포함:
- Step 1 컨텍스트 한 줄 요약
- 분석 대상 경로
- Step 2 전체 체크리스트
- 의존성 CVE는 범위 외임을 명시 (`/review:deps`가 담당)
- Step 4 출력 형식 지시

**빌드/테스트 실행 금지, 코드 읽기만.**

## 점수 산정 규칙

**점수 산정 방식**: 발견 취약점 기반 감점

| 심각도 | 감점 |
|--------|------|
| Critical | -20점 |
| High | -10점 |
| Medium | -5점 |
| Low | -2점 |

- **기준 점수**: 100점
- **최저 점수**: 0점 (마이너스 없음)
- **N/A 처리**: §C 프레임워크별 항목은 감지된 스택에만 적용. 해당 없는 프레임워크 항목은 탐지 시도 자체를 생략 (감점 없음)
- **예시**: Critical 2개 + High 3개 → 100 − 40 − 30 = 30점

## Step 4: 출력 형식

```markdown
## 보안 리뷰 결과

### 요약
- **스캔 범위**: [경로]
- **감지된 스택**: [언어/프레임워크]
- **위험 점수**: XX/100
- **발견 항목**: Critical X / High X / Medium X / Low X

### Critical/High 발견 항목
| # | 카테고리 | 파일:줄 | 설명 | CWE |

(심층 모드: 각 항목에 취약 코드 / 위험 / 수정 코드)

### Medium/Low 발견 항목
| # | 카테고리 | 파일:줄 | 설명 |

### 시크릿 탐지
| # | 패턴 | 파일:줄 | 조치 |

### 프레임워크 보안 설정
| 항목 | 상태 | 권장 |

### 권장 조치 (우선순위순)
1. Critical: ...
2. High: ...
3. Medium/Low: ...
```

## Step 5: 드릴다운

- 취약 라이브러리 상세 → `/review:deps`
- 에러 처리 전반 → `/review:code`
- 인증/인가 구조 문제 → `/review:architecture`
