---
status: 承認済み
validity: 上書き済み
superseded-by: ADR-20260221-xref-tc-new,
---
# ADR-20260220-xref-tc-old: 末尾カンマ superseded-by の堅牢性検証用

## Status

承認済み（上書き済み）

## Context

fixture 用。superseded-by が末尾カンマ付き（`ADR-...-new,`）の正常系 corpus（05）。
末尾カンマ由来の空要素はスキップされ、有効な後継1本が正しく照合されることを検証する。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

末尾カンマは無害（違反にならない）ことを検証する。

## 関連ADR

- Superseded by: ADR-20260221-xref-tc-new
