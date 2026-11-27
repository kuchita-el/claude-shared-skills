---
name: manage-adr
description: ADR のライフサイクル操作（起票・承認・上書き・廃止・却下の5遷移）と多決定 ADR の分割、誤った退役の取り消しを実行し、front-matter（`status`/`validity`/`superseded-by`）と相互参照をスキーマに従い書き込む。既存 ADR の編集は core／非core／些末で変更種別を確定して操作へ導く。ADR 化要否と格下げ（廃止するか）も判定し、各操作後は lint-adr で自己検証する。ADR 化を迷う・起こす・状態を変える・分割する・編集する・退役を取り消す・ADR の規範を他の文書へ移す・ADR が名指すファイルを消すときに使用。
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
  - Bash(bash *scripts/verify-split-verbatim.sh*)
  - Bash(bash *scripts/print-adr-config.sh*)
---

# ADRライフサイクル操作（Manage ADR）

## 文脈固有ルール

- **対象範囲**: 指定されたADRと許可された遷移・編集分類だけを扱う。
- **成果物**: front-matter、本文、相互参照をスキーマに沿って必要十分に更新する。
- **停止条件**: 遷移条件、参照整合、lintのいずれかが未決・不合格なら状態を進めない。
- **変更境界**: 対象ADR以外を変更せず、別判断を黙って混ぜない。ただし次の2つは、対象ADR以外の変更として許容する。1つは、遷移手順（`transitions.md`「共通: 退役に伴う inbound `Related:` の点検・付け替え」節）が付け替えを指示する箇所である。箇所は、対象ADRを指す他の `validity-active` のADRの`Related:`行と本文の散文引用、および非ADR文書であり、同節が指示する範囲に限る。もう1つは、自己検証で再生成する`index.md`である。
- **変更境界（取り消し）**: `transitions.md`「取り消し（誤った退役の訂正）」節が編集を指示する後継ADRと`Related:`行も、対象ADR以外の変更として許容する。

ADR の各操作で、front-matter と相互参照の節を、手作業で組み立てずに本スキルの手順で書き込む。front-matter のキーは `status`/`validity`/`superseded-by` であり、相互参照の節は `## <xref-heading>` である。各操作の締めに、後掲「各操作後の自己検証（必須）」を行う。

状態は、役割を表す設定のキーで指す。各役割の定義と既定値は `${CLAUDE_SKILL_DIR}/references/adr-model.md`「状態の2軸」に従う。

- 承認軸: `status-proposed`／`status-approved`／`status-rejected`
- 有効性軸: `validity-active`／`validity-superseded`／`validity-abandoned`

手順と参照ファイルの `<キー>`（例: `status: <status-proposed>`、`## <xref-heading>`）は、後掲「書き込む値の取得」で得た値に置き換えて書く。値を例として示すときは、既定値であることを添える（例: 既定値 `提案中`）。既定値は導入先の設定で変わる。front-matter の書き方は `${CLAUDE_SKILL_DIR}/references/adr-model.md`「front-matter（状態の唯一の権威）」に従う。

## 引数

- 操作種別（起票／承認／上書き／分割／廃止／却下／編集／取り消し）と対象 ADR の識別子・パス
- 省略時は会話コンテキストから意図を判定する。操作種別・対象が特定できなければ、その1点のみ質問する

## 対象操作

### 5遷移（front-matter 状態遷移）

各操作の遷移前の状態・遷移後の構成子・ガードは `${CLAUDE_SKILL_DIR}/references/adr-model.md`「遷移の表」が持つ。手順は `${CLAUDE_SKILL_DIR}/references/transitions.md` の次の節が持つ。

| 操作 | 手順 |
|---|---|
| 起票 | `transitions.md`「起票（提案中）」 |
| 承認 | `transitions.md`「承認（承認済み・有効）」 |
| 上書き | `transitions.md`「上書き（上書き済み・双方向相互参照）」 |
| 廃止 | `transitions.md`「廃止（廃止済み）」 |
| 却下 | `transitions.md`「却下（却下）」 |

ADR 本文へ他文書への参照を書く場合（起票時を含む）は、`${CLAUDE_SKILL_DIR}/references/adr-reference-principle.md` に従う。

### 分割（多決定 ADR の部分上書き。5遷移とは別軸の構造操作）

複数の決定を束ねた ADR を、決定ごとに後継へ再配置する。既定は分割しない。適用条件・手順・締めの検査は `${CLAUDE_SKILL_DIR}/references/transitions.md`「分割（多決定 ADR の部分上書き）」が持つ。新規に起こす ADR へ何を束ねてよいかは `${CLAUDE_SKILL_DIR}/references/adr-splitting.md` が持つ。

締めの検査のうち網羅性と逐語性は、同梱の照合スクリプトで確かめる。実行形は `bash ${CLAUDE_PLUGIN_ROOT}/scripts/verify-split-verbatim.sh <原 ADR> <対応表>` である。対応表の書き方と結果の読み方は、`transitions.md`「照合スクリプト」に従う。

### 編集判定フロー（既存 ADR の変更）

`validity-active` の ADR への変更は、変更種別（core／非core／些末）をスキルが自動で判定せず、`AskUserQuestion` で利用者へ問って確定する。問いの立て方と、問いを立てない例外は、`${CLAUDE_SKILL_DIR}/references/edit-decision.md`「AskUserQuestion の問い設計」が持つ。判定基準・分類ごとの操作・退役 ADR への編集の可否（凍結の射程）も、同ファイルが持つ。

### ADR 化要否の判定（起票の前段）

