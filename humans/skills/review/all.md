---
name: review:all
description: 프로젝트 품질을 6개 영역(아키텍처/코드/테스트/보안/성능/의존성)으로 병렬 분석
type: slash-command
category: review
follows-standards:
  - standards/CLAUDE.md
  - standards/coding/coding-guidelines.md
  - standards/testing/testing-guidelines.md
enforcement: required
---

# 프로젝트 리뷰 (오케스트레이터)

> ⚠️ **Standards 준수 필수** — 모든 sub-skill의 판단 기준은 standards를 우선합니다.
> @standards/CLAUDE.md · @standards/coding/coding-guidelines.md · @standards/testing/testing-guidelines.md

6개 sub-skill을 병렬 호출하여 프로젝트 품질 스냅샷을 생성합니다. 각 영역의 상세 기준과 체크리스트는 **sub-skill 파일이 단일 출처(SSOT)** 이며, 이 오케스트레이터는 얇은 래퍼입니다.

> **설계 원칙 (점수 노이즈 억제)**: 점수는 *추측이 아니라 측정에서 파생*됩니다.
> ① Step 0.5에서 결정적 신호(lint·type·test·coverage·audit)를 **직접 측정**해 모든 에이전트에 공통 주입 → 같은 코드는 같은 점수.
> ② 스코프를 명시적으로 고정(기본 = 브랜치 diff) → 기존 부채와 이번 변경을 분리.
> ③ 발견을 **원장(ledger)** 에 누적 → 실행 간 `열림/해결/신규`를 diff. 스칼라 점수보다 원장이 1급 산출물.

$ARGUMENTS
- `deep` — 각 sub-skill을 심층 모드로 실행 (코드 예시 + 개선안 포함)
- `full` — 스코프를 **레포 전체**로 (기본은 브랜치 diff)
- **서비스명 또는 경로** — 해당 범위만 분석
- 인자 없음 → **브랜치 diff** 를 요약 모드로 분석
- 예: `/review:all`, `/review:all full`, `/review:all deep platform/account`

## Step 0: 프로젝트 컨텍스트 파악

분석 전에 아래를 한 번만 파악하고, **모든 sub-skill 호출에 동일한 한 줄 요약으로 전달**합니다.
- 언어, 프레임워크, 빌드 도구
- 디렉토리 구조 및 아키텍처 패턴
- standards 문서 경로 (`docs/standards/` 또는 cockpit의 `@standards/*`)

## Step 0.4: 캐시 체크 ("같은 커밋 = 같은 결과") ★

리뷰 결과를 **결정 축 `(트리 해시, 룰셋 버전, 모델 ID)`** 로 캐시합니다. 커밋이 바뀌지 않았으면 재리뷰하지 않고 캐시 스냅샷을 그대로 반환 → "돌릴 때마다 다름"의 절반을 제거.

```bash
TREE=$(git rev-parse HEAD^{tree})          # 워킹트리 반영하려면 git stash create 병행
# RULESET_VERSION 은 이 스킬과 함께 설치되므로 커맨드 설치 경로에서 읽는다
# (임의 프로젝트 CWD 에서 상대경로가 안 풀리는 문제 회피).
RULESET=$(cat ~/.claude/commands/review/RULESET_VERSION 2>/dev/null \
       || cat .claude/commands/review/RULESET_VERSION 2>/dev/null || echo v1)
CACHE="docs/review/cache/${TREE}-${RULESET}.json"
[ -f "$CACHE" ] && echo "HIT → 캐시 반환" || echo "MISS → 리뷰 진행"
```
- **부분 무효화**: diff 스코프면 변경 파일에 걸린 발견만 재평가하고 나머지는 캐시 재사용.
- 캐시 히트 시에도 리포트 상단에 `(cached: <commit>)` 를 명시.

## Step 0.5: 측정값 수집 (결정적 신호) ★

