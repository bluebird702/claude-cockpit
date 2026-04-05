# Cheapest Setup · 최저 비용 셋업 경로

> **⚠️ 지역·가격 정보**: 일부 서비스 가격·리전 정보는 한국 기준입니다. 본인 위치에 맞춰 리전·결제 수단을 재확인하세요.

> 목표: **인프라 비용 $0 으로 시작**해서 실제 필요가 증명된 후에만 단계별로 지출.

## 비용 구조의 진실

설계 대화에서 가장 많이 오해되는 부분은 "봇을 돌리려면 서버가 비싸다" 이다. 실제로는 그 반대다:

| 비용 항목 | 월 추정 | 지배성 |
|---|---|---|
| **Claude API 토큰** | $30 ~ $2,000+ | 🔴 지배적 (사용량 비례) |
| Slack | $0 ~ $10 | 🟡 봇 수에 따라 |
| 컴퓨트 (hosting) | $0 ~ $30 | 🟢 거의 무료 |
| GitHub | $0 | 🟢 무료 |
| Secrets 관리 | $0 ~ $3 | 🟢 거의 무료 |

**핵심 인사이트**: 컴퓨트·인프라는 전체 비용의 **1% 미만**이다. 무엇을 선택하든 LLM 토큰이 90%+ 를 차지한다. 따라서 "최저 비용 셋업" 의 진짜 질문은 **"어떻게 하면 적은 LLM 호출로 가치를 내는가"** 이다.

## Phase 0 · $0 셋업 (최소 2 봇 MVP)

### 구성

```
봇 수:  2개 (CTO + briefing)
Slack:  Free (10 apps 한도 안)
Host:   Fly.io 무료 또는 로컬 (노트북/라즈파이)
GitHub: Personal Free (Actions 2000min/mo, unlimited public)
Secret: pass + macOS Keychain (op CLI 아직 불필요)
Model:  Sonnet 위주, Opus 는 복잡한 판단만
```

### 구체 선택지

**Slack**:
- **Slack Free** 는 워크스페이스당 **앱 10 개 한도**. 2 봇은 여유
- 90 일 메시지 이력 한도 있지만 운영 초기엔 충분
- 봇 user 는 유료 seat 로 카운트되지 않음 (CEO 혼자면 $0)

**Hosting 옵션 (완전 무료)**:

1. **Fly.io 무료 티어** (추천)
   - shared-cpu-1x 256MB 머신 3 개
   - 3GB 영구 볼륨
   - 160GB/월 egress
   - 2 봇이면 1 머신에 같이 돌려도 됨
   - **크레딧카드 등록만 필요** (과금 없음)

2. **Oracle Cloud Always Free**
   - ARM A1.Flex 4 vCPU 24GB RAM (관대함)
   - 200GB 블록 스토리지
   - 리전 주의 (서울 가능)
   - 계정 승인 까다로울 수 있음

3. **로컬 노트북** (진짜 $0)
   - `docker compose up -d` 로 macOS 에서 바로
   - 노트북 꺼지면 봇 오프라인 → 개발·실험엔 충분
   - macOS `caffeinate` 로 슬립 방지

4. **라즈베리파이 / 집 서버**
   - 한 번 사면 전기료만 (월 ~1000원)
   - 상시 구동 가능
   - 재택 네트워크 필요

**GitHub**:
- Personal Free 계정: Actions 2000 min/월 (private repo), 공용 repo 무제한
- GitHub Apps: 무제한 생성 무료
- 봇 1 태스크 ≈ 5 분 가정 → 월 400 태스크 가능
- 초과하면 분당 $0.008 (50 태스크 더 돌려도 $2)

**Secrets**:
- `pass` (Unix password manager) + `gpg` 키 → 완전 무료
- macOS Keychain 도 좋지만 쉘에서 다루기 어려움
- 1Password 는 **Phase 1+** 에서 도입 ($3/월)

**Claude API**:
- Anthropic 신규 가입 시 $5 크레딧 (테스트 충분)
- Phase 0 에서 아끼는 법:
  - 모델 티어링: 분류·라우팅은 **Haiku**, 실제 작업은 **Sonnet**, 복잡 판단만 **Opus**
  - Prompt caching 활성화 → 시스템 프롬프트 부분 90% 할인
  - 짧은 스레드 강제: max_turns_per_thread = 5
  - 초기 봇 2개로 한정
