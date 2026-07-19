---
name: review:all
description: 프로젝트 품질을 7개 영역(아키텍처/코드/테스트/보안/성능/회복탄력성/의존성)으로 병렬 분석
type: slash-command
category: review
follows-brain:
  - brain/CLAUDE.md
  - brain/coding/coding-guidelines.md
  - brain/testing/testing-guidelines.md
enforcement: required
---

# 프로젝트 리뷰 (오케스트레이터)

> ⚠️ **Brain 원칙 준수 필수** — 모든 sub-skill의 판단 기준은 standards를 우선합니다.
> @brain/CLAUDE.md · @brain/coding/coding-guidelines.md · @brain/testing/testing-guidelines.md

7개 sub-skill을 병렬 호출하여 프로젝트 품질 스냅샷을 생성합니다. 각 영역의 상세 기준과 체크리스트는 **sub-skill 파일이 단일 출처(SSOT)** 이며, 이 오케스트레이터는 얇은 래퍼입니다.

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
- brain 문서 경로 (`docs/brain/` 또는 cockpit의 `@brain/*`)

## Step 0.4: 캐시 체크 ("같은 커밋 = 같은 결과") ★

리뷰 결과를 **결정 축 `(트리 해시, 룰셋 버전, 모델 ID)`** 로 캐시합니다. 커밋이 바뀌지 않았으면 재리뷰하지 않고 캐시 스냅샷을 그대로 반환 → "돌릴 때마다 다름"의 절반을 제거.

```bash
# 캐시 키의 트리 해시는 **리뷰의 자기 산출물을 제외**하고 계산한다 —
# docs/review/(ledger·cache) 와 docs/process/cockpit-metrics.jsonl 을 포함하면,
# 스냅샷을 append 할 때마다 트리 해시가 바뀌어 연속 실행이 항상 MISS 가 된다
# (리뷰가 자기 캐시를 무효화하는 자기무력화 버그).
TREE=$(git ls-tree -r HEAD \
       | grep -vE '\bdocs/review/|\bdocs/process/cockpit-metrics\.jsonl' \
       | git hash-object --stdin)
# RULESET_VERSION 은 이 스킬과 함께 설치되므로 커맨드 설치 경로에서 읽는다.
RULESET=$(cat ~/.claude/commands/review/RULESET_VERSION 2>/dev/null \
       || cat .claude/commands/review/RULESET_VERSION 2>/dev/null || echo v1)
CACHE="docs/review/cache/${TREE}-${RULESET}.json"
[ -f "$CACHE" ] && echo "HIT → 캐시 반환" || echo "MISS → 리뷰 진행"
```
- 워킹트리 반영이 필요하면 `git ls-files` 기반으로 확장(스테이징 무관 현재 내용 해시).
- **부분 무효화**: diff 스코프면 변경 파일에 걸린 발견만 재평가하고 나머지는 캐시 재사용.
- 캐시 히트 시에도 리포트 상단에 `(cached: <commit>)` 를 명시.

## Step 0.5: 측정값 수집 (결정적 신호) ★

**오케스트레이터가 직접 도구를 1회 실행**해 재현 가능한 수치를 확보합니다. 이 수치를 Step 2의 6개 에이전트에 **공통 컨텍스트로 주입**합니다 — 에이전트는 이 값을 *해석*만 하고 스스로 baseline을 재발명하지 않습니다. (에이전트는 여전히 빌드/테스트를 직접 실행하지 않습니다.)

### 스택 자동 감지 → 명령 매핑

레포 루트의 마커 파일로 툴체인을 감지하고, 해당 명령만 실행합니다. **도구 부재·실패는 `n/a`로 기록**(스킵)하고 진행합니다.

