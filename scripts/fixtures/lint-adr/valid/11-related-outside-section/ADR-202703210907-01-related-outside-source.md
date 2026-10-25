---
status: 承認済み
validity: 有効
---
# ADR-202703210907-01-related-outside-source: 関連ADR 節の外に Related 行を持つ有効な source

## Status

承認済み

## Context

fixture 用（valid/11）。有効な source が、`## 関連ADR` 節の前と後の両方に `Related:` 行を持つ。レイヤ4 が `Related:` を抽出するのは `## 関連ADR` 節の内側に限るため、節の外の行は検査されず違反にならないことを確認する。

節の外の行は、行頭の書式だけを見れば抽出の対象に当たる形で置く。

- Related: ADR-209903210101-01-nonexistent-before-section（節より前の行。実在しない参照先）

節の外の参照先に**実在しない** stem を置くのは、節の限定が外れる退行を dangling 違反として現れさせるためである。節の後ろにも行を置くのは、節の終端（次の `## ` 見出し）で抽出を止める側も固定するためである。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ4 は節の外の行を検査せず exit 0 を維持する。

## 関連ADR

- Related: ADR-202703220907-01-related-outside-target（節の内側の行。有効な参照先）

## 備考

- Related: ADR-209903210101-01-nonexistent-after-section（節より後の行。実在しない参照先）
