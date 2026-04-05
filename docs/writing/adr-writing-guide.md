# ADR 작성 가이드

> ADR (Architecture Decision Record) — **되돌리기 어려운 결정**의 이유를 기록하는 짧은 문서.

## 언제 작성하나

ADR 이 필요한 결정의 특징:
- **되돌리기 비용이 큼** (DB 스키마, 인증 방식, 프레임워크 선택)
- **여러 대안이 있었음** (왜 이것을 골랐는지 설명 필요)
- **코드만 봐서는 이유를 알 수 없음**

ADR 이 **필요 없는** 경우:
- 일반적 리팩토링, 버그 수정, 기능 추가
- 커밋 메시지 1-2줄로 충분한 변경

## 위치와 파일명

- 프로젝트 루트의 `docs/adr/` 디렉토리
- 파일명: `NNN-kebab-case-title.md` (번호 3자리, 순차 증가)
- 예: `004-event-sourcing-for-audit-log.md`

## 템플릿

공식 템플릿은 `@standards/templates/adr-template.md` 를 사용합니다. 복사 후 빈칸을 채우세요.

```markdown
# ADR-NNN: <결정 제목>

- Status: Proposed | Accepted | Deprecated | Superseded by ADR-XXX
- Date: YYYY-MM-DD
- Deciders: @user1, @user2

## Context
<어떤 문제가 있었는가. 제약 조건, 요구사항>

## Decision
<무엇을 결정했는가. 한 문단으로 명확히>

## Consequences
### Positive
### Negative
### Neutral

## Alternatives Considered
### Option A
### Option B (선택됨)
### Option C

## References
- 관련 이슈, 설계 문서, 외부 자료
```

## 작성 원칙

1. **짧게**: 1-2페이지. 길면 배경을 별도 설계 문서로 분리.
2. **현재 시점의 맥락**을 기록: 몇 년 뒤 읽는 사람이 "왜 이런 결정을 했지?" 라고 물을 때 답이 되어야 합니다.
3. **결정은 불변**: 번복할 때는 새 ADR 을 만들고 이전 ADR 상태를 `Superseded by ADR-XXX` 로 변경.
4. **대안을 솔직하게**: 기각된 옵션의 장점도 적어야 공정성이 생깁니다.

## Status 전이

```
Proposed → Accepted → (Deprecated | Superseded by ADR-N)
```

- **Proposed**: 제안 단계, 리뷰 중
- **Accepted**: 승인됨, 코드에 반영
- **Deprecated**: 더 이상 유효하지 않지만 대체 결정 없음
- **Superseded**: 다른 ADR 로 대체됨

## 좋은 ADR 의 특징

- 코드만 읽어서는 **왜** 이렇게 했는지 알 수 없는 정보가 담김
- 대안을 최소 2개 이상 검토
- "이 결정이 틀렸을 때 어떻게 롤백하는가" 가 Consequences 에 명시
- 1년 뒤 읽어도 맥락이 이해됨

## 안티패턴

- 단순 구현 가이드를 ADR 로 작성 (그건 README 또는 설계 문서)
- "우리는 클린 아키텍처를 쓴다" 같은 일반론
- Context 없이 Decision 만 나열
- 완료 후 Status 를 갱신하지 않음

## 예시 참고

- `@standards/templates/adr-template.md` — 빈 템플릿
- `docs/examples/example-CLAUDE.md` — 마이크로서비스 플랫폼 프로젝트의 CLAUDE.md 샘플
