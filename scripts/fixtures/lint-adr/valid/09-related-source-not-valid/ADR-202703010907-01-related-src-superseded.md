---
status: 承認済み
validity: 上書き済み
superseded-by: ADR-202703020907-01-related-src-successor
---
# ADR-202703010907-01-related-src-superseded: 実在しない参照先を指す上書き済みの source

## Status

承認済み（上書き済み）

## Context

fixture 用（valid/09）。`validity: 上書き済み` の source が、`## 関連ADR` の `Related:` で実在しない ADR を指す。レイヤ4 の source は有効 ADR に限るため、この参照は検査されず違反にならないことを確認する。

参照先に**実在しない** stem を置くのは、source の限定が外れる退行を dangling 違反として現れさせるためである。dangling 検査は参照先の `validity` に依存しないため、退役検査の語彙の増減に左右されない。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

index には現れない（有効でないため）。

## 関連ADR

- Superseded by: ADR-202703020907-01-related-src-successor（相互参照双方向性を満たすペア）
- Related: ADR-209903010101-01-nonexistent-from-superseded（実在しない参照先。source が有効でないため検査されない）
