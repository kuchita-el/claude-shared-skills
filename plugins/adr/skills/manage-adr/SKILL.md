---
name: manage-adr
description: ADR のライフサイクル操作（起票・承認・上書き・廃止・却下の5遷移）と多決定 ADR の分割、誤った退役の取り消しを実行し、front-matter（`status`/`validity`/`superseded-by`）と相互参照をスキーマに従い書き込む。既存 ADR の編集は core／非core／些末で変更種別を確定して操作へ導く。ADR 化要否と退役（格下げ）の要否も判定し、各操作後は lint-adr で自己検証する。ADR 化を迷う・起こす・状態を変える・分割する・編集する・退役を取り消す・ADR の規範を他の文書へ移す・ADR が名指すファイルを消すときに使用。
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
- **変更境界**: 対象ADR以外を変更せず、別判断を黙って混ぜない。ただし次の2つは、対象ADR以外の変更として許容する。1つは、遷移手順（`transitions.md`「共通: 退役に伴う inbound `Related:` の点検・付け替え」節）が付け替えを指示する相互参照相手である。相手は、対象ADRを指す他の `validity-active` のADRの`Related:`行と、非ADR文書である。もう1つは、自己検証で再生成する`index.md`である。
- **変更境界（取り消し）**: `transitions.md`「取り消し（誤った退役の訂正）」節が編集を指示する後継ADRと`Related:`行も、対象ADR以外の変更として許容する。

ADR の各遷移（起票・承認・上書き・廃止・却下）と既存 ADR の編集で、front-matter と相互参照の節を正しく書き込む。front-matter のキーは `status`/`validity`/`superseded-by` であり、相互参照の節は `## <xref-heading>` である。手順の実体は本スキルが持ち、手作業で組み立てずスキル経由で一貫した状態遷移を実行し、各操作の締めに drift-lint で自己検証する。

Claude Codeではcommit前PreToolUse hookが補助的に同じlintを実行する。Codexにはこのplugin単位hookがないため、ホストにかかわらず各操作後の明示lintを必須とする。

状態は、役割を表す設定のキーで指す。各状態の定義と既定値は `${CLAUDE_SKILL_DIR}/references/adr-model.md`「状態の2軸」に従う。

- 承認軸: `status-proposed`（承認前）／`status-approved`（承認）／`status-rejected`（却下）
- 有効性軸: `validity-active`（効力を持つ）／`validity-superseded`（後継へ置換）／`validity-abandoned`（後継なしで終了）

手順と参照ファイルの `<キー>`（例: `status: <status-proposed>`、`## <xref-heading>`）は、後掲「書き込む値の取得」で得た値に置き換えて書く。値を例として示すときは、既定値であることを添える（例: 既定値 `提案中`）。既定値は導入先の設定で変わる。値の説明・トレーリングコメントを front-matter 内に書かない（lint パーサが行全体を値として取り込むため）。

## 引数

- 操作種別（起票／承認／上書き／分割／廃止／却下／編集／取り消し）と対象 ADR の識別子・パス
- 省略時は会話コンテキストから意図を判定する。操作種別・対象が特定できなければ、その1点のみ質問する

## 対象操作

### 5遷移（front-matter 状態遷移）

| 操作 | 概要 |
|---|---|
| 起票 | 採番規則で新規 ADR ファイルを生成し、状態の型の `status-proposed` の構成子へ置く |
| 承認 | `validity-active` の構成子へ移す |
| 上書き | 旧 ADR を後継を保持する `validity-superseded` の構成子へ移し、後継本文 `## <xref-heading>` に `Supersedes: <旧>`、旧 ADR 本文 `## <xref-heading>` に `Superseded by: <後継>` を書く（双方向） |
| 廃止 | `validity-abandoned` の構成子へ移す |
| 却下 | `status-rejected` の構成子へ移す |

各遷移後の front-matter 最終状態は `${CLAUDE_SKILL_DIR}/references/adr-model.md`「状態の型」の構成子として構成できる形にする。採番規則・写入手順・上書きの双方向相互参照の書き込みは `${CLAUDE_SKILL_DIR}/references/transitions.md` を参照する。ADR 本文へ他文書への参照を書く場合（起票時を含む）は、`${CLAUDE_SKILL_DIR}/references/adr-reference-principle.md` に従う。原 ADR の一部決定だけが反転する 1→N（部分上書き）は、5遷移ではなく下記「分割」を扱う。

