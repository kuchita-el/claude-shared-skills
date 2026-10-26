---
status: 承認済み
validity: 廃止済み
---
# ADR-202703030907-01-related-src-abolished: 実在しない参照先を指す廃止済みの source

## Status

承認済み（廃止済み）

## Context

fixture 用（valid/09）。`validity: 廃止済み` の source が、`## 関連ADR` の `Related:` で実在しない ADR を指す。レイヤ4 の source は有効 ADR に限るため、この参照は検査されず違反にならないことを確認する。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

index には現れない（有効でないため）。

## 関連ADR

- Related: ADR-209903010101-01-nonexistent-from-abolished（実在しない参照先。source が有効でないため検査されない）
