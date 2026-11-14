---
status: 承認済み
validity: 有効
superseded-by:
---
# ADR-202611010902-01: 上書きを取り消された後継決定

## Context

fixture 用。退役の取り消し後の ADR 群（12-retirement-undone）の1本。
旧 ADR-202611010901-01-undone-supersede-old への上書きが取り消された後継を表す。
後継は `有効` のまま残り、`Supersedes:` 行は取り消しで `Related:` 行へ改めてある。

## Decision

fixture 用の決定。旧 ADR が結論を与えていない事項 B について案 Q を採る。

## Consequences

fixture として index 生成器の入力に使う。

## 関連ADR

- Related: ADR-202611010901-01-undone-supersede-old（取り消しで Supersedes から改めた関連）
