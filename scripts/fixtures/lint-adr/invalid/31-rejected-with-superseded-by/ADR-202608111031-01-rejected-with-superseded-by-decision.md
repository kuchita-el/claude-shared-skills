---
status: 却下
superseded-by: ADR-202608121031-01-rejected-superseded-by-successor
---
# ADR-202608111031-01-rejected-with-superseded-by-decision: 却下なのに superseded-by を持つ決定

## Context

fixture 用。`status: 却下` でありながら `superseded-by` を持つ ADR。却下 は一度も運用されない終端であり、有効性軸（validity・superseded-by）を持たない。上書きは有効な決定が後継へ置き換わる遷移であって、却下された決定には起こり得ない。レイヤ1の組み合わせ違反（種別7）を検出させる。

30-proposed-with-superseded-by が 提案中 側を担うのに対し、本 corpus は 却下 側を担う。種別7 の条件は `status=提案中` と `status=却下` の選言であり、既存の 14-proposed-with-validity / 15-rejected-with-validity（種別6）が両状態を別 fixture で押さえているのと対称に置く。

他レイヤが発火しないことは 30 と同じである（`validity` が空のため index にもレイヤ4 の source 集合にも入らず、後継が逆参照を持つためレイヤ3 も充足する）。

## Decision

fixture 用のため実質的な決定内容は無い。

## 関連ADR

- Superseded by: ADR-202608121031-01-rejected-superseded-by-successor（組み合わせ違反 fixture のペア）
