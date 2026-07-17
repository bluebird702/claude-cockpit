---
name: review:deps
description: 의존성 보안 취약점·라이선스·업데이트 필요성·공급망 위험 감사
type: slash-command
category: review
follows-standards:
  - standards/CLAUDE.md
  - standards/management/security.md
  - standards/hard-won-conventions.md
enforcement: required
---

# 의존성 리뷰

> ⚠️ **Standards 준수 필수** — 버전/라이선스 정책은 standards를 우선합니다.
> @standards/management/security.md(§의존성 — 감사 주기·critical 24h/moderate 1주 SLA·버전 핀) · @standards/hard-won-conventions.md(§공급망·실행 신뢰) · @standards/CLAUDE.md

프로젝트의 모든 의존성을 분석하여 보안 취약점(CVE), 라이선스 호환성, 업데이트 필요성, 공급망 위험을 점검합니다.

$ARGUMENTS
- `deep` — 심층 모드 (패키지별 상세 + 마이그레이션 가이드)
- **경로** — 해당 디렉토리의 의존성만 분석
- 인자 없음 → 프로젝트 전체 의존성
- 예: `/review:deps`, `/review:deps deep services/api`

## Step 1: 의존성 파일 수집

| 생태계 | 대상 파일 |
|--------|----------|
| JVM (Gradle) | `build.gradle.kts`, `build.gradle`, `libs.versions.toml` |
| JVM (Maven) | `pom.xml` |
| Ruby | `Gemfile`, `Gemfile.lock` |
| Node.js | `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` |
| Python | `requirements.txt`, `pyproject.toml`, `Pipfile`, `poetry.lock` |
| Go | `go.mod`, `go.sum` |
| Rust | `Cargo.toml`, `Cargo.lock` |
| PHP | `composer.json`, `composer.lock` |

## Step 2: 체크리스트 (4개 카테고리)

### A. 보안 취약점 (CVE)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 1 | 알려진 CVE | 현재 버전에 해당하는 Critical/High CVE (CVE DB 대조, 측정) | objective | critical |
| 2 | 수정 버전 존재 | 패치가 나와 있는지, 호환성 있는 최소 업그레이드 (측정) | objective | high |
| 3 | 전이 의존성 CVE | 직접 의존성을 통한 간접 노출 (측정) | objective | high |
| 4 | 도구 실행 | `npm audit`, `bundle audit`, `pip-audit`, `./gradlew dependencyCheckAnalyze` (가능 시, 측정) | objective | high |

도구 실행이 불가능하면 의존성 파일을 직접 읽고 주요 라이브러리의 알려진 취약점을 확인합니다.

### B. 버전·업데이트 (4)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 5 | 최신성 | 현재 vs 최신 버전 차이 (측정) | objective | low |
| 6 | Major 버전 차이 | 브레이킹 체인지 존재 여부, 마이그레이션 가이드 (major diff 측정) | objective | medium |
| 7 | EOL 버전 | 지원 종료된 버전 사용 (EOL 데이터 대조, 측정) | objective | high |
| 8 | LTS 트랙 | LTS 사용 여부 (Node, Java, Spring 등, 측정) | objective | low |

### C. 라이선스 (3)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 9 | 라이선스 식별 | 각 패키지의 라이선스 (메타데이터 측정) | objective | medium |
| 10 | 상용 호환성 | GPL/AGPL 등 상용 배포 제약 라이선스 탐지 (측정) | objective | high |
| 11 | 불명 라이선스 | 라이선스 미표기 패키지 (측정) | objective | medium |

### D. 공급망 위험 (4)
| # | 항목 | 점검 내용 | Tier | Sev |
|---|------|----------|------|-----|
| 12 | 유지보수 상태 | 최근 2년 이상 업데이트 없음 (last update 측정) | objective | medium |
| 13 | 단일 유지보수자 | 버스 팩터 1인 핵심 패키지 | evidence | low |
| 14 | 전이/직접 비율 | 직접 의존성 대비 전이 의존성 규모 (비율 측정) | objective | low |
| 15 | 타이포스쿼팅 | 유사 이름 악성 패키지 (특히 Node/Python) | evidence | high |

> Tier=objective 는 METRICS 수치로 자동 판정, evidence 는 증거+검증, advisory 는 점수 제외.

## Step 3: 에이전트 위임

**cockpit 자체 에이전트 `review-deps`** 에게 위임 (미설치 시 `general-purpose` 폴백 —
이 파일의 체크리스트·출력 형식을 프롬프트에 그대로 실음). 프롬프트에 포함:
- Step 1 수집 결과
- Step 2 전체 체크리스트
- standards의 버전/라이선스 정책
- Step 4 출력 형식 지시

**빌드/설치 실행 금지** (audit 도구 실행은 허용하되 실패 시 정적 분석으로 대체).

## 점수 산정 (all.md 가 계산)

이 스킬은 점수를 직접 매기지 않는다. 체크리스트 위반을 **findings 블록**으로 방출하고,
종합/영역 점수는 오케스트레이터(all.md)가 `100 − Σ(severity_penalty × confidence)` 로
결정적으로 계산한다.

- **objective 항목**: Step 0.5 METRICS 수치로 verdict 자동 결정 (LLM 재판정 금지)
- **evidence 항목**: file:line 증거가 있을 때만 발견으로 기록 (confidence 부여, 적대적 검증 대상)
- **advisory 항목**: 서술로만 노출, 점수에서 제외
- **N/A**: 언어·스택상 비해당 항목은 `n/a` (감점 아님, 재현성 위해 노출)
- **CVE 확인(#1~#3)**: audit 도구 실행 불가 시 의존성 파일의 버전과 알려진 취약점을 지식 기반으로 대조. 도구 실행 결과와 차이가 있을 수 있으므로 결과에 명시

## Step 4: 출력 형식

```markdown
## 의존성 리뷰 결과

### 요약
- **스캔 범위**: [경로 목록]
- **감지된 생태계**: [목록]
- **총 직접 의존성**: X개 / **전이 의존성**: X개
- **라이선스 문제**: X개
- **업데이트 필요**: X개

### 발견 요약
- critical N · high N · medium N · low N  (점수는 all.md 가 findings 로 계산)

### 보안 취약점
| 패키지 | 현재 | 심각도 | CVE | 수정 버전 | 생태계 |

### 업데이트 권장 (우선순위순)
| 우선순위 | 패키지 | 현재 | 최신 | 차이 | 사유 |

### 라이선스 현황
| 라이선스 | 패키지 수 | 상용 호환 | 비고 |

### 공급망 위험
| # | 패키지 | 위험 유형 | 권장 조치 |

### 권장 조치 (단계별)
1. 즉시 (Critical CVE):
2. 단기 (High CVE / EOL):
3. 중기 (Major 업그레이드):
4. 모니터링 (유지보수 위험):
```

### findings (기계 판독 — 원장용, 필수)
```findings
severity|area|file:line|category|한 줄 요약
```
severity ∈ {critical,high,medium,low}. area 는 이 스킬 영역(deps). 발견 없으면 빈 블록.

## Step 5: 드릴다운

- 코드 레벨 보안 이슈 → `/review:security`
- 의존성 교체가 구조 변경 유발 → `/review:architecture`
- 전체 품질 현황 → `/review:all`
