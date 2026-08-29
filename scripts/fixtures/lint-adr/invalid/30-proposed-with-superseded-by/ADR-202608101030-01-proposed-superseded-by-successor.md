---
status: 承認済み
validity: 有効
---
# ADR-202608101030-01-proposed-superseded-by-successor: 種別7 fixture の後継決定

## Context

fixture 用。30-proposed-with-superseded-by ADR 群の後継 ADR。ADR-202608091030-01-proposed-with-superseded-by-decision を上書きする側として本文に `Supersedes:` 逆参照を持ち、レイヤ3 を充足させる役割のみを担う。

この後継ファイルが無いと、種別7 の分岐を消す変異に対してレイヤ3 の「参照先が見つかりません」が代わりに発火し、変異が空振りしたまま ADR 群は exit 1 のままになる。変異が赤にする原因を種別7 の分岐へ一意に絞るために置いてある。

本 ADR 自身の front-matter は承認行（`承認済み` / `有効` / superseded-by 無し）に適合しており、レイヤ1違反を出さない。

## Decision

fixture 用のため実質的な決定内容は無い。

## 関連ADR

- Supersedes: ADR-202608091030-01-proposed-with-superseded-by-decision（組み合わせ違反 fixture のペア）