| 스택 (마커) | lint | type | test | coverage | dep-audit | secret-scan | **complexity·size** |
|---|---|---|---|---|---|---|---|
| Python (`pyproject.toml`/`poetry.lock`) | `ruff check --output-format=concise` | `mypy .` | `pytest -q` | `pytest --cov --cov-report=term-missing` | `pip-audit` | `gitleaks detect --no-git` | `radon cc -s -n C .` · `lizard` |
| Node/TS (`package.json`) | `eslint . -f compact` | `tsc --noEmit` | `vitest run`/`jest` | `--coverage` | `npm audit --json` | `gitleaks detect` | `eslint complexity` · `lizard` |
| Kotlin/JVM (`build.gradle*`) | `ktlint`/`detekt` | (컴파일) | `gradle test` | `kover`/`jacoco` | `gradle dependencyCheckAnalyze` | `gitleaks detect` | `detekt`(CC·LongMethod) · `lizard` |
| Go (`go.mod`) | `golangci-lint run` | (build) | `go test ./...` | `-cover` | `govulncheck ./...` | `gitleaks detect` | `gocyclo -over 10` · `lizard` |
| Rust (`Cargo.toml`) | `cargo clippy` | (check) | `cargo test` | `tarpaulin` | `cargo audit` | `gitleaks detect` | `lizard` |

