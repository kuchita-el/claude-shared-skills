---
status: 承認済み
validity: 有効
---
# ADR-20260205-xref-nested-new: 入れ子バレット相互参照検証用の後継決定

## Status

承認済み

## Context

fixture 用。相互参照検証専用 corpus（02-xref-valid）の後継 ADR。
ADR-20260204-xref-nested-old を上書きする。本文の Supersedes 宣言を
入れ子（インデント）バレットで記載し、行頭空白を許容する緩和後の
正規表現が誤検知しないことを確認する。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

fixture として index 生成器の入力に使う。

## 関連ADR

- 関連する決定:
  - Supersedes: ADR-20260204-xref-nested-old（入れ子バレット相互参照 fixture のペア）