**오케스트레이터가 직접 도구를 1회 실행**해 재현 가능한 수치를 확보합니다. 이 수치를 Step 2의 6개 에이전트에 **공통 컨텍스트로 주입**합니다 — 에이전트는 이 값을 *해석*만 하고 스스로 baseline을 재발명하지 않습니다. (에이전트는 여전히 빌드/테스트를 직접 실행하지 않습니다.)

### 스택 자동 감지 → 명령 매핑

레포 루트의 마커 파일로 툴체인을 감지하고, 해당 명령만 실행합니다. **도구 부재·실패는 `n/a`로 기록**(스킵)하고 진행합니다.

| 스택 (마커) | lint | type | test | coverage | dep-audit | secret-scan |
|---|---|---|---|---|---|---|
| Python (`pyproject.toml`/`poetry.lock`) | `ruff check --output-format=concise` | `mypy .` | `pytest -q` | `pytest --cov --cov-report=term-missing` | `pip-audit` | `gitleaks detect --no-git` |
| Node/TS (`package.json`) | `eslint . -f compact` | `tsc --noEmit` | `vitest run`/`jest` | `--coverage` | `npm audit --json` | `gitleaks detect` |
| Kotlin/JVM (`build.gradle*`) | `ktlint`/`detekt` | (컴파일) | `gradle test` | `kover`/`jacoco` | `gradle dependencyCheckAnalyze` | `gitleaks detect` |
| Go (`go.mod`) | `golangci-lint run` | (build) | `go test ./...` | `-cover` | `govulncheck ./...` | `gitleaks detect` |
| Rust (`Cargo.toml`) | `cargo clippy` | (check) | `cargo test` | `tarpaulin` | `cargo audit` | `gitleaks detect` |

> 프로젝트별 러너 래퍼가 있으면 우선(`poetry run`, `pnpm`, `./gradlew`, `make lint` 등). 실행 시간이 길면(대형 test suite) `test`/`coverage`는 **변경 범위로 한정**하거나 스킵하고 그 사실을 명시.

### 측정 결과 블록 (에이전트에 주입할 형식)

```text
METRICS (측정 스냅샷 — 이 값을 점수의 앵커로 사용, 재측정 금지):
- scope: <diff:main...HEAD | full | path>
- lint: <오류 N건 / n/a> (top 규칙: E501×3, N818×2 …)
- type: <오류 N건 / n/a>
- test: <pass P / fail F / error E / n/a>
- coverage: <line L% / n/a> (무테스트 파일: a.py, b.py …)
- dep-audit: <CVE N건 (critical/high/moderate 분포) / n/a>
- secret-scan: <hit N건 / clean / n/a>
- complexity: <최대 CC / 평균 / n/a> (radon 등 있으면)
- diff-size: <+A −D, 파일 F개>
```

`n/a`는 감점 사유가 아니라 "측정 불가"입니다. 점수를 깎지 말고 리포트에 그대로 노출해 재현성을 알립니다.

## Step 1: 모드·스코프 판별

- `$ARGUMENTS`에 `deep` 포함 → **심층 모드** / 아니면 **요약 모드**.
- `$ARGUMENTS`에 `full` 포함 → **레포 전체** / 아니면 **브랜치 diff**(`git diff --stat main...HEAD`; main 없으면 기본 브랜치 자동 감지).
- 경로 인자가 있으면 해당 경로로 스코프 한정.
- **스코프는 리포트 상단에 명시**하고, `full`이 아니면 에이전트에게 "**이번 변경(diff)에서 도입/영향받은 문제**에 집중하고, 기존 부채는 `[기존]`으로 태깅만" 하도록 지시.

## Step 2: 6개 sub-skill 병렬 호출

**반드시 하나의 메시지에서 6개 Agent tool을 동시에 호출**합니다. 각 sub-skill의 **Step 2 체크리스트와 Step 4 출력 형식**을 해당 sub-skill 파일에서 그대로 사용합니다 (중복 정의 금지).

