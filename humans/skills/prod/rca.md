---
name: prod:rca
description: 5 Whys 기반 장애 근본 원인 분석(RCA) 및 포스트모템
type: slash-command
category: prod
follows-standards:
  - standards/CLAUDE.md
  - standards/engineering/reliability.md
enforcement: required
---

# 🚑 장애 근본 원인 분석 (Root Cause Analysis & Post-mortem)

> ⚠️ **Standards 준수 필수**
> 이 skill은 아래 문서의 규칙을 반드시 따릅니다. 결과물이 위반되면 즉시 수정하세요.
> - @standards/engineering/reliability.md

운영 환경(Production)에서 발생한 장애 로그나 버그 리포트를 바탕으로, 단순히 에러가 난 라인을 고치는 것을 넘어 '5 Whys' 기법을 통해 아키텍처와 프로세스의 근본적인 결함을 찾아내는 플레이북입니다.

$ARGUMENTS
- `[에러 로그 또는 장애 현상 설명]`

## 절차

### 1. 현상 파악 및 1차 원인 분석
- 주어진 로그를 분석하여 가장 표면적인 에러 원인(예: NullPointerException, Connection Timeout)을 특정합니다.

### 2. 5 Whys 심층 추적
- '왜 이 에러가 났는가?'를 5단계로 파고듭니다. 
- (예: 1. DB 연결 실패 ➡️ 2. 커넥션 풀 고갈 ➡️ 3. 느린 쿼리로 인한 풀 점유 ➡️ 4. 인덱스 누락 ➡️ 5. 마이그레이션 스크립트 리뷰 프로세스 부재)

### 3. 영구적 해결책 (Permanent Fix) 제시
- 단순 코드 패치(Patch)가 아닌, 재발 방지를 위한 시스템 레벨의 조치(서킷 브레이커 추가, 알람 설정, 프로세스 개선)를 제안합니다.

## 출력 형식

반드시 아래의 XML 태그 구조를 준수하여 응답하십시오.

```markdown
<thinking>
표면적인 증상(Symptom)에 속지 않고, 장애를 유발한 인프라스트럭처, 데이터 상태, 비동기 레이스 컨디션 등 근본 구조를 파헤칩니다.
</thinking>
<plan>
- [ ] 장애 현상 요약
- [ ] 5 Whys 근본 원인 추적
- [ ] 액션 아이템(영구적 해결책) 도출
</plan>
<execution>
### 🚨 장애 요약 (Incident Summary)
- **발생 증상:** (에러 요약)
- **영향도:** (시스템/비즈니스 임팩트 추정)

### 🕵️ 5 Whys (근본 원인 추적)
1. **Why?** (표면적 원인)
2. **Why?** (...)
3. **Why?** (...)
4. **Why?** (...)
5. **Why?** (근본적인 시스템/프로세스 결함)

### 💊 재발 방지 액션 아이템 (Action Items)
- [ ] **단기 패치 (Hotfix):** (즉각 조치 사항)
- [ ] **영구적 조치 (Long-term Fix):** (아키텍처 개선 또는 알람 설정)
</execution>
```
