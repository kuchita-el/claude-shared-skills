---
status: 提案中
validity: 有効
---
# ADR-20260803-proposed-with-validity-decision: 提案中なのに validity を持つ決定

## Context

fixture 用。`status: 提案中`（起票）でありながら `validity` を持つ ADR。スキーマ表では、起票行の validity は「（無し）」であり、この組み合わせは表に存在しない。レイヤ1の組み合わせ違反を検出させる。

語彙メンバシップ検査だけでは、`提案中` も `有効` もそれぞれ語彙に属するため素通りする。表の行としての妥当性を検査して初めて検出できる経路の再現。

## Decision

fixture 用のため実質的な決定内容は無い。
