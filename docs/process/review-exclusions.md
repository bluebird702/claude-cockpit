# 리뷰 제외 항목

> 아키텍처 리뷰 시 다음 항목들은 **평가에서 제외**됩니다.

## 공통 제외 항목

| 항목 | 사유 | 해당 서비스 |
|-----|-----|------------|
| Redis 캐싱 구현 | 추후 구현 예정 | Profile, Community, Social |
| 통합 테스트 (Testcontainers) | 추후 구현 예정 | Profile, Social |
| REST API 문서화 | 추후 구현 예정 | Account, Profile, Community |
| 비즈니스 메트릭 계측 | 추후 구현 예정 | Account, Community |
| 이벤트 발행 (Kafka) | 추후 구현 예정 | Social |
| Notification 도메인 | 추후 구현 예정 | Social |

## 서비스별 고유 제외 항목

### Account
- Domain Event 발행/구독: 현재 단일 서비스로 운영
- Kafka 어댑터 구현: Domain Event와 연계

### Gateway
- WebSocket 지원: 추후 구현 예정
- API 버저닝 (v2): 현재 v1만 운영
- gRPC 라우팅: REST API로 충분

### Profile
- TenantClientPort 직접 구현: Account 서비스 연동 예정

### Social
- Notification 도메인 구현: 추후 구현 예정

### Community
- CQRS 패턴: 현재 서비스 규모에서 불필요
- PostService 분리: CQRS 미적용으로 단일 서비스 유지
- Repository ISP 분리: CQRS 미적용으로 현재 구조 유지
- Specification 패턴: 현재 검증 로직 복잡도에서 불필요
- Rate Limiting: Gateway에서 처리

### Mypedia
- ViewComponent 마이그레이션: 추후 구현 예정
- GraphQL API: REST API로 충분
- 외래키 제약 스키마 레벨 적용: 의도적 설계 결정

### Clients
- 테스트 커버리지: 초기 개발 단계
- i18n 다국어 지원: 추후 구현 예정
- E2E 테스트: 추후 구현 예정
- PWA 지원: 추후 검토 예정

---

**최종 업데이트**: 2026-01-02
