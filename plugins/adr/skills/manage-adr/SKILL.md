---
name: manage-adr
description: ADR のライフサイクル操作（起票・承認・上書き・廃止・却下の5遷移）と多決定 ADR の分割（1→N の部分上書き）を実行し、front-matter（`status`/`validity`/`superseded-by`）と相互参照をスキーマに従い書き込む。既存 ADR の編集は core／非core／些末で変更種別を確定し、core は新規起票＋旧 ADR 上書き、非core／些末は直接編集へ導く。ADR 化要否も判定し、各操作後は lint-adr で自己検証する。ADR 化を迷う・新規に起こす・承認や上書きで状態を変える・分割する・既存 ADR を編集したいときに使用。
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
  - Edit
  - AskUserQuestion
  - Bash(bash *scripts/lint-adr.sh*)
  - Bash(bash *scripts/gen-adr-index.sh*)
  - Bash(bash *scripts/next-adr-id.sh*)
---

# ADRライフサイクル操作（Manage ADR）

## 文脈固有ルール

- **対象範囲**: 指定されたADRと許可された遷移・編集分類だけを扱う。
- **成果物**: front-matter、本文、相互参照をスキーマに沿って必要十分に更新する。
- **停止条件**: 遷移条件、参照整合、lintのいずれかが未決・不合格なら状態を進めない。
- **変更境界**: 対象ADR以外を変更せず、別判断を黙って混ぜない。

ADR の各遷移（起票・承認・上書き・廃止・却下）と既存 ADR の編集で、front-matter（`status`/`validity`/`superseded-by`）と `## 関連ADR` の相互参照を正しく書き込む。手順の実体は本スキルが持ち、手作業で組み立てずスキル経由で一貫した状態遷移を実行し、各操作の締めに drift-lint で自己検証する。

Claude Codeではcommit前PreToolUse hookが補助的に同じlintを実行する。Codexにはこのplugin単位hookがないため、ホストにかかわらず各操作後の明示lintを必須とする。Codex側のhook/policy callbackが利用可能になった場合だけ、重複workflowを作らずhost adapterへ移行する。

状態値は日本語ユビキタス言語（`提案中`/`承認済み`/`却下`/`有効`/`上書き済み`/`廃止済み`）、キーは英語。値の説明・トレーリングコメントを front-matter 内に書かない（lint パーサが行全体を値として取り込むため）。

## 引数

- 操作種別（`起票`／`承認`／`上書き`／`分割`／`廃止`／`却下`／`編集`）と対象 ADR の識別子・パス
- 省略時は会話コンテキストから意図を判定する。操作種別・対象が特定できなければ、その1点のみ質問する

## 対象操作

### 5遷移（front-matter 状態遷移）

| 操作 | 概要 |
|---|---|
| 起票 | 採番規則で新規 ADR ファイルを生成し `status: 提案中`（`validity`/`superseded-by` は空） |
| 承認 | `status: 承認済み`・`validity: 有効`（`superseded-by` は空のまま） |
| 上書き | 旧 ADR に `validity: 上書き済み`・`superseded-by: <後継>`、後継本文 `## 関連ADR` に `Supersedes: <旧>`（双方向）、旧 ADR 本文 `## 関連ADR` に `Superseded by: <後継>` |
| 廃止 | `validity: 廃止済み`（`superseded-by` は付与しない） |
| 却下 | `status: 却下`（`validity`・`superseded-by` は付与しない） |

各遷移後の front-matter 最終状態は `${CLAUDE_SKILL_DIR}/references/adr-model.md`「状態の型」の構成子として構成できる形にする。採番規則・写入手順・上書きの双方向相互参照の書き込みは `${CLAUDE_SKILL_DIR}/references/transitions.md` を参照する。ADR 本文へ他文書への参照を書く場合（起票時を含む）は、`${CLAUDE_SKILL_DIR}/references/edit-decision.md` の「記録の参照原則」に従う。原 ADR の一部決定だけが反転する 1→N（部分上書き）は、5遷移ではなく下記「分割」を扱う。

### 分割（多決定 ADR の部分上書き。5遷移とは別軸の構造操作）

複数の決定を束ねた ADR の一部だけが core 反転して残りが生存する場合（1→N の部分上書き）、または束ね ADR を予防的に分解する場合（衛生的分割）に使う。原 ADR 全体を `上書き済み` にすると生存決定を誤って退役させるため、生存決定を後継へ逐語 restate してから原 ADR を上書きする。

呼び出しの適用条件は2トリガに分かれる。**既定は分割しない**——既存の多決定 ADR を遡及的に分割せず、下記いずれかのトリガが立ったときにのみ駆動する。

