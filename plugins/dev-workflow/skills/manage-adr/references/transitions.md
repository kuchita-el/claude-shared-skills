# 遷移リファレンス（transitions.md）

ADR の5遷移（起票・承認・上書き・廃止・却下）の front-matter 写入手順・採番規則・相互参照の書き込み手順。front-matter スキーマの必須ルールは正本（`docs/adr/ADR-20260711-3-adr-two-axis-status-validity-model.md` 決定2）を唯一の出典とし、本ファイルはその適用手順を記す（スキーマ表を独自に再定義しない）。

## 目次

- 共通: front-matter の書き方
- 採番規則
- 起票（提案中）
- 承認（承認済み・有効）
- 上書き（上書き済み・双方向相互参照）
- 廃止（廃止済み）
- 却下（却下）
- 自己検証の隔離コピーセット
- 入出力例（上書き遷移）

## 共通: front-matter の書き方

各 ADR ファイル冒頭に `---` で挟んだ front-matter を置く。キーは英語、値は日本語ユビキタス言語。

```yaml
---
status: <提案中 | 承認済み | 却下>
validity: <有効 | 上書き済み | 廃止済み | （空）>
superseded-by: <後継ADRの識別子 | （空）>
---
```

- **値の説明・トレーリングコメントを書かない**。lint パーサ（`scripts/lint-adr.sh`）は `key: value` の行全体を値として取り込むため、`# 説明` を付けると値が壊れる。
- 「キー省略」と「キーあり値空」は同じ「空」として扱われる。空にする軸は値を空にする（キー行自体は残してよい）。
- H1 見出しは `# ADR-YYYYMMDD[-N]: <タイトル>` 形式にする（`gen-adr-index.sh` が `: ` 以降をタイトルとして抽出するため）。

各遷移後の `status`/`validity`/`superseded-by` の最終状態は、必ず正本・決定2の必須ルール表に一致させること。

**遷移前の状態確認（実行ガード）**: 各遷移は期待する遷移元状態を前提とする — 承認は `status: 提案中` から、上書き・廃止は `承認済み`・`validity: 有効` な ADR に対して、却下は未承認の `status: 提案中` に対して行う。実行前に対象 ADR の現在の `status`/`validity` を確認し、期待と異なれば操作を中断して利用者に確認する。`承認済み` の `status` は不変（決定2）であり、承認済み ADR へ却下操作を適用しない。lint は最終状態のスキーマ整合のみを検査し遷移元は見ないため、この不変条件は手順側で守る。

## 採番規則

正本・決定8に従う。採番日＝起票日。**採番日は `date` コマンドを実行せず、実行時コンテキストの現在日付から取得する。**

- 識別子: `ADR-YYYYMMDD[-N]`。ファイル名: `ADR-YYYYMMDD[-N]-<slug>.md`（`<slug>` は短い英数字ハイフン区切り）。
- 同日1件目は `-N` なし（`ADR-YYYYMMDD`）、2件目以降は `-2` から付与。
- 衝突時（同日に既存 ADR がある）は、当日 ADR 一覧の最大番号 +1。`Glob` で `<対象ディレクトリ>/ADR-YYYYMMDD*.md` を列挙し、既存の最大 `-N` を確認してから採番する。
  - 例: 同日に `ADR-20260713`・`ADR-20260713-2` が既存 → 次は `ADR-20260713-3`。
- 配置は `docs/adr/`（本スキルの検証時は隔離ディレクトリ）フラット。サブディレクトリを作らない。

「識別子」は `ADR-YYYYMMDD[-N]` の番号部、「full slug」はファイル名から `.md` を除いた stem（`ADR-YYYYMMDD[-N]-<slug>`）を指す。相互参照（`superseded-by`／`Supersedes:`）には **full slug（stem）** を用いる（lint はファイル存在を stem で解決するため）。

## 起票（提案中）

新規 ADR ファイルを生成する。骨格は `docs/adr/template.md` の構成（front-matter＋`## Status`／`## Context`／`## Decision`／`## Consequences`／`## 関連ADR` の見出し）に準拠しつつ、**見出し骨格＋空プレースホルダを新規に組み立てる**。決定内容の本文（Context／Decision／Consequences の中身）は上位／人間が埋める前提で、空プレースホルダのまま残す。

