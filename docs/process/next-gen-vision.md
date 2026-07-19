# AI-Native Repository Vision & Roadmap

> **Meta-Instruction for AI Agents**: 
> 이 문서는 `claude-cockpit`의 차세대(Next-Gen) 진화를 위한 아키텍처 명세서이자 마스터 플랜입니다. 미래의 AI 에이전트(Claude, Gemini 등)가 이 문서를 읽고 새로운 기능을 구현할 때, **반드시 각 Feature의 `Implementation Strategy`와 `Constraints`를 준수**하여 개발해야 합니다. 작업을 시작하기 전, 이 문서를 Single Source of Truth(SSOT)로 삼아 설계의 의도를 파악하십시오.

---

## 1. Manifesto (핵심 철학 및 비전)

**"코드를 담는 저장소(Repository)에서, 기획부터 운영까지 IT 프로덕트의 전 주기(Full-Lifecycle)를 통달한 순수 AI 노하우의 집결지로."**

`claude-cockpit`은 단순한 코드 검열 스크립트나 특정 플랫폼에 종속된 부품이 아닙니다. 우리의 목표는 **전 세계 누구나 다운로드하면 기획(Ideation), 설계(Design), 코딩(Dev), 검증(Review), 문서화(Docs), 운영(Prod)**에 이르는 소프트웨어 엔지니어링의 모든 단계를 세계 최고 수준의 AI와 함께 수행할 수 있게 만드는 **'플랫폼 불가지론적(Platform-Agnostic) 오픈소스 플레이북'**을 완성하는 것입니다.

---

## 2. 3단계 진화 로드맵 (The 3-Phase Roadmap)

총 10가지의 혁신 과제(Core Pillars)는 의존성에 따라 3단계로 나뉘어 구현됩니다.

### Phase 1: Zero-Config Intelligence (제로 컨피그 지능)
목표: 설치 즉시 환경을 100% 자동 인식하고, AI의 인지 능력을 최대로 끌어올리는 기반을 마련한다.

#### Feature 1.1: 생각의 구조화 강제 (Chain-of-Thought Protocol)
*   **Context:** AI가 계획 없이 즉흥적으로 코드를 짜서 발생하는 퀄리티 저하 방지.
*   **Implementation Strategy:** `skills/_template.md` 및 모든 하위 스킬 프롬프트에 `<thinking>`, `<plan>`, `<execution>` XML 태그 구조를 의무적으로 사용하도록 지시문 삽입.
*   **Constraints:** `<thinking>` 과정 없이 출력된 최종 산출물은 린터(Linter) 단계에서 강제 실패 처리(Reject)되어야 함.
*   **Definition of Done (DoD):** 임의의 `/review:all` 실행 시, 모델이 반드시 자신의 판단 근거를 `<thinking>` 블록에 명시한 후 결과를 반환하는지 자동 검증(`eval.py`).

#### Feature 1.2: 환경 자동 인식 (Zero-Shot Auto-Calibration)
*   **Context:** 사용자의 개입 없이 프로젝트의 규모와 복잡도를 파악하여 AI의 엄격도 조절.
*   **Implementation Strategy:** `scripts/bootstrap.sh` 단계에서 LOC(Lines of Code), 쿠버네티스 매니페스트 유무, 패키지 개수를 스캔하여 `scale.tier` (prototype / production / hyperscale)를 자동 판별 후 `system/settings.json` 또는 로컬 규칙에 동적 주입.
*   **Constraints:** 환경 감지 로직은 5초 이내에 완료되어야 하며(`jq` 및 기본 shell 명령어 활용), 오판 시 사용자가 쉽게 오버라이드 가능해야 함.
*   **DoD:** 대규모 레포에서 설치 시 자동으로 `scale.tier: hyperscale`이 적용되어 규칙 가중치가 변경됨을 확인.