- **反転駆動**: 前段の1→N の部分上書きがこれにあたる。部分 core 反転が実際に当たったときに駆動する（要求される）
- **衛生的分割**: 前段の予防的な分解がこれにあたる。既定（分割しない）に対する**任意**の例外であり、反転駆動と違って要求されない

新規に起こす ADR が独立に反転しうる core を束ねないための制約は `${CLAUDE_SKILL_DIR}/references/adr-scoping.md`「新規 ADR の束ねの制約」節に従う。

分割は5遷移（front-matter 状態遷移）の一種ではない。決定のファイル間再配置という別軸の構造操作であり、本文編集の core／非core／些末分類でもなくリファクタリングに相当する。終端 front-matter は上書きと同型（原 ADR `validity: 上書き済み`・`superseded-by` に全後継を列挙）だが、後継が複数（1→N）で生存決定の救出を伴う点で上書き（1→1）と操作が異なる。

手順の実体（起票・逐語 restate・開示・相互参照の各手順と締めの検査）は `${CLAUDE_SKILL_DIR}/references/transitions.md`「分割（多決定 ADR の部分上書き）」節を参照する。

### 編集判定フロー（既存 ADR の変更）

`validity: 有効` な ADR への変更は、変更種別（core／非core／些末）を `AskUserQuestion` で利用者へ問って確定する。既定選択肢は core（安全則「迷ったら core」）。分類に応じて操作を分岐する。

- **core** → 新規 ADR 起票＋旧 ADR 上書き（5遷移へ）
- **非core** → 直接編集＋本文 `## 変更履歴` に1行追記（front-matter は不変）。節を持たない ADR で新設する場合の配置は後掲の雛形が定める
- **些末** → 直接編集のみ（front-matter・`## 変更履歴` 不変、履歴は git）

分類はスキルが自動判定せず、必ず利用者へ問う。判定基準・問い設計・分岐の詳細は `${CLAUDE_SKILL_DIR}/references/edit-decision.md` を参照する。`上書き済み`／`廃止済み` に退役した ADR は凍結された歴史的成果物であり本文編集しない。

### ADR 化要否の判定（起票の前段）

ある決定を ADR にすべきか、いつ起票するか、命名規約を ADR の対象に含めるかは、却下代替の必要条件と粒度判定基準で判定する。まず当該決定が採らなかった選択肢とその却下理由を持つかを確認し、持たなければ点数を数えず ADR 化しない。持つ場合に粒度判定基準のチェックリストで採点し、判定境界では「書かない」を優先する。4項目の名称・同点処理・行き先に加え、各項目が判定する入力の値域と定義、閾値とスコア境界の数値、および判定結果に添える申告の規律（数えた対象の列挙・発見型短絡の申告・推定で補わないこと）も `${CLAUDE_SKILL_DIR}/references/adr-scoping.md` が単独で持つ。同ファイルのみを参照し、スキル独自の基準を導入しない。

要否の判定は起票操作の前段であり、ADR 化すると判断した場合のみ起票（5遷移）へ進む。ただしその行き先は新規 ADR とは限らず、既存 ADR への非core 改訂の側もある（分類の確定は粒度判定ではなく前掲の編集判定フローに従う）。ADR 化しないと判断した対象にも置き場所の一般則がある。いずれの振り分けも前掲の `adr-scoping.md`「判定結果の行き先」節に従う。

### 格下げ判定（既存 ADR を退役させるか）

既に記録された ADR を `validity: 廃止済み` へ移して index から外すかは、起票の判定とは別の基準で決める。実体は `${CLAUDE_SKILL_DIR}/references/adr-demotion.md` に在り、判定条件・判定形式（必要条件の連言）・安全側の向き（迷ったら残す）をここ以外で再定義しない。**`adr-scoping.md` の粒度判定基準を既存 ADR へ遡及適用して退役を決めない。** 退役と判定した場合は前掲5遷移の「廃止」へ進む（手順の実体は `${CLAUDE_SKILL_DIR}/references/transitions.md`「廃止（廃止済み）」節）。

判定を誰がいつ起動するか（起動主体・起動タイミング・入力範囲）は同ファイルの対象外であり、本スキルも既定を与えない。

## 手順の参照（各 references を直接参照）

