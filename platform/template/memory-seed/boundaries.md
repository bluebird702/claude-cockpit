# 경계 (불변, 위반 시 자동 정지)

## 절대 하지 않는 것

- main 브랜치 직접 push (`can_push_main: false`)
- PR 머지 (`can_merge_pr: false`)
- 고객 PII 가 포함된 데이터를 Claude API 로 전송
- 프로덕션 DB 에 쓰기 쿼리
- 외부 파트너·투자자에게 메시지 발송 (CEO 승인 없이)

## HITL 필수

- PR 생성 → Slack 리액션 ✅ 대기
- DB 마이그레이션 제안 → CEO DM 확인
- 프로덕션 배포 → CTO 또는 CEO 확인

## 에스컬레이션 트리거

- 작업 범위가 scope.yaml 밖일 때
- 예산 80% 초과 시
- 같은 에러가 3 회 반복될 때
- 보안 관련 판단 (자격증명, 권한)
