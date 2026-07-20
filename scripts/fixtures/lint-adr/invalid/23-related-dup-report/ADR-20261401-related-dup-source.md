---
status: 承認済み
validity: 有効
---
# ADR-20261401-related-dup-source: 同一退役ADRを複数Related行から参照する source

## Status

承認済み

## Context

fixture 用（invalid/23）。同一の退役（廃止済み）ADR を、書式の異なる2本の `Related:` 行（plain＋markdown リンク）から参照する。extract_body_related のファイル内 dedup により参照先退役違反が**1回のみ**報告される（park 側 dedup と対称）ことを固定する回帰。dedup を外すと二重報告に戻る。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ4 が参照先退役違反を1回のみ報告し exit 1 になる。

## 関連ADR

- Related: ADR-20261402-related-dup-target（同一退役先への1本目・plain 書式）
- Related: [ADR-20261402-related-dup-target](./ADR-20261402-related-dup-target.md)（同一退役先への2本目・リンク書式。dedup 検証）
