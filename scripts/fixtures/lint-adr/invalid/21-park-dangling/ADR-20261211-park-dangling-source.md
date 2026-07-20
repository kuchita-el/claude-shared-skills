---
status: 承認済み
validity: 有効
---
# ADR-20261211-park-dangling-source: 保留した決定が非存在 slug を指す source

## Status

承認済み

## Context

fixture 用（invalid/21）。`## 保留した決定`（パーク欄）の参照先ファイルが存在しない（dangling）。レイヤ4 が park 欄も dangling 検査の対象に含めることを確認する（退役検査は park には非適用＝J4）。参照は markdown リンク形式で書き、同一 stem がラベル部とパス部に2回現れても違反が二重報告されない（dedup）ことも確認する。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ4 が dangling 参照違反を報告し exit 1 になる。

## 保留した決定

- あるfacet を未決のまま残す（想定継承先: [ADR-20261298-park-missing](./ADR-20261298-park-missing.md)）
