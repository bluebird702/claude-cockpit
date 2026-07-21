#!/usr/bin/env bash
# scripts/setup-git-hooks.sh
# 로컬 개발 환경에 Git Hook을 설치합니다.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -d "$ROOT_DIR/.git/hooks" ]; then
  ln -sf "$ROOT_DIR/system/git/pre-commit" "$ROOT_DIR/.git/hooks/pre-commit"
  chmod +x "$ROOT_DIR/system/git/pre-commit"
  echo "✅ Git pre-commit 훅이 성공적으로 설치되었습니다. (.git/hooks/pre-commit)"
else
  echo "❌ .git/hooks 디렉토리를 찾을 수 없습니다. Git 레포지토리가 맞는지 확인해주세요."
  exit 1
fi
