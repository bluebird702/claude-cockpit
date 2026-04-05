# 커밋 메시지 가이드

> 기준: Conventional Commits + 한글 본문. (영어 본문이 필요한 팀은 본인 규칙에 맞춰 조정하세요.)

## 형식

```
<type>(<scope>): <subject>

<body>

<footer>
```

- **type**: `feat` · `fix` · `refactor` · `chore` · `docs` · `test` · `perf` · `build` · `ci` · `style` · `revert`
- **scope**: 서비스/모듈명 (선택). 예: `account`, `gateway`, `mcp`, `standards`
- **subject**: 명령형·한글 허용·마침표 없음·70자 이하
- **body**: 변경 "이유" 중심. 한 줄당 72자 이내. 한글로 작성해도 됨
- **footer**: `Refs: JIRA-123`, `Closes: #42`, `BREAKING CHANGE: ...`

## 제목 작성 원칙

1. **무엇을 했는지가 아니라 왜 했는지**를 떠올릴 수 있는 제목
   - ❌ `fix: null 체크 추가`
   - ✅ `fix(account): 로그인 응답에서 null 세션 처리 누락`
2. **한 커밋 = 한 변경 의도**. 리팩토링과 기능 추가를 섞지 않습니다.
3. **명령형 현재형**: "추가한다" 보다는 "추가"로 끝맺어 간결하게.

## type 선택 기준

| type | 사용 상황 |
|------|----------|
| `feat` | 사용자에게 보이는 새 기능 |
| `fix` | 버그 수정 (의도와 실제 동작의 차이를 좁힘) |
| `refactor` | 동작 변화 없는 내부 정리 |
| `perf` | 성능 개선 (동작 동일) |
| `docs` | 문서만 변경 |
| `test` | 테스트만 추가/수정 |
| `chore` | 빌드·의존성·설정 등 잡일 |
| `ci` | CI 파이프라인 변경 |
| `build` | 빌드 시스템 자체 변경 |
| `style` | 포매팅·세미콜론 등 (로직 변화 없음) |
| `revert` | 이전 커밋 되돌리기 |

## 본문 체크리스트

- [ ] **왜** 이 변경이 필요했는지 첫 문단에 있는가
- [ ] **무엇을** 바꿨는지 (필요한 경우) 요약
- [ ] **어떻게** 검증했는지 (테스트·수동 확인) — 사소한 변경은 생략 가능
- [ ] 관련 이슈·ADR·티켓 번호 footer에 기재

## 예시

```
feat(mcp): Keychain 기반 비밀값 저장소 도입

파일 평문 저장은 커밋 누출 위험이 있고, 여러 머신에서 동기화 시 민감값이
노출될 수 있어 macOS Keychain / libsecret 백엔드를 도입했습니다. 폴백은
chmod 600 파일이며 경고 로그를 출력합니다.

- setup.sh: 비밀·공개 입력을 분리해 Keychain 저장
- clean.sh: --purge-env 시 Keychain 항목까지 삭제
- 로더 스크립트 자동 생성 + 쉘 rc source 라인 추가(멱등)

Refs: cockpit#12
```

```
fix(gateway): JWT 만료 직전 재발급 시 블랙리스트 경합

Redis SETNX 미사용으로 짧은 구간에 중복 재발급이 발생했습니다.
SETNX + EXPIRE 로 원자성 확보.

Closes: #88
```

## 금지 사항

- 한 커밋에 여러 무관 변경 섞기
- "WIP", "temp", "fix typo" 단독 제목 (스쿼시 전 로컬 커밋은 예외)
- 민감값·경로를 그대로 본문에 기입
- `git commit --amend` 로 공유된 커밋을 재작성 (별도 커밋으로)

## AI 서명

AI 보조 도구가 작성한 커밋은 Co-Authored-By 를 추가합니다:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```
