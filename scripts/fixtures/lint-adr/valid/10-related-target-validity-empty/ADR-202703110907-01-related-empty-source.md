---
status: 承認済み
validity: 有効
---
# ADR-202703110907-01-related-empty-source: validity が空の参照先を指す有効な source

## Status

承認済み

## Context

fixture 用（valid/10）。有効な source が、`## 関連ADR` の `Related:` で `validity` が空の実在 ADR（旧形式・提案中・却下）を指す。参照先退役違反は `validity` が上書き済みと完全一致する参照先だけを対象とし、空値はどの退役語彙とも一致しないため違反にならない（fail-open）ことを確認する。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ4 は参照先退役違反も dangling 参照違反も出さず exit 0 を維持する。

## 関連ADR

- Related: ADR-20270312-legacy-related-empty-target（参照先が旧形式。front-matter を持たず validity が空）
- Related: ADR-202703130907-01-related-empty-target-proposed（参照先が提案中。validity が空）
- Related: ADR-202703140907-01-related-empty-target-rejected（参照先が却下。validity が空）
