> [!NOTE]
> This document is currently in Korean. The repository owner's translation quota was exceeded.
> To translate it to English, run: `./scripts/sync-i18n.sh`

---
name: review:security
description: OWASP Top 10·시크릿·인증/인가·프레임워크 보안 설정 심층 리뷰
type: slash-command
category: review
follows-standards:
  - brain/CLAUDE.md
  - brain/management/security.md
  - brain/hard-won-conventions.md
  - brain/coding/coding-guidelines.md
  - brain/api/api-design.md
enforcement: required
---

# 보안 리뷰

> ⚠️ **Standards 준수 필수** — 보안 판단 기준은 standards를 우선합니다.
> @brain/management/security.md · @brain/hard-won-conventions.md(§보안—신뢰 경계: XFF·JWT·fail-fast 실사고 관례) · @brain/coding/coding-guidelines.md · @brain/api/api-design.md · @brain/CLAUDE.md

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
| # | 카테고리 | 탐지 대상 | Tier | Sev |
|---|---------|----------|------|-----|
| 1 | Injection | SQL/command/LDAP/ORM/NoSQL injection, 문자열 결합 쿼리 | evidence | critical |
| 2 | 인증 결함 | 하드코딩 credential, 약한 해시(MD5/SHA1), 세션 관리 미흡, 토큰 만료 없음 | evidence | high |
| 3 | 민감 데이터 노출 | 로그에 PII/비밀번호, 평문 저장, 약한 암호화, HTTPS 미강제 | evidence | high |
| 4 | XXE | 안전하지 않은 XML 파서, DTD 허용 | evidence | high |
| 5 | 접근 제어 | 인가 검사 누락, IDOR, 경로 순회, 권한 상승 | evidence | critical |
| 6 | 보안 설정 오류 | DEBUG 모드, CORS 와일드카드, 불필요 포트 노출, 기본 자격증명 (grep hit, 측정) | objective | high |
| 7 | XSS | innerHTML 직접 주입, 미이스케이프 템플릿, React 위험 HTML prop, URL 파라미터 반영 | evidence | high |
| 8 | 역직렬화 | 안전하지 않은 역직렬화, yaml.load 미지정 로더, Java ObjectInputStream (grep hit, 측정) | objective | high |
| 9 | 취약 컴포넌트 | 알려진 취약 버전 사용 (CVE 대조, 요약만, 상세는 `/review:deps`) | objective | high |
| 10 | 로깅 부족 | 인증 실패/권한 변경 미로깅, 감사 로그 부재 | evidence | medium |

### B. 시크릿 탐지 (5항목)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 11 | 하드코딩 시크릿 | API 키, 토큰, 비밀번호 리터럴 (secret hit, 측정) | objective | critical |
| 12 | .env 추적 | `.env`, `.env.*`의 Git 추적 여부 (측정) | objective | high |
| 13 | 프라이빗 키 | `.pem`, `.p12`, `id_rsa` 등 포함 (파일 매칭, 측정) | objective | critical |
| 14 | 패턴 매칭 | `(password\|secret\|token\|key\|api_key)\s*[=:]\s*['"][^'"]+['"]` (regex hit, 측정) | objective | critical |
| 15 | Git 히스토리 잔존 | 과거 커밋에 노출된 시크릿 (git log grep, 측정, 옵션) | objective | high |

### C. 프레임워크별 추가 점검
| 프레임워크 | 항목 | Tier | Sev |
|-----------|------|------|-----|
| Spring Boot | CSRF 설정, SecurityFilterChain, actuator 노출, `@PreAuthorize` 누락 | evidence | high |
| Rails | mass assignment, strong params, CSRF 토큰, 원시 SQL 남용 | evidence | high |
| Next.js/React | 위험 HTML 주입 prop, SSR 데이터 노출, API route 인가, middleware | evidence | high |
| Express | helmet, rate limiting, CORS 설정, body 크기 제한 | evidence | high |
| Django | CSRF middleware, `SECRET_KEY` 관리, `DEBUG=False`, ALLOWED_HOSTS | evidence | high |

> Tier=objective 는 METRICS 수치로 자동 판정, evidence 는 증거+검증, advisory 는 점수 제외.

## Step 3: 에이전트 위임

**cockpit 자체 에이전트 `review-security`** 에게 위임 (미설치 시 `general-purpose` 폴백 —
이 파일의 체크리스트·출력 형식을 프롬프트에 그대로 실음). 프롬프트에 포함:
- Step 1 컨텍스트 한 줄 요약
- 분석 대상 경로
- Step 2 전체 체크리스트
- 의존성 CVE는 범위 외임을 명시 (`/review:deps`가 담당)
- Step 4 출력 형식 지시

**빌드/테스트 실행 금지, 코드 읽기만.**

## 점수 산정 (all.md 가 계산)

이 스킬은 점수를 직접 매기지 않는다. 체크리스트 위반을 **findings 블록**으로 방출하고,
종합/영역 점수는 오케스트레이터(all.md)가 `100 − Σ(severity_penalty × confidence)` 로
결정적으로 계산한다.

- **objective 항목**: Step 0.5 METRICS 수치로 verdict 자동 결정 (LLM 재판정 금지)
- **evidence 항목**: file:line 증거가 있을 때만 발견으로 기록 (confidence 부여, 적대적 검증 대상)
- **advisory 항목**: 서술로만 노출, 점수에서 제외
- **N/A**: 언어·스택상 비해당 항목은 `n/a` (감점 아님, 재현성 위해 노출)

## Step 4: 출력 형식

```markdown
## 보안 리뷰 결과

### 요약
- **스캔 범위**: [경로]
- **감지된 스택**: [언어/프레임워크]

### 발견 요약
- critical N · high N · medium N · low N  (점수는 all.md 가 findings 로 계산)

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

### findings (기계 판독 — 원장용, 필수)
```findings
severity|area|file:line|category|한 줄 요약
```
severity ∈ {critical,high,medium,low}. area 는 이 스킬 영역(security). 발견 없으면 빈 블록.

## Step 5: 드릴다운

- 취약 라이브러리 상세 → `/review:deps`
- 에러 처리 전반 → `/review:code`
- 인증/인가 구조 문제 → `/review:architecture`
