---
name: ci:security-scan
description: OWASP Top 10 + 시크릿 탐지 기반 정적 보안 스캔
type: slash-command
category: ci
follows-standards:
  - standards/CLAUDE.md
  - standards/coding/coding-guidelines.md
enforcement: required
---

# 보안 취약점 스캔

> ⚠️ **Standards 준수 필수** — 보안 점검 판단 기준은 standards를 우선 참고합니다.
> @standards/coding/coding-guidelines.md · @standards/api/api-design.md

프로젝트 코드를 정적 분석하여 보안 취약점을 탐지합니다.

$ARGUMENTS
- 인자가 **파일/디렉토리 경로**이면 → 해당 범위만 스캔
- 인자가 없으면 → 프로젝트 전체 스캔

## 절차

### 1. 프로젝트 컨텍스트 파악
- 사용 언어 및 프레임워크 식별
- 인증/인가 관련 코드 위치 파악
- 외부 입력 진입점 (Controller, API endpoint, form handler 등) 식별

### 2. 취약점 스캔 항목 (OWASP Top 10)

| 카테고리 | 탐지 대상 |
|---------|----------|
| **Injection** | SQL/command/LDAP/ORM injection |
| **인증 결함** | 하드코딩 credential, 약한 해시, 세션 관리 미흡 |
| **민감 데이터 노출** | 로그에 민감 정보, 평문 저장, 불충분한 암호화 |
| **XXE** | 안전하지 않은 XML 파서 설정 |
| **접근 제어** | 인가 검사 누락, IDOR, 경로 순회 |
| **보안 설정 오류** | DEBUG 모드, CORS 와일드카드, 불필요한 포트 노출 |
| **XSS** | innerHTML 직접 주입, 미이스케이프 템플릿, React 위험 HTML prop |
| **역직렬화** | 안전하지 않은 역직렬화 라이브러리 사용, yaml.load 미지정 로더 |
| **취약 컴포넌트** | 알려진 취약 버전 사용 |
| **로깅 부족** | 인증 실패/권한 변경 미로깅 |

### 3. 시크릿 탐지

- API 키, 토큰, 비밀번호 하드코딩
- .env 파일의 Git 추적 여부
- 프라이빗 키 파일 포함
- 패턴: `(password|secret|token|key|api_key)\s*[=:]\s*['"][^'"]+['"]`

### 4. 프레임워크별 추가 점검

- **Spring Boot**: CSRF, Security 설정, actuator 노출
- **Rails**: mass assignment, SQL injection, CSRF 토큰
- **Next.js/React**: 위험 HTML 주입 prop, SSR 데이터 노출, API route 인가
- **Express**: helmet, rate limiting, CORS 설정

## 출력 형식

```markdown
## 보안 스캔 결과

### 요약
- **스캔 범위**: [경로]
- **감지된 언어/프레임워크**: [목록]
- **위험 점수**: [0-100]
- **발견 항목**: Critical X / High X / Medium X / Low X

### Critical/High 발견 항목
| # | 카테고리 | 파일 | 줄 | 설명 | CWE |

(각 항목별 상세: 취약 코드 / 위험 / 수정 방안)

### Medium/Low 발견 항목
### 시크릿 탐지 결과
### 권장 조치 (우선순위순)
```
