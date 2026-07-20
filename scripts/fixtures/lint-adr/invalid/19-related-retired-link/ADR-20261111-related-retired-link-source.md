---
status: 承認済み
validity: 有効
---
# ADR-20261111-related-retired-link-source: リンク形式 Related が退役ADRを指す source

## Status

承認済み

## Context

fixture 用（invalid/19）。穴2（markdown リンク形式）の `Related:` 行が退役（上書き済み）ADR を指す。レイヤ4 がリンク先頭の `[` を吸収して stem を抽出し退役参照違反を検出することを確認する。参照先の退役ペアはレイヤ3双方向を満たし、退役違反のみを分離する。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ4 が参照先退役違反を報告し exit 1 になる（相互参照違反は出ない）。

## 関連ADR

- Related: [ADR-20261112-related-retired-link-old](./ADR-20261112-related-retired-link-old.md)（リンク形式の一方向 Related。参照先は上書き済みで退役参照検査を発火させる）
