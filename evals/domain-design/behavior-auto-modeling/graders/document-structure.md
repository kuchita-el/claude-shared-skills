---
# 狙う所見: 正しい完了。notation:468-490・flow:249-262 の文書構造の主要節と、コマンドの `イベント:` 欄が揃っているか。
# `イベント:` 行の存在は event-field-no-state（not_contains）が空振りで合格するのを防ぐ対でもある。
type: regex
target:
  source: file
  path: docs/library/domain-model.md
pattern: '^(?=[\s\S]*スコープ)(?=[\s\S]*共通値)(?=[\s\S]*会員)(?=[\s\S]*貸出)(?=[\s\S]*ワークフロー)(?=[\s\S]*コンテキスト境界)(?=[\s\S]*DL\s*文書との対応表)(?=[\s\S]*モデル化で露出した論点)(?=[\s\S]*\n[ \t]*イベント:[ \t]*\S)'
---