#### Feature 1.3: MCP 오토 디스커버리 (Auto-Discovery)
*   **Context:** AI의 도구(Tools) 설정을 수동으로 해야 하는 병목 제거.
*   **Implementation Strategy:** 레포지토리 내 `.git/config`, `package.json`, `pyproject.toml` 등을 스캔하여 필요한 MCP 서버(GitHub, Linter, JIRA 등)를 찾아내고 `servers.json`을 자동 구성하는 훅 작성.
*   **Constraints:** 자동 추가되는 MCP 서버는 반드시 보안 설정(버전 핀 고정, Secret Flag) 규약(cockpit.md §5)을 통과해야 함.
*   **DoD:** 설치 후 `servers.json`에 환경에 맞는 필수 도구가 에러 없이 자동 매핑됨.

#### Feature 1.4: 컨텍스트 증류 및 압축 (Context Distillation)
*   **Context:** 여러 파일에 흩어진 Standards로 인한 AI의 어텐션(Attention) 분산 및 토큰 낭비 해결.
*   **Implementation Strategy:** `install.sh` 실행 시, 해당 프로젝트 환경에 가장 중요한 핵심 룰만 추출(Distillation)하여 단일 고밀도 파일(`.claude/context_payload.md`)로 렌더링.
*   **Constraints:** 압축 과정에서 보안(Security) 관련 필수 규정은 절대 생략되어서는 안 됨.
*   **DoD:** 압축된 단일 프롬프트를 사용하여 리뷰를 수행했을 때, `eval.py`의 Precision/Recall이 분산된 문서를 읽었을 때와 동등하거나 더 높음을 증명.

---

### Phase 2: Autonomous Execution (자율 실행과 증명)
목표: 정적 분석의 한계를 넘어, 코드를 직접 실행하고 스스로 비판 및 치유하는 시스템 완성.

#### Feature 2.1: 내부 비판자 탑재 (Auto-Critic & Verifier)
*   **Context:** AI가 생성한 초안의 오류(Hallucination)를 사용자에게 노출하기 전 1차단.
*   **Implementation Strategy:** 코드 Write/Edit 액션 발생 시, 백그라운드의 `review-verifier` 에이전트가 가로채어 "이 변경사항을 반증하라"는 적대적 검증(Adversarial Verification) 수행.
*   **Constraints:** 검증에 소요되는 추가 시간 제어 및 API 비용 한도 설정.
*   **DoD:** 의도적으로 결함이 있는 코드를 AI가 작성하도록 유도했을 때, Auto-Critic이 이를 감지하고 수정을 강제하는 워크플로우 통과.

#### Feature 2.2: 동적 샌드박싱 (Dynamic Sandboxing)
*   **Context:** 눈으로 읽는 정적 리뷰(Static Analysis)의 한계를 극복. 오탐(FP)률 제로화.
*   **Implementation Strategy:** 의심스러운 로직 발견 시, Docker/Colima 기반의 일회성 격리 컨테이너를 띄워 단위 테스트(또는 퍼징) 코드를 자동 생성 및 실행하여 버그를 '수학적으로 증명'함.
*   **Constraints:** 샌드박스 컨테이너는 호스트의 민감 파일 시스템 및 네트워크에 접근할 수 없도록 철저히 격리(Air-gapped)되어야 함.
*   **DoD:** Race Condition이 있는 코드를 샌드박스에서 100회 실행하여 실패 로그를 증거(Proof)로 첨부한 리뷰 결과 생성.

#### Feature 2.3: 자동 치유 파이프라인 (Self-Healing)
*   **Context:** 문제 지적을 넘어 스스로 기술 부채를 청산하는 자율 조직 완성.
*   **Implementation Strategy:** 백그라운드 Subagent가 `docs/review/ledger.jsonl`의 `open` 상태 부채를 주기적으로 읽어 들여 스스로 코드를 리팩터링하고, 테스트(샌드박스)를 돌린 뒤 PR을 생성.
*   **Constraints:** 치유된 코드는 반드시 기존 테스트 코드를 100% 통과해야 하며(Regression 금지), PR 설명에 해결된 부채 ID 명시.
*   **DoD:** 원장에 남겨진 "미사용 변수"나 "단순 Lint 에러"를 AI가 백그라운드에서 자동 수정하여 성공적으로 PR을 생성함.

---

