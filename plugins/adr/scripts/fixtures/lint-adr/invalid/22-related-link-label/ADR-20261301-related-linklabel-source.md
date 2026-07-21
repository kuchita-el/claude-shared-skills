---
status: 承認済み
validity: 有効
---
# ADR-20261301-related-linklabel-source: リンクラベルが説明文の Related が退役ADRを指す source

## Status

承認済み

## Context

fixture 用（invalid/22）。`Related:` のリンクラベルが説明文で ADR stem がパス部にのみ現れる書式（`[詳細はこちら](./ADR-X.md)`）でも、`Related:` 以降で最初に現れる ADR stem を抽出して退役参照違反を検出することを確認する（書式非依存の適用範囲＝リンクラベル書式）。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ4 が参照先退役違反を報告し exit 1 になる。

## 関連ADR

- Related: [詳細はこちら](./ADR-20261302-related-linklabel-target.md)（リンクラベルが説明文で stem はパス部のみ。書式非依存で退役参照検査を発火させる）
