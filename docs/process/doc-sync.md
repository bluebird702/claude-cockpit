# API 문서 동기화 가이드

> API 변경 시 반드시 `docs/site/docs/` 문서도 함께 업데이트해야 합니다.

## 변경 항목별 영향 매핑

| 변경 항목 | 영향받는 API 문서 |
|----------|------------------|
| API 엔드포인트 추가/수정/삭제 | `api-reference/*.md` |
| 에러 코드 변경 | `appendix/error-codes.md`, 관련 API 문서 |
| 인증/권한 로직 변경 | `getting-started/authentication.md` |
| Rate Limit 정책 변경 | `appendix/rate-limits.md` |
| 엔티티 상태값 변경 | `appendix/status-codes.md` |
| 핵심 개념 변경 (Account, Tenant, Member 등) | `core-concepts/*.md` |

## 작업 체크리스트

```
- [ ] API 엔드포인트 구현
- [ ] 테스트 작성
- [ ] docs/site/docs/api-reference/{service}.md 업데이트
- [ ] 관련 에러 코드 문서화
```