### Phase 3: Fleet Scale & Evolution (전사적 확장 및 진화)
목표: 개별 프로젝트를 넘어 전사(Organization) 단위의 지식 공유 및 보안 면역 체계 구축.

#### Feature 3.1: 로컬 RAG (Semantic Memory) 도입
*   **Context:** 방대한 사내 문서 및 과거 장애 기록을 AI의 프롬프트에 모두 담을 수 없는 한계 극복.
*   **Implementation Strategy:** 로컬 Vector DB(예: Chroma, FAISS, 또는 `context7` MCP 활용)를 연동하여, 코드 리뷰 시 관련된 과거 ADR(Architecture Decision Record) 및 장애 포스트모템을 실시간 검색(Retrieval) 후 주입.
*   **Constraints:** RAG 시스템 도입이 기존 리뷰 파이프라인의 속도를 크게 저하시켜서는 안 됨(빠른 P95 응답 속도).
*   **DoD:** 특정 도메인 로직 수정 시, 관련된 사내 문서가 RAG를 통해 자동으로 프롬프트에 포함되어 리뷰 품질이 향상됨을 확인.

#### Feature 3.2: 적대적 Red Teaming 에이전트
*   **Context:** 수동적 보안을 넘어, 24시간 능동적으로 취약점을 찾는 면역 체계 구축.
*   **Implementation Strategy:** 해커 페르소나를 가진 에이전트를 상시 가동하여, 프롬프트 인젝션 우회, 권한 우회 시나리오 등을 끊임없이 퍼징(Fuzzing)하고 취약점 발견 시 원장(`ledger.jsonl`)에 Critical로 등록.
*   **Constraints:** Red Teaming 과정에서 운영(Production) 환경 또는 실제 리소스에 어떠한 사이드 이펙트(Side Effect)도 주어서는 안 됨(Safe Mode).
*   **DoD:** 의도적으로 삽입된 Prompt Injection 벡터를 Red Teaming 에이전트가 스캔하여 사전에 찾아냄.

#### Feature 3.3: 전사 관제 대시보드 (Global Observability)
*   **Context:** 수십~수백 개의 저장소에 분산된 AI 지표를 중앙에서 통제.
*   **Implementation Strategy:** 개별 `cockpit-metrics.py`의 결과를 중앙 텔레메트리 서버(Datadog, Grafana 등)로 전송. 리더십에서 조직 전체의 AI 룰 준수율과 부채 추이를 모니터링하고 중앙에서 룰셋(`RULESET_VERSION`) 일괄 업데이트.
*   **Constraints:** 전송되는 메트릭 데이터에는 소스코드 원문이나 민감한 시크릿 정보가 절대 포함되지 않도록 마스킹 처리 필수.
*   **DoD:** 3개 이상의 로컬 저장소에서 발생한 리뷰 메트릭이 중앙 대시보드용 JSON으로 성공적으로 집계(Aggregation)됨.

---

## 🤖 Meta-Instructions for Implementing Agents
(이 문서를 바탕으로 코드를 작성할 AI 에이전트 전용 지침)

1. **Step-by-Step Execution:** 반드시 Phase 1부터 구현을 시작하십시오. Phase 1이 안정화되지 않은 상태에서 Phase 2를 시도하지 마십시오.
2. **Regression Prevention:** 새로운 기능을 구현할 때마다 기존의 `bash -n`, `scripts/lint-skills.sh`, `system/review-fixtures/eval.py` 테스트를 모두 돌려 통과(PASS)하는지 확인해야 합니다.
3. **Type Safety:** 파이썬 스크립트를 작성할 때는 이전 보안 패치(커밋 `2e13e01`)의 교훈을 잊지 마십시오. LLM이 생성한 JSON 데이터를 다룰 때는 맹목적으로 타입을 신뢰하지 말고 반드시 엄격한 타입 체킹(`isinstance`)을 거치십시오.
4. **Idempotency:** 스크립트 작성 시 멱등성을 보장해야 합니다. 여러 번 실행해도 동일한 결과를 낳도록 설계하십시오 (`set -euo pipefail` 준수).


