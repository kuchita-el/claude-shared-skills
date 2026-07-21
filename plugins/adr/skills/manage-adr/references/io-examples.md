# 入出力例（io-examples.md）

起票・承認・上書きの代表的な入出力例。front-matter の before→after、ファイル名、相互参照の具体値を示す。front-matter のスキーマ・値域・遷移ごとの必須ルールそのものは SKILL.md が指す状態モデルの規約が実体を持つため、本ファイルではそれらを再定義せず、規約に従う具体値のみを示す。

## 例1: 起票

- **入力**: 新規決定「X を採用する」、起票日 2031-04-15、slug `adopt-x`、同日に既存 ADR なし
- **出力ファイル**: `ADR-20310415-adopt-x.md`（同日1件目のため `-N` なし）
- **出力（front-matter）**:
  ```yaml
  ---
  status: 提案中
  validity:
  superseded-by:
  ---
  ```
- **出力（本文骨格）**: `# ADR-20310415: X を採用する` ＋ `## Context`／`## Decision`／`## Consequences`／`## 関連ADR` の見出しと空プレースホルダ（決定内容は人間が埋める）。状態は front-matter のみで表現し、本文に状態記述の見出し節を置かない。本 ADR が意図的に決めなかった facet（パーク）があれば `## Consequences` の後に `## 保留した決定` を置く（省略可。詳細は ADR-20260720-4）。

**採番衝突例**: 同日に `ADR-20310415`・`ADR-20310415-2` が既存なら、次の起票は `ADR-20310415-3-<slug>.md`（当日最大番号 +1）。

## 例2: 承認

- **入力**: `ADR-20310415-adopt-x.md`（`status: 提案中`）を承認
- **出力（front-matter, before→after）**:
  ```yaml
  # before
  status: 提案中
  validity:
  superseded-by:
  # after
  status: 承認済み
  validity: 有効
  superseded-by:
  ```
- `superseded-by` は空のまま。`status` は以後不変。

## 例3: 上書き（双方向相互参照）

- **入力**: 旧 `ADR-20310409-foo.md`（`status: 承認済み`／`validity: 有効`）を、後継 `ADR-20310415-2-bar`（起票・承認済み）で置換
- **出力（旧側 `ADR-20310409-foo.md` の front-matter, before→after）**:
  ```yaml
  # before
  status: 承認済み
  validity: 有効
  superseded-by:
  # after
  status: 承認済み
  validity: 上書き済み
  superseded-by: ADR-20310415-2-bar
  ```
  旧側の `status: 承認済み` は上書きでも不変（承認は歴史事実）。front-matter 行に説明のトレーリングコメントを書かない規約のため、この注記はコードブロック外で述べる。
- **出力（後継側 `ADR-20310415-2-bar.md` の本文 `## 関連ADR`）**: 次の1行を追加（行頭 `- `、full slug 完全一致）
  ```markdown
  ## 関連ADR

  - Supersedes: ADR-20310409-foo
  ```
- **出力（旧側 `ADR-20310409-foo.md` の本文 `## 関連ADR`）**: 次の1行を追加
  ```markdown
  - Superseded by: ADR-20310415-2-bar
  ```
- 旧側 `superseded-by`（後継 stem）と後継側 `Supersedes:`（旧 stem）が双方向で揃うことで、lint-adr レイヤ3（forward・reverse）が違反を出さない。旧側本文の `Superseded by:` は lint の走査対象外のため、記載漏れは exit 0 のまま素通りする。

## 例4: 廃止・却下（superseded-by を付けない）

- **廃止**: `validity: 有効` → `validity: 廃止済み`（`status: 承認済み` 不変、`superseded-by` 空）
- **却下**: `status: 提案中` → `status: 却下`（`validity`・`superseded-by` 空）。廃止と異なり `validity` を空に保つ。
