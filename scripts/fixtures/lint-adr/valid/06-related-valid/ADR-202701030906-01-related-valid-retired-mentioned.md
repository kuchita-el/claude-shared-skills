---
status: 承認済み
validity: 廃止済み
---
# ADR-202701030906-01-related-valid-retired-mentioned: 先頭 stem として指される後継なし退役（廃止済み）ADR

## Status

承認済み（廃止済み）

## Context

fixture 用（valid/06）。source の `Related:` 行から**先頭 stem として**指される、後継を持たずに退役した（`廃止済み`・実在）ADR。差し替え先が存在しないため退役検査の対象外であり、参照されても違反にならないことを確認する。

ファイル名 stem の `-mentioned` は、散文で言及されるデコイだった当時の名残である。デコイは実在しない stem へ移したため、本 ADR の役割は先頭 stem として指される非違反の参照先のみである。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

index には現れない（有効でないため）。実在するため dangling ではない。