| # | 영역 | Sub-skill | 위임 에이전트 |
|---|------|-----------|--------------|
| 1 | 아키텍처 | @skills/review/architecture.md | `code-review-ai:architect-review` |
| 2 | 코드 품질 | @skills/review/code.md | `pr-review-toolkit:code-reviewer` |
| 3 | 테스트 | @skills/review/test.md | `backend-development:tdd-orchestrator` |
| 4 | 보안 | @skills/review/security.md | `pr-review-toolkit:silent-failure-hunter` |
| 5 | 성능·관측성 | @skills/review/performance.md | `backend-development:backend-architect` |
| 6 | 의존성 | @skills/review/deps.md | `backend-development:backend-architect` |

> **에이전트 폴백 (clone-and-go 견고성)** ★: 위 위임 에이전트는 외부 플러그인(pr-review-toolkit·backend-development·code-review-ai)에서 옵니다. **해당 플러그인이 설치돼 있지 않으면 `general-purpose` 에이전트로 폴백**하고, sub-skill 파일의 체크리스트·출력 형식을 프롬프트에 그대로 실어 동일 결과를 냅니다. 즉 이 스킬은 **cockpit 만 clone·install 해도 동작**하며, 전용 에이전트는 있으면 품질↑ 선택지입니다.

### 공통 에이전트 지시

- **빌드/테스트 직접 실행 금지** — 코드 읽기 + **Step 0.5의 METRICS 블록 해석**만
- **점수는 METRICS를 앵커로**: 예 "lint 3건·CC max 7·coverage 71% → 82". 제공된 수치와 모순되는 점수 금지. 측정된 항목은 감(感)으로 덮어쓰지 말 것.
- **프로젝트 standards 절대 우선** ★: 체크리스트 기본 임계값과 프로젝트 `@standards/coding/*`·`@standards/testing/*`·`@standards/api/*` 가 다르면 **standards 값을 채택**(예: standards가 `CC<5`면 체크리스트 `≤10`을 덮어씀). standards에만 있는 **프로젝트 고유 규칙**(인자 2개↑ named+개행, 검증 로직 도메인 캡슐화, Controller 반환 타입, Domain 프레임워크 의존 금지 등)은 **누락 없이 별도 발견으로 방출**. "일반적으로 괜찮다"는 이유로 standards 위반을 봐주지 말 것 — 이게 리뷰어 간 판정 불일치의 주 원인.
- 스코프가 `full`이 아니면: 이번 diff에서 **도입/영향받은** 문제 우선, 기존 부채는 `[기존]` 태그
- **기계 판독 발견 블록 필수** (원장용): 산문 결과 끝에 아래 fenced 블록 추가
  ````text
  ```findings
  severity|area|file:line|category|한 줄 요약
  high|security|scripts/x.sh:12|command-injection|source 로 .env 평가
  ```
  ````
  severity ∈ {critical, high, medium, low}. 발견 없으면 빈 블록.
- **1000자 이내** (요약) / **1800자 이내** (심층). sub-skill 파일의 Step 4 출력 형식 준수.

### (선택) 안정화 옵션
- 점수 분산이 큰 영역(보안·아키텍처)은 저-temperature로 **N=3 재실행 후 중앙값** 사용 가능. 리포트엔 `88±3`처럼 범위 표기.
- 각 발견에 **적대적 검증**(별도 에이전트가 반증 시도)을 붙이면 plausible-but-wrong 발견이 걸러져 점수가 안정화됨.

### 분석 깊이 가이드
- 소규모 (≤30 파일): 전체 분석
- 중규모 (30~100): 도메인/비즈니스 로직 전체 + 인프라 샘플링
- 대규모 (>100): 구조 파악 후 모듈별 대표 파일 심층

## 점수 산정 규칙

**종합 점수 = 6개 영역 가중 평균** (단, 아래 게이트를 먼저 평가)

### 게이트 (스칼라보다 우선하는 불리언)
점수와 별개로 매 실행 아래를 boolean으로 판정해 리포트 상단에 표기:
- `test_green`: 실패/에러 0 (n/a면 `unknown`)
- `no_new_critical_high`: 이번 스코프에서 신규 Critical/High 발견 0
- `no_secret_leak`: secret-scan clean
- `coverage_not_dropped`: 원장 대비 coverage 하락 없음

