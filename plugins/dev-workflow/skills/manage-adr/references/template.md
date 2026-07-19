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
-->

# ADR-YYYYMMDD[-N]: <Title>

<!--
ファイル名規則: ADR-YYYYMMDD[-N]-<slug>.md
- 同日1件目は `-N` なし、2件目以降は `-2` から付与
- `<slug>` は内容を表す短い英数字ハイフン区切り（例: cache-layer-replacement）
詳細は manage-adr スキルを参照
-->

## Context

<決定の背景・前提・制約を記述。なぜこの判断が必要になったか、関連するホットスポット番号や先行Issueがあれば併記>

## Decision

<採用した決定内容を記述。複数項目を束ねる場合は箇条書きで列挙>

## Consequences

<採用結果としての影響・トレードオフ・将来の留保事項を記述。受容したコスト、得られた利益、将来再検討する条件など>

## 関連ADR

<!--
表記規約:
- Supersedes: ADR-YYYYMMDD[-N]-<slug>   （本ADRが旧ADRを全体上書きする場合。旧ADR側 front-matter の superseded-by が本ADRを指す）
- Superseded by: ADR-YYYYMMDD[-N]-<slug> （本ADRが後継ADRに全体上書きされた場合。本ADR自身の front-matter superseded-by にも後継の full slug を記載する）
- Related: ADR-YYYYMMDD[-N]-<slug>       （直接の上書き関係はない関連ADR）
- Amends / Amended by: 旧運用で使われ、現行スキーマでは廃止済みの表記。既存ファイルに残る記載は凍結保持せず、生存語彙（Supersedes: / Superseded by: / Related: および ## 変更履歴）へ移行したうえで corpus から除去する。新規起票では使わない。
該当なしの場合は「該当なし」と記述。関連Issueも併記可（書式: `関連Issue: #<番号>`、複数件はカンマ区切り）
-->

<先行ADR・後継ADR・関連ADRを full slug で列挙。該当なしの場合は「該当なし」と明記>
