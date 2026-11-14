---
status: 承認済み
validity: 有効
superseded-by:
---
# ADR-202611010901-01: 上書きを取り消した旧決定

## Context

fixture 用。退役の取り消し後の ADR 群（12-retirement-undone）の1本。
後継 ADR-202611010902-01-undone-supersede-new による上書きを取り消した旧 ADR を表す。
取り消しで `validity: 有効` へ戻し、`superseded-by` を空にしてある。
本文 `## 関連ADR` の `Superseded by:` 行は取り消しで除いてある。

## Decision

fixture 用の決定。事項 A について案 P を採る。

## Consequences

fixture として index 生成器の入力に使う。

## 関連ADR

該当なし

## 変更履歴

- 2026-11-02 上書き（後継 ADR-202611010902-01-undone-supersede-new）を取り消した。根拠: 後継は事項 A の結論を変えていない
