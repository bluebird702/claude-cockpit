---
description: 기계용 진실 공급원 - 시스템 아키텍처 및 분산 시스템 설계 표준
---

# Architecture Engineering Brain

이 문서는 AI가 시스템 설계(Architecture)를 수행할 때 반드시 지켜야 하는 원칙입니다.
모든 설계 스킬(예: `/design:system-design`)은 이 룰셋을 상속합니다.

## 1. 정량적 트래픽 산정 (QPS & Capacity Planning)
"트래픽이 많을 것으로 예상됨"과 같은 정성적 표현을 금지합니다.
*   반드시 DAU(Daily Active Users), 예상 체류 시간, 사용자당 API 호출 빈도를 추정하여 **Read/Write QPS**를 수치(Numbers)로 도출하십시오.
*   Peak QPS는 평균 QPS의 최소 3배 이상으로 마진을 잡으십시오.
*   저장소 용량(Storage Capacity) 산정 시, 1년/3년 치의 예상 데이터 증가량(Growth Rate)을 명시하십시오.

## 2. CAP 정리 기반 트레이드오프 명시
데이터베이스 및 분산 큐 설계 시, Consistency(일관성), Availability(가용성), Partition Tolerance(분할 내성) 중 어느 것을 우선했는지 반드시 이유와 함께 명시하십시오.
*   Eventual Consistency를 선택했다면, 데이터 지연(Staleness)으로 인해 발생하는 비즈니스 임팩트와 그 완화책(Mitigation)을 서술하십시오.

## 3. FMEA (Failure Mode and Effects Analysis)
아키텍처 제안의 마지막에는 주요 컴포넌트별 장애 시나리오 테이블(FMEA)을 작성하십시오.
*   **컴포넌트:** 장애가 발생할 수 있는 노드 (예: Redis Cache)
*   **장애 모드:** 어떻게 고장나는가? (예: OOM, Network Partition)
*   **영향도:** 시스템과 사용자에게 미치는 영향 (예: DB 부하 급증)
*   **완화책(방어):** (예: Cache Stampede 방지를 위한 Jitter 추가, Circuit Breaker)
