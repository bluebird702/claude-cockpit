# Abillity-AI Integration & Risk Mitigation Strategy

> **Meta-Instruction for AI Agents**:
> 이 문서는 `claude-cockpit`과 `abillity-ai`의 결합 과정에서 발생할 수 있는 치명적인 아키텍처 및 비즈니스 리스크를 통제하기 위한 개선 지침입니다. 코드를 수정하거나 새로운 룰을 작성할 때 이 기준을 최우선으로 적용하십시오.

---

## 1. 프롬프트 및 프로토콜 호환성 방어 (Versioning Risk)
**현황:** `cockpit`의 자연어 프롬프트나 출력 포맷(XML 등)이 변경되면 `abillity-ai`의 파서(Parser)가 붕괴될 위험이 높음.
**개선 사항:**
- **출력 포맷의 스키마화:** AI가 뱉어내는 행동 강령(Action Trigger)은 반드시 JSON Schema 또는 정형화된 XML 형태로 `cockpit`에 명시되어야 함.
- **Prompt SemVer 도입:** `cockpit`의 핵심 프롬프트(예: `all.md`)가 변경될 때마다 버전(예: `v2.1.0`)을 명시하여, `abillity-ai` 엔진이 자신이 지원하는 프롬프트 버전인지 검증할 수 있도록 강제.

## 2. 속도와 비용 최적화 (Latency & Cost)
**현황:** 다중 에이전트 오케스트레이션 및 샌드박스 반복 실행은 토큰 비용과 대기 시간을 기하급수적으로 증가시킴.
**개선 사항:**
- **Tier 기반 조기 종료(Early Exit):** `prototype` 티어에서는 적대적 검증(Verifier)과 샌드박싱을 생략하고, `hyperscale`에서만 전체 파이프라인을 가동하도록 `cockpit`의 룰(Rule) 개편.
- **캐싱(Caching) 극대화:** 동일한 코드 블록에 대한 리뷰나 동일한 컨텍스트(RAG) 호출은 `abillity-ai` 단에서 해시(Hash) 기반으로 캐싱하여 불필요한 LLM API 호출을 차단.

## 3. 오픈소스 카니발리제이션 방지 (Open-Source Boundary)
**현황:** `cockpit`에 파이썬 기반의 강력한 평가 로직(`eval.py`, `cockpit-metrics.py`)이 다수 포함되어 있어, 엔터프라이즈 고객이 `abillity-ai` 플랫폼을 결제할 유인이 감소할 수 있음.
**개선 사항:**
- **경계 재설정 (Ruthless SoC):** `cockpit` 오픈소스는 철저히 **"인터페이스(Interface)와 스키마, 프롬프트"**만을 제공하도록 제한. 
- 복잡한 데이터 집계 로직이나 다중 샌드박스 오케스트레이션 로직은 `abillity-ai`의 Private Repo로 이관하여 핵심 비즈니스 로직(Moat)을 보호.

## 4. 비결정적 AI 응답에 대한 결함 허용 (Fault Tolerance for Non-Determinism)
**현황:** LLM이 마크다운 포맷을 어기거나 닫는 태그를 누락할 경우 플랫폼 엔진이 정지할 위험.
**개선 사항:**
- **Self-Correction 프롬프트 루프:** `abillity-ai`는 파싱 에러 발생 시 시스템을 중단하는 대신, 에러 메시지를 포함하여 동일한 에이전트에게 "포맷에 맞춰 다시 답변하라"고 핑퐁(Retry)하는 로직 구현.
- **완화된 정규식(Fuzzy Parsing):** `cockpit`의 출력 규약은 엄격하되, `abillity-ai`의 파서는 대소문자나 미세한 공백 차이를 무시할 수 있는 유연한 파싱 로직을 갖추도록 설계.
