---
name: dev:refactor
description: 안전한 점진적 리팩터링 및 구조 개선
type: slash-command
category: dev
follows-standards:
  - standards/CLAUDE.md
  - standards/coding/coding-guidelines.md
enforcement: required
---

# 🛠️ 안전한 점진적 리팩터링 (Safe Progressive Refactoring)

> ⚠️ **Standards 준수 필수**
> 이 skill은 아래 문서의 규칙을 반드시 따릅니다. 결과물이 위반되면 즉시 수정하세요.
> - @standards/coding/coding-guidelines.md

레거시 코드를 수정할 때, 기존 비즈니스 로직과 인터페이스를 파괴하지 않고 안전하게(Safely) 구조를 개선하는 'AI 리팩터링 플레이북'입니다. 

$ARGUMENTS
- `[대상 파일/폴더]` — 리팩터링할 타겟 코드 경로

## 절차

### 1. 부작용(Side Effect) 영향도 스캔
- 타겟 코드의 의존성을 역추적하여, 이 함수/클래스를 수정할 때 깨질 수 있는 외부 모듈들을 나열합니다.

### 2. 리팩터링 전략 수립 (Strangler Fig Pattern 등)
- 코드를 한 번에 갈아엎지 않고, 구형 인터페이스를 래핑(Wrapping)하거나 분리하여 점진적으로 교체하는 전략을 세웁니다.

### 3. 리팩터링 코드 제시 및 테스트 코드 요구
- SOLID 원칙(특히 단일 책임 원칙)에 입각하여 개선된 코드를 제시합니다.
- **반드시** 기존 테스트 코드가 없다면 새로 작성할 것을 권고합니다.

## 출력 형식

반드시 아래의 XML 태그 구조를 준수하여 응답하십시오.

```markdown
<thinking>
기존 로직이 외부 시스템에 미치는 영향(Side Effects)을 파악합니다.
주석과 네이밍의 원래 의도를 해치지 않는 선에서 코드 복잡도(Cyclomatic Complexity)를 낮출 방안을 설계합니다.
</thinking>
<plan>
- [ ] 의존성 및 부작용 영향도 분석
- [ ] 점진적 교체 전략 설계
- [ ] 개선된 코드 및 방어적 테스트 제안
</plan>
<execution>
### 1. 🔍 영향도 분석 (Impact Analysis)
(수정 시 파급 효과가 미치는 파일 및 로직)

### 2. 📐 리팩터링 설계
(어떤 패턴을 사용하여 어떻게 쪼갤 것인지 설명)

### 3. 💻 개선된 코드 제안
```[언어]
// 개선된 소스 코드 (기존 주석 및 인터페이스 최대한 보존)
```
> ⚠️ **경고:** 위 코드를 적용하기 전에 반드시 기존 기능을 검증하는 단위 테스트(Unit Test)를 먼저 확보(또는 작성)하십시오.
</execution>
```
