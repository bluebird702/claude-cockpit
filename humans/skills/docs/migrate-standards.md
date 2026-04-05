---
name: docs:migrate-standards
description: 프로젝트에 cockpit standards를 연결하고 기존 CLAUDE.md 중복 정리
type: slash-command
category: docs
follows-standards:
  - standards/CLAUDE.md
enforcement: required
---

# standards 마이그레이션

> ⚠️ **Standards 준수 필수** — 표준 참조 방식은 cockpit 규약을 따릅니다.
> @standards/CLAUDE.md

프로젝트에 cockpit standards를 연결하고, 기존 CLAUDE.md에서 중복을 정리합니다.

$ARGUMENTS
- 인자 없음 → 현재 프로젝트에 마이그레이션 실행
- `--dry-run` → 변경 사항을 미리보기만 하고 실제 변경하지 않음

## Step 1: 사전 확인

- `docs/standards/` 경로에 cockpit standards 링크(또는 submodule)가 이미 있는지 확인
- 이미 있으면 "이미 standards가 연결되어 있습니다" 안내 후 Step 3으로 이동
- CLAUDE.md가 존재하는지 확인. 없으면 Step 2-2에서 템플릿으로 생성

## Step 2-1: standards 연결

cockpit이 submodule로 추가되어 있으면:
```bash
.cockpit/scripts/project-link.sh --with standards
```

cockpit이 없으면 먼저 추가:
```bash
git submodule add git@github.com:<YOUR_ORG>/claude-cockpit.git .cockpit
.cockpit/scripts/project-link.sh --with standards
```

연결 후 `docs/standards/CLAUDE.md` 가 존재하는지 확인합니다.

## Step 2-2: CLAUDE.md가 없는 경우

`docs/standards/templates/CLAUDE.md.template` 을 프로젝트 루트에 `CLAUDE.md` 로 복사하고, 사용자에게 프로젝트 정보를 채워달라고 안내합니다.

## Step 3: 기존 CLAUDE.md 정리

### 제거 대상 (standards와 중복)

- 코딩 가이드라인 파일 참조 (`coding-guidelines.md` 등)
- 테스트 가이드라인 파일 참조 (`testing-guidelines.md` 등)
- API 설계 가이드 파일 참조 (`api-design.md` 등)
- "응답 언어는 한글" 정책
- "커버리지 임계값 조정 금지" 정책
- "Domain 모듈에 프레임워크 의존성 금지" 정책

### 유지 대상

- 프로젝트 개요, 아키텍처 설명
- 빌드/테스트 명령어
- 환경 설정 (환경변수, Docker 등)
- 서비스별 커버리지 목표 (구체적 수치 테이블)
- 프로젝트 고유 정책
- 인증 흐름, 저장소 규칙

### 추가할 내용

개발 문서 섹션에 아래 한 줄 추가 (이미 있으면 건너뛰기):

```markdown
> ⚠️ 공통 개발 표준은 `docs/standards/CLAUDE.md` 에서 자동 로딩됩니다.
```

## Step 4: 기존 가이드라인 파일 정리

프로젝트에 cockpit standards와 동일한 내용의 파일이 있는지 확인:
- `**/coding-guidelines.md`
- `**/testing-guidelines.md`
- `**/api-design.md`
- `**/adr/TEMPLATE.md` 또는 `**/adr-template.md`

발견되면:
1. 내용을 cockpit standards 버전과 비교
2. 프로젝트 전용 내용이 포함되어 있다면 → 해당 부분만 유지, 공통 부분 삭제 제안
3. 완전히 동일하면 → 삭제 제안
4. **사용자 확인 후** 삭제 진행 (자동 삭제 금지)

## Step 5: 결과 보고

```
## 마이그레이션 완료

### 추가됨
- docs/standards/ (cockpit symlink)

### CLAUDE.md 변경
- 제거: [제거된 항목 목록]
- 추가: standards 자동 로딩 안내

### 삭제 대상 파일
- [삭제되었거나 삭제가 제안된 파일 목록]

### 다음 단계
- `git add .gitmodules .cockpit docs/standards CLAUDE.md`
- `git commit -m "chore: claude-cockpit standards 도입"`
```

## 주의사항

- `--dry-run` 일 경우 모든 변경 사항을 텍스트로만 출력하고 실제 파일 수정/삭제를 하지 않습니다
- 기존 구조(섹션 순서, 마크다운 스타일)를 최대한 유지합니다
- 판단이 어려운 경우 사용자에게 확인합니다
- 커밋은 하지 않습니다 (사용자가 직접 확인 후 커밋)
