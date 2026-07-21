---
status: 承認済み
validity: 上書き済み
superseded-by: ,
---
# ADR-20261110-xref-list-empty-old: 空要素のみの superseded-by（病的値）検証用

## Status

承認済み（上書き済み）

## Context

fixture 用。superseded-by がカンマ・空白のみで有効な参照先 stem を1つも含まない病的値の corpus（11）。
レイヤ1の raw 空判定を通過し、かつ forward の分割結果が0件になるため、
「validity=上書き済み ⟹ 少なくとも1件の後継が照合される」不変条件が崩れる経路を検証する。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

forward で「有効な参照先 stem がありません」違反として検出されることを検証する
（かつ set -e 下でスクリプトが異常終了しないこと）。