ある決定を ADR にすべきか、いつ起票するかは、`${CLAUDE_SKILL_DIR}/references/adr-scoping.md` で判定する。判定結果の行き先は `${CLAUDE_SKILL_DIR}/references/adr-destination.md` に従う。スキル独自の基準を導入しない。

### 格下げ判定（既存 ADR を廃止するか）

既に記録された ADR を廃止するかは、`${CLAUDE_SKILL_DIR}/references/adr-demotion.md` で判定する。判定を誰がいつ何へ回すかも、同ファイルが持つ。

### 誤った退役の取り消し（遷移ではない）

誤って行った上書き・廃止の取り消しは、`${CLAUDE_SKILL_DIR}/references/transitions.md`「取り消し（誤った退役の訂正）」に従う。

## 手順の参照（各 references を直接参照）

- `${CLAUDE_SKILL_DIR}/references/adr-model.md` — 状態・front-matter・遷移の表・用語の意味・配置・採番を確かめるとき
- `${CLAUDE_SKILL_DIR}/references/transitions.md` — 遷移・分割・取り消しを実行するとき。退役に伴う参照の付け替えと、隔離検証も持つ
- `${CLAUDE_SKILL_DIR}/references/edit-decision.md` — 既存 ADR の編集の分類を問うとき
- `${CLAUDE_SKILL_DIR}/references/adr-scoping.md` — ある決定を ADR にするか、いつ起票するかを判定するとき
- `${CLAUDE_SKILL_DIR}/references/adr-destination.md` — ADR 化要否の判定を終えた対象の置き場所を決めるとき
- `${CLAUDE_SKILL_DIR}/references/adr-demotion.md` — 既存 ADR を廃止するかを判定するとき
- `${CLAUDE_SKILL_DIR}/references/adr-splitting.md` — 新規の ADR へ何を束ねるかを決めるとき
- `${CLAUDE_SKILL_DIR}/references/template.md` — 起票するとき。節を持たない ADR に `## 変更履歴` を新設するとき
- `${CLAUDE_SKILL_DIR}/references/adr-reference-principle.md` — ADR 本文へ参照を書く・直すとき
- `${CLAUDE_SKILL_DIR}/references/cross-references.md` — 相互参照を書くとき。`Related:` の検査違反を直すとき

以降の手順に現れる `<対象ディレクトリ>` の解決は、`${CLAUDE_SKILL_DIR}/references/adr-model.md`「配置」に従う。利用者が対象ディレクトリを明示しないときは、後掲「書き込む値の取得」の出力の `adr-dir:` 行の値を使う。

識別子の発番の実行形は `bash ${CLAUDE_PLUGIN_ROOT}/scripts/next-adr-id.sh <対象ディレクトリ>` である。発番の手順は `${CLAUDE_SKILL_DIR}/references/adr-model.md`「採番衝突時の解消手順」に従う。

### 書き込む値の取得

ADR を操作するときは、最初に設定の値を取得する。実行形は `bash ${CLAUDE_PLUGIN_ROOT}/scripts/print-adr-config.sh [<対象ディレクトリ>]` である。対象ディレクトリが明示されていなければ、引数を省く。出力の `キー: 値` の行が、導入先の設定（無ければ同梱の既定値）から lint-adr と同じ規則で解決した値である。`adr-dir:` 行は、明示が無いときの `<対象ディレクトリ>` である。front-matter と `## <xref-heading>` へは語の群の値を書き、遷移前の状態確認でもこの値と照合する。例として添えた既定値を書き込まない。スクリプトが失敗したら、標準エラーの原因を利用者へ示して操作を始めない。既定値へ切り替えて続けない。

## 各操作後の自己検証（必須）

各遷移・編集操作の完了後、対象ディレクトリを直接対象として次を実行する。index の再生成と lint の `<対象ディレクトリ>` には、同じ解決結果を渡す。

1. **index 同期**: `${CLAUDE_SKILL_DIR}/references/adr-model.md`「遷移の表」で `validity` を変える操作の後に、`bash ${CLAUDE_PLUGIN_ROOT}/scripts/gen-adr-index.sh <対象ディレクトリ>` の出力で `<対象ディレクトリ>/index.md` を再生成する。lint の前に行う。飛ばすと、lint の index 同期の検査が違反を出す。
2. **lint 実行**: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/lint-adr.sh <対象ディレクトリ>` を実行し、exit 0 を確認する。この exit 0 が合否基準である。
3. **フィードバックループ**（exit 0 以外）: lint-adr の出力を利用者へ提示する。報告された検査項目を `${CLAUDE_SKILL_DIR}/references/adr-model.md`「検査項目と正本の対応」で引き、指された正本の是正手段に従って ADR を直す。再度 lint-adr を実行し、exit 0 になるまで反復する。exit 0 を得られないまま操作を完了扱いにしない。

commit 前ゲートは、ホストのツール経由の `git commit` にだけ掛かる PreToolUse フックである。端末や IDE から直接打つ commit には掛からず、ゲートを持たないホストもある。そのため、ゲートに委ねず、ホストを問わずに本節を実行する。

**方式の根拠**: 直接検証を既定とするのは、操作結果と対象ディレクトリ全体の整合を同時に検査でき、隔離コピーのように相互参照相手を漏らして自ら false negative を生むことがないためである。操作の前から対象ディレクトリが red で、正しい操作でも exit 0 に達しない場合に限り、`${CLAUDE_SKILL_DIR}/references/transitions.md`「隔離検証（baseline red のときのフォールバック）」に従って隔離検証を用いる。
