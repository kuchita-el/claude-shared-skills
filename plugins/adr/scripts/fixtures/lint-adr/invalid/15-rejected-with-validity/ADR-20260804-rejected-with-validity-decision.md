---
status: 却下
validity: 有効
---
# ADR-20260804-rejected-with-validity-decision: 却下なのに validity を持つ決定

## Context

fixture 用。`status: 却下`（却下）でありながら `validity` を持つ ADR。スキーマ表では、却下行の validity は「（無し）」であり、この組み合わせは表に存在しない。レイヤ1の組み合わせ違反を検出させる。

決定1 は「`却下` は一度も運用されない終端」と定めており、一度も有効になっていない ADR が `validity: 有効` を持つのは 2軸の意味論に反する。この状態を放置すると、却下された ADR が有効 index に採録される。

## Decision

fixture 用のため実質的な決定内容は無い。