> 프로젝트별 러너 래퍼가 있으면 우선(`poetry run`, `pnpm`, `./gradlew`, `make lint` 등). 실행 시간이 길면(대형 test suite) `test`/`coverage`는 **변경 범위로 한정**하거나 스킵하고 그 사실을 명시.
> `lizard` 는 다언어 CC·함수 LOC·파라미터 수·중첩을 한 번에 주는 범용 폴백(대부분 objective 항목을 커버). 하나만 깔려도 code.md 의 objective 항목(#7·#8·#9·#10·#20·#22)이 진짜 objective 가 됩니다.

### objective 항목의 판정 주체 (중요) ★

**objective 티어 항목은 반드시 위 도구의 측정값으로만 판정**합니다. 도구가 없으면 그 항목을 `n/a` 로 두고 **LLM이 눈으로 세지 않습니다** — 눈대중으로 세는 순간 objective 가 아니라 evidence(주관)로 전락해 재현성이 깨집니다. 즉 "측정 못 하면 점수에서 빼되, 추측으로 채우지 말 것."

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
- complexity: <최대 CC / 평균 / n/a>  (objective 판정용 위반 목록 포함)
    - cc_gt_threshold: [funcA:12, funcB:8 …]     # brain 임계(기본 CC<5, 없으면 10) 초과 함수
    - func_loc_gt_20: [funcC:34 …]               # 함수 LOC>20
    - params_ge_5:   [funcD:6 …]                 # 파라미터 5개↑
    - nesting_ge_4:  [funcE:4 …]                 # 중첩 4단계↑
    - class_loc_max: <파일:줄수>                  # 최대 클래스 LOC (God Object 판정)
- diff-size: <+A −D, 파일 F개>
- scale-signals (scale.tier ≥ production 일 때만 측정, 아니면 전부 n/a):
    - timeout_missing:  [client.py:11 …]   # HTTP/DB 클라이언트 생성부 timeout 미명시 (grep)
    - retry_no_backoff: [sync.py:40 …]     # 백오프 없는 재시도 루프 (grep)
    - unbounded_query:  [report.py:14 …]   # LIMIT/페이지네이션 없는 목록 조회 (grep)
    - invalidate_all:   [cache.py:9 …]     # 전체 캐시 flush (grep)
    - metric_cardinality: [metrics.py:22 …] # 메트릭 라벨에 user_id/email/URL 원문 (grep)
    - explain: <seq scan N건 / n/a>         # hyperscale: diff 내 쿼리 EXPLAIN
    - loadtest: <p95 Xms (예산 Yms) / n/a>  # hyperscale: k6/vegeta 스모크 결과
```
> objective 항목은 위 **위반 목록 그대로가 findings** 가 됩니다(에이전트 재판정 없음). 예: `func_loc_gt_20`의 각 항목 → `low|code|foo.py:120|long-method|func LOC 34>20`.

`n/a`는 감점 사유가 아니라 "측정 불가"입니다. 점수를 깎지 말고 리포트에 그대로 노출해 재현성을 알립니다.

## Step 0.6: 유효 규칙 해결 (RULESET resolve + inject) ★

규칙도 METRICS 처럼 **"한 번 resolve 해서 주입"** 합니다 — 에이전트가 "cockpit vs 프로젝트 로컬 뭐가 우선?"을 각자 추측하면 판정이 흔들리기 때문. 오케스트레이터가 baseline 과 프로젝트 delta 를 **병합해 단일 RULESET 블록**으로 6개 에이전트에 공통 주입.

### 소스 (2개)
1. **base**: cockpit `@brain/*` (org baseline) — coding/testing/api/management
2. **override**: 프로젝트 로컬 규칙 (path-scoped delta). 없으면 base 만.
```bash
# 프로젝트 로컬 rules 수집 (cockpit submodule 제외). Claude Code 는 이들을
# path glob frontmatter 로 자동 로드하므로, 리뷰도 동일 소스를 명시적으로 병합한다.
find . -path '*/.claude/rules/*.md' -not -path '*/cockpit/*' -not -path '*/.git/*' 2>/dev/null
```

### 병합 규칙
- 로컬 rule 이 같은 항목을 정의 → **그 값 채택** + `[override]` + 근거(로컬 파일 경로) 명시
- 로컬에 없는 항목 → base 값 `[base]`
- 로컬 rule 의 `paths:` frontmatter 스코프 → **해당 경로 파일에만** override 적용(그 밖은 base)
- 모든 override·충돌은 RULESET 블록에 **그대로 노출**(숨기지 않음)

### RULESET 블록 (에이전트에 주입할 형식)
```text
RULESET (유효 규칙 — 이 값만 기준으로 판정, 재해석·추측 금지):
- source: base=cockpit@brain · overrides=[platform/account/.claude/rules/testing-strategy.md]
- scale.tier: hyperscale    [override: .claude/rules/scale.md] — 미선언 시 prototype (+ "티어 미선언" 리포트 명시)
- test.coverage_line: 80%   [override: testing-strategy.md — 근거: 레거시 모듈]
- test.mutation:      90%   [base: testing-guidelines]
- code.cc_max:        <5    [base: coding-guidelines]
- code.named_arg_newline: 필수 [base: coding-guidelines]
  … (판정에 쓰는 임계·규칙만, 스코프별로)
```

> **scale.tier** ★: @brain/engineering/reliability.md 의 티어 축. `prototype` 이면
> reliability 항목은 advisory 로 강등(과잉 규제 금지), `production`/`hyperscale` 이면 티어 열에
> 맞는 항목을 활성화. `hyperscale` 은 §게이트의 launch-readiness 4종과 가중치 프로파일도 바꾼다.
> 에이전트는 **RULESET + METRICS 두 장만** 기준으로 판정. "일반적으로 괜찮다"는 추측 금지. 로컬 rules 유무와 무관하게 **동일한 방식**으로 동작(로컬 rules 없는 프로젝트=base만, 있는 프로젝트=base⊕override 병합).

### 프로젝트 로컬 rules 계약 (delta-only) ★
병합이 깔끔하려면 로컬 규칙이 baseline 을 **복사하면 안 됩니다**(복사 = drift 원천). 프로젝트 `.claude/rules/X.md` 는:
1. frontmatter `paths:` (스코프)
2. `@brain/…/X.md` **import**(baseline 참조 — 복사 금지)
3. **프로젝트 delta**(override·추가)만

## Step 1: 모드·스코프 판별

- `$ARGUMENTS`에 `deep` 포함 → **심층 모드** / 아니면 **요약 모드**.
- `$ARGUMENTS`에 `full` 포함 → **레포 전체** / 아니면 **브랜치 diff**(`git diff --stat main...HEAD`; main 없으면 기본 브랜치 자동 감지).
- 경로 인자가 있으면 해당 경로로 스코프 한정.
- **스코프는 리포트 상단에 명시**하고, `full`이 아니면 에이전트에게 "**이번 변경(diff)에서 도입/영향받은 문제**에 집중하고, 기존 부채는 `[기존]`으로 태깅만" 하도록 지시.

## Step 2: 7개 sub-skill 병렬 호출

**반드시 하나의 메시지에서 7개 Agent tool을 동시에 호출**합니다. 각 sub-skill의 **Step 2 체크리스트와 Step 4 출력 형식**을 해당 sub-skill 파일에서 그대로 사용합니다 (중복 정의 금지).

| # | 영역 | Sub-skill | 위임 에이전트 (cockpit 자체) |
|---|------|-----------|--------------|
| 1 | 아키텍처 | @skills/review/architecture.md | `review-architecture` |
| 2 | 코드 품질 | @skills/review/code.md | `review-code` |
| 3 | 테스트 | @skills/review/test.md | `review-test` |
| 4 | 보안 | @skills/review/security.md | `review-security` |
| 5 | 성능·관측성 | @skills/review/performance.md | `review-performance` |
| 6 | 회복탄력성 | @skills/review/resilience.md | `review-resilience` |
| 7 | 의존성 | @skills/review/deps.md | `review-deps` |

> **에이전트 폴백 (clone-and-go 견고성)** ★: 위 위임 에이전트는 cockpit 자체 서브에이전트
> (`system/subagents/review-*.md`, global-install 로 `~/.claude/agents` 링크)입니다 — 전문
> 시스템 프롬프트(관여 계약·판정 앵커)가 recall 의 핵심 레버라 외부 플러그인 대신 자체 소유·자체
> 측정(골든셋)합니다. **미설치 환경에서는 `general-purpose` 로 폴백**하고, sub-skill 파일의
> 체크리스트·출력 형식(files_read 매니페스트 포함)을 프롬프트에 그대로 실어 동일 계약을 요구합니다.

### 공통 에이전트 지시

- **각 파일 정독 + files_read 매니페스트** ★: 디렉토리 목록·파일명만 보고 판단하지 말고, 스코프 내 파일을 실제로 **열어 읽는다**(특히 `import`·공유 가변 상태·쿼리·에러 처리·경로 기반 계층). 파일을 안 열고 `[]`(발견 없음)을 내는 관여 부족은 **리뷰 실패**다. (골든셋 실측: 정독 강제 시 탐지율 급상승 — 관여 2→9 tool-use, recall 0.43→1.0 의 핵심 레버) 각 에이전트는 결과 끝에 ` ```files_read ` 블록(읽은 파일 목록)을 **필수** 방출한다 — 정독을 선언이 아니라 **검증 가능한 산출물**로 만든다.
- **빌드/테스트 직접 실행 금지** — 코드 읽기 + **Step 0.5의 METRICS 블록 해석**만
- **점수는 METRICS를 앵커로**: 예 "lint 3건·CC max 7·coverage 71% → 82". 제공된 수치와 모순되는 점수 금지. 측정된 항목은 감(感)으로 덮어쓰지 말 것.
- **Step 0.6 RULESET 이 규칙의 단일 기준** ★: 체크리스트 기본 임계값이 RULESET 과 다르면 **RULESET 값을 채택**(예: RULESET `code.cc_max:<5` → 체크리스트 `≤10`을 덮어씀). RULESET 에 담긴 **프로젝트 고유 규칙**(인자 2개↑ named+개행, 검증 로직 도메인 캡슐화, Controller 반환 타입, Domain 프레임워크 의존 금지 등)은 **누락 없이 발견으로 방출**. cockpit vs 로컬 우선순위는 Step 0.6 이 이미 해결했으므로 **에이전트가 다시 판단하지 않는다** — RULESET 을 그대로 따른다. "일반적으로 괜찮다"고 봐주는 것이 리뷰어 간 판정 불일치의 주 원인.
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

### 정독 커버리지 게이트 (low-engagement 가드) ★
- **files_read 커버리지 판정 (objective)**: 각 에이전트의 `files_read` 를 스코프 파일 목록과 대조해 `커버리지 = |읽음 ∩ 스코프| / |스코프|` 를 계산한다. **커버리지 < 80%** 면 발견 유무와 무관하게 그 영역을 **1회 재실행** (누락 파일 목록을 명시해 "이 파일들을 마저 읽어라"). — "얕게 읽고 뭔가 찾은 척"까지 잡는다 (빈 결과만 보는 가드의 확장).
- evidence 티어 영역이 `[]`(발견 없음)을 반환하면, **관여 부족(파일 미정독)일 수 있으므로** 그 영역만 **1회 확인 재실행**한다: "스코프의 각 파일을 실제로 Read 했는지 확인하고, 그래도 없으면 `[]`".
- 두 결과의 **findings 합집합**을 채택(중복은 안정 키로 dedup, 거짓 발견은 Step 2.6 적대적 검증이 제거). 즉 재확인은 **recall 만 올리고 precision 은 검증이 지킨다**.
- 근거(골든셋 실측): 성능(동시성) 에이전트가 **같은 입력에 2 tool-use면 race 를 놓치고 15 tool-use면 잡음** — 빈 결과 1회 재확인이 이 flaky miss 를 흡수한다. (빈 결과에만 걸리므로 비용 증가 미미)

### (선택) 앙상블
- 점수 분산이 큰 영역(보안·아키텍처·**성능 동시성**)은 저-temperature로 **N=3 재실행 후 중앙값**(점수)·**합집합**(발견) 사용 가능. 리포트엔 `88±3`처럼 범위 표기. (기본 off — 비용 3배)

### 분석 깊이 가이드
- 소규모 (≤30 파일): 전체 분석
- 중규모 (30~100): 도메인/비즈니스 로직 전체 + 인프라 샘플링
- 대규모 (>100): 구조 파악 후 모듈별 대표 파일 심층

## Step 2.6: 적대적 검증 (High/Critical 강제) ★

발견의 최대 노이즈원은 **plausible-but-wrong**(그럴듯하지만 틀린) 발견입니다 — 한 실행엔 나오고 다른 실행엔 안 나와 점수를 흔듭니다. 이를 없애기 위해 **검증을 기본 on** 으로 강제합니다.

### 무엇을 검증하나 (confidence 부여 규칙)
| 발견 종류 | 검증 | confidence |
|---|---|---|
| **objective** (측정값 기반) | 검증 안 함 (측정이라 확실) | **1.0** |
| **evidence + severity ∈ {critical, high}** | **적대적 검증 필수** | 검증 결과(0~1) |
| **evidence + severity ∈ {medium, low}** | 단일 패스 (비용 절감) | 기본 **0.8** |

### 적대적 검증 방법
각 high/critical evidence 발견마다 **cockpit 자체 에이전트 `review-verifier`** (미설치 시 별도 general-purpose 에이전트)에 "이 발견을 반증하라" 를 지시:
```
입력: {file:line, category, 주장(summary), 근거}
지시: "이 주장을 반증하라. 코드를 다시 읽고 반례·오해·맥락 누락을 찾아라.
       기본 입장은 '반증'이며, 반증 못 할 때만 confirmed. 재현 시나리오를 1줄로."
출력: {verdict: confirmed|refuted, confidence: 0~1, reason, repro}
```
- **refuted 또는 confidence < 0.6 → 점수에서 제외**(리포트엔 "미확인 발견"으로만 노출).
- 확정된 것만 findings.json 의 `confidence` 로 들어가 Step 3 점수 스크립트에 투입.
- **비용 관리**: objective·medium·low 는 검증 안 함 → 검증 대상은 대개 소수(high/critical). 캐시 히트 시 0. 발견이 많으면 severity 상위 N개만 우선.
- **다수결(옵션)**: 특히 중요한 발견은 서로 다른 렌즈(정확성·보안·재현성)로 3인 검증 후 과반 confirmed.

> 이 단계가 "매번 다른 발견이 튀는" 현상의 핵심 방어선입니다. objective 는 측정이라 안 흔들리고, high/critical evidence 는 검증으로 걸러지고, medium/low 는 가중치가 낮아 영향이 작습니다.

> **검증자도 측정 대상** ★: 검증자가 진짜 결함을 refute 하면 recall 이 조용히 죽고, 오탐을
> confirm 하면 이 방어선이 무력화됩니다. 검증자 자체의 정답률은 골든셋의
> `verifier-cases.jsonl` + `eval_verifier.py` 로 잽니다 (모델·프롬프트 변경 시 재실행 —
> `system/review-fixtures/README.md` §검증자 골든셋).

## 점수 산정 규칙

**종합 점수 = 7개 영역 가중 평균** (단, 아래 게이트를 먼저 평가)

### 게이트 (스칼라보다 우선하는 불리언)
점수와 별개로 매 실행 아래를 boolean으로 판정해 리포트 상단에 표기:
- `test_green`: 실패/에러 0 (n/a면 `unknown`)
- `no_new_critical_high`: 이번 스코프에서 신규 Critical/High 발견 0
- `no_secret_leak`: secret-scan clean
- `coverage_not_dropped`: 원장 대비 coverage 하락 없음

**launch-readiness 게이트 (scale.tier = hyperscale 일 때만 추가)** — @brain/engineering/reliability.md §5:
- `slo_defined`: p95/에러율 예산이 숫자로 존재
- `load_tested`: 부하 측정값 존재 + p95 예산 이내. **측정 n/a = unknown 이 아니라 `false`** ("측정 없으면 스케일 판정 불가")
- `rollback_ready`: 롤백 기준 숫자 + 절차 존재
- `dashboards_exist`: 핵심 지표 대시보드·알림 존재

> **판단은 게이트 우선**: "90점"보다 "게이트 전부 통과 + 추세 개선"이 건강한 통과 기준입니다.

### 과락 — 약한 영역을 점수에 반영 (가중평균의 착시 제거) ★
가중평균은 **한 영역의 심각한 약점을 희석**한다 — 예: 성능이 61이어도 나머지가 95면
종합 ~92로 "괜찮아 보인다". **착시다.** 게이트(통과/실패)로 옆에 붙이는 대신 **점수 자체에 반영**한다:
- **과락 기준 = 영역 점수 80.** 한 영역이라도 80 미만이면 **과락**.
- **과락 시 종합 = 최저 영역 점수로 캡** (`종합 = min(가중평균, 최저영역)`). 약한 영역이
  종합을 끌어내려 높은 나머지가 가리지 못한다. 예: 성능 61·나머지 95 → **종합 61**(92 아님).
- **통과선 = 80.** 종합 ≥ 80 이어야 통과 (과락이 있으면 종합이 80 미만으로 떨어져 자동 미통과).
- 리포트는 종합 옆에 과락 영역 병기: `종합 61 (과락: 성능 61)`.

### 가중치 (scale.tier 프로파일) ★
티어가 리스크 순위를 바꾼다 — 하이퍼스케일에서 서비스를 죽이는 건 코드 위생이 아니라 시스템 결함이므로 가중치가 이동한다.

| 영역 | default (prototype/production) | hyperscale | 근거 |
|------|------|------|------|
| 보안 | 25% | 20% | 취약점은 즉시 영향 |
| 코드 품질 | 20% | 10% | 유지보수성·가독성 |
| 아키텍처 | 15% | 15% | 구조적 건전성 |
| 테스트 | 15% | 15% | 변경 안전망 |
| 성능·관측성 | 10% | 15% | 규모에서 병목·가시성 |
| 회복탄력성 | 10% | 20% | 장애 경로·멱등성 — 규모의 1차 사인(死因) |
| 의존성 | 5% | 5% | 외부 리스크 |

> 각 프로파일 합계 = **100%**. (6영역 시절 성능 15%로 합 105% 부풀림을 자기 리뷰로 잡았던 전례가 있으니, 프로파일 수정 시 스크립트의 assert 가 합=1.0 을 강제한다.)

- **종합 계산 (과락 캡 포함)**:
  1. `가중 = Σ(영역점수 × 티어 프로파일 가중치)`
  2. `종합 = min(가중, 최저영역)` **단 최저영역 < 80(과락)일 때만 캡**, 아니면 `종합 = 가중` (반올림)
- **통과선 = 80**: 종합 ≥ 80 이어야 통과. **상태**: 🟢 80+ / 🟡 60-79 / 🔴 <60

### 영역 점수는 LLM이 매기지 않는다 — 발견에서 결정적으로 계산 ★

LLM은 0~100 스칼라를 일관되게 못 매깁니다("82 vs 88"이 요동의 주범). 그러니 에이전트는 **점수를 말하지 않고**, `findings` 블록에 `severity·confidence·evidence`만 냅니다. **오케스트레이터가 아래 공식으로 계산**합니다:

```
severity_penalty = {critical: 25, high: 12, medium: 5, low: 1.5}
영역점수 = round( 100 − Σ(severity_penalty[f] × confidence[f]) )   # f = confidence ≥ 0.6 인 confirmed 발견
             , 0~100 로 clamp
```
- `confidence < 0.6` 발견은 점수 제외(리포트엔 "미확인"으로만) → 환각 발견이 점수를 흔들지 못함.
- METRICS의 결정적 신호(lint/test/audit/secret hit)는 **각각 하나의 발견으로 정규화**해 동일 공식에 투입(예: `high|deps|pyproject.toml|cve|aiohttp CVE-xxxx`). 즉 측정값이 자동으로 감점에 반영됨.
  - **lint 은 실결함만 objective — 순수 스타일은 advisory (2026-07-19 승격)**: `F`(미정의/미사용)·`B`(버그류)·보안 규칙은 점수 반영. 줄길이(E501)·상수 대문자(N806)·예외 명명(N818)·`dict()`(C408) 같은 **포매터가 잡거나 의도적인 스타일**은 advisory — 큰 코드베이스에서 스타일 hit 수십 개가 area 를 노이즈로 눌러 재현성이 아니라 크기를 재는 것이 된다.
- 같은 발견 집합이면 **항상 같은 점수** — 리뷰어의 그날 기분이 사라짐.

> **크기 정규화 주의 (2026-07-19 승격) ★**: 이 공식은 **건당 감점 · 크기 무정규화**다 —
> 함수·파일이 많은 큰 코드베이스일수록 objective 위반의 꼬리(CC>임계·길이>절대선)가 길어져
> area 점수가 결함 밀도가 아니라 **크기**를 반영해 버린다. abillity-ai 실리뷰(2026-07-19)에서
> CC>10 함수 7개만으로 code 영역이 1점(false 과락)이 나왔다. 방어 3중:
> ① **CC 를 복잡도 1급 지표로**, 길이·파라미터는 CC 종속 advisory (code.md #7·#9 ★) — 이중 계상 제거.
> ② **순수 스타일 lint 는 advisory** (위 항목).
> ③ (권장·미구현) 대규모 레포는 objective 감점을 **함수 수/KLOC 로 정규화**하거나 상위 N개만
>    점수화 — 나머지는 원장에 `[기존]`으로 누적만. 정규화 도입 전까지는 ①②로 완화하고,
>    큰 레포의 code/objective 점수는 **추세(원장 diff)로 읽고 절대값 과신 금지**.

#### 산술은 LLM이 하지 않는다 — 스크립트로 계산 ★
발견을 `docs/review/findings.json`(배열: `{area,severity,confidence}`)으로 모은 뒤, **아래 스크립트를 실행해 점수를 산출**합니다(모델의 암산 금지 — 암산도 흔들림).
```python
# scripts: python3 - <tier> < findings.json  (아래 인라인 스크립트가 정본 — 별도 파일 없음)
import json,sys
TIER=(sys.argv[1] if len(sys.argv)>1 else "default")  # default | hyperscale
WEIGHTS={
  "default":    {"security":.25,"code":.20,"architecture":.15,"test":.15,
                 "performance":.10,"resilience":.10,"deps":.05},
  "hyperscale": {"security":.20,"code":.10,"architecture":.15,"test":.15,
                 "performance":.15,"resilience":.20,"deps":.05},
}
W=WEIGHTS["hyperscale" if TIER=="hyperscale" else "default"]
P={"critical":25,"high":12,"medium":5,"low":1.5}
FLOOR=80   # 과락 기준 · 통과선
for name,w in WEIGHTS.items():
    assert abs(sum(w.values())-1.0)<1e-9, f"가중치 합은 1.0 이어야 함: {name}"
F=json.load(sys.stdin)
if not isinstance(F, list): F = [F] if isinstance(F, dict) else []
area={}
for a in W:
    pen=sum(P[f.get("severity")]*f.get("confidence",1.0)
            for f in F if isinstance(f, dict) and f.get("area")==a and f.get("confidence",1.0)>=0.6 and f.get("severity") in P)
    area[a]=max(0,min(100,round(100-pen)))
weighted=round(sum(area[a]*w for a,w in W.items()))
min_area=min(area,key=area.get)          # 최저 영역
failing=[a for a in area if area[a]<FLOOR]  # 과락 영역
# 과락 시 종합을 최저 영역 점수로 캡 (약점을 가중평균이 가리지 못하게)
overall=min(weighted, area[min_area]) if area[min_area]<FLOOR else weighted
print(json.dumps({"tier":TIER,"overall":overall,"weighted":weighted,"area":area,
    "failing":failing,"passed":overall>=FLOOR},ensure_ascii=False))
```
> objective 발견은 confidence=1.0(측정이라 확실), evidence 발견은 검증 후 confidence(0.6~1.0). 이 스크립트 출력이 리포트의 점수이자 원장 `scores` 필드입니다. `failing`(과락 영역)·`passed`(종합≥80)도 함께 기록.

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
    "scores": {"overall": 91, "security": 93, "code": 90, "architecture": 88, "test": 90, "performance": 90, "resilience": 89, "deps": 85},
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

### 승격 넛지 (플라이휠 연결) ★
diff·게이트를 계산한 뒤, 아래 중 하나라도 해당하면 리포트에 **승격 넛지 한 줄**을 남긴다. **호출은 하지 않는다** — `/review:promote` 실행은 사람이 결정(승격은 사람 게이트).
- 같은 안정 키가 **원장 3개↑ 스냅샷에서 연속 `open`** (반복 부채 = 규칙화 자격)
- `no_new_critical_high` 게이트 **실패** (High+ 신규 = 1회로 즉시 자격)
- (골든셋을 함께 돌렸다면) `eval.py` **FAIL** (리뷰어 갭 = 체크리스트/픽스처 자격)

넛지는 **"언제 promote를 쓸지"** 힌트일 뿐. 무엇을·어떻게 승격할지는 `/review:promote`가 초안화하고 사람이 승인한다.

## Step 4: 통합 보고서 출력

6개 결과 + 원장 diff를 아래 형식으로 **직접** 작성합니다. 취합 에이전트를 추가 실행하지 않습니다.

```markdown
<thinking>
각 영역별 점수 취합 및 주요 발견 사항, 원장 상태 변화를 분석합니다.
스케일 티어에 따른 중점 항목을 확인합니다.
</thinking>
<execution>
# 프로젝트 리뷰 결과

**프로젝트**: [이름] | **범위**: [diff/full/경로] | **스택**: [언어/FW] | **모드**: 요약/심층 | **스케일 티어**: [prototype/production/hyperscale/미선언]

## 게이트
✅/❌ test_green · ✅/❌ no_new_critical_high · ✅/❌ no_secret_leak · ✅/❌ coverage_not_dropped
(hyperscale) ✅/❌ slo_defined · ✅/❌ load_tested · ✅/❌ rollback_ready · ✅/❌ dashboards_exist

## 측정 스냅샷 (METRICS)
lint N · type N · test P/F · coverage L% · dep-audit N · secret clean · diff +A/−D · scale-signals [요약 또는 n/a]

## 종합 점수: XX/100 (통과선 80 · 직전 YY → Δ±Z)  [과락 시: 종합 = 최저영역 XX (과락: <영역> XX) — 미통과]
> 가중 프로파일: [default: 보안25+코드20+아키15+테스트15+성능10+회복탄력성10+의존성5 | hyperscale: 보안20+코드10+아키15+테스트15+성능15+회복탄력성20+의존성5] = 100%

| 영역 | 점수(Δ) | 상태 | 앵커 근거 | 핵심 발견 |
|------|------|------|----------|----------|
| 아키텍처 | XX (±Z) | 🟢/🟡/🔴 | [측정 근거 1줄] | [1줄] |
| 코드 품질 | XX (±Z) | … | … | … |
| 테스트 | XX (±Z) | … | … | … |
| 보안 | XX (±Z) | … | … | … |
| 성능·관측성 | XX (±Z) | … | … | … |
| 회복탄력성 | XX (±Z) | … | … | … |
| 의존성 | XX (±Z) | … | … | … |

## 원장 변화
- ✅ 해결 N건: [요약]
- 🆕 신규 N건: [요약]
- ➖ 잔존 N건 (기존 부채 K건 포함)
- 🔍 미확인 N건 (적대적 검증에서 refuted/저confidence — 점수 제외, 참고용): [요약]
- 💡 승격 후보 N건 (3회↑ open / High+ 신규 / 골든셋 FAIL) — 있으면: `/review:promote` 고려 (없으면 이 줄 생략)

## Top 5 액션 아이템 (신규·High 우선)
| # | 영역 | 문제 | 영향도 | 권장 조치 |

## 드릴다운 추천
- 점수 낮은/신규 발견 많은 영역 → `/review:<영역>` 단독 실행
- 예: 테스트 65점 → `/review:test deep platform/account`
</execution>
```

> 마지막에 이번 스냅샷을 `docs/review/ledger.jsonl`에 append 했음을 한 줄로 확인.
