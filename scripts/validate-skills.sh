#!/usr/bin/env bash
# スキルファイルのallowed-toolsバリデーション
# - AskUserQuestionがallowed-toolsにあるのに本文に対話パスがないケースを検出
set -euo pipefail

set -u
root="${1:-.}"
errors=0
skill_count=0

while IFS= read -r -d '' skill_file; do
  [ -f "$skill_file" ] || continue
  skill_count=$((skill_count + 1))
  skill_name=$(basename "$(dirname "$skill_file")")

  # フロントマターにAskUserQuestionがあるか
  if grep -q 'AskUserQuestion' "$skill_file"; then
    # 本文（フロントマター以降）にAskUserQuestion/ユーザーに確認/ユーザーに質問 の参照があるか
    body=$(sed -n '/^---$/,/^---$/!p' "$skill_file")
    if ! echo "$body" | grep -qi 'AskUserQuestion\|ユーザーに確認\|ユーザーに質問'; then
      echo "WARNING: $skill_name - AskUserQuestionがallowed-toolsにあるが本文に対話パスがありません"
      errors=$((errors + 1))
    fi
  fi
done < <(find "$root/plugins" -path '*/skills/*/SKILL.md' -print0 2>/dev/null)

if [ "$skill_count" -eq 0 ]; then
  echo "検査対象skillが0件"
  errors=$((errors + 1))
fi

if [ "$errors" -gt 0 ]; then
  echo ""
  echo "$errors 件の警告があります"
  exit 1
fi