> **판단은 게이트 우선**: "90점"보다 "게이트 전부 통과 + 추세 개선"이 건강한 통과 기준입니다.

### 가중치
| 영역 | 가중치 | 근거 |
|------|--------|------|
| 보안 | 25% | 취약점은 즉시 영향 |
| 코드 품질 | 20% | 유지보수성·가독성 |
| 아키텍처 | 20% | 구조적 건전성 |
| 테스트 | 15% | 변경 안전망 |
| 성능·관측성 | 15% | 운영 가시성 |
| 의존성 | 10% | 외부 리스크 |

- **종합 계산**: `종합 = 보안×0.25 + 코드×0.20 + 아키텍처×0.20 + 테스트×0.15 + 성능×0.15 + 의존성×0.10` (반올림)
- **상태**: 🟢 80+ / 🟡 60-79 / 🔴 <60

### 영역 점수는 LLM이 매기지 않는다 — 발견에서 결정적으로 계산 ★

LLM은 0~100 스칼라를 일관되게 못 매깁니다("82 vs 88"이 요동의 주범). 그러니 에이전트는 **점수를 말하지 않고**, `findings` 블록에 `severity·confidence·evidence`만 냅니다. **오케스트레이터가 아래 공식으로 계산**합니다:

```
severity_penalty = {critical: 25, high: 12, medium: 5, low: 1.5}
영역점수 = round( 100 − Σ(severity_penalty[f] × confidence[f]) )   # f = confidence ≥ 0.6 인 confirmed 발견
             , 0~100 로 clamp
```
- `confidence < 0.6` 발견은 점수 제외(리포트엔 "미확인"으로만) → 환각 발견이 점수를 흔들지 못함.
- METRICS의 결정적 신호(lint/test/audit/secret hit)는 **각각 하나의 발견으로 정규화**해 동일 공식에 투입(예: `high|deps|pyproject.toml|cve|aiohttp CVE-xxxx`). 즉 측정값이 자동으로 감점에 반영됨.
- 같은 발견 집합이면 **항상 같은 점수** — 리뷰어의 그날 기분이 사라짐.

> sub-skill 파일의 "점수 규칙"은 이제 **어떤 위반이 어떤 severity인지**를 정의하는 용도이지, 스칼라를 직접 부르는 용도가 아닙니다.

### 체크리스트 항목 3층 (안정성의 핵심) ★

각 sub-skill의 체크리스트 항목은 **판정 방식**에 따라 3층으로 태깅됩니다. **점수는 objective + evidence 층만** 반영하고, advisory는 서술로만 노출 → 퍼지 판단이 숫자를 흔들지 못함.

| 층 | 판정 | 예 | 점수 |
|----|------|-----|------|
| **objective** | 측정값/grep **임계값을 코드가 판정** (100% 결정적) | `함수 LOC>20`, `CC>10`, lint hit, secret hit, CVE | ✅ |
| **evidence** | LLM 판정 + **file:line 증거 필수** + 적대적 검증 통과 | SRP 위반, 예외 삼키기, 도메인 경계 누수 | ✅ (confidence≥0.6) |
| **advisory** | 순수 설계 의견 | "우아한가", "관용적인가" | ❌ 서술만 |

원칙: **가능한 항목은 objective로 끌어내림**(퍼지 서술 대신 측정 임계값). objective 항목의 verdict는 METRICS 수치로 자동 결정되므로 LLM 재판정 불필요.

## Step 3: 발견 원장(ledger) 갱신 ★

6개 에이전트의 `findings` 블록을 합쳐 원장을 append/diff 합니다.

