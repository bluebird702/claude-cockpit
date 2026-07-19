---
name: plan:ideation
description: 역방향 기획 및 엣지 케이스 발굴 브레인스토밍
type: slash-command
category: plan
follows-standards:
  - standards/CLAUDE.md
  - standards/planning/product.md
enforcement: required
---

# 🧠 기획 및 아이데이션 (Ideation & Edge-Case Discovery)

> ⚠️ **Standards 준수 필수**
> 이 skill은 아래 문서의 규칙을 반드시 따릅니다. 결과물이 위반되면 즉시 수정하세요.
> - @standards/CLAUDE.md

단순한 기능 나열(Feature List)을 지양하고, 비즈니스 가치, 안티 페르소나(Anti-Persona), 엣지 케이스(Edge Cases)를 집요하게 파고들어 기획의 허점을 사전에 방어하는 역방향 기획 도구입니다.

$ARGUMENTS
- `[아이디어 요약]` — 사용자가 만들고자 하는 기능이나 프로덕트의 대략적인 설명

## 절차

### 1. 비전 챌린지 (Vision Challenge)
- 사용자가 제시한 아이디어의 "진짜 문제(Real Problem)"가 무엇인지 역문(Reverse Question)합니다.
- 이 기능이 실패할 경우의 가장 유력한 시나리오 3가지를 도출합니다.

### 2. 안티 페르소나 및 엣지 케이스 탐색
- 이 기능을 악용하거나, 오용할 수 있는 사용자(Anti-Persona)를 상정합니다.
- 네트워크 단절, 데이터 동시성 충돌, 타임존 차이 등 극한의 엣지 케이스를 5개 이상 발굴합니다.

### 3. 성공 지표 (KPI) 정의
- 기능의 성공 여부를 수학적/정량적으로 측정할 수 있는 지표(Metrics)를 3개 제안합니다.

## 출력 형식

반드시 아래의 XML 태그 구조를 준수하여 응답하십시오.

```markdown
<thinking>
아이디어의 본질적 가치와 가장 취약한 지점을 분석합니다.
해피 패스(Happy Path)가 아닌 예외 상황에 집중합니다.
</thinking>
<plan>
- [ ] 비전 챌린지 및 실패 시나리오 분석
- [ ] 엣지 케이스 및 보안 취약점 도출
- [ ] 핵심 KPI 정의
</plan>
<execution>
### 1. 🛑 아이디어 검증 (Devil's Advocate)
(비판적 시각에서의 아이디어 분석 및 실패 시나리오)

### 2. ⚡ 엣지 케이스 및 안티 페르소나
(악용 사례 및 극한의 예외 상황)

### 3. 📈 측정 가능한 성공 지표 (KPI)
(정량적 데이터 지표 제안)

---
> **다음 스텝:** 위 논의를 바탕으로 기획을 확정하시겠습니까? 확정 시 `/plan:prd-draft` 를 호출하여 요구사항 정의서를 자동 생성합니다.
</execution>
```
