#!/usr/bin/env bash
# guard-secrets.sh - PreToolUse(Write|Edit) 훅
#
# Write/Edit 하려는 파일 내용·경로에 시크릿 패턴이 있으면 차단합니다.
# Cowork/indirect prompt injection 으로 비밀이 평문 파일로 유출되는 것을 막는 최후 방어선입니다.
#
# stdin : Claude Code PreToolUse JSON 이벤트
#   { "tool_name": "Write"|"Edit",
#     "tool_input": { "file_path": "...", "content": "..." | "new_string": "..." } }
#
# exit 0 : 통과
# exit 2 : 차단 (stderr 메시지가 Claude 에게 피드백)

set -euo pipefail

# jq 미설치 시 fail-safe 축소 스캔 (fail-open 금지 — security.md § 안전 기본값·fail-closed).
# 원문(JSON) 전체를 grep 으로 훑어 고신호 시크릿을 차단하고, 축소 모드임을 알린다.
if ! command -v jq >/dev/null 2>&1; then
  raw="$(cat)"
  if printf '%s' "$raw" | grep -Eq 'BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[oprsu]_[A-Za-z0-9]{30,}|glpat-[A-Za-z0-9_-]{20,}|xox[abpr]-[A-Za-z0-9-]{10,}|sk-ant-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35}'; then
    echo "[cockpit:guard-secrets] jq 미설치 — 축소 스캔에서 시크릿 패턴 감지, 쓰기 차단" >&2
    exit 2
  fi
  echo "[cockpit:guard-secrets] ⚠ jq 미설치 — 가드가 축소 모드로 동작합니다(정밀도↓). jq 설치를 권장합니다." >&2
  exit 0
fi

payload="$(cat)"
[ -z "$payload" ] && exit 0

tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"
case "$tool" in
  Write|Edit|MultiEdit) ;;
  *) exit 0 ;;
esac

file_path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')"
content="$(printf '%s' "$payload" | jq -r '
  .tool_input.content
  // .tool_input.new_string
  // ([.tool_input.edits // []] | flatten | map(.new_string // "") | join("\n"))
  // empty
')"

# ─────────────────────────────────────────────
# 1) 금지된 대상 경로 (민감 디렉토리·파일명 자체를 편집 시도)
# ─────────────────────────────────────────────
case "$file_path" in
  */.ssh/id_*|*/.ssh/*_rsa|*/.ssh/*_ed25519|*/.aws/credentials|*/.kube/config)
    echo "[cockpit:guard-secrets] 민감 파일 쓰기 차단: $file_path" >&2
    exit 2 ;;
  *.env.example|*.env.sample|*.env.dist|*.env.template) ;;  # 템플릿 허용 (실값 없음) — .env.* 차단보다 먼저
  .env|.env.*|*/.env|*/.env.*)
    # bare 상대경로 `.env` + 모든 변형(.env.local·.env.production·.env.staging 등).
    # 이전 `*/.env` 패턴은 leading slash 를 요구해 상대경로·비표준 변형이 새었음.
    echo "[cockpit:guard-secrets] .env 파일 쓰기는 사용자 승인이 필요합니다: $file_path" >&2
    echo "ask 권한으로 다시 시도하거나, 사용자에게 직접 편집을 요청하세요." >&2
    exit 2 ;;
  *.pem|*.key|*.p12|*.pfx)
    echo "[cockpit:guard-secrets] 인증서/키 파일 쓰기 차단: $file_path" >&2
    exit 2 ;;
  *credentials.json|*service-account*.json)
    # security.md § 시크릿 관리의 커밋 금지 목록과 정합 (GCP service account 등)
    echo "[cockpit:guard-secrets] 자격증명 파일 쓰기 차단: $file_path" >&2
    exit 2 ;;
esac

# ─────────────────────────────────────────────
# 2) 콘텐츠 시크릿 패턴 (정규식, 대소문자 무시)
# ─────────────────────────────────────────────
[ -z "$content" ] && exit 0

# awk 단일 패스 스캔 (grep -E 다중 호출보다 빠름)
hit="$(printf '%s' "$content" | awk '
  BEGIN { IGNORECASE=1; found="" }
  /-----BEGIN (RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY-----/ { found="PRIVATE KEY block"; exit }
  /AKIA[0-9A-Z]{16}/                                        { found="AWS access key (AKIA...)"; exit }
  /ASIA[0-9A-Z]{16}/                                        { found="AWS temp key (ASIA...)"; exit }
  /aws_secret_access_key[[:space:]]*=[[:space:]]*[A-Za-z0-9\/+=]{30,}/ { found="AWS secret access key"; exit }
  /ghp_[A-Za-z0-9]{30,}/                                    { found="GitHub personal token (ghp_)"; exit }
  /gho_[A-Za-z0-9]{30,}/                                    { found="GitHub OAuth token (gho_)"; exit }
  /ghu_[A-Za-z0-9]{30,}/                                    { found="GitHub user-to-server token"; exit }
  /ghs_[A-Za-z0-9]{30,}/                                    { found="GitHub server-to-server token"; exit }
  /ghr_[A-Za-z0-9]{30,}/                                    { found="GitHub refresh token"; exit }
  /glpat-[A-Za-z0-9_-]{20,}/                                { found="GitLab PAT"; exit }
  /xox[abpr]-[A-Za-z0-9-]{10,}/                             { found="Slack token (xox.-)"; exit }
  /sk-[A-Za-z0-9]{32,}/                                     { found="OpenAI/Anthropic-style API key (sk-...)"; exit }
  /sk-ant-[A-Za-z0-9_-]{20,}/                               { found="Anthropic API key"; exit }
  /AIza[0-9A-Za-z_-]{35}/                                   { found="Google API key (AIza...)"; exit }
  /ya29\.[0-9A-Za-z_-]{20,}/                                { found="Google OAuth token"; exit }
  /SG\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{30,}/              { found="SendGrid API key"; exit }
  /[A-Za-z0-9_-]{0,10}_?(PASSWORD|PASSWD|SECRET|TOKEN|APIKEY|API_KEY)[[:space:]]*=[[:space:]]*"[^"$\{]{12,}"/ { found="hardcoded password/secret assignment"; exit }
  END { if (found != "") print found }
')"

if [ -n "$hit" ]; then
  echo "[cockpit:guard-secrets] 시크릿 패턴 감지 — 쓰기 차단" >&2
  echo "파일      : $file_path" >&2
  echo "패턴      : $hit" >&2
  echo "해결 방법 : 값을 환경변수/Keychain 참조로 치환한 뒤 다시 시도하세요." >&2
  echo "          (예: process.env.GITHUB_TOKEN, os.environ[\"GITHUB_TOKEN\"])" >&2
  exit 2
fi

exit 0
