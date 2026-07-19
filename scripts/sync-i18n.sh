#!/usr/bin/env bash
# scripts/sync-i18n.sh
# 
# 한국어 스킬 파일(*.ko.md)을 영어 원본(*.md)으로 자동 번역하여 동기화합니다.
# 사용법: ./scripts/sync-i18n.sh [파일경로 또는 폴더경로]

set -euo pipefail

TARGET="${1:-humans/skills}"

if ! command -v claude >/dev/null 2>&1; then
  echo "Error: 'claude' CLI is required for auto-translation."
  exit 1
fi

find "$TARGET" -name "*.ko.md" | while read -r ko_file; do
  en_file="${ko_file%.ko.md}.md"
  
  if [ -f "$en_file" ] && [ "$ko_file" -ot "$en_file" ]; then
    echo "Skipping $ko_file (English version is newer or up-to-date)"
    continue
  fi

  echo "Translating $ko_file -> $en_file ..."
  
  # Claude Code를 사용해 인라인 번역 실행
  claude -p "Translate the following markdown file to professional Software Engineering English. Keep all YAML frontmatter keys exactly the same, only translate their string values if necessary. Keep all XML tags like <thinking> exactly the same. Do not output anything except the translated markdown. File content: $(cat "$ko_file")" > "$en_file"
  
  echo "✅ Translated: $en_file"
done

echo "🎉 All files synced."
