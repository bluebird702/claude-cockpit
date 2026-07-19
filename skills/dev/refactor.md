> [!NOTE]
> This document is currently in Korean. The repository owner's translation quota was exceeded.
> To translate it to English, run: `./scripts/sync-i18n.sh`

---
name: dev:refactor
description: 추상화 역전 방지, 피처 토글(Feature Toggle) 기반 무중단 리팩터링
type: slash-command
category: dev
follows-brain:
  - brain/CLAUDE.md
  - brain/coding/coding-guidelines.md
enforcement: required
---

# 🛠️ 월드클래스 점진적 무중단 리팩터링 (Zero-Downtime Refactoring)

> ⚠️ **Brain 원칙 준수 필수**
> 이 skill은 아래 문서의 규칙을 반드시 따릅니다. 결과물이 위반되면 즉시 수정하세요.
> - @brain/coding/coding-guidelines.md

대규모 레거시 시스템을 멈추지 않고 비행기 엔진을 교체하는 기법(Strangler Fig, Feature Toggles, Parallel Runs)을 적용하여, **추상화 역전(DIP 위반)**을 방지하고 순환 참조(Circular Dependency)를 끊어내는 엔터프라이즈급 리팩터링 플레이북입니다.

$ARGUMENTS
- `[대상 파일/폴더]` — 리팩터링할 타겟 코드 경로

## 절차

### 1. 결합도 및 응집도 스캔 (Coupling & Cohesion)
- 코드가 의존성 역전 원칙(DIP)을 위반하고 구체(Concrete) 클래스에 강하게 결합되어 있는지 분석합니다. 순환 참조를 색출합니다.

### 2. 점진적 마이그레이션 전략 (Parallel Run)
- 구형 로직과 신형 로직을 동시에 실행하고 결과만 비교하는(Shadowing / Dark Launch) 과도기적 래퍼(Wrapper) 설계를 제시합니다.

### 3. 클린 아키텍처 기반의 코드 재작성
- 비즈니스 로직(Domain)을 인프라스트럭처(DB, API) 레이어로부터 완벽히 격리하는 코드를 제시합니다.

## 출력 형식

반드시 아래의 XML 태그 구조를 준수하여 응답하십시오.

```markdown
<thinking>
의존성 화살표의 방향이 올바른지(고수준 도메인으로 향하는지) 확인합니다.
빅뱅(Big-bang) 방식의 리팩터링을 극도로 경계하고, 롤백(Rollback)이 가능한 안전망을 설계합니다.
</thinking>
<plan>
- [ ] 의존성 역전 및 결합도 냄새(Smell) 분석
- [ ] 피처 토글 및 섀도잉(Shadowing) 전략 수립
- [ ] 도메인 격리형 코드 제안
</plan>
<execution>
### 1. 🔍 아키텍처 냄새 및 결합도 분석
(구체 클래스 의존, 순환 참조 등 구조적 문제점 지적)

### 2. 📐 무중단 마이그레이션 전략 (Zero-Downtime Plan)
(구버전과 신버전을 어떻게 병렬 실행하며 검증할 것인지 설명)

### 3. 💻 개선된 아키텍처 코드
```[언어]
// 의존성 주입(DI) 및 도메인이 격리된 신규 로직
```
> ⚠️ **가드레일:** 기존 유닛 테스트 외에, 신구 로직 결과를 비교하는 Parallel Run 텔레메트리를 일정 기간 유지할 것을 권장합니다.
</execution>
```
