---
status: 承認済み
validity: 有効
superseded-by: ADR-20260806-active-superseded-by-successor
---
# ADR-20260805-active-with-superseded-by-decision: 有効なのに superseded-by を持つ決定

## Context

fixture 用。`validity: 有効` でありながら `superseded-by` を持つ ADR。スキーマ表では、承認行の superseded-by は「（無し）」であり、この組み合わせは表に存在しない。レイヤ1の組み合わせ違反を検出させる。

後継 ADR-20260806-active-superseded-by-successor が本文に逆参照を持つため、レイヤ3（相互参照双方向性）は forward・reverse とも充足し発火しない。これによりレイヤ1の組み合わせ違反のみを単独で観測できる。

有効性軸の意味論としても、後継へ置き換えられた（superseded-by がある）のに `有効` のままという状態は矛盾しており、放置すると原 ADR と後継が同時に有効 index へ並ぶ。

## Decision

fixture 用のため実質的な決定内容は無い。

## 関連ADR

- Superseded by: ADR-20260806-active-superseded-by-successor（組み合わせ違反 fixture のペア）
