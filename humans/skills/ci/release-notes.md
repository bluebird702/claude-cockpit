---
name: ci:release-notes
description: 두 태그(또는 커밋) 사이의 PR 목록에서 사용자용 릴리스 노트 초안 생성
type: slash-command
category: ci
follows-standards:
  - standards/CLAUDE.md
enforcement: required
---

# 릴리스 노트 초안

> ⚠️ **Standards 준수 필수** · @standards/CLAUDE.md · @docs/writing

$ARGUMENTS
- `<from>..<to>` 형식 (예: `v1.2.0..v1.3.0`, `HEAD~20..HEAD`)
- 인자 없음 → 직전 태그..HEAD

## Step 1: 범위 확정
```bash
# 직전 태그 찾기
git describe --tags --abbrev=0
# 범위 검증
git log <from>..<to> --oneline | head
```

## Step 2: 머지된 PR 수집
```bash
git log <from>..<to> --merges --pretty='%H %s'
# 또는 GitHub 기준
gh pr list --state merged --search "merged:<from-date>..<to-date>" --limit 200 --json number,title,author,labels,body
```

## Step 3: 분류
라벨·제목 패턴으로 그룹화:
- `feat:` / `feature` 라벨 → **새 기능**
- `fix:` / `bug` 라벨 → **버그 수정**
- `perf:` → **성능**
- `security` 라벨 → **보안** (최상단 노출)
- `breaking` / `!:` → **파괴적 변경** (가장 눈에 띄게)
- 나머지 → **기타**

내부 리팩터링·테스트·문서(`chore`, `refactor`, `test`, `docs`)는 기본 제외. 필요하면 접을 수 있는 "내부 변경" 섹션으로.

## Step 4: 사용자 관점 재작성
각 항목을 **사용자가 체감하는 말**로 변환:
- ❌ "Refactor payment processor to use strategy pattern"
- ✅ "결제 실패 시 재시도 로직 개선 (간헐적 실패 감소)"

근거가 없는 사용자 가치는 쓰지 말 것 (추측 금지). PR 본문에서 인용.

## Step 5: 출력

```markdown
# Release v1.3.0 — 2026-04-05

## 🚨 파괴적 변경 (마이그레이션 필요)
- API `/v1/orders` 응답 필드 `total_amount` → `total` (#1234)
  - 마이그레이션: [링크]

## ✨ 새 기능
- 결제 수단에 **카카오페이** 추가 (#1210)
- 주문 상세 화면 재설계 (#1218)

## 🐛 버그 수정
- 대시보드 월별 차트 타임존 오류 (#1221)

## 🔒 보안
- axios 취약점 패치 (#1225, CVE-2024-xxxx)

## ⚡ 성능
- 상품 목록 API p95 120ms → 70ms (#1230)

<details>
<summary>내부 변경 (기여자용)</summary>

- 테스트 유틸 통합 (#1215)
- CI 파이프라인 캐시 최적화 (#1228)
</details>

---
**전체 변경 내역**: v1.2.0...v1.3.0
**기여자**: @contributor-a, @contributor-b, @new-dev (첫 기여 환영)
```

**원칙**: 사용자가 알고 싶어하는 것만. 내부 디테일은 접어두거나 제외.
