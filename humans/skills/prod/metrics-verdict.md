---
name: prod:metrics-verdict
description: 런치된 기능의 Goal/Guardrail 실측값으로 Kept/Killed 판정 — 측정 없으면 판정 불가
type: slash-command
category: prod
follows-standards:
  - standards/CLAUDE.md
  - standards/product/metrics.md
  - standards/planning/prd-guidelines.md
enforcement: required
---

# 지표 사후 판정 (Kept / Killed)

> ⚠️ **Standards 준수 필수**
> - @standards/product/metrics.md (Goal/Guardrail 프레임 — Goal +10% 여도 Guardrail -5% 면 롤백/재설계)
> - @standards/planning/prd-guidelines.md (라이프사이클: Shipped → 측정 후 → Kept / Killed. Killed 를 부끄러워하지 않음)

`/prod:metrics-define` 이 런치 **전** 도구라면, 이 스킬은 런치 **후** 도구입니다. PRD 의 Goal/Guardrail 을 실측값과 대조해 **Kept / Killed / 재설계** 를 판정합니다. 측정 기간이 끝나고도 판정하지 않은 기능은 "지표 없는 런치" 와 같은 위반입니다.

$ARGUMENTS
- `<PRD 파일 경로>` — 권장 (Goal/Guardrail/기간을 자동 추출)
- `<기능명>` — PRD 없으면 Goal/Guardrail 을 되물음
- 예: `/prod:metrics-verdict docs/prd/0007-search.md`

## 절차

### 1. 계약 추출

PRD 에서 추출: Goal(타겟 값+기간) · Guardrail(임계값) · 롤백 기준 · 런치일.
- 측정 기간이 아직 안 끝났으면 → "판정일: YYYY-MM-DD" 만 알려주고 종료 (조기 판정 금지, p-hacking 방지).
- PRD 에 숫자 타겟이 없으면 → 판정 불가 선언 + 소급 타겟 설정은 **경고와 함께만** (사후 타겟은 자기기만 위험).

### 2. 실측값 수집

- 대시보드/이벤트 소스에서 Goal·Guardrail 실측값 확보. 접근 불가하면 사용자에게 숫자를 요청.
- **실측값 없이 판정하지 않습니다** — "느낌상 잘 되는 것 같다" 는 입력으로 거부 (@standards/philosophy.md: 측정 없으면 주장 없음).

### 3. 판정 (기계적)

| Goal | Guardrail | 판정 |
|------|-----------|------|
| 달성 | 무손상 | ✅ **Kept** |
| 달성 | 손상 | ⚠️ **롤백 또는 재설계** (metrics.md 원칙) |
| 미달 | 무손상 | 🔪 **Killed 권고** (또는 1회 한정 이터레이션 — 새 타겟+기간 명시 시) |
| 미달 | 손상 | 🔪 **Killed + 롤백** |

### 4. 후처리

- PRD `상태:` 필드 업데이트 초안 (Shipped → Kept/Killed) — 적용은 사용자 승인.
- **Killed 여도 PRD 는 삭제하지 않음** — "왜 실패했는가" 1-3줄을 PRD 하단에 추가 (다음 PRD 의 입력).
- Kept 면: 이 지표를 계속 볼 것인지(대시보드 상주) vs 졸업시킬 것인지 제안.

## 출력 형식

```markdown
# ⚖️ 지표 판정 — <기능명> (YYYY-MM-DD)

## 계약 vs 실측
| 지표 | 타겟 | 실측 | 달성 |
|------|------|------|------|
| Goal: <이름> | 30% (2주) | 24% | ❌ |
| Guardrail: p95 | <300ms | 280ms | ✅ |

## 판정: 🔪 Killed 권고
근거: Goal 미달 (24% < 30%), Guardrail 무손상 → 유지 비용만 남음

## 후처리
- [ ] PRD 상태 Shipped → Killed
- [ ] 실패 원인 1-3줄 PRD 에 추가: <초안>
- [ ] 기능 플래그/코드 제거 이슈 생성 여부
```

**원칙**:
- 판정 표는 **기계적으로** 적용 — 애착으로 Kept 로 끌어올리지 않음.
- "이터레이션 한 번 더" 는 **새 타겟+새 기간을 숫자로** 다시 걸 때만 허용 (무한 연장 금지).
- 실측값 출처(대시보드 URL/쿼리)를 판정문에 남겨 재현 가능하게.
