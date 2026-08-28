---
status: 承認済み
validity: 有効
---
# ADR-202612131034-01-xref-reverse-dangling-new: 逆方向の参照先そのものが実在しない後継決定

## Status

承認済み

## Context

fixture 用。本文の `## 関連ADR` で `Supersedes:` を宣言しているが、その宣言の
参照先 ADR そのものがディレクトリに存在しない（逆方向の参照先不在）。

参照先が実在したうえで front-matter が追随していないケース
（`invalid/07-xref-reverse-missing`）とは到達する分岐が異なる。前者は参照先の
front-matter superseded-by を読みに行って不一致を報告するのに対し、本 fixture は
その手前でファイル不在として報告される。

単一原因で違反1件になる形に保つ。front-matter は合法な組（`承認済み` ＋ `有効`）で
superseded-by を持たず、ファイル名・H1・index のいずれもレイヤ1・2・5 を発火させない。
他レイヤが同時に発火すると、この分岐を落とす変異が赤にならない。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

fixture として drift-lint の入力に使う。

## 関連ADR

- Supersedes: ADR-202612101034-01-xref-reverse-dangling-absent-old
