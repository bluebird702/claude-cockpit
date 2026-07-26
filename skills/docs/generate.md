---
name: docs:generate
description: 문서 생성 스킬
type: slash-command
category: docs
follows-brain:
  - brain/CLAUDE.md
enforcement: required
---

> [!NOTE]
> This document is currently in Korean. The repository owner's translation quota was exceeded.
> To translate it to English, run: `./scripts/sync-i18n.sh`

# 문서 생성

> ⚠️ **Brain 원칙 준수 필수**
> 이 skill은 아래 문서의 규칙을 반드시 따릅니다. 결과물이 위반되면 즉시 수정하세요.
> - @brain/CLAUDE.md

이 스킬은 프로젝트 문서를 생성합니다.
