# MCP (Model Context Protocol) 설정

cockpit이 관리하는 MCP 서버: **GitHub · Jira · Confluence · Playwright**

## 빠른 시작

```bash
# 설치 (TUI)
./mcp/setup.sh

# 특정 서버만
./mcp/setup.sh --only github,jira

# 비대화형 (CI·재설치용)
./mcp/setup.sh --env-file ./mcp/.env.example --yes

# 제거
./mcp/clean.sh
./mcp/clean.sh --purge-env   # ~/.config/claude-cockpit/mcp.env 도 삭제
```

## 동작 방식

1. **Phase 1 · 사전 점검** — `node`, `npx`, `jq`, `~/.claude/settings.json` 존재 확인
2. **Phase 2 · 입력 수집** — 선택한 서버의 모든 필수 입력값을 **처음에 한 번에** 수집하고 유효성 검사
3. **Phase 3 · 일괄 적용** — 사용자 확인 후 settings.json 백업 → jq 머지 → 검증

## 환경변수 저장 방식 (보안)

비밀값은 **OS의 안전한 저장소**에 보관되며 평문 파일로 커밋·저장되지 않습니다.

| OS | 저장소 | 조회 방법 |
|----|--------|----------|
| macOS | **Keychain** (`security add-generic-password`) | `security find-generic-password -a GITHUB_TOKEN -s claude-cockpit -w` |
| Linux | **libsecret / GNOME Keyring** (`secret-tool`) | `secret-tool lookup service claude-cockpit account GITHUB_TOKEN` |
| 폴백 | `~/.config/claude-cockpit/secrets.env` (chmod 600, 경고) | 로더 스크립트가 자동 source |

### 파일 구성

- `~/.claude/settings.json` — `${GITHUB_TOKEN}` 형태의 **참조만** 기록, 값은 포함 안 됨
- `~/.config/claude-cockpit/mcp.public.env` — URL·이메일 등 **비밀 아닌 값**만 (chmod 600)
- `~/.config/claude-cockpit/load-mcp-env.sh` — 자동 생성 로더. Keychain/libsecret에서 비밀을 읽어 `export`
- `~/.zshrc` (또는 `~/.bashrc`)에 아래 한 줄 자동 추가:
  ```bash
  [ -f ~/.config/claude-cockpit/load-mcp-env.sh ] && source ~/.config/claude-cockpit/load-mcp-env.sh
  ```

### 강제로 파일 폴백 쓰기
```bash
COCKPIT_SECRETS_BACKEND=file ./mcp/setup.sh
```

## 토큰 발급 가이드

| 서버 | 발급 경로 |
|------|----------|
| GitHub | https://github.com/settings/tokens (classic, `repo` + `read:org`) |
| Jira | https://id.atlassian.com/manage-profile/security/api-tokens |
| Confluence | 위와 동일 (Atlassian 계정 1개로 공유) |
| Playwright | 토큰 불필요 |

## 백업과 롤백

모든 변경 전 `~/.claude/backups/mcp-YYYYMMDD-HHMMSS/settings.json` 에 백업됩니다. 문제 발생 시:

```bash
cp ~/.claude/backups/mcp-<TIMESTAMP>/settings.json ~/.claude/settings.json
```
