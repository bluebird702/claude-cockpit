---
name: <카테고리>:<이름>
description: <한 줄 설명>
type: slash-command
category: review | design | dev | docs | ci | mgmt | prod | plan | wiki
follows-standards:
  - standards/CLAUDE.md
  - standards/coding/coding-guidelines.md
  - standards/testing/testing-guidelines.md
enforcement: required
---

# <제목>

> ⚠️ **Standards 준수 필수**
> 이 skill은 아래 문서의 규칙을 반드시 따릅니다. 결과물이 위반되면 즉시 수정하세요.
> - @standards/CLAUDE.md
> - @standards/coding/coding-guidelines.md
> - @standards/testing/testing-guidelines.md

<한 줄 요약: 이 skill이 무엇을 하는지>

$ARGUMENTS
- `arg1` — 설명
- 인자 없음 → 기본 동작

## 절차

### 1. 컨텍스트 파악
...

### 2. 작업 수행
...

## 출력 형식

반드시 아래의 XML 태그 구조를 준수하여 응답하십시오.

```markdown
<thinking>
이 스킬의 목적과 컨텍스트를 분석합니다.
어떤 기준(Standards)을 적용해야 하는지 판단합니다.
발견된 문제점이나 수행할 작업의 근거를 논리적으로 전개합니다.
</thinking>
<plan>
- [ ] 실행할 작업 1
- [ ] 실행할 작업 2
</plan>
<execution>
실제 출력 내용이나 실행 결과를 여기에 작성합니다.
</execution>
```
