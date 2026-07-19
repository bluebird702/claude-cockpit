# How to Build a Product with Cockpit

이 튜토리얼은 당신이 백지상태(Empty Repository)에서 시작하여, 완벽한 IT 프로덕트를 런칭하기까지 Cockpit의 스킬들을 어떻게 **연속기(Combo)**로 활용해야 하는지 알려주는 플레이북입니다.

## Phase 1. 기획 (Ideation)
"무엇을 만들지" 아이디어만 있는 상태입니다. 코드를 짜고 싶은 욕망을 참고 기획부터 시작하세요.

```bash
> /plan:ideation "나만의 로컬 마크다운 노트 앱을 만들고 싶어"
```
AI가 JTBD 프레임워크와 RICE 스코어링을 통해 당신의 아이디어를 냉정한 비즈니스 관점에서 평가하고, 핵심 기능만 추려낸 기획안(Artifact)을 만들어 줄 것입니다.

## Phase 2. 요구사항 정의 (PRD)
아이디어가 검증되었다면, 개발자가 개발할 수 있는 명세서로 변환해야 합니다.

```bash
> /plan:prd-draft "방금 기획한 노트 앱의 첫 번째 MVP 스펙을 PRD로 뽑아줘"
```
유저 스토리(User Story)와 인수 조건(Acceptance Criteria)이 명시된 PRD가 생성됩니다.

## Phase 3. 아키텍처 설계 (System Design)
코드 폴더를 만들기 전, 아키텍처의 골격을 잡아야 합니다.

```bash
> /design:system-design "방금 만든 PRD를 기반으로 Mac 로컬 환경에 맞는 아키텍처를 설계해 줘"
```
AI가 C4 모델, 예상 QPS(로컬 앱의 경우 파일 I/O 속도), FMEA(장애 시나리오)가 포함된 탄탄한 설계 문서를 뽑아냅니다.

## Phase 4. 개발 및 리팩터링 (Dev)
이제 진짜 코딩을 할 시간입니다! 프롬프트로 기능을 구현하다가 코드가 스파게티가 될 것 같으면 리팩터링 스킬을 호출하세요.

```bash
> /dev:refactor "NoteList 컴포넌트가 너무 방대해졌어. 단일 책임 원칙(SRP)에 맞게 쪼개줘"
```
AI가 무중단(Zero-Downtime) 원칙에 입각하여 코드를 아름답게 분리할 것입니다.

## Phase 5. 검증 및 출시 (Review & Prod)
코드를 다 짰다면 리뷰어 서브에이전트 군단을 호출하세요.

```bash
> /review:all
```
보안, 성능, 아키텍처 위반 여부를 봇들이 알아서 크로스 체크해 줍니다.
출시 후 장애가 났다면? 당황하지 말고 `/prod:rca`를 호출하여 Blameless 포스트모템을 작성하세요.
