> [!NOTE]
> This document is currently in Korean. The repository owner's translation quota was exceeded.
> To translate it to English, run: `./scripts/sync-i18n.sh`

---
name: prod:rca
description: 비난 없는 포스트모템(Blameless Post-mortem), MTTR 지표 기반의 세계적 수준 장애 분석
type: slash-command
category: prod
follows-standards:
  - brain/CLAUDE.md
  - brain/engineering/reliability.md
enforcement: required
---

# 🚑 월드클래스 장애 분석 및 포스트모템 (Blameless RCA)

> ⚠️ **Standards 준수 필수**
> 이 skill은 아래 문서의 규칙을 반드시 따릅니다. 결과물이 위반되면 즉시 수정하세요.
> - @brain/engineering/reliability.md

구글 SRE(Site Reliability Engineering)의 핵심 철학인 **"비난 없는 포스트모템(Blameless Post-mortem)"**과 **"Action Item 범주화(Prevent, Detect, Mitigate)"**를 강제하여, 시스템을 근본적으로 진화시키는 장애 분석 플레이북입니다.

$ARGUMENTS
- `[에러 로그 또는 장애 현상 설명]`

## 절차

### 1. 타임라인 및 영향도 (Timeline & Impact)
- 장애가 감지(MTTD)되고 복구(MTTR)되기까지의 타임라인을 추정하고 사용자 경험에 미친 영향을 객관적 지표로 서술합니다.

### 2. 5 Whys (Blameless)
- 사람의 실수를 탓하지 않고("개발자가 코드를 잘못 짰다" ➡️ X), 시스템이 그 실수를 허용한 구조적 결함("CI/CD 파이프라인에 Lint 게이트가 없었다" ➡️ O)을 파고드는 5 Whys 분석을 수행합니다.

### 3. Action Items (PDM 프레임워크)
- 재발 방지 대책을 Prevent(원천 차단), Detect(조기 감지), Mitigate(피해 완화)의 세 가지 방어선으로 분류하여 제안합니다.

## 출력 형식

반드시 아래의 XML 태그 구조를 준수하여 응답하십시오.

```markdown
<thinking>
장애의 책임을 사람에게 묻지 않고, 시스템과 프로세스의 결함(Testing 부재, Alerting 부재, Timeout 설정 오류 등)에 집중합니다.
</thinking>
<plan>
- [ ] 타임라인 및 비즈니스 임팩트 정리
- [ ] 구조적 결함 파악을 위한 5 Whys
- [ ] PDM 기반 Action Items 도출
</plan>
<execution>
### 🚨 장애 요약 및 타임라인 (Impact & Timeline)
- **비즈니스 임팩트:** (예: 결제 실패율 5% 증가, 잠재적 매출 손실 $10K)
- **발견(MTTD) 및 복구(MTTR):** (추정치)

### 🕵️ 5 Whys (Blameless Root Cause)
1. **Why?** (표면적 에러 발생)
2. **Why?** (...)
3. **Why?** (...)
4. **Why?** (...)
5. **Why?** (시스템/프로세스가 이 에러를 사전에 막지 못한 근본 원인)

### 🛡️ 재발 방지 Action Items (PDM Framework)
- **[Prevent] (원천 차단):** (예: CI에서 DB 락킹 스캔 테스트 추가)
- **[Detect] (조기 감지):** (예: Datadog APM 지연시간 P99 알람 설정)
- **[Mitigate] (피해 완화):** (예: 장애 시 읽기 전용 캐시 모드로 자동 폴백(Fallback))
</execution>
```
