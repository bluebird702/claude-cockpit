#!/usr/bin/env bash
# guard-bash.sh - PreToolUse(Bash) 훅
#
# 위험한 쉘 패턴을 차단합니다. settings.json 의 deny 리스트는 prefix 매칭만 하므로,
# 파이프/서브쉘/인코딩 우회 같은 패턴을 이 훅이 잡아냅니다.
#
# stdin : { "tool_name": "Bash", "tool_input": { "command": "..." } }

set -euo pipefail

# jq 미설치 시 fail-safe 축소 스캔 (fail-open 금지 — security.md § 안전 기본값·fail-closed).
# 명령 문자열이 JSON 원문에 그대로 있으므로 고신호 위험 패턴을 원문에서 직접 차단한다.
if ! command -v jq >/dev/null 2>&1; then
  raw="$(cat | tr -s '[:space:]' ' ')"
  if printf '%s' "$raw" | grep -Eq 'curl[^|]*\| *(ba)?sh|wget[^|]*\| *(ba)?sh|base64 (-d|--decode)[^|]*\| *(ba)?sh|/dev/(tcp|udp)/|rm -[rf][rf] +(/|~|\$HOME)|nc(at)? -l[^|]*-e|socat[^ ]* EXEC:|env [^|]*(curl|wget)'; then
    echo "[cockpit:guard-bash] jq 미설치 — 축소 스캔에서 위험 패턴 감지, 차단" >&2
    exit 2
  fi
  echo "[cockpit:guard-bash] ⚠ jq 미설치 — 가드가 축소 모드로 동작합니다(정밀도↓). jq 설치를 권장합니다." >&2
  exit 0
fi

payload="$(cat)"
[ -z "$payload" ] && exit 0
[ "$(printf '%s' "$payload" | jq -r '.tool_name // empty')" = "Bash" ] || exit 0

cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')"
[ -z "$cmd" ] && exit 0

block() {
  echo "[cockpit:guard-bash] 위험 패턴 차단: $1" >&2
  echo "명령   : $cmd" >&2
  echo "해결   : 명시적으로 승인된 안전한 명령으로 바꾸거나, 사용자에게 직접 실행을 요청하세요." >&2
  exit 2
}

# 공백 정규화 버전 (연속 공백 압축) — 패턴 매칭용
norm="$(printf '%s' "$cmd" | tr -s '[:space:]' ' ')"

# 1) curl/wget | shell 체인 ("sh" 부분 문자열이 bash/zsh 도 포함)
case "$norm" in
  *"curl"*"|"*"sh"*|*"wget"*"|"*"sh"*)
    block "원격 스크립트 즉시 실행 (curl/wget | sh)" ;;
esac

# 2) base64 디코딩 후 실행
case "$norm" in
  *"base64 -d"*"|"*"sh"*|*"base64 --decode"*"|"*"sh"*)
    block "base64 디코딩 후 실행" ;;
esac

# 3) eval / source 외부 URL
case "$norm" in
  *'eval "$(curl'*|*'eval "$(wget'*|*"eval \`curl"*|*"eval \`wget"*)
    block "eval 로 원격 스크립트 실행" ;;
esac

# 4) /dev/tcp 리버스쉘
case "$cmd" in
  *"/dev/tcp/"*|*"/dev/udp/"*)
    block "리버스쉘 의심 (/dev/tcp|/dev/udp)" ;;
esac

# 5) 네트워크 바인딩 + 쉘 실행
case "$norm" in
  *"nc -l"*"-e"*|*"ncat -l"*"-e"*|*"socat"*"EXEC:"*)
    block "백도어 의심 (nc/ncat/socat -e)" ;;
esac

# 6) 히스토리 은닉
case "$norm" in
  *"HISTFILE=/dev/null"*|*"unset HISTFILE"*|*"history -c"*)
    block "쉘 히스토리 은닉 시도" ;;
esac

# 7) 광범위 재귀 삭제 (deny 리스트 보강 — 변수·환경치환 우회 차단)
case "$norm" in
  *"rm -rf /"|*"rm -rf / "*|*"rm -rf /*"*|*"rm -rf ~"|*"rm -rf ~/"*|*"rm -rf \$HOME"*|*"rm -fr /"*|*"rm -fr ~"*)
    block "광범위 재귀 삭제" ;;
esac

# 8) 민감 파일 평문 출력 (exfiltration 패턴)
# `.ssh/id_`·`.aws/credentials` 와 대칭으로 `.env` 도 bare `cat` 까지 차단한다 —
# 파이프/리다이렉션이 없어도 stdout → 모델 컨텍스트로 시크릿이 유출되기 때문
# (ai-usage.md: 시크릿 AI 전송 금지). 무공백 리다이렉트(`cat .env>out`)도 커버.
case "$norm" in
  *"cat "*".ssh/id_"*|*"cat "*".aws/credentials"*|*"cat "*".env"*)
    block "민감 파일 내용 출력/유출 (.env·키·자격증명)" ;;
esac

# 9) git 서명·훅 우회
case "$norm" in
  *"--no-verify"*|*"--no-gpg-sign"*|*"-c commit.gpgsign=false"*)
    block "git 훅/서명 우회" ;;
esac

# 10) 환경변수 전체 덤프 + 네트워크 전송 ("env " 부분 문자열이 printenv 도 포함)
case "$norm" in
  *"env "*"curl"*|*"env "*"wget"*)
    block "환경변수 덤프 + 외부 전송 (시크릿 유출 패턴)" ;;
esac

# 11) sudo 우회 시도 (deny 보강)
case "$norm" in
  *"sudo -i"*|*"sudo -s"*|*"sudo su"*)
    block "sudo 인터랙티브 진입" ;;
esac

exit 0
