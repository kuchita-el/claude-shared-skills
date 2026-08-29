---
status: 承認済み
validity: 上書き済み
superseded-by: ADR-202610111010-01-xref-list-fm-new-a, ADR-202610121010-01-xref-list-fm-missing-b
---
# ADR-202610101010-01-xref-list-fm-old: forward参照先ファイル不在（リスト）検証用の旧決定

## Status

承認済み（上書き済み）

## Context

fixture 用。superseded-by のうち後継A は実ファイルとして存在するが、後継B は
ADR 群内に実ファイルが存在しない（実在しない stem を指す）異常系の ADR 群（10）の分割元 ADR。
リスト要素単位のファイル存在チェック（配列展開・ループ境界）を検証する。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

後継Bのエッジのみ「参照先が見つかりません」違反となり、後継Aは独立して照合へ進むことを検証する。

## 関連ADR

- Superseded by: ADR-202610111010-01-xref-list-fm-new-a, ADR-202610121010-01-xref-list-fm-missing-b
