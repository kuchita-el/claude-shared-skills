---
status: 承認済み
validity: 廃止済み
superseded-by: ADR-20260808-abandoned-superseded-by-successor
---
# ADR-20260807-abandoned-with-superseded-by-decision: 廃止済みなのに superseded-by を持つ決定

## Context

fixture 用。`validity: 廃止済み` でありながら `superseded-by` を持つ ADR。ADR-20260711-3 決定2 のスキーマ表では、廃止行の superseded-by は「（無し）」であり、この組み合わせは表に存在しない。レイヤ1の組み合わせ違反を検出させる。

決定1 は `廃止済み` を「後継なしで放棄された」と定義しており、後継を指す `superseded-by` を持つなら本来は `上書き済み` であるべきで、2軸の意味論に反する。`廃止済み` と `上書き済み` の取り違えを検出する経路の再現。

後継 ADR-20260808-abandoned-superseded-by-successor が本文に逆参照を持つため、レイヤ3は forward・reverse とも充足し発火しない。これによりレイヤ1の組み合わせ違反のみを単独で観測できる。

## Decision

fixture 用のため実質的な決定内容は無い。

## 関連ADR

- Superseded by: ADR-20260808-abandoned-superseded-by-successor（組み合わせ違反 fixture のペア）
