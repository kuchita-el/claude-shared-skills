---
status: 提案中
---
# ADR-202703040907-01-related-src-proposed: 実在しない参照先を指す提案中の source

## Status

提案中

## Context

fixture 用（valid/09）。提案中（`validity` 空）の source が、`## 関連ADR` の `Related:` で実在しない ADR を指す。提案中の参照はまだ確定した決定の一部でないため、レイヤ4 は検査せず違反にならないことを確認する。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

index には現れない（有効でないため）。

## 関連ADR

- Related: ADR-209903010101-01-nonexistent-from-proposed（実在しない参照先。source が有効でないため検査されない）
