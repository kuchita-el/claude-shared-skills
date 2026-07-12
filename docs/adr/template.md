---
status: 提案中
validity:
superseded-by:
---

# ADR-YYYYMMDD[-N]: <Title>

<!--
ファイル名規則: ADR-YYYYMMDD[-N]-<slug>.md
- 同日1件目は `-N` なし、2件目以降は `-2` から付与
- `<slug>` は短い英数字ハイフン区切り（例: technical-decision-aggregate-foundation）
詳細は docs/adr/README.md を参照
-->

## Status（承認軸／有効性軸）

<!--
状態は本ファイル冒頭の front-matter（status / validity / superseded-by）が唯一の権威。
本節はその補足説明・遷移の記録用。スキーマ・遷移ルールの正本は ADR-20260711-3 を参照。
front-matter 内には値の説明・トレーリングコメントを書かない（純粋な `key: value` のみ、lint パーサが行全体を値として取り込むため）。値域・必須条件は本節に記述する。
-->

- **承認軸**（`status`・不変の履歴事実）: `提案中` → `承認済み` または `却下` のいずれか。起票時は `提案中` で開始し、以後は上書きしない。
- **有効性軸**（`validity`・可変の現在の効力）: `有効` → `上書き済み` または `廃止済み` のいずれか。`提案中`・`却下` のときは空のまま。
- **`superseded-by`**: `validity=上書き済み` のとき必須（値の例: `ADR-YYYYMMDD[-N]-<slug>`）。それ以外は空のまま。

front-matter の値と遷移の対応（代表例）:

| 遷移 | status | validity | superseded-by |
|---|---|---|---|
| 起票 | 提案中 | （空） | （空） |
| 承認 | 承認済み | 有効 | （空） |
| 上書き | 承認済み（不変） | 上書き済み | 必須（後継ADRの識別子） |
| 廃止 | 承認済み（不変） | 廃止済み | （空） |
| 却下 | 却下 | （空） | （空） |

上書き・廃止の詳細手順は `docs/adr/README.md`「廃止・上書き手順」を参照。

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
- Superseded by: ADR-YYYYMMDD[-N]-<slug> （本ADRが後継ADRに全体上書きされた場合。本ADR自身の front-matter superseded-by にも後継の識別子を記載する）
- Related: ADR-YYYYMMDD[-N]-<slug>       （直接の上書き関係はない関連ADR）
- Amends / Amended by: 凍結された歴史的相互参照。ADR-20260511系の旧運用（facet改訂）で使われた表記であり、新スキーマでは廃止（ADR-20260711-3 決定4）。既存ファイルの記載は遡及編集せず保持するが、新規起票では使わない。
該当なしの場合は「該当なし」と記述。関連Issueも併記可（例: 関連Issue: #130, #169）
-->

<先行ADR・後継ADR・関連ADRの識別子を列挙。該当なしの場合は「該当なし」と明記>
