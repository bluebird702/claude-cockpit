---
name: mgmt:ceo-briefing
description: 기술 CEO 용 일/주간 브리핑 (ceo-briefing 에이전트 호출)
type: slash-command
category: mgmt
follows-standards:
  - standards/CLAUDE.md
enforcement: required
---

# CEO 브리핑

> ⚠️ **Standards 준수 필수** · @standards/CLAUDE.md

`ceo-briefing` 서브에이전트에 위임합니다. 얇은 래퍼.

$ARGUMENTS
- `today` (기본) — 지난 24시간
- `week` — 지난 7일
- `sprint` — 현재 스프린트 기간 (Jira/Linear 연동 필요)

## 실행

`ceo-briefing` 에이전트를 호출. 에이전트가 수집·분류·출력을 모두 담당합니다.

## 후처리

에이전트 출력 끝에 다음 블록을 추가:

```markdown
---
## 브리핑 보관
이 브리핑을 `~/.claude/briefings/YYYY-MM-DD.md` 에 저장해 시간순 히스토리로 남길지 여부 (사용자 승인 필요).
```

**금지**: 에이전트 판단을 재가공하지 말 것. 숫자를 추가로 계산하지 말 것. 인용만.
