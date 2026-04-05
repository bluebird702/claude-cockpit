# Roadmap · Sprint 0~4 실행 계획

> **⚠️ 이 로드맵은 특정 전제를 가진 샘플 스프린트 계획입니다.** 예시 제품명, 12 봇 구성, Sprint 일정이 포함됩니다. 그대로 따라할 것이 아니라 **단계 구조와 체크포인트** 만 참고하고 일정·봇 수는 본인 상황에 맞춰 재조정하세요. 전체 안내는 [`README.md`](./README.md) 참조.

> 원칙: **한 스프린트 끝날 때마다 작동하는 시스템**. 12 봇 동시 출시는 금지.

## 전체 그림

```
Sprint 0  기반 레이아웃 (1 주)
  → core/·humans/·workers/ 구조 확정, _runtime 공통 라이브러리, AGENT.md 스키마 v1
  산출물: 코드는 많지만 봇은 아직 0 개

Sprint 1  1 호 봇 — CTO (1 주)
  → workers/cto/, Slack bootstrap, install.sh Phase 9~12
  산출물: @CTO 1명이 Slack 에서 동작

Sprint 2  6 리더 전개 (1~2 주)
  → CFO, CMO, CPO, CDO, Design 추가
  산출물: C-suite 6 명 가동, #leaders-lounge 협업

Sprint 3  CTO 하위 서브워커 5 (1~2 주)
  → backend-dev, frontend-dev, qa-dev, devops-dev, infra-dev
  → delegates.yaml 라우팅, product-repo GitHub App 분리
  산출물: @CTO /review → 실제 수정 완결 플로우

Sprint 4  지식 루프 + 감사 + 비용 대시보드 (지속)
  → /wiki:capture 자동화, 주간 비용 리포트, 샘플 품질 리뷰
  산출물: 피드백 루프 정착, 장기 운영 가능
```

## Sprint 0 · 기반 (1 주)

### 목표
- 새 디렉토리 구조로 이전
- 공통 런타임 라이브러리 기초 완성
- AGENT.md 스키마 v1 확정
- worker 1 명을 로컬에서 띄울 수 있는 상태

### 작업 목록

1. **레포 재구조화**
   - `global/` → `core/` 이동 (CLAUDE.md, settings.json, standards/)
   - `scripts/hooks/` → `core/hooks/` 이동
   - `skills/` → `humans/skills/` 이동
   - `agents/` → `humans/subagents/` 이동
   - `mcp/` → `core/mcp-shared/` 이동
   - `workers/` 신규, `_runtime/`, `_template/` 골격
   - `slack/`, `deploy/`, `knowledge/`, `secrets/` 신규
   - `scripts/install.sh` 의 phase 1~8 을 새 경로로 갱신
   - `post-install-check.sh` 도 새 경로 반영

2. **공통 런타임 라이브러리** (`workers/_runtime/`)
   - `bolt_adapter.py` — Slack Bolt Socket Mode 래퍼
   - `claude_adapter.py` — Claude Agent SDK 호출, 메시지/도구 변환
   - `loop_guard.py` — 5 중 방어 (자기기동 금지, 턴 캡, 체인 깊이, 봇 무시, rate limit)
   - `budget.py` — 토큰·USD 누적, 일일·스레드 캡, 초과 시 halt
   - `memory.py` — 불변 (role/boundaries/conventions) vs 가변 (long-term) 분리
   - `hitl.py` — 리액션 승인 대기, 타임아웃
   - `audit.py` — JSONL append, 필드: timestamp, worker, thread, tool, tokens, usd
   - `commands.py` — `/status /pause /resume /budget /trace` 공통 핸들러
   - `delegation.py` — 리더 → 서브워커 Task 툴 위임 래퍼
   - `entrypoint.py` — AGENT.md 로드 → 위 모든 것 조립 → 메인 루프

3. **AGENT.md 스키마 v1**
   - YAML frontmatter 필드 명세 (`docs/agent-platform/schemas/agent-md.yaml`)
   - Pydantic 모델로 런타임 검증
   - `_template/AGENT.md` 예시

4. **스캐폴드 스크립트**
   - `scripts/worker-scaffold.sh --leader <name>` — `_template/` 복사 + 이름 치환
   - `scripts/worker-run.sh <name>` — 로컬 단일 봇 기동 (디버그)

