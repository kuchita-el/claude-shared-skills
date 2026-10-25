---
status: 却下
---
# ADR-202703050907-01-related-src-rejected: 実在しない参照先を指す却下の source

## Status

却下

## Context

fixture 用（valid/09）。却下（`validity` 空）の source が、`## 関連ADR` の `Related:` で実在しない ADR を指す。却下された ADR の参照は確定した決定の一部でないため、レイヤ4 は検査せず違反にならないことを確認する。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

index には現れない（有効でないため）。

## 関連ADR

- Related: ADR-209903010101-01-nonexistent-from-rejected（実在しない参照先。source が有効でないため検査されない）
