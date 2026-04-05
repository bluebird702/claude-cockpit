# Agent Platform 설계 문서

> claude-cockpit 을 "1인 창업자 dotfiles" 에서 **에이전트-직원 기반 조직 OS** 로 확장하기 위한 설계 아카이브.

> **📌 공개 레포 안내**
>
> 이 폴더의 문서는 특정 전제(제품명 · 6 리더 + 5 서브워커 구조 · Slack 채널명 · `delegates.yaml` 라우팅 규칙) 를 가진 **개인 설계 초안** 입니다. 일반화된 템플릿이 아니라 "이렇게 잡으면 어떤 모양이 되는가" 를 구체적으로 보여주기 위한 샘플입니다.
>
> 본인 구성에 맞춰 사용하려면:
> 1. 문서에 등장하는 `<product>` · `<knowledge>` 플레이스홀더를 본인 프로젝트/레포명으로 치환
> 2. 리더·서브워커 수와 역할을 본인 조직도에 맞춰 조정 (6+5 는 하나의 예시)
> 3. Slack 채널명과 계층 구조를 본인 워크스페이스에 맞춰 재설계
> 4. `roadmap.md` 의 Sprint 범위는 샘플 일정이므로 참고만

## 이 폴더의 목적

2026-04-05 세션에서 합의된 방향성을 차후 작업의 기준선으로 남긴다. 구현이 시작되면 각 문서는 "의도 선언" 으로 남고, 실제 레퍼런스는 코드·`AGENT.md`·`install.sh` 가 맡는다.

## 목차

| 문서 | 내용 |
|---|---|
| [vision.md](./vision.md) | 왜 에이전트-직원인가, 비서 1 + C-suite 6 + 서브워커 5 구조, 핵심 원칙 |
| [architecture.md](./architecture.md) | 레포 구조, Slack workspace 설계, worker 런타임, 실제 동작 시나리오 |
| [cheapest-setup.md](./cheapest-setup.md) | 최저 비용 셋업 경로 — 무료로 시작해 단계별 확장 |
| [install-flow.md](./install-flow.md) | `install.sh` 오케스트레이션 · 자동화 vs 수동 경계 |
| [roadmap.md](./roadmap.md) | Sprint 0~4 실행 계획 |

## TL;DR

- **비전**: Slack 에 1 명의 비서 (Secretary) + 6 명의 AI 리더 봇 (CTO / CFO / CMO / CPO / CDO / Design) 이 상주하여 CEO 1 인이 조직 전체를 운영한다. CTO 하위에는 backend / frontend / qa / devops / infra 5 명의 서브워커가 있다. 총 12 봇.
- **레포 분할**: `claude-cockpit` = 조직 인프라 · 에이전트 정의 · Slack 부트스트랩, `<product>` = 실제 제품 코드, `<knowledge>` (신규) = ADR · runbook · postmortem.
- **런타임**: Slack listener 는 Fly.io 무료 티어 상주, 무거운 작업은 GitHub Actions 이벤트 잡. 상시 컴퓨트 비용은 사실상 0.
- **지배적 비용**: Claude API 토큰. 인프라는 거의 무료, 실제 지출은 LLM 사용량에 비례.
- **시작점**: 봇 1~2 개 (CTO + briefing) 로 Phase 0 진입. 검증 후 나머지 리더 전개.
- **한 방 설치**: `./install.sh` 가 12 Phase 오케스트레이션. 사람 개입은 첫 설치 2~3 분 (Slack OAuth 승인).

## 선행 결정

| 주제 | 결정 |
|---|---|
| 언어 | Python (Slack Bolt + Claude Agent SDK) |
| 런타임 | Phase 1: Fly.io 무료 + GitHub Actions. Phase 2+: Cloud Run. |
| 개인 레이어 | **제거**. CEO 1인 창업자 컨텍스트에서 "한글·존댓말" 등은 전사 정책이므로 `core/` 에 통합 |
| 네이밍 | 비서 `@Secretary` + C-suite (`@CTO`, `@CFO`, `@CMO`, `@CPO`, `@CDO`, `@Design`) |
| 레포 구조 | **monorepo 유지** (Sprint 0~3). Sprint 4 에 분할 체크포인트 — 트리거 2 개 이상 발생 시 `claude-cockpit` / `agent-platform` / `company-workers` 3 레포로 분할 검토 |
| 제품 레포 접근 | 서브워커별 GitHub App (per-scope 권한 분리) |
| 지식 DB | 초기엔 `<product>/docs/` 활용, 리더 봇 활동으로 데이터 쌓이면 별도 레포로 분리 |

## 다음 액션

[roadmap.md](./roadmap.md) 의 Sprint 0 부터 진행.