- front-matter: `status: 提案中`、`validity:`（空）、`superseded-by:`（空）
- ファイル名を採番規則で決定する。
- **テンプレートの HTML 注釈ブロック（`<!-- ... -->`）を生成物へ残さない**。とりわけ `## 関連ADR` 節のテンプレート注釈には表記例として `- Supersedes: ADR-YYYYMMDD[-N]-<slug>` の行が含まれ、lint-adr の本文走査は HTML コメントを認識せずこの例示行を実データの逆参照として拾い、存在しない後継先を指す相互参照違反（起票直後の自己検証が exit 1）を招く。`## 関連ADR` 節は注釈を除去し、先行・後継・関連が無ければ `該当なし` のプレーンな1行のみを置く。

## 承認（承認済み・有効）

対象 ADR の front-matter を編集する。

- `status: 承認済み`、`validity: 有効`。`superseded-by` は空のまま。
- `status` は以後不変（承認は歴史事実）。

## 上書き（上書き済み・双方向相互参照）

core 変更で新規 ADR（後継）が起票・承認済みであることを前提とする（後継が未作成なら起票を先行させる。上書き操作単体では後継ファイルを新規生成しない）。**旧 ADR と後継 ADR の2ファイルを両方更新する**。

1. **旧 ADR の front-matter**（後継への置換を記録）:
   - `status: 承認済み`（不変）、`validity: 上書き済み`、`superseded-by: <後継の full slug>`
2. **後継 ADR の本文 `## 関連ADR`**（逆参照を追加）:
   - `- Supersedes: <旧の full slug>` の行を1行追加する。

この双方向が揃わないと lint-adr レイヤ3（相互参照双方向性）が違反する。lint は次を厳格に要求するため厳守する:

- 後継本文の逆参照は `## 関連ADR` 節内の行で、`- Supersedes: <旧 full slug>`（行頭 `- `＝バレット、full slug 完全一致）。
- `superseded-by` の値と後継ファイル名の stem が一致し、`Supersedes:` の値と旧ファイル名の stem が一致すること（forward・reverse の両方向を検査）。

**分割（1→N）は本スキルのスコープ外**。当面は単一後継（1→1）の上書きのみ扱う（正本・決定3の grandfather 方針。lint reverse は `superseded-by` の完全一致で照合するため、リスト値による 1→N は将来 Issue で対応する）。

## 廃止（廃止済み）

後継なしで決定を放棄する。対象 ADR の front-matter を編集する。

- `status: 承認済み`（不変）、`validity: 廃止済み`。**`superseded-by` は付与しない**（空のまま）。

## 却下（却下）

一度も承認に至らず終了する終端。対象 ADR の front-matter を編集する。

- `status: 却下`。**`validity`・`superseded-by` は付与しない**（空のまま）。
- 廃止（`validity: 廃止済み`）と異なり `validity` を空に保つ。`status: 却下`＋`validity` 空はレイヤ1で合法（`status=承認済み` のときのみ `validity` 必須のため、`却下` では違反にならない）。

## 自己検証の隔離コピーセット

SKILL.md の「各操作後の自己検証」は、live `docs/adr`（#③ 完了まで baseline red）を直接 lint せず、変更/生成した ADR を隔離コピーしたディレクトリに対して lint する。隔離セットに**含めるファイルの規則**は下記。漏らすとレイヤ3 相互参照が false negative（正しい操作でも exit 1）になる。

| 操作 | 隔離コピーに含める ADR |
|---|---|
| 起票 | 生成した ADR 単体（相互参照なし） |
| 承認 | 対象 ADR 単体 |
| 上書き | **旧 ADR ＋後継 ADR の2ファイル**（双方向相互参照の相手を必ず含める） |
| 廃止 | 対象 ADR 単体（`superseded-by` を持たないため相手なし） |
| 却下 | 対象 ADR 単体 |

原則: **変更/生成した ADR と、それが `superseded-by`／`Supersedes:` で指す相互参照の相手をすべて含める**。上書きで旧 ADR 単体をコピーすると、旧の `superseded-by` が指す後継ファイルが隔離セットに不在となり、lint レイヤ3 forward が「参照先が見つかりません」で発火する（実測 exit 1）。旧＋後継の2ファイルを含めれば双方向が揃い exit 0 になる。

コピー後、`validity` を変える操作（承認・上書き・廃止）では隔離ディレクトリで `gen-adr-index.sh` により `index.md` を再生成してから lint する（起票・却下は index 再生成不要）。

## 入出力例（上書き遷移）

- **入力**: 旧 `ADR-20260701-foo.md`（`status: 承認済み`／`validity: 有効`）、後継識別子 `ADR-20260713-2-bar`
- **出力（旧側 front-matter）**: `status: 承認済み`（不変）／`validity: 上書き済み`／`superseded-by: ADR-20260713-2-bar`
- **出力（後継側 `## 関連ADR`）**: `- Supersedes: ADR-20260701-foo` を1行追加