### 分割（多決定 ADR の部分上書き。5遷移とは別軸の構造操作）

複数の決定を束ねた ADR の一部だけが core 反転して残りが生存する場合（1→N の部分上書き）、または束ね ADR を予防的に分解する場合（衛生的分割）に使う。原 ADR 全体を `validity-superseded` にすると生存決定を誤って退役させるため、生存決定を後継へ逐語 restate してから原 ADR を上書きする。後継を立てずに原 ADR へ残してよい生存決定の条件は、後掲の手順の実体が定める。

呼び出しの適用条件は2トリガに分かれる。**既定は分割しない**——既存の多決定 ADR を遡及的に分割せず、下記いずれかのトリガが立ったときにのみ駆動する。

- **反転駆動**: 前段の1→N の部分上書きがこれにあたる。部分 core 反転が実際に当たったときに駆動する（要求される）
- **衛生的分割**: 前段の予防的な分解がこれにあたる。既定（分割しない）に対する**任意**の例外であり、反転駆動と違って要求されない

新規に起こす ADR が独立に反転しうる core を束ねないための制約は `${CLAUDE_SKILL_DIR}/references/adr-splitting.md` に従う。

分割は5遷移（front-matter 状態遷移）の一種ではない。決定のファイル間再配置という別軸の構造操作であり、本文編集の core／非core／些末分類でもなくリファクタリングに相当する。終端 front-matter は上書きと同型である（原 ADR `validity: <validity-superseded>`・`superseded-by` に全後継を列挙）。ただし後継が複数（1→N）で生存決定の救出を伴う点で、上書き（1→1）と操作が異なる。

手順の実体は `${CLAUDE_SKILL_DIR}/references/transitions.md`「分割（多決定 ADR の部分上書き）」節を参照する。同節は、決定の振り分け・起票・逐語 restate・却下代替の持ち越し・開示・相互参照の各手順と、締めの検査を持つ。

締めの検査のうち網羅性と逐語性は、同梱の照合スクリプトで確かめる。実行形は `bash ${CLAUDE_PLUGIN_ROOT}/scripts/verify-split-verbatim.sh <原 ADR> <対応表>` である。対応表の書き方と結果の読み方は同節に従う。

### 編集判定フロー（既存 ADR の変更）

`validity-active` の ADR への変更は、変更種別（core／非core／些末）を `AskUserQuestion` で利用者へ問って確定する。既定選択肢は core（安全則「迷ったら core」）。分類に応じて操作を分岐する。

- **core** → 新規 ADR 起票＋旧 ADR 上書き（5遷移へ）
- **非core** → 直接編集＋本文 `## 変更履歴` に1行追記（front-matter は不変）。節を持たない ADR で新設する場合の配置は後掲の雛形が定める
- **些末** → 直接編集のみ（front-matter・`## 変更履歴` 不変、履歴は git）

分類はスキルが自動判定せず、必ず利用者へ問う。判定基準・問い設計・分岐の詳細は `${CLAUDE_SKILL_DIR}/references/edit-decision.md` を参照する。`validity-superseded`／`validity-abandoned` に退役した ADR は凍結された歴史的成果物であり本文編集しない。

### ADR 化要否の判定（起票の前段）

ある決定を ADR にすべきか、いつ起票するか、命名規約を ADR の対象に含めるかは、却下代替の必要条件と粒度判定基準で判定する。まず当該決定が採らなかった選択肢とその却下理由を持つかを確認し、持たなければ点数を数えず ADR 化しない。持つ場合に粒度判定基準のチェックリストで採点し、判定境界では「書かない」を優先する。4項目の名称・同点処理、各項目が判定する入力の値域と定義、閾値とスコア境界の数値は `${CLAUDE_SKILL_DIR}/references/adr-scoping.md` が単独で持つ。判定結果に添える申告の規律（数えた対象の列挙・発見型短絡の申告・推定で補わないこととその例外・採用理由を推定した旨の申告・起票の時点の照合範囲の申告）と起票の時点も、同ファイルが単独で持つ。判定結果の行き先は `${CLAUDE_SKILL_DIR}/references/adr-destination.md` が単独で持つ。いずれについてもこれらのファイルのみを参照し、スキル独自の基準を導入しない。