### 저장 위치·형식
- 경로: `docs/review/ledger.jsonl` (없으면 생성). 각 줄 = 1 스냅샷.
- 스냅샷 스키마:
  ```json
  {
    "commit": "<git rev-parse --short HEAD>",
    "at": "<date -u +%Y-%m-%dT%H:%M:%SZ>",
    "scope": "diff:main...HEAD",
    "gates": {"test_green": true, "no_new_critical_high": true, "no_secret_leak": true, "coverage_not_dropped": true},
    "scores": {"overall": 91, "security": 93, "code": 90, "architecture": 88, "test": 90, "performance": 90, "deps": 85},
    "findings": [
      {"key": "security:scripts/x.sh:command-injection", "severity": "high", "area": "security", "file": "scripts/x.sh:12", "summary": "…"}
    ]
  }
  ```
  > `commit`/`at`은 셸에서 `git rev-parse --short HEAD`·`date -u`로 채웁니다 (모델이 날짜를 지어내지 말 것).

### 안정 키 (원장 churn 방지) ★
발견을 표준 키로 정규화해야 "같은 이슈의 다른 표현"이 매번 신규로 튀지 않습니다.
```
key = f"{area}:{normalize_path(file)}:{category}:{rule_id or slug(summary)}"
```
- **라인 번호 제외** (흔들림 — 표시용으로만 보존)
- `normalize_path`: 리포 상대경로로 통일, 대소문자·후행슬래시 정리
- `category`: 소문자 + 동의어 사전 매핑(`command-injection`=`cmd-inj`=`shell-injection`)
- `rule_id`: 도구 규칙 코드(있으면 우선, 예 `ruff:E501`, `cve:CVE-2024-xxxx`) → 가장 안정적
- 없으면 `slug(summary)`: 요약을 소문자·불용어 제거·상위 N토큰으로 슬러그화
- 키 생성 후 **의미 유사도 dedup**(코사인/자카드 임계값)로 잔여 중복 병합

### diff 로직
- 직전 스냅샷과 안정 키로 비교:
  - `해결(fixed)`: 이전엔 있고 이번엔 없음
  - `신규(new)`: 이번에 처음 등장
  - `잔존(open)`: 양쪽 다 존재
- 이 3분류가 스칼라 점수보다 안정적인 신호 — 리포트의 핵심.

## Step 4: 통합 보고서 출력

6개 결과 + 원장 diff를 아래 형식으로 **직접** 작성합니다. 취합 에이전트를 추가 실행하지 않습니다.

```markdown
# 프로젝트 리뷰 결과

**프로젝트**: [이름] | **범위**: [diff/full/경로] | **스택**: [언어/FW] | **모드**: 요약/심층

## 게이트
✅/❌ test_green · ✅/❌ no_new_critical_high · ✅/❌ no_secret_leak · ✅/❌ coverage_not_dropped

## 측정 스냅샷 (METRICS)
lint N · type N · test P/F · coverage L% · dep-audit N · secret clean · diff +A/−D

## 종합 점수: XX/100  (직전 YY → Δ±Z)
> 가중 평균: 보안(25%)+코드(20%)+아키텍처(20%)+테스트(15%)+성능(15%)+의존성(10%)

| 영역 | 점수(Δ) | 상태 | 앵커 근거 | 핵심 발견 |
|------|------|------|----------|----------|
| 아키텍처 | XX (±Z) | 🟢/🟡/🔴 | [측정 근거 1줄] | [1줄] |
| 코드 품질 | XX (±Z) | … | … | … |
| 테스트 | XX (±Z) | … | … | … |
| 보안 | XX (±Z) | … | … | … |
| 성능·관측성 | XX (±Z) | … | … | … |
| 의존성 | XX (±Z) | … | … | … |

## 원장 변화
- ✅ 해결 N건: [요약]
- 🆕 신규 N건: [요약]
- ➖ 잔존 N건 (기존 부채 K건 포함)

## Top 5 액션 아이템 (신규·High 우선)
| # | 영역 | 문제 | 영향도 | 권장 조치 |

## 드릴다운 추천
- 점수 낮은/신규 발견 많은 영역 → `/review:<영역>` 단독 실행
- 예: 테스트 65점 → `/review:test deep platform/account`
```

> 마지막에 이번 스냅샷을 `docs/review/ledger.jsonl`에 append 했음을 한 줄로 확인.