5. **헬스체크 확장**
   - `post-install-check.sh` 에 worker 카운트·상태 추가 (Phase 0 에선 0)

### 완료 조건
- `./install.sh` 기존 기능 전부 동작 (회귀 없음)
- `workers/_runtime/` 가 import 가능, 단위 테스트 통과
- `./scripts/worker-scaffold.sh --leader test-bot` 실행 시 `workers/test-bot/` 생성됨
- 해당 test-bot 을 AGENT.md 만 채워도 `worker-run.sh` 로 로컬 기동 가능 (Slack 연결 없이 dry-run)

## Sprint 1 · 1 호 봇 CTO (1 주)

### 목표
- `@CTO` 가 Slack 에서 실제 동작
- `/review`, "수정해", 리액션 승인 풀 플로우
- `install.sh` Phase 9~12 완성

### 작업 목록

1. **Slack 설정**
   - Slack workspace 선정 (기존 워크스페이스 재사용 or 신규 테스트 워크스페이스)
   - `slack/workspace.yaml` 초안 작성 (CTO 관련 채널만: #engineering, #agent-admin, #agent-ops, #bot-lounge)
   - Bootstrapper App 매니페스트 작성

2. **CTO AGENT.md 작성**
   - `workers/cto/AGENT.md` — 전체 필드 채움
   - `workers/cto/persona.md` — "15년 경력 백엔드 리더" 페르소나
   - `workers/cto/memory-seed/` — role, boundaries, company-facts 초기화
   - `workers/cto/delegates.yaml` — 아직 서브워커 없으므로 비어있거나 "전부 자기 처리"

3. **GitHub App**
   - `cto` 전용 GitHub App 생성 (scopes: contents:write, pull_requests:write, issues:write)
   - product-repo 에 설치
   - Installation token 교환 로직을 `workers/_runtime/tools/github_app.py` 에 구현

4. **`install.sh` Phase 9~12 구현**
   - `scripts/phases/09-slack-bootstrap.sh` — manifest 렌더링, 채널 생성, 봇 앱 생성, OAuth 안내
   - `scripts/phases/10-build-image.sh` — Dockerfile 빌드
   - `scripts/phases/11-launch-workers.sh` — docker compose up (로컬 모드)
   - `scripts/phases/12-integration-health.sh` — 각 봇 /status 핑

5. **`deploy/local/`**
   - `Dockerfile` (공통 worker 이미지)
   - `docker-compose.yaml` 렌더링 스크립트

6. **E2E 시나리오 테스트**
   - `@CTO /review PR #<실제>` → 리뷰 결과 포스트
   - "1, 3 수정해" → backend-dev 역할까지 CTO 가 직접 수행 (아직 위임 없음)
   - commit · push · CI 확인
   - `:white_check_mark:` 리액션 승인 (머지는 수동)

### 완료 조건
- `./install.sh` 한 번으로 CTO 봇 기동 (첫 설치 3 분)
- Slack 에서 CTO 가 실제 PR 리뷰 수행
- `audit.log` 에 모든 동작 기록
- 일일 비용 캡 동작 확인

## Sprint 2 · 6 리더 + 비서 전개 (1~2 주)

### 목표
- CFO, CMO, CPO, CDO, Design-Chief 5 명 리더 추가
- **Secretary (비서) 1 명 추가** — CEO 직속 운영 보조
- `#leaders-lounge` 에서 리더 간 협업 테스트
- `#ceo-office` 에서 비서 일일 브리핑 자동화
- install.sh 재실행으로 전개

### 작업 목록

1. **각 리더·비서 페르소나 · 경계 · 메모리 시드**
   - 5 명 리더 + 1 명 비서 × (AGENT.md + persona.md + memory-seed/{role, boundaries, conventions})
   - 비서 (`workers/secretary/`): CEO 직속, C-suite 과 별도 층. 읽기 우선 · 쓰기는 전부 HITL
   - CEO 가 직접 톤·스타일 검토 (가장 시간 드는 부분)

2. **역할별 MCP · 툴**
   - Secretary: Google Calendar MCP, Gmail MCP, Notion/Linear (읽기), 리더 봇 멘션 권한
   - CFO: 회계 SaaS MCP (가능하면), GSheets, 계산기
   - CMO: web search, Brave, 경쟁사 URL 모니터
   - CPO: Linear/Jira MCP
   - CDO: PostgreSQL MCP, dbt MCP
   - Design: Figma API

3. **`#leaders-lounge` 협업 시나리오 1 건**
   - 예: CEO 가 `@CPO #leaders-lounge 에서 @CTO 와 상의해서 다음 스프린트 플래닝 해줘`
   - CPO → CTO 스레드에서 대화 → CPO 가 결론 요약 → CEO 에게 DM

4. **비용 모니터링**
   - 6 명 가동 시 일일 비용 패턴 측정
   - `#agent-ops` 에 일일 리포트 자동화

### 완료 조건
- Slack 에 6 명의 C-suite 봇 + 1 명 비서 online (총 7 명)
- 각 리더가 자기 홈 채널 + `#leaders-lounge` 에서 응답
- 비서가 `#ceo-office` 에서 매일 아침 브리핑 자동 포스트
- 첫 리더 간 협업 성공 사례 1 건
- 일일 비용 $12 이내 유지 (비서 1 명 추가분 고려)

## Sprint 3 · CTO 서브워커 5 (1~2 주)

### 목표
- backend-dev, frontend-dev, qa-dev, devops-dev, infra-dev 가동
- `delegates.yaml` 라우팅 실전 검증
- product-repo 에 서브워커별 GitHub App 설치

### 작업 목록

1. **서브워커별 AGENT.md · scope.yaml**
   - 각 서브워커의 `scope.yaml` 에 product-repo 경로 (allowed/read-only/forbidden)
   - `AGENT.md` 의 `github_app` 필드 각자 설정

2. **GitHub App 5 개 생성 · 설치**
   - 권한 분리:
     - backend-dev: `services/`, `platform/*` (frontend 제외) 에만 write
     - frontend-dev: `platform/frontend` 에만 write
     - qa-dev: `e2e/` write + 전체 read
     - devops-dev: `ops/{docker,ansible,scripts}`, `.github/workflows` write
     - infra-dev: `ops/{terraform,kubernetes,infra}` write, **prod 변경은 HITL 필수**

3. **`workers/cto/delegates.yaml` 완성**
   - 경로 매칭 규칙 (architecture.md 참조)
   - 라벨 기반 규칙
   - 에스컬레이션 규칙

4. **CTO 의 위임 로직 구현**
   - CTO 가 요청 받으면 delegates.yaml 조회 → Task 툴로 서브워커 호출
   - 서브워커 결과를 CTO 가 종합 → Slack 응답
   - 여러 서브워커 병렬 호출 지원

5. **E2E 시나리오**
   - CEO `@CTO /review PR #x` (여러 영역 섞인 PR)
   - CTO 가 backend-dev + qa-dev 병렬 호출
   - 결과 통합 보고
   - "수정해" 로 양쪽 모두 수정

### 완료 조건
- 12 봇 전부 online (비서 1 + 리더 6 + 서브워커 5)
- 실제 product-repo PR 에 대해 위임 플로우 검증
- 서브워커가 scope 밖 파일을 수정하려 하면 거부됨 (가드 동작 확인)

## Sprint 4 · 지식 루프 + 감사 + 비용 대시보드 (지속)

### 목표
- 봇 활동이 knowledge 로 축적되기 시작
- 비용·품질 리포트 자동화
- 장기 운영 체계 정착

### 작업 목록

1. **Knowledge 루프**
   - `product-repo/docs/adr/` 의 기존 ADR 을 knowledge MCP 로 인덱싱
   - `/wiki:capture` 스킬이 세션 말미에 ADR 템플릿 PR 생성
   - CTO 가 결정 시점마다 ADR 제안

2. **주간 비용·품질 리포트**
   - 매주 월요일 09:00 cron → CEO DM
   - 내용: 봇별 비용, 활성 스레드 수, PR 채택률, 사람 override 율, 예산 대비 소진율
   - Claude Haiku 로 요약 (저렴)

3. **샘플 품질 리뷰**
   - 주 1 회 CEO 가 무작위 봇 PR 1 건 선택 → 직접 리뷰 → 피드백을 봇 memory 에 저장
   - 피드백 저장 명령: `@CTO 방금 그 리뷰 다음엔 이렇게 해. [피드백]`
   - 봇이 자기 long-term memory 에 기록

4. **루프 방어 검증**
   - 의도적으로 스레드 팔라독스 상황 만들기 (A→B→A)
   - 가드가 언제 발동하는지 관찰 · 조정

5. **Shadow 모드 승격 시스템**
   - 신규 봇은 shadow 로 시작 (CEO 에게만 DM, 채널 포스트 금지)
   - 일주일 관찰 후 `./scripts/worker-promote.sh <name>` 로 public 전환

6. **🔴 레포 분할 체크포인트 — "지금 나눌까?"**

   Sprint 0~3 를 monorepo 로 달려온 시점. 아래 트리거 중 **2 개 이상** 발생했으면 분할 준비:

   **트리거 시그널**:
   - [ ] `workers/` 파일 수가 전체의 50% 초과
   - [ ] `_runtime/` 이 v1.0 안정화 — 인터페이스가 더 이상 바뀌지 않음
   - [ ] 두 번째 사람이 합류해 봇 전담 (human dotfiles 와 분리된 업무)
   - [ ] product-repo 팀원이 `workers/` 에 읽기 권한 필요하지만 CEO cockpit 엔 접근 금지
   - [ ] 봇 CI/CD 파이프라인이 dotfiles 관리와 완전히 달라짐 (Docker 빌드 빈도·시크릿 요구사항)
   - [ ] `_runtime/` 을 오픈소스로 공개하고 싶어짐

   **분할 형태 (트리거 발생 시)**:
   ```
   claude-cockpit       (현 상태 유지, 인간 dotfiles)
     core/ humans/ scripts/ docs/

   agent-platform       (신규, 오픈소스 후보)
     _runtime/ _template/ schemas/ scripts/worker-*.sh
     → PyPI 배포 가능한 Python 라이브러리

   company-workers      (신규, 프라이빗)
     workers/cto/ workers/cfo/ ... slack/ deploy/ secrets/
     → agent-platform 의존. product-repo 회사 자산
   ```

   `core/standards/` 는 별도 `standards` 레포로 승격 또는 submodule 로 두 레포에서 참조.

   **트리거 미달이면**: 분할하지 말고 monorepo 유지. 1 인 · 2 레포 운영 비용이 benefit 초과.

   **결정 산출물**: `docs/adr/NNNN-repo-split-or-not.md` ADR 작성 (분할하든 안 하든)

### 완료 조건
- 주간 리포트가 CEO DM 으로 자동 도착
- 최소 1 건의 봇 생성 ADR PR 이 merge 됨
- 봇 품질 피드백이 long-term memory 에 반영되어 다음 작업에서 재현됨

## 진척 추적 방식

- 각 스프린트의 완료 조건이 곧 진행 판정
- `~/.claude/projects/<project-id>/memory/` 에 스프린트별 완료 기록
- `cockpit-review.md` 에 "에이전트 플랫폼 상태" 섹션 추가

## 리스크 · 회피책

| 리스크 | 회피책 |
|---|---|
| Slack API rate limit 에 걸림 | Bootstrapper 호출 시 sleep 삽입, 배치 크기 제한 |
| GitHub Actions 무료 한도 초과 | 월 중 상태 모니터링, 초과 예측되면 긴급 Sprint 우선순위 조정 |
| Claude API 비용 폭주 | 각 봇 일일 캡 + Anthropic 콘솔 org 한도 + 킬스위치 4 중 방어 |
| 봇 간 무한 루프 | 5 중 loop guard, 발생 시 자동 정지 + 분석 리포트 |
| 프롬프트 인젝션으로 봇 탈취 | guard 훅 + system/user 메시지 분리 + 승인 게이트 우회 불가 |
| 서브워커가 scope 밖 수정 | scope.yaml 기반 정적 검증 + 실행 시점 path check |
| CEO 가 전체 감당 못 함 | 봇 수 증가에 맞춰 위임 단순화, shadow 모드로 점진 전환 |

## 다음 액션

Sprint 0 의 첫 작업 = **레포 재구조화**. 이것부터 시작.
