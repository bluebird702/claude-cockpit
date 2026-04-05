#!/usr/bin/env bash
# session-context.sh - SessionStart 훅
#
# 세션 시작 시 현재 작업 디렉토리의 git 상태·브랜치·최근 커밋을 Claude 에게 주입합니다.
# stdout 출력이 그대로 additionalContext 로 세션에 합류합니다.
#
# 목표: "이 세션이 어떤 레포·브랜치·상태에서 시작됐는지" 한 화면으로.

set -euo pipefail
cwd="$(pwd)"

# git 레포가 아니면 조용히 통과
git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
upstream="$(git -C "$cwd" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo '')"
ahead_behind="$(git -C "$cwd" rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null || echo '0 0')"
behind="$(echo "$ahead_behind" | awk '{print $1}')"
ahead="$(echo "$ahead_behind" | awk '{print $2}')"

dirty_count="$(git -C "$cwd" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
staged_count="$(git -C "$cwd" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')"

cat <<EOF
## 🛰  세션 컨텍스트 (cockpit)

- **CWD**: \`$cwd\`
- **브랜치**: \`$branch\`${upstream:+ → \`$upstream\`}${ahead:+ (ahead $ahead, behind $behind)}
- **변경 파일**: ${dirty_count}개 (staged ${staged_count})

### 최근 커밋 5건
\`\`\`
$(git -C "$cwd" log --oneline -5 2>/dev/null || echo '(없음)')
\`\`\`
EOF

# 변경 파일이 있으면 간단히 나열 (최대 15줄)
if [ "$dirty_count" -gt 0 ]; then
  echo
  echo "### 변경된 파일"
  echo '```'
  git -C "$cwd" status --short 2>/dev/null | head -15
  echo '```'
fi

# 레포별 CLAUDE.md 가 있으면 존재만 알림 (로딩은 Claude Code 본체가 담당)
if [ -f "$cwd/.claude/CLAUDE.md" ] || [ -f "$cwd/CLAUDE.md" ]; then
  echo
  echo "_프로젝트 CLAUDE.md 가 로드되어 있습니다._"
fi

exit 0
