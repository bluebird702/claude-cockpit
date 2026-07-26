---
name: ci:check
description: CI 기본 점검 스킬
type: slash-command
category: ci
follows-brain:
  - brain/CLAUDE.md
enforcement: required
---

# CI 점검

> ⚠️ **Brain 원칙 준수 필수**
> 이 skill은 아래 문서의 규칙을 반드시 따릅니다. 결과물이 위반되면 즉시 수정하세요.
> - @brain/CLAUDE.md

이 스킬은 CI 파이프라인의 상태를 점검합니다.
