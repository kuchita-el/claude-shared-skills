---
status: 承認済み
validity: 有効
---
# ADR-202612101032-01-index-missing-decision: index.md を同梱しない corpus の決定

## Context

fixture 用（invalid/32）。**この corpus は index.md を意図的に持たない。** レイヤ2 は index.md の不在を index 同期違反として扱う。ここへ index.md を足すと corpus は exit 0 へ落ち、不在検査の負例が消える。生成し忘れた index を「差分が無い」と読んで緑にしないことが、この検査の目的である。

本 ADR 自身は `承認済み` / `有効` の承認行に適合し、superseded-by も持たない。ファイル名・H1 も規約に適合する。したがって本 corpus が exit 1 になる原因はレイヤ2 の不在検査だけであり、その分岐を消せば違反メッセージが出なくなる。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ2 が `index 同期違反（index.md が存在しません）` を報告し exit 1 になる。
