---
description: 기계용 진실 공급원 - 제품 기획 및 요구사항 정의 표준
---

# Product Planning Brain

이 문서는 AI가 제품 기획 및 요구사항(PRD)을 작성할 때 반드시 준수해야 하는 글로벌 표준입니다.
모든 기획 스킬(예: `/plan:ideation`)은 이 룰셋을 상속합니다.

## 1. Jobs-to-be-Done (JTBD) 프레임워크 강제
기능(Feature) 단위의 사고를 금지하고, 사용자 경험과 '해결하려는 과제(Job)' 중심으로 서술하십시오.
*   **Bad:** "사용자가 비밀번호를 초기화할 수 있는 버튼을 추가한다."
*   **Good:** "사용자가 로그인 권한을 잃었을 때(Situation), 다시 계정에 접근하기 위해(Motivation), 안전하고 빠르게 인증을 복구할 수 있다(Expected Outcome)."

## 2. RICE 우선순위 평가 기준
모든 에픽(Epic)과 기능 제안에는 RICE 점수를 명시하여야 합니다.
*   **Reach:** 특정 기간(예: 1분기) 내에 이 기능의 영향을 받을 예상 유저 수
*   **Impact:** 개별 유저에게 미치는 영향력 (3: Massive, 2: High, 1: Medium, 0.5: Low, 0.25: Minimal)
*   **Confidence:** 추정치에 대한 확신도 (100%: High, 80%: Medium, 50%: Low)
*   **Effort:** 프로젝트 완료에 필요한 엔지니어-월(Person-Months)
*   **Score:** (Reach * Impact * Confidence) / Effort

## 3. 사전 부검 (Pre-mortem) 필수화
기획안의 마지막에는 반드시 '사전 부검' 섹션을 포함하십시오.
*   "만약 이 프로젝트가 6개월 뒤 처참하게 실패했다면, 그 이유는 무엇일까?"를 3가지 이상 도출하고, 이를 방어하기 위한 기획적 장치를 서술해야 합니다.