要否の判定は起票操作の前段であり、ADR 化すると判断し、かつ起票の時点に達した場合のみ起票（5遷移）へ進む。ただしその行き先は新規 ADR とは限らず、既存 ADR への非core 改訂の側もある（分類の確定は粒度判定ではなく前掲の編集判定フローに従う）。ADR 化しないと判断した対象にも置き場所の一般則がある。いずれの振り分けも `${CLAUDE_SKILL_DIR}/references/adr-destination.md` に従う。

### 格下げ判定（既存 ADR を退役させるか）

既に記録された ADR を `validity-abandoned` へ移して index から外すかは、起票の判定とは別の基準で決める。実体は `${CLAUDE_SKILL_DIR}/references/adr-demotion.md` に在る。判定条件・判定形式（必要条件の連言）・安全側の向き（迷ったら残す）を、ここ以外で再定義しない。**`adr-scoping.md` の粒度判定基準を既存 ADR へ遡及適用して退役を決めない。** 退役と判定した場合は前掲5遷移の「廃止」へ進む（手順の実体は `${CLAUDE_SKILL_DIR}/references/transitions.md`「廃止（廃止済み）」節）。

判定を誰がいつ何へ回すか（起動主体・起動タイミング・入力範囲）は `${CLAUDE_SKILL_DIR}/references/adr-demotion.md`「判定の起動」に従う。定期の棚卸しとして ADR 群の全数へ回さない。

### 誤った退役の取り消し（遷移ではない）

誤って行った上書き・廃止は、`validity-active` への状態遷移を足さず、退役操作の記録の訂正として取り消す。判定基準（退役を決めた基準の再適用）・実行手順・記録要件は、`${CLAUDE_SKILL_DIR}/references/transitions.md`「取り消し（誤った退役の訂正）」節が持つ。分割は取り消しの対象外である。

## 手順の参照（各 references を直接参照）

- `${CLAUDE_SKILL_DIR}/references/adr-model.md` — 状態の2軸の値域・合法な front-matter を表す状態の型・配置・採番方式（full slug の定義）・発番スクリプトの契約・index の同期・識別子の一意性・H1 見出しの形式と識別子部の整合・検査項目と正本の対応
- `${CLAUDE_SKILL_DIR}/references/adr-scoping.md` — ADR 化要否の必要条件・4項目の名称・同点処理・判定する入力の値域と定義・閾値とスコア境界・判定に添える申告・起票のタイミング
- `${CLAUDE_SKILL_DIR}/references/adr-destination.md` — 判定結果の行き先（ADR 化する側／しない側の分岐）と命名規約の ADR 化基準
- `${CLAUDE_SKILL_DIR}/references/adr-splitting.md` — 新規に起こす ADR へ何を束ねてよいかの制約
- `${CLAUDE_SKILL_DIR}/references/adr-demotion.md` — 既存 ADR の格下げ（退役）判定の条件・判定形式・安全側の向き・格下げ固有の入力の採否・起動
- `${CLAUDE_SKILL_DIR}/references/template.md` — 新規 ADR の雛形（front-matter＋見出し骨格。起票時にこの構成へ準拠する）と、`## 変更履歴` 節の配置規約（節を持たない ADR で新設するときに従う単一出典）
- `${CLAUDE_SKILL_DIR}/references/transitions.md` — 5遷移と分割の実行手順・取り消し・採番規則・双方向相互参照の書き込み・index の再生成
- `${CLAUDE_SKILL_DIR}/references/edit-decision.md` — core／非core／些末 の判定と問い設計・操作分岐。参照の深さの数え方も持つ
- `${CLAUDE_SKILL_DIR}/references/adr-reference-principle.md` — ADR 本文へ参照を書く／直す際の判定（記録の参照原則。起票時にも適用する）
- `${CLAUDE_SKILL_DIR}/references/cross-references.md` — 相互参照の関係語彙・`Related:` の書式規約・検査範囲・是正手段。相互参照を書くときに従う

