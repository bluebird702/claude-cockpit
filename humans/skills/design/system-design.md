---
name: design:system-design
description: 시스템 아키텍처 다이어그램 및 ADR 생성
type: slash-command
category: design
follows-standards:
  - standards/CLAUDE.md
  - standards/engineering/reliability.md
enforcement: required
---

# 🏗️ 시스템 설계 및 아키텍처 의사결정 (System Design & ADR)

> ⚠️ **Standards 준수 필수**
> 이 skill은 아래 문서의 규칙을 반드시 따릅니다. 결과물이 위반되면 즉시 수정하세요.
> - @standards/engineering/reliability.md

주어진 요구사항을 바탕으로 단일 장애점(SPOF)이 없고 확장 가능한 시스템 아키텍처를 설계하며, 기술적 트레이드오프를 문서화한 ADR(Architecture Decision Record)을 생성합니다.

$ARGUMENTS
- `[요구사항 또는 PRD 파일]` — 시스템으로 설계할 대상

## 절차

### 1. 트레이드오프 분석 (Trade-off Analysis)
- CAP 정리(일관성, 가용성, 분할 내성) 중 어떤 것을 우선할지 분석합니다.
- 데이터 정합성 vs 응답 속도의 관점에서 적절한 DB 및 캐싱 전략을 선택합니다.

### 2. 다이어그램 생성 (Mermaid)
- 시스템 컴포넌트 간의 상호작용을 나타내는 아키텍처 다이어그램(C4 모델 기반)을 Mermaid.js 문법으로 작성합니다.

### 3. ADR (Architecture Decision Record) 작성
- 선택한 기술 스택과 아키텍처 패턴의 채택 이유, 그리고 대안으로 고려했으나 기각된 옵션(Alternatives)을 명시합니다.

## 출력 형식

반드시 아래의 XML 태그 구조를 준수하여 응답하십시오.

```markdown
<thinking>
시스템의 병목 지점(Bottlenecks)과 단일 장애점(SPOF)을 식별합니다.
비즈니스 요구사항에 맞는 최적의 데이터베이스 및 아키텍처 패턴을 고려합니다.
</thinking>
<plan>
- [ ] 트레이드오프 및 병목 분석
- [ ] Mermaid 다이어그램 작성
- [ ] ADR 문서 렌더링
</plan>
<execution>
### 1. ⚖️ 기술적 트레이드오프 분석
(CAP 정리, 일관성, 확장성 관점에서의 분석)

### 2. 🗺️ 시스템 아키텍처 다이어그램
```mermaid
graph TD
  ... (C4 모델 기반 아키텍처)
```

### 3. 📄 ADR: [아키텍처 결정 사항 요약]
- **Context:** (왜 이 결정이 필요한가)
- **Decision:** (무엇을 선택했는가)
- **Alternatives Considered:** (어떤 대안들을 기각했는가)
- **Consequences:** (이 결정으로 인해 얻는 이득과 감수해야 할 부채)
</execution>
```
