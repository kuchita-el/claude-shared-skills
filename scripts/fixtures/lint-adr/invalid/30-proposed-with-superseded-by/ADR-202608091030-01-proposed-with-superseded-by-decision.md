---
status: 提案中
superseded-by: ADR-202608101030-01-proposed-superseded-by-successor
---
# ADR-202608091030-01-proposed-with-superseded-by-decision: 提案中なのに superseded-by を持つ決定

## Context

fixture 用。`status: 提案中`（起票）でありながら `superseded-by` を持つ ADR。提案中 は承認軸が未承認の状態であり、有効性軸（validity・superseded-by）を持たない。この組み合わせは合法な状態として構成できない。レイヤ1の組み合わせ違反（種別7）を検出させる。

この経路は他のレイヤでは塞がらない。`validity` が空であるため index には採録されず、レイヤ2 は原理的に発火しない。後継 ADR-202608101030-01-proposed-superseded-by-successor が本文に `Supersedes:` 逆参照を持つため、レイヤ3（相互参照双方向性）も forward・reverse とも充足して発火しない。`validity` が `有効` でないためレイヤ4 の source 対象からも外れる。ファイル名・H1 はいずれも規約に適合しレイヤ5 も発火しない。したがって本 corpus が exit 1 になる原因は種別7 の検査だけであり、その分岐を消せば exit 0 へ落ちる。

## Decision

fixture 用のため実質的な決定内容は無い。

## 関連ADR

- Superseded by: ADR-202608101030-01-proposed-superseded-by-successor（組み合わせ違反 fixture のペア）
