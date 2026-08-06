---
status: 提案中
validity:
superseded-by:
---

<!--
状態の記述規約:
- 状態は上記 front-matter（status / validity / superseded-by）が唯一の権威。本文に `## Status` 節を置かない。
  front-matter が唯一の権威である以上、本文の状態記述は定義上すべて重複であり、遷移時に取り残されて drift の源になるため。
- front-matter 内には値の説明・トレーリングコメントを書かない（純粋な `key: value` のみ、lint パーサが行全体を値として取り込むため）。
- 値域（各軸の値とその定義）は本雛形に再掲しない。
- 遷移表・front-matter スキーマの必須ルールは本雛形に再掲しない。
- 遷移（承認・上書き・廃止・却下）の実施手順は manage-adr スキルを参照。
- 承認軸（status）と有効性軸（validity）を別フィールドへ分けているのは、1つの欄へ2軸を混在させると
  承認の歴史事実（承認済み）と現在の効力（有効）が判別できなくなるため。1欄混在の案と、
  `Proposed / Accepted / Deprecated / Superseded` の英文4状態で表す案はいずれも却下した
  （後者も承認の歴史事実と現在の効力を同じ値域へ同居させる）。
- キーを英語・値を日本語のユビキタス言語とするのは、キーが状態概念そのものではなく構造的な
  フィールド名であり、英語キーでも概念の二重管理による drift を生まないため（ユビキタス言語の
  本体は値側にある）。冒頭で status と validity が隣接することで「承認済み」を「有効」と
  誤読する罠も防ぐ。
-->

# ADR-YYYYMMDDHHMM-NN: <Title>

<!--
ファイル名規則: ADR-YYYYMMDDHHMM-NN-<slug>.md
- `YYYYMMDDHHMM` は起票時刻（分粒度・ローカル時刻）。同梱の next-adr-id.sh が発番する
- `-NN` は同一時刻部内の連番。`01` 始まりの2桁ゼロ埋めで、1件目にも `-01` を付与
- `<slug>` は内容を表す短い英数字ハイフン区切り（例: cache-layer-replacement）
詳細は manage-adr スキルを参照
-->

## Context

<決定の背景・前提・制約を記述。なぜこの判断が必要になったか、関連するホットスポット番号や先行Issueがあれば併記。本ADR全体に掛かる射程の限定（意図的に決めなかったこと）もここへ書く>

## Decision

<採用した決定内容を記述。複数項目を束ねる場合は箇条書きで列挙。束ねてよいのは一体で反転する塊に限り、独立に反転しうる決定は別 ADR へ分ける。特定の決定に掛かる射程の限定は、専用の節を設けず当該決定の本文へ注記として置く。射程の限定には想定継承先（#Issue番号 / ADR-slug）を併記してよいが、非拘束のポインタであり追随更新の義務を負わない>

## Consequences

<採用結果としての影響・トレードオフを記述。受容したコスト、得られた利益、将来再検討する条件など>

## 関連ADR

<!--
表記規約:
- Supersedes: ADR-YYYYMMDDHHMM-NN-<slug>    （本ADRが旧ADRを全体上書きする場合。旧ADR側 front-matter の superseded-by が本ADRを指す）
- Superseded by: ADR-YYYYMMDDHHMM-NN-<slug>  （本ADRが後継ADRに全体上書きされた場合。本ADR自身の front-matter superseded-by にも後継の full slug を記載する）
- Related: ADR-YYYYMMDDHHMM-NN-<slug>        （直接の上書き関係はない関連ADR）
該当なしの場合は「該当なし」と記述。関連Issueも併記可（書式: `関連Issue: #<番号>`、複数件はカンマ区切り）
書式規約と機械検査の範囲は「相互参照の規約」に従う。
-->

<先行ADR・後継ADR・関連ADRを full slug で列挙。該当なしの場合は「該当なし」と明記>