- `${CLAUDE_SKILL_DIR}/references/adr-model.md` — 状態の2軸の値域・合法な front-matter を表す状態の型・配置・採番方式（full slug の定義）
- `${CLAUDE_SKILL_DIR}/references/adr-scoping.md` — ADR 化要否の必要条件・4項目の名称・同点処理・判定する入力の値域と定義・閾値とスコア境界・判定に添える申告・起票のタイミング・判定結果の行き先・束ね・命名規約
- `${CLAUDE_SKILL_DIR}/references/adr-demotion.md` — 既存 ADR の格下げ（退役）判定の条件・判定形式・安全側の向き・格下げ固有の入力の採否
- `${CLAUDE_SKILL_DIR}/references/template.md` — 新規 ADR の雛形（front-matter＋見出し骨格。起票時にこの構成へ準拠する）と、`## 変更履歴` 節の配置規約（節を持たない ADR で新設するときに従う単一出典）
- `${CLAUDE_SKILL_DIR}/references/transitions.md` — 5遷移と分割の実行手順・採番規則・双方向相互参照の書き込み・index の再生成
- `${CLAUDE_SKILL_DIR}/references/edit-decision.md` — core／非core／些末 の判定と `AskUserQuestion` 問い設計・操作分岐、および ADR 本文へ参照を書く／直す際の判定（記録の参照原則。起票時にも適用する）
- `${CLAUDE_SKILL_DIR}/references/cross-references.md` — `## 関連ADR` の関係語彙・`Related:` の書式規約・機械検査の範囲と是正手段（相互参照を書くときに従う）

以降の手順に現れる `<対象ディレクトリ>` の解決（既定と第1引数による上書き）は `${CLAUDE_SKILL_DIR}/references/adr-model.md`「配置」節に従う。

識別子の発番は `bash ${CLAUDE_SKILL_DIR}/../../scripts/next-adr-id.sh <対象ディレクトリ>` を実行し、その出力を用いる。時刻部（分粒度・ローカル時刻）の取得と同一時刻部内の連番決定はスクリプトが担う。`date` 等の外部コマンドを直接実行せず、配置ディレクトリを列挙して番号を組み立てない。

## 各操作後の自己検証（必須）

実 ADR ファイルは対象ディレクトリへ書き込み、**自己検証も同ディレクトリを直接対象として実行する**（対象ディレクトリの解決は前掲の「配置」節の規約に従う）。各遷移・編集操作の完了後、以下を実行する。

1. **index 同期**（`validity` を変える操作＝承認・上書き・分割・廃止の後）: `bash ${CLAUDE_SKILL_DIR}/../../scripts/gen-adr-index.sh <対象ディレクトリ>` の出力で `<対象ディレクトリ>/index.md` を再生成する（起票・却下は `validity` を変えないため index 再生成不要）。
2. **lint 実行**: `bash ${CLAUDE_SKILL_DIR}/../../scripts/lint-adr.sh <対象ディレクトリ>` を実行し exit 0 を確認する。**この exit 0 が合否基準**である。
3. **フィードバックループ**（exit 0 以外）: lint-adr の出力を利用者へ提示し、報告された検査項目を `${CLAUDE_SKILL_DIR}/references/adr-model.md`「検査項目と正本の対応」で引き、指された正本文書の是正手段に従って ADR を直す。再度 lint-adr を実行し、**exit 0 になるまで反復する**。exit 0 を得られないまま操作を完了扱いにしない。

`lint-adr.sh` の exit code: `0`＝違反0件／`1`＝違反検出／`2`＝対象ディレクトリ不在。

**commit 前ゲートとの二面構成**: 同梱の PreToolUse フックが `git commit` 時にも drift-lint を実行し、違反があれば exit 2 で commit をブロックする。本節の自己検証は、そのブロックを操作の直後に前倒しで潰す位置づけである。

ただしゲートの射程は自己検証より狭い。フックは Bash ツール経由の `git commit` にのみ掛かり、端末や IDE から直接打つ commit は通らない。検査対象も既定の配置に固定されており、既定以外の配置を採る導入先ではゲートが働かない（前掲の「配置」節を参照）。いずれの場合も自己検証が唯一の検出機会になるため、ゲートに委ねず本節を実行する。

**フォールバック**: 操作前から対象ディレクトリが exit 1（baseline red）で、本操作と無関係な違反が exit 0 到達を妨げる場合に限り、変更/生成した ADR とその相互参照相手を一時ディレクトリへコピーし、そのディレクトリを対象に手順1〜3を実行してよい（コピーに含めるファイルの規則は `${CLAUDE_SKILL_DIR}/references/transitions.md` を参照）。

**方式の判断と根拠**: 既定を対象ディレクトリの直接検証とし、隔離コピー方式は既定手順から退けた。隔離コピーは「対象ディレクトリ全体の baseline が red で、どれだけ正しく操作しても全体 green にできない」ことを前提とする過渡措置であり、直接 lint すると正しい操作でも exit 0 に到達できない（false negative）ことを避けるためのものだった。front-matter 移行と index 初期生成の完了により baseline が exit 0 となってこの前提が失効したため、隔離方式には相互参照相手を漏らすと自ら false negative を生むという組み立てコストだけが残る。直接検証は操作結果と対象ディレクトリ全体の整合を同時に検査でき、隔離セットの漏れによる誤検知も生じない。ただし baseline が red へ戻った場合の可用性を確保するため、隔離検証は上記フォールバックとして残置する。