- **예상 지출**: 하루 10 태스크 평균 → 월 $30~80

### Phase 0 총 비용

```
Slack ................. $0
Hosting ............... $0  (Fly.io free 또는 노트북)
GitHub Actions ........ $0
Secrets ............... $0  (pass)
Claude API ............ $30 ~ $80  (사용량)
────────────────────────────
합계: $30 ~ $80/월
```

**인프라 비용 진정으로 $0**. Claude API 만 사용한 만큼 낸다.

## Phase 1 · $10~20 셋업 (리더 6 명 전개)

### 구성

```
봇 수:     6 (리더만)
Slack:     Pro ($8.75/월) ─ 10 apps 한도 초과, unlimited 필요
Host:      Fly.io 무료 (여전)
GitHub:    Pro ($4/월, Actions 3000min 증가) ─ 선택적
Secrets:   1Password ($3/월) ─ 선택적
Model:     리더 Opus, 위임 Sonnet, 라우팅 Haiku
```

### Slack Pro 로의 전환 시점

- **8 개 앱 이하**: Free 유지
- **10 개 초과**: Pro 필수 ($8.75/월/유저, 연간 결제)
- **CEO 1 명 + 봇 다수**: 유저 카운트는 1 명이므로 월 $8.75
- Free 에서 Pro 업그레이드 시 기존 봇 앱·메시지 전부 유지

### Phase 1 총 비용

```
Slack Pro ............. $9
Hosting ............... $0  (Fly.io)
GitHub Pro ............ $4  (선택)
1Password ............. $3  (선택)
Claude API ............ $100 ~ $400  (리더 6 명 × 활동)
────────────────────────────
합계: $116 ~ $416/월
```

## Phase 2 · $30~50 셋업 (12 봇 풀 가동)

### 구성

```
봇 수:     11 (리더 6 + 서브워커 5)
Slack:     Pro (유지)
Host:      Cloud Run min-instance=1 per listener (~$15~25/월)
GitHub:    Pro (3000 min 한도, 큰 작업은 Cloud Run jobs 로)
Secrets:   1Password
Temporal:  없음 (아직)
Model:     리더 Opus, 서브워커 Sonnet
```

### Fly.io 를 넘어가는 지점

- 메모리·CPU 한도 초과 (봇 12 개 동시 + 컨텍스트 캐시)
- 지역 지연 최소화 필요 (한국 사용자 기준)
- SLA / 고가용성 요구
- 이 지점에서 **Cloud Run** (또는 유사 관리형 컨테이너) 로 전환

### Phase 2 총 비용

```
Slack Pro ............. $9
Cloud Run (listeners).. $20
GitHub Pro ............ $4
1Password ............. $3
Claude API ............ $500 ~ $1,500
────────────────────────────
합계: $536 ~ $1,536/월
```

여전히 LLM 토큰이 지배적이다.

## 토큰 비용 최소화 기법

인프라는 이미 최저다. 남은 최적화는 전부 LLM 호출 쪽이다.

### 1. 모델 티어링

```
라우팅 · 의도 분류      → Haiku    ($0.80/M in, $4/M out)
일반 리뷰 · 작업         → Sonnet   ($3/M in, $15/M out)
복잡한 판단 · 아키텍처    → Opus     ($15/M in, $75/M out)
```

**예시**: CTO 봇이 요청을 받으면
1. Haiku 로 "이게 /review 인지, 질문인지, 위임인지" 분류 (저렴)
2. 실제 리뷰는 Sonnet 으로 (중간)
3. "이 PR 이 아키텍처를 바꾸는가" 같은 메타 판단만 Opus (드물지만 비쌈)

평균 비용이 Sonnet-only 대비 **30~50% 절감**.

### 2. Prompt Caching

Anthropic Claude API 는 prompt caching 지원. 시스템 프롬프트·페르소나·표준 문서 같은 **매 호출마다 반복되는 부분**을 캐시해 90% 할인.

