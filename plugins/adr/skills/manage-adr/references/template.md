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

<決定の背景・前提・制約を記述。なぜこの判断が必要になったか、関連するホットスポット番号や先行Issueがあれば併記>

## Decision

<採用した決定内容を記述。複数項目を束ねる場合は箇条書きで列挙。束ねてよいのは一体で反転する塊に限り、独立に反転しうる決定は別 ADR へ分ける>

## Consequences

<採用結果としての影響・トレードオフを記述。受容したコスト、得られた利益、将来再検討する条件など。本ADRが意図的に決めなかった facet（パーク）は任意節「## 保留した決定」へ置く（下記コメント参照）>

<!--
任意セクション「## 保留した決定」（パークがある ADR のみ・既定は不在）:
本ADRが意図的に決めなかった facet（パーク）があれば、Consequences の後・関連ADR の前に `## 保留した決定` 節を追加する。パークが無ければ節ごと置かない（「該当なし」も書かない）。
- 意味論: 何を決めなかったかの起票時点スナップショット。open/resolved 等の状態は持たせず、後から本ADRをさかのぼって更新しない（更新義務が drift を生み、退役後は凍結原則で編集もできないため）。
- 書式: バレットで「保留した facet の説明（想定継承先: #Issue番号 / ADR-slug、起票時点で分かれば。非拘束のポインタ）」。
- 充足の記録は後継ADR側に置く: 後継が本ADRの保留 facet を決めたら、後継の「## 関連ADR」に `- Related: <本ADR>（… を充足。上書きでない）` を書く。本ADRは編集しない。
- 意味論・充足規約・lint 要件の詳細は「保留した決定」節の運用規約に従う。
-->

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
