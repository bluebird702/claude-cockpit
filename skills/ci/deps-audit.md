---
name: ci:deps-audit
description: 의존성 보안 취약점, 라이선스, 업데이트 필요성 감사
type: slash-command
category: ci
follows-standards:
  - standards/CLAUDE.md
enforcement: required
---

# 의존성 감사

> ⚠️ **Standards 준수 필수** — 버전/라이선스 정책은 standards를 우선 참고합니다.
> @standards/CLAUDE.md

프로젝트의 모든 의존성을 분석하여 보안 취약점, 라이선스 문제, 업데이트 필요성을 점검합니다.

$ARGUMENTS
- 인자가 **경로**이면 → 해당 디렉토리의 의존성만 분석
- 인자가 없으면 → 프로젝트 전체 의존성 분석

## 절차

### 1. 의존성 파일 수집

| 생태계 | 대상 파일 |
|--------|----------|
| JVM (Gradle) | `build.gradle.kts`, `build.gradle`, `libs.versions.toml` |
| JVM (Maven) | `pom.xml` |
| Ruby | `Gemfile`, `Gemfile.lock` |
| Node.js | `package.json`, `package-lock.json`, `yarn.lock` |
| Python | `requirements.txt`, `pyproject.toml`, `Pipfile` |
| Go | `go.mod` |
| Rust | `Cargo.toml` |

### 2. 보안 취약점 스캔

```bash
npm audit --json
bundle audit check
./gradlew dependencyCheckAnalyze
pip-audit
```

도구 실행이 불가능하면 의존성 파일을 직접 읽고 주요 라이브러리의 알려진 취약점을 확인합니다.

### 3. 버전 분석
- 현재 버전 vs 최신 버전
- Major 버전 차이 (브레이킹 체인지)
- EOL 버전 사용 여부

### 4. 라이선스 점검
- 라이선스 식별
- 상용 비호환 라이선스 탐지 (GPL, AGPL 등)
- 라이선스 불명 패키지 식별

### 5. 공급망 위험
- 최근 2년 이상 업데이트 없음
- 직접 의존성 대비 전이 의존성 비율
- 단일 유지보수자에 의존하는 핵심 패키지

## 출력 형식

```markdown
## 의존성 감사 결과

### 요약
- **스캔 범위**: [경로 목록]
- **감지된 생태계**: [목록]
- **총 직접 의존성**: X개
- **보안 취약점**: Critical X / High X / Medium X / Low X
- **라이선스 문제**: X개
- **업데이트 필요**: X개

### 보안 취약점
| 패키지 | 현재 버전 | 심각도 | CVE | 수정 버전 | 생태계 |

### 업데이트 권장
| 우선순위 | 패키지 | 현재 | 최신 | 차이 | 사유 |

### 라이선스 현황
| 라이선스 | 패키지 수 | 상용 호환 | 비고 |

### 공급망 위험
### 권장 조치
```
