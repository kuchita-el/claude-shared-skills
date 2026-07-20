---
status: 承認済み
validity: 有効
---
# ADR-20261101-related-retired-nb-source: バレット無し Related が退役ADRを指す source

## Status

承認済み

## Context

fixture 用（invalid/18）。穴1（行頭バレット無し）の `Related:` 行が退役（廃止済み）ADR を指す。レイヤ4 が書式非依存に先頭 stem を抽出し退役参照違反を検出することを確認する。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ4 が参照先退役違反を報告し exit 1 になる。

## 関連ADR

Related: ADR-20261102-related-retired-nb-target（バレット無しの一方向 Related。参照先は廃止済みで退役参照検査を発火させる）
