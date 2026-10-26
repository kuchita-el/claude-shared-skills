# ADR-20270306: 実在しない参照先を指す旧形式の source

## Status

Accepted

## Context

fixture 用（valid/09）。front-matter を持たない旧 `## Status` 形式の source が、`## 関連ADR` の `Related:` で実在しない ADR を指す。旧形式は `validity` を持たず有効 ADR に当たらないため、レイヤ4 は検査せず違反にならないことを確認する。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

index には現れない（front-matter を持たないため）。

## 関連ADR

- Related: ADR-209903010101-01-nonexistent-from-legacy（実在しない参照先。source が有効でないため検査されない）
