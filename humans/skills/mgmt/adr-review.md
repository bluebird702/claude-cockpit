---
name: mgmt:adr-review
description: decision-log.md 가 요구하는 분기별 ADR 리뷰 — 유효성·상태 전이·미기록 결정 점검
type: slash-command
category: mgmt
follows-standards:
  - standards/CLAUDE.md
  - standards/management/decision-log.md
enforcement: required
---

# 분기 ADR 리뷰

> ⚠️ **Standards 준수 필수**
> - @standards/management/decision-log.md (§분기별 리뷰 — 이 스킬이 그 루틴의 실행 도구)

`docs/adr/` 전체를 스캔해 **여전히 유효한가 / 뒤집어야 할 것은 없는가 / 기록 안 된 결정은 없는가**를 점검합니다. 과거 결정의 맥락은 지우지 않습니다 — 뒤집힌 결정은 삭제가 아니라 Superseded.

$ARGUMENTS
- 없음 → 현재 프로젝트의 `docs/adr/`
- **경로** → 해당 디렉토리

## 절차

### 1. 인벤토리 (측정)

- `docs/adr/*.md` 전체 목록: 번호·제목·상태(Proposed/Accepted/Deprecated/Superseded)·최종 수정일.
- 상태 파싱 불가 문서는 형식 위반으로 표기 (adr-template.md 골격 기준).

### 2. 냄새 감지

| 냄새 | 기준 | 의미 |
|------|------|------|
| 고인 Proposed | Proposed 상태 30일+ | 결정을 안 내렸거나 기록을 안 닫음 |
| 깨진 Superseded 체인 | `Superseded by ADR-XXXX` 대상 부재 | 맥락 유실 |
| 장기 미검토 | 최종 수정 6개월+ 인 Accepted | 여전히 유효한지 재확인 대상 |
| Negative 없는 Consequences | Positive 만 나열 | 결정 품질 의심 (decision-log 체크리스트) |

### 3. 유효성 질문 생성

장기 미검토 Accepted 각각에 대해 **코드베이스 현실과 대조**:
- 그 결정이 전제한 제약(비용·규모·의존성)이 여전히 참인가?
- 결정과 반대로 구현된 코드가 있는가? (있으면 "결정이 죽었는데 문서만 살아있음")

### 4. 미기록 결정 탐지

- 최근 분기 커밋/PR 에서 decision-log.md 의 "언제 ADR 을 쓰는가" 기준(되돌리기 어려운 선택·비자명한 트레이드오프)에 해당하는데 ADR 이 없는 변경을 후보로 제시.
- 후보는 `/wiki:capture adr` 로 초안화 제안.

## 출력 형식

```markdown
# 📋 분기 ADR 리뷰 — YYYY-Qn

## 인벤토리
| ADR | 제목 | 상태 | 최종 수정 | 냄새 |
|-----|------|------|-----------|------|

## 재검토 필요 (여전히 유효한가?)
- ADR-0007: <전제가 바뀐 근거>

## 미기록 결정 후보
- <커밋/PR> — <왜 ADR 감인지> → `/wiki:capture adr`

## 액션 (최대 5개)
1. ...
```

**원칙**:
- ADR 삭제 제안 금지 — 뒤집힌 것은 **Superseded 처리 + 새 ADR** 제안.
- 상태 변경·문서 수정은 초안 제시까지만, 적용은 사용자 승인.
- 냄새 판정은 파일 메타데이터·본문 파싱으로만 (추측 금지, 애매하면 질문으로 남김).
