---
name: mgmt:standup
description: 어제 활동(커밋·PR·티켓)을 데일리 스크럼 포맷으로 요약
type: slash-command
category: mgmt
follows-standards:
  - standards/CLAUDE.md
enforcement: required
---

# 데일리 스탠드업 초안

> ⚠️ **Standards 준수 필수** · @standards/CLAUDE.md

"어제 한 일 / 오늘 할 일 / 블로커" 3섹션 고정.

$ARGUMENTS
- 없음: 오늘 기준 어제
- `week`: 월요일에 금요일부터 어제까지
- `monday`: 자동으로 주말 건너뜀

## Step 1: 기간 계산
- 기본: 어제 00:00 ~ 어제 23:59 (로컬)
- 오늘이 월요일이면 금요일 ~ 일요일 포함

## Step 2: 데이터 수집 (병렬, 읽기 전용)

1. **Git**: `git log --all --author="$(git config user.email)" --since='<from>' --until='<to>' --pretty='%h %s' --no-merges`
2. **GitHub PR**: `gh pr list --author @me --search "updated:>=<from>" --json number,title,state,updatedAt`
3. **GitHub 리뷰**: `gh search prs --reviewed-by @me --updated ">=<from>" --json number,title,repository`
4. **Jira/Linear** (MCP 가능 시): 내 티켓 상태 변화
5. **오늘 남은 일**: 현재 브랜치·WIP PR·내게 할당된 열린 티켓

## Step 3: 블로커 감지
다음이면 블로커 후보로 표시:
- 3일 이상 리뷰 대기 중인 내 PR
- "blocked" 라벨 달린 내 티켓
- CI 실패가 반복되는 PR

## Step 4: 출력 (고정 포맷)

```markdown
# 🗓 스탠드업 — 2026-04-05 (@me)

## 어제 (04-04, 목)
- ✅ `payment-service`: 멱등 키 로직 구현 (#1234 머지)
- ✅ `web`: 온보딩 A/B 코드 리뷰 2건
- 🔧 `infra`: Colima 메모리 늘림 (로컬 환경)

## 오늘 (04-05, 금)
- [ ] #1240 결제 실패율 알람 임계값 조정 (PR 초안)
- [ ] @teammate 의 #1238 리뷰 마무리
- [ ] 주간 CEO 브리핑 작성 (`ceo-briefing` 에이전트)

## 블로커 / 도움 요청
- ⚠️ PR #1230 리뷰 3일째 대기 (@bob) — 다른 리뷰어 요청 필요
- (없으면 "없음" 이라고 명시)

---
_수집 누락_: Linear(MCP 미설치)
```

**원칙**:
- 3섹션 넘지 말 것.
- 완료 안 된 항목은 "오늘" 섹션으로 자동 이월.
- 내부 리팩터링·탐색은 제외, 결과만.