- cockpit 의 `core/CLAUDE.md` + `workers/<name>/persona.md` + `standards/*.md` 는 거의 바뀌지 않음 → 캐시 적합
- 캐시 TTL 5 분 (자동 갱신)
- 활성 봇이 자주 호출되면 **시스템 프롬프트 부분의 비용은 실질 0**

### 3. 스레드 히스토리 요약

긴 스레드는 매 턴마다 전체 히스토리를 주입하면 토큰이 급증한다.

- 스레드 턴 5 회 초과 시 앞부분을 요약본으로 교체
- 요약 자체는 Haiku 로 (저렴)
- 최신 2~3 턴은 원문 유지

### 4. 작업 티켓 시스템

봇을 멘션할 때마다 새 세션이 아니라 **티켓 기반** 으로:

- 같은 PR 리뷰 요청이 2 번째면 이전 분석 캐시 활용
- "수정해" 는 이전 리뷰 컨텍스트 재사용
- `~/.cockpit-agents/<name>/cache/` 에 저장

### 5. 배치 처리

- 사소한 작업 (오타 수정, 린트 경고) 은 즉시 처리하지 말고 모았다가 **주 1 회 배치** PR 생성
- 각각 봇 호출하면 오버헤드가 작업 자체보다 큼
- 배치는 cron 트리거, 결과를 한 스레드에 몰아서 보고

### 6. 로컬 도구 우선

- `grep`, `rg`, `jq`, `git log` 등 CLI 로 해결되는 건 Claude 호출 안 함
- Claude 는 "판단" 에만 쓰고, "검색·추출" 은 결정적 도구에 맡김
- 에이전트 SDK 의 tool use 가 이 분리를 강제

### 7. 일일 예산 캡

각 봇의 `AGENT.md` 에 `usd_per_day` 설정. 초과하면 자동 정지 + Slack 알림. 폭주 방지 + 예측 가능성.

## "주말 아침 공포" 방지

무한 루프나 폭주로 월 예산이 하룻밤에 타버리는 시나리오. 4 층 방어:

1. **봇별 일일 캡** — AGENT.md `usd_per_day`
2. **스레드별 캡** — `tokens_per_thread`
3. **Anthropic API 키의 organization spend limit** — 콘솔에서 월 한도 설정 (절대 한도)
4. **Slack 리액션 기반 킬 스위치** — CEO 가 Slack 에서 `/agent stop-all` 한 줄로 전원 정지

4 층 중 어느 하나만 동작해도 폭주가 막힌다.

## 최소 $0 시작 체크리스트

진짜로 돈 한 푼 안 쓰고 시작하려면:

- [ ] Slack Free 워크스페이스 생성 (또는 기존 워크스페이스 재사용)
- [ ] Anthropic API 키 발급 (신규 $5 크레딧)
- [ ] Fly.io 가입 (카드 등록 필요, 과금 없음)
- [ ] GitHub Personal Free 계정 확인 (Actions 2000min)
- [ ] `brew install pass gnupg` → GPG 키 생성 → `pass init`
- [ ] cockpit 에 CTO 봇 + briefing 봇만 먼저 정의
- [ ] `fly launch` → `fly deploy`
- [ ] Slack 에서 `@CTO` 멘션 테스트

이 체크리스트를 완료하면 **월 운영비 $30 ~ $80** 수준에서 시작할 수 있다. 전부 Claude API 사용량이다.

## 언제 각 Phase 로 올라가는가

| 트리거 | 다음 Phase |
|---|---|
| 봇 수가 8 개를 넘어갈 때 | Phase 1 (Slack Pro) |
| Fly.io 무료 한도 초과 | Phase 2 (Cloud Run) |
| 봇이 비즈니스 임계 경로에 들어갈 때 | SLA 가용성 투자 |
| 감사 요구사항 발생 | 중앙 감사 로그 수집 |
| 2 번째 사람 직원 | 1Password Business |
| 팀 단위 격리 필요 | 팀 오버레이 레포 |

**원칙**: 다음 Phase 의 비용을 미리 내지 말 것. 필요가 증명된 후에만 업그레이드.
