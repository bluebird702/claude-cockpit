> [!NOTE]
> This document is currently in Korean. The repository owner's translation quota was exceeded.
> To translate it to English, run: `./scripts/sync-i18n.sh`

---
name: plan:ideation
description: JTBD, RICE 프레임워크, Pre-mortem이 포함된 극한의 기획 검증
type: slash-command
category: plan
follows-standards:
  - brain/CLAUDE.md
  - brain/planning/product.md
enforcement: required
---

# 🧠 월드클래스 기획 및 아이데이션 (World-Class Ideation & Pre-mortem)

> ⚠️ **Standards 준수 필수**
> 이 skill은 아래 문서의 규칙을 반드시 따릅니다. 결과물이 위반되면 즉시 수정하세요.
> - @brain/CLAUDE.md

"무엇을 만들까?"가 아니라 **"사용자는 왜 이것을 고용하는가?(JTBD)"**를 파고들며, 제품 출시 전 실패를 미리 경험해 보는 **Pre-mortem(사전 부검)** 기법을 도입하여 글로벌 스탠다드 수준의 제품 기획을 강제합니다.

$ARGUMENTS
- `[아이디어 요약]` — 사용자가 만들고자 하는 기능이나 프로덕트의 대략적인 설명

## 절차

### 1. JTBD (Jobs-to-be-Done) 분석
- 사용자가 이 기능을 '고용(Hire)'하려는 근본적인 심리적, 사회적, 기능적 목적을 파헤칩니다.

### 2. Pre-mortem (사전 부검) 및 엣지 케이스
- "제품 출시 후 1년, 우리는 완전히 망했다. 그 이유는 무엇인가?"라는 극단적인 역발상을 통해 치명적인 UX 결함이나 비즈니스 모델의 허점을 도출합니다.

### 3. RICE 프레임워크 기반 기능 우선순위
- Reach(도달률), Impact(영향력), Confidence(자신감), Effort(노력)의 4가지 척도를 통해 당장 버려야 할 기능과 집중해야 할 핵심 기능(MVP)을 분리합니다.

## 출력 형식

반드시 아래의 XML 태그 구조를 준수하여 응답하십시오.

```markdown
<thinking>
표면적인 기능(Feature) 요구사항 이면에 숨겨진 진짜 고객의 고통(Pain point)을 찾습니다.
가장 자원을 적게 들이면서 가장 큰 임팩트를 낼 수 있는 가설을 설계합니다.
</thinking>
<plan>
- [ ] JTBD 도출
- [ ] Pre-mortem (실패 시나리오) 작성
- [ ] RICE 기반 MVP 정의
</plan>
<execution>
### 1. 🎯 JTBD (Jobs-to-be-Done)
- **상황 (When):** 
- **동기 (I want to):** 
- **목표 (So I can):** 

### 2. ☠️ Pre-mortem (사전 부검 리포트)
*가정: 이 제품은 1년 뒤 완전히 실패했습니다. 왜 실패했을까요?*
- (치명적 리스크 1)
- (치명적 리스크 2)

### 3. 📊 RICE 기반 우선순위 및 MVP 정의
| 기능 (Feature) | Reach | Impact | Confidence | Effort | Score | 결론 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| ... | ... | ... | ... | ... | ... | (MVP 포함/보류) |

---
> **다음 스텝:** 위 검증을 바탕으로 `/plan:prd-draft` 를 호출하여 확정된 요구사항 정의서를 생성하시겠습니까?
</execution>
```