以降の手順に現れる `<対象ディレクトリ>` の解決（既定と第1引数による上書き）は `${CLAUDE_SKILL_DIR}/references/adr-model.md`「配置」節に従う。

識別子の発番は `bash ${CLAUDE_PLUGIN_ROOT}/scripts/next-adr-id.sh <対象ディレクトリ>` を実行し、その出力を用いる。時刻部（分粒度・ローカル時刻）の取得と同一時刻部内の連番決定はスクリプトが担う。`date` 等の外部コマンドを直接実行せず、配置ディレクトリを列挙して番号を組み立てない。

### 書き込む値の取得

front-matter か相互参照の節を読み書きする操作では、最初に値を取得する。実行形は `bash ${CLAUDE_PLUGIN_ROOT}/scripts/print-adr-config.sh <対象ディレクトリ>` である。出力の `キー: 値` の行が、導入先の設定（無ければ同梱の既定値）から lint-adr と同じ規則で解決した値である。front-matter と `## <xref-heading>` へはこの値を書き、遷移前の状態確認でもこの値と照合する。例として添えた既定値を書き込まない。exit 2 は設定の誤りか対象ディレクトリの不在である。標準エラーの原因を利用者へ示して操作を始めず、既定値へ切り替えて続けない。

## 各操作後の自己検証（必須）

実 ADR ファイルは対象ディレクトリへ書き込み、**自己検証も同ディレクトリを直接対象として実行する**（対象ディレクトリの解決は前掲の「配置」節の規約に従う）。各遷移・編集操作の完了後、以下を実行する。

1. **index 同期**: `validity` を変える操作（承認・上書き・分割・廃止・取り消し）の後に行う。`bash ${CLAUDE_PLUGIN_ROOT}/scripts/gen-adr-index.sh <対象ディレクトリ>` の出力で `<対象ディレクトリ>/index.md` を再生成する。起票・却下は `validity` を変えないため index 再生成不要である。
2. **lint 実行**: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/lint-adr.sh <対象ディレクトリ>` を実行し exit 0 を確認する。**この exit 0 が合否基準**である。
3. **フィードバックループ**（exit 0 以外）: lint-adr の出力を利用者へ提示し、報告された検査項目を `${CLAUDE_SKILL_DIR}/references/adr-model.md`「検査項目と正本の対応」で引き、指された正本文書の是正手段に従って ADR を直す。再度 lint-adr を実行し、**exit 0 になるまで反復する**。exit 0 を得られないまま操作を完了扱いにしない。

`lint-adr.sh` の exit code: `0`＝違反0件／`1`＝違反検出／`2`＝対象ディレクトリ不在。

**commit 前ゲートとの二面構成**: 同梱の PreToolUse フックが `git commit` 時にも drift-lint を実行し、違反があれば exit 2 で commit をブロックする。本節の自己検証は、そのブロックを操作の直後に前倒しで潰す位置づけである。

ただしゲートの射程は自己検証より狭い。フックは Bash ツール経由の `git commit` にのみ掛かり、端末や IDE から直接打つ commit は通らない。検査対象も既定の配置に固定されており、既定以外の配置を採る導入先ではゲートが働かない（前掲の「配置」節を参照）。いずれの場合も自己検証が唯一の検出機会になるため、ゲートに委ねず本節を実行する。

**フォールバック**: 操作前から対象ディレクトリが exit 1（baseline red）で、本操作と無関係な違反が exit 0 到達を妨げる場合に限り、変更/生成した ADR とその相互参照相手を一時ディレクトリへコピーし、そのディレクトリを対象に手順1〜3を実行してよい（コピーに含めるファイルの規則は `${CLAUDE_SKILL_DIR}/references/transitions.md` を参照）。

**方式の根拠**: 直接検証を既定とするのは、操作結果と対象ディレクトリ全体の整合を同時に検査でき、隔離コピーのように相互参照相手を漏らして自ら false negative を生むことがないためである。隔離検証は、baseline が red で正しい操作でも exit 0 に到達できない場合の可用性を確保する上記フォールバックに限って用いる。
