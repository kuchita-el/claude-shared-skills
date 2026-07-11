# 個人ローカル store（生観測）仕様

growth プラグインの学習ループ（概念上の5段: `[Capture] → [Distill] → [Route] → [Promote] → [Distribute]`。Phase 1 のスキルマッピングでは Route は Distill に統合される＝DESIGN.md §4・決定事項8）の起点となる、生観測（未検証の観察）を蓄積する個人ローカル store の置き場・形式・distill 処理源選択（処理済みカーソル）を定義する。あわせて、Distill が生成し `promote` が消費する**仮説ファイル（`candidates.md`）**の置き場・形式・メタ欄スキーマも本仕様で単一出典化する（#348）。

## 位置づけ

- `DESIGN.md` 決定事項3「個人 store の置き場」を具体化する文書。生の観測は個人ローカル（共有されない）に置き、検証を経たものだけ committed の学び置き場へ昇格させる。
- 本 store は学習ループの **Capture の書き込み先**であり、**Distill の入力源**である。Capture の検知ロジック本体・committed な学び置き場（`learnings.md`）への物理昇格（Distribute、Phase 2）・過去セッションログの横断解析は本仕様の対象外（別 Issue / 別 Phase）。一方、**`captures.md` は無状態の append-only 観測コーパスであり（エントリ単位の処理状態フィールドを持たない）、distill の処理源選択（provenance 導出 ＋ 処理済みカーソル）とカーソルの格納・前進・巻き戻し規約は本仕様が定義する**（ADR-20260711 / ADR-20260711-2。「distill 処理源選択と処理済みカーソル」節）。
- 本 store は committed な学び置き場（単一の人間可読ファイル）とは別物である。store は未検証の生記録を貯める一時領域であり、検証を経た学びは store の外（昇格先）へ移送される。
- 本仕様はさらに、Distill が生成し `promote` が消費する**仮説ファイル（`candidates.md`）**の置き場・形式・メタ欄スキーマを単一出典として定義する（#348。「仮説ファイル（candidates.md）」節）。仮説ファイルは store（生観測）でも `learnings.md`（配布物）でもない第3の個人ローカル成果物である。

### memory との違い

置き場こそ既存 memory 機構と同じ user-local 領域に同居するが、store は memory とは設計意図が異なる。memory は「個人で終わる」（共有のデッドエンド）。本 store は **昇格経路を必ず持つ**点で memory と differ する。store は学びの出発点であって終点ではない——貯めた生観測は検証され、支持されたものが committed の配布物へ昇格していく。昇格状態は候補側の `candidate-status`（「仮説ファイル（candidates.md）」節）が追跡し、`captures.md` 自身は無状態である。

## 置き場

生観測 store のパスを以下に確定する。

```
~/.claude/projects/<project-id>/growth/captures.md
```

- `<project-id>` は既存 memory 機構が用いるプロジェクト識別子と同一（このリポジトリでは作業ディレクトリのパス区切りを `-` に置換した形式。例: `-home-kuchita-Development-claude-shared-skills`）。memory が `projects/<project-id>/memory/` を使うのと同階層に `projects/<project-id>/growth/` を置く。
- **スコープは per-project**。観測はプロジェクト文脈（作業セッション）で発生するため、プロジェクトごとに store を分離して出所文脈を保持する。Distill はこのプロジェクト単位の store を入力源とする。
- このパスはユーザースコープ（`~/.claude/` 配下）にあり、本リポジトリの work tree の外にある。したがって**配布物（プラグイン）に物理的に含まれず**、プラグイン更新で消えず、配布を受けた consumer の環境でも各自の user-local 領域として成立する。

### project-id とパスの解決手順

`<project-id>` と store パスは以下の手順で解決する。**Capture（capture スキル）と Distill（distill スキル）は本手順を共通の単一出典として参照する**（操作手順を各スキルへ二重定義せず、git のバージョン要件や置換規約の改修をここ一箇所に集約する）。

**リポジトリルートと project-id**:

```bash
git rev-parse --path-format=absolute --git-common-dir
```

このコマンドは worktree・通常リポジトリの両方で共通の `.git` ディレクトリの**絶対パス**を返す（例: `/home/user/myproject/.git`）。`--path-format=absolute` は Git 2.31 以降で利用可能。末尾の `/.git` を除いたパスをリポジトリルートとし、全 `/` を `-` に置換して `<project-id>` とする（例: `-home-user-myproject`）。

> `--git-common-dir` 単体は CWD に応じて相対パスを返す場合があるため `--path-format=absolute` を必ず併用する。
> `git rev-parse --show-toplevel` は worktree 内では worktree 固有パスを返すため使用しない。

**store パスの組み立て**:

- store パス: `~/.claude/projects/<project-id>/growth/captures.md`

> capture（Capture）は同一の `<project-id>` から jsonl パス `~/.claude/projects/<project-id>/<session-UUID>.jsonl` も組み立てるが、session UUID 解決と jsonl 読取は Capture 固有の手順であり本仕様の対象外（capture SKILL.md が定義する）。

## 観測エントリの形式

store は Markdown ファイルであり、1観測を1セクション（`##` 見出し）として追記する。人間可読であり、肥大が一目で分かる（`DESIGN.md` 原理5「足場を痩せさせる」の前提）。

ファイルは Markdown として保存・閲覧するが、パースは行ベースの平文規約で完結させ、YAML パーサによる厳密解釈は前提としない。区切り規約は以下とする。

- **エントリ境界**: 1エントリは `## <timestamp>` 見出しから次の `##` 見出し（またはファイル末尾）まで。
- **メタフィールド**: `signal` / `session` / `origin` / `expected` / `actual` は `- key: value` 形式の単一行。エントリ内の `- key: value` 行をメタとして抽出する。`origin`（出所）・`expected`（予測）・`actual`（実際）も同一の単一行メタ規約に従い、`signal` と直交する独立軸として追加する（値域・必須性は「スキーマ」「出所」節を参照）。
- **引用の単一行畳み込み**: `expected` / `actual` の引用が複数行に渡る場合（tool_result の stderr・複数行のユーザー発話等）は、メタ行を単一行に保つため、**代表行の逐語引用**、または**改行を空白へ正規化**して1行に収める。逐語性は「要点が transcript に実在する文字列であること」で担保し、全文の逐語転記は要求しない（多行の生情報が必要なら observation 本文へ記す）。
- **observation 本文**: メタ行と見出し直後の空行を除いた残りの行が observation 本文。複数行を自然に含められる。YAML のブロックスカラー（`|`）等の記法は用いない。

observation を必ずメタフィールド群の後（エントリ末尾側）に置くことで、多行の生観察を行ベースの区切りだけで欠落なく抽出できる。

### スキーマ

| フィールド | 必須 | 内容 |
|---|---|---|
| 見出し（`## <timestamp>`） | 必須 | ISO 8601 形式の **capture 実行時刻**（UTC）。1 run で複数観察を記録する場合は run 内序数サフィックス `-NN` を付して一意化する（capture SKILL.md Step 1・ADR-20260711-4）。provenance の同定キーとカーソルの順序キーを兼ねる |
| `signal` | 必須 | シグナル種別。値域は「シグナル種別」節を参照 |
| `session` | 必須 | 由来セッション参照。Claude Code がセッション管理に用いる識別子（UUID 形式）。どのセッションの観察かを辿るため。取得元は Phase 1 実装時に確定する（「出所」は出所軸 `origin` の語に充て、`session` には用いない） |
| `origin` | 必須 | 出所軸。値域は `tool-result` / `user-utterance` の2値。「出所」節を参照。`signal` と直交する独立軸 |
| `expected` | 該当時必須 | 予測。当方が予測した結果。transcript の痕跡（`type=thinking` / `tool_use.input` 等）に基づく**再構成**を可とする（逐語引用に限らない。`actual` との非対称は「生記録性」節を参照）。価値判断・原因分析・改善案は混入させない。フィールドは常設し、手掛かりが無ければ空可 |
| `actual` | 該当時必須 | 実際。実際に起きた結果。transcript の**逐語断片を含む引用**に限る（要点が transcript に実在する文字列であればよく、地の文で囲んでよい。全文の逐語転記は不要。複数行は代表行の引用または改行を空白へ正規化して単一行に収める。「パース規約」節「引用の単一行畳み込み」を参照）。フィールドは常設し、値は transcript から抽出できる場合に記す（抽出不能なら空可）。「生記録性」節を参照 |
| `observation` | 必須 | 生観察。何が起きたかの記録のみ。メタフィールドの後にエントリ末尾の本文ブロックとして記述する（複数行可、「パース規約」節を参照） |

AC の必須欄「生観察」「シグナル種別」「由来セッション参照」はそれぞれ `observation` / `signal` / `session` に対応する。新フィールドのうち `origin`（出所軸）は常に必須、`expected` / `actual` はフィールド常設・値は該当時必須（transcript から抽出できる場合に記す）。これらは `signal` と直交する独立軸であり、既存の必須欄（`observation` / `signal` / `session`）を置換・改名しない。

### 生記録性（判断は後回し）

`DESIGN.md` の Capture 原則「判断は後回しにする」を構造的に担保するため、スキーマに**解釈・原因分析・対策・改善案を書くフィールドを設けない**。観測時点では「何が起きたか」（observation）だけを記録し、「なぜ起きたか」「次にどうするか」は Distill 以降の検証フェーズに委ねる。生記録に解釈を混ぜないことが、未検証の幻覚を配布物に流し込まない第一の防波堤になる。observation は複数行記述できるが、記録するのは観察事実に限り、分量は文脈が伝わる範囲に留める（解釈・原因・対策を書かない方針は行数に関わらず保持する）。

新フィールドの `origin`（出所）・`expected`（予測）・`actual`（実際）も同じ生記録性の制約下にあるが、transcript からの**引用可能性は一様でない**。`origin`（出所の判別）と `actual`（実際に起きた結果）は transcript に実在する痕跡（tool_result のエラー文字列・ユーザーの訂正発話等）に裏付けられる——`actual` はその**逐語断片を含む引用**として記せる（要点が transcript に実在する文字列であればよく、地の文で囲んでよい。全文の逐語転記は不要。「パース規約」節「引用の単一行畳み込み」を参照）。一方 `expected`（予測した結果）は、当方が予測を明示的に言語化していない限り transcript に逐語では存在しないことが多く、痕跡（`type=thinking` / `tool_use.input` 等）に基づく**再構成**を要する。したがって `expected` は逐語に縛らず、痕跡に基づく予測の再構成を許す（`origin` / `actual` は transcript の痕跡に裏付けられた記述に限る）。

ただし、`expected` で再構成してよいのは「何を予測していたか」の言語化までであり、`origin` / `actual` と同じく**摩擦/学びの価値判断・原因分析・改善案は混入させない**（AC5）。「予測の言語化」は事実の再構成であって、「なぜ失敗したか（原因）」「次にどうすべきか（対策）」とは別物である。`expected` / `actual` は痕跡（手掛かり）が無ければ**捏造せず空にする**（フィールドは常設・値は該当時のみ）。手掛かりの無い予測を埋めようとすると解釈の混入を招き、生記録性の契約を侵すため。出所からの摩擦/判断の分類は Distill の責務であり、capture は抽出・記録までに限る（事実＝capture / 判断＝distill の線引き）。

### 記述例

user-utterance 由来（ユーザーの訂正）の例:

```
## 2026-06-26T14:32:10Z
- signal: 訂正
- session: 2265f83f-c5a8-41a0-b284-b5d90882a2da
- origin: user-utterance
- expected: ファイル復元に git checkout を提案すれば受け入れられる
- actual: ユーザーが「git checkout ではなく git restore を使え」と訂正した

当方はファイル復元に git checkout を提案したが、ユーザーが git restore を使うよう訂正した。
```

`origin: user-utterance` により出所がユーザー発話由来であることが判別でき、`expected`（予測した結果）と `actual`（実際に起きた結果）が別行で読み取れる。tool-result 由来の対比例は capture SKILL.md の記述例を参照。

## シグナル種別

`signal` の値域は `DESIGN.md` の Capture が定義するシグナルを網羅する。摩擦知（予測誤差＝驚きの源泉）の5値と、判断知（復元不能な会話知）の4値からなる。

摩擦知シグナル（摩擦サブセットの補助検出器）:

| 値（ラベル） | 意味 |
|---|---|
| `訂正` | ユーザーが当方の出力・提案を訂正した |
| `ツール拒否` | ツール呼び出しが拒否された（権限拒否・hook ブロック等） |
| `反復試行` | 同一目的の操作を繰り返した（再試行の連続） |
| `期待違反` | 予測した結果と実際の結果が食い違った |
| `客観痕跡` | git revert・CI 失敗等の外部の客観的痕跡 |

判断知シグナル（予測誤差の形を持たない。価値軸は復元不能性。教示信号検出器が拾う）:

| 値（ラベル） | 意味 |
|---|---|
| `選好` | ユーザーが選択肢間の選好・傾きを表明した |
| `却下理由` | ユーザーが提案・設計を理由付きで却下した |
| `目標表明` | ユーザーが目標・意図・継続方針を表明した |
| `設計判断` | ユーザーが設計境界・方針を確定する判断を示した |

- ラベルは日本語を正準とする（`DESIGN.md` の表記に準拠）。
- **知識型（判断知 / 摩擦知）は signal がどちらの群に属するかで導出する**（独立フィールドは設けない＝additive 拡張。摩擦知5値は破壊・改名しない）。下流 Distill は知識型で出力形を分岐する（摩擦知→`behavior-diff`、判断知→`decision-record`）。
- `客観痕跡` は Phase 1（痕跡ソースが現セッションの会話履歴に限られる）では投入されない見込みだが、値域には含める。git revert・CI 失敗の取得は Phase 3 以降であり、その時点で同一スキーマに追記できるようにするため。

## 出所

`origin` の値域は、観察の学習シグナルが**どこに現れたか**（出所）を表す。Phase 1（痕跡ソースが現セッションの会話履歴に限られる）では transcript 由来の以下2値とする。

| 値 | 意味 |
|---|---|
| `tool-result` | ツール結果（tool-result）由来の出所。環境（権限・hook・コマンド失敗等）との摩擦の候補 |
| `user-utterance` | ユーザー発話（user-utterance）由来の出所。当方の判断・提案の誤りの候補 |

- **`signal` 種別とは直交する独立軸である**。出所軸は signal 5値（訂正/ツール拒否/反復試行/期待違反/客観痕跡）を**置換・改名せず**、それと並ぶ別軸として併存する（AC3）。同一の signal が tool-result 由来でも user-utterance 由来でもありうる（例: `期待違反` はツール結果の食い違いにも、ユーザー指摘による食い違いにも現れる）。
- この直交性により、下流 Distill は出所で環境摩擦（`tool-result`）と判断誤り（`user-utterance`）を分類できる。**ただし出所から摩擦/学びの価値を判定する責務は Distill 側にあり、本仕様（capture 側）は出所の抽出・記録までに限る**（distill 側の分類・重み付けは OUT。capture/distill 責務線引きの ADR 化は distill 側 Issue へ繰り延べる）。
- **Phase 3 拡張余地**: `客観痕跡` シグナル（git revert / CI 失敗等）は transcript の tool-result でも user-utterance でもない**外部痕跡**が出所であり、本 Phase の2値には収まらない。`客観痕跡` を投入する Phase 3 では、本軸へ外部痕跡向けの出所値を**追加しうる**（既存2値を破壊しない追加的拡張）。本 Phase は出所＝transcript 由来の2値として定義する。

## distill 処理源選択と処理済みカーソル

`captures.md` は無状態の append-only 観測コーパスであり、エントリ単位の処理状態フィールド（旧 `status`）を持たない。「どの観測を distill が処理するか」は、captures 側のフラグではなく **distill 側の処理源選択**で定める。処理源選択は役割の異なる2機構の合成である（ADR-20260711 / ADR-20260711-2）。

- **有界化（処理済みカーソル / high-water mark）**: store レベルに単一の「最終処理 timestamp（カーソル）」を持ち、ルーチン distill はカーソルより**新しい**観測のみを処理源とする。これにより未 distill 観測が齢で無音脱落せず（coverage 欠損の除去）、走査済みノイズの毎回再走査（LLM 非決定性による偽候補 churn）も起きない。
- **重複排除（provenance 導出）**: カーソルより新しいスライス内でも、既に `promoted` または `pending` の候補を provenance に持つ観測は処理源から除外する（重複候補生成の防止）。`rejected` 候補しか持たない観測・候補を持たない観測は provenance では除外せず処理源に残す。ただし有界化（カーソル）が別途効くため、ルーチン distill でこれらが処理源に入るのはカーソルより新しい間（＝当該走査の1回）に限られ、処理後はカーソル前進とともに処理源から外れる（走査済みノイズと同じ扱い。以降の再走査は巻き戻しでのみ開く）。

有界化（カーソル）と重複排除（provenance）は役割が異なり、両者は合成される。カーソルは batch 処理の進捗マーカー（process bookkeeping）であって、候補の検証結果（domain state ＝ `candidate-status`）とは別カテゴリである。状態軸は候補側 `candidate-status` 1 本に集約し、captures 側には状態を持たない。

### カーソルの格納場所

処理済みカーソルは以下の専用メタファイルに、行ベース平文の単一行で持つ。

```
~/.claude/projects/<project-id>/growth/distill-state.md
```

```
- distill-cursor: <ISO8601 見出しキー。複数観察時は -NN サフィックス込み>
```

- `<project-id>` と親ディレクトリの解決は「project-id とパスの解決手順」を共通参照する（`captures.md` / `candidates.md` と同一階層・同一 project-id）。
- カーソル値は `captures.md` の `## <timestamp>` 見出し（ISO 8601）と**同一キー空間**で辞書順比較する。観測は capture 実行時刻の単調増加 timestamp を持つため「カーソルより新しい」は一意に定まる（ADR-20260711-2 末尾）。1 run 複数観察に付す run 内序数サフィックス（`-NN`・固定幅）は辞書順で記録順に整列するため、同一キー空間・単調増加の前提を保つ（ADR-20260711-4）。
- カーソルは captures.md のフロントマターにも candidates.md にも同居させず、専用ファイルに置く。カーソルは観測の内容でも候補の内容でもなく、distill の処理進捗のみを表すためである。

### 前進・巻き戻し・欠損規則

- **前進**: ルーチン distill は処理後、カーソルを今回走査した観測の**最新見出しキー**（辞書順の最大。`-NN` 込みになりうる）へ前進させる。カーソルを前進させる主体は **distill のみ**であり、`promote` は触らない（旧 `status` のようなスキル間反転結合を生まない）。
- **巻き戻し（distiller 改善時）**: distiller を改善したときは、カーソルを意図的に**先頭**（または再走査したい範囲の起点）へ巻き戻して1回だけ再導出する。巻き戻し範囲の観測を再走査し、provenance が live 候補（`promoted` / `pending`）の重複を止め、`rejected` 不可侵（ADR-20260629 決定3）が棄却済み同一仮説の復活を止める。再導出後カーソルを最新へ戻す。改善判定は自動化せず、改善を入れた開発者が明示操作として巻き戻す。
- **巻き戻し（candidates.md 消失時）**: `candidates.md` が消失した場合はカーソルを**先頭**へ巻き戻し、`captures.md` 全体から再導出する（ADR-20260711 Consequence (b) の「再生成可能」をカーソル巻き戻しとして具体化）。
- **欠損時既定**: カーソル（`distill-state.md` またはその中の `- distill-cursor:` 行）が欠損している場合は「**先頭**」を既定とし、一度だけ全走査する。データ損失を招かず安全に劣化する。

### 後方互換

既存 `captures.md` に旧 `status` フィールド（`- status: unprocessed` / `- status: promoted`）付きのエントリが残っていても、distill は**読み取り時にこの行を無視して読む**。破壊的な一括変換（旧エントリからの当該行の削除・書き換え）は行わない。処理源選択は上記のカーソル ＋ provenance のみで判定し、旧 `status` の値には依存しない。

### retention の目的

観測は削除しない。retention の目的は監査保持（単独利用者ゆえ不要）ではなく、**distiller 改善時にカーソルを巻き戻して再導出することを可能にするため**である（ADR-20260711 決定4 / ADR-20260711-2）。改善された distiller が過去の観測から新たなシグナルを拾えるよう、観測コーパスを保持する。

### 二段ゲートとの整合

この処理源選択と昇格経路は `DESIGN.md` の二段ゲート、および自律度モデル L0–L3 / 承認ゲート軸（ADR-20260601 / ADR-20260602-2）と整合する。

- **保存（store への書き込み）= L3（AI 自律・承認段が縮退）**: 観測は無ゲートで自動的に `captures.md` へ貯まる（無状態の追記）。
- **仕組み化（昇格＝ committed への移送）= L2（提案→承認の二段）**: 昇格は、promote の検証段（原理2＝未検証仮説を配布経路に乗せないフィルタ）を通過した仮説が `gh` で自動起票されたことを表す。**起票前に人間承認ゲートは置かない**（自動化を阻害し下流ゲートと二重になるため）。L2 の規範的な仕組み化ゲート（承認またはマルチエージェントレビュー）は、起票後の既存ワークフロー（refine-issue / DoR / PR レビュー）が担う。この昇格状態は候補側 `candidate-status: promoted`（「仮説ファイル（candidates.md）」節）が表し、captures 側には状態を持たない。

## 仮説ファイル（candidates.md）

Distill が生成し `promote` が消費する**仮説ファイル**の置き場・形式・スキーマを単一出典として定義する（#348）。仮説ファイルは生観測 store（`captures.md`）でも配布物（`learnings.md`）でもない**第3の個人ローカル成果物**であり、Distill の仮説形成結果を `promote` の入力として永続化する一時領域である。

### 置き場

```
~/.claude/projects/<project-id>/growth/candidates.md
```

- `captures.md` と**同一階層**（`~/.claude/projects/<project-id>/growth/`）に置く。per-project・user-local。`<project-id>` の解決は「project-id とパスの解決手順」を共通参照する（Distill・promote とも同手順）。
- captures.md 同様ユーザースコープ（`~/.claude/` 配下）にあり work tree の外。配布物に物理的に含まれない。
- **in-repo dogfooding**: growth プラグイン自身を本リポジトリで開発・dogfooding する際にリポジトリ内へ仮説を書き出す運用も、既存 `.gitignore` の `plugins/growth/.local/` がディレクトリごと追跡対象外にするためカバーされる。仮説ファイルのための `.gitignore` 追加変更は不要。

### 形式とスキーマ

仮説ファイルは Markdown であり、1仮説を1セクション（`##` 見出し）として持つ。captures.md と同じく行ベースの平文規約でパースする（YAML パーサによる厳密解釈は前提としない）。captures.md と異なり、仮説は**メタ欄を持つ**（learnings.md の1欄スキーマとは別物。下記参照）。

| 要素 | 必須 | 内容 |
|---|---|---|
| 見出し（`## <短い見出し>`） | 必須 | 仮説の一文要約。tags に `behavior-diff` を含む仮説は命じる振る舞い差分（規範）、`decision-record` を含む仮説は決定の要約、混在ゾーン（両値併記）は両者を要約する。learnings.md へ昇格した際そのまま見出しになる形 |
| `tags` | 必須 | 仮説の知識型（多値 set）。値域 `{behavior-diff, decision-record}` の非空部分集合。`behavior-diff`＝摩擦知、`decision-record`＝判断知（選好・却下理由・目標表明・設計判断）。混在ゾーン（1観測が両知識型にまたがる領域）は両値を併記する。tags の各要素により本文スキーマと promote の検証が分岐する（下記「tags 別スキーマ」）。旧 `type` 単値スキーマの後方互換は下記「後方互換規約」を参照 |
| `provenance` | 必須 | 由来する store エントリへの一意参照。値は `captures.md` の `## <timestamp>` 見出し（ISO 8601。1 run 複数観察時は序数サフィックス込みの見出しキー）。クラスタが複数 observation を畳む場合は複数 timestamp をカンマ区切り等で列挙する。distill が provenance 導出で処理源から除外する観測（`promoted` / `pending` 候補を持つもの）を特定する粒度 |
| `scope-hypothesis` | 必須 | スコープタグ。値域は `project-local` / `universal` の2値（learning-store-spec.md「2空間モデル」に対応）。Distill が仮説形成観点として付与する**仮説**であり、確証しない（最終裁定は人間の refine/review、横断解析は Phase 3 の支援どまり） |
| `career-hypothesis` | 必須 | キャリアタグ。**昇格先キャリア**（`強キャリア` / `改善還元` / `ADR 差分` / `learnings.md` の4分類）＋**宛先 repo の仮説**を `<career> / repo: <宛先 repo 仮説>` の1行形式で持つ。判定基準（4分類の決定表）は distill 側（distill-procedure.md「career-hypothesis の判定（決定表）」）を単一出典とする。`scope-hypothesis` と**対称・直交**な独立メタ欄であり（キャリア軸 ⊥ 空間軸。DESIGN.md「種別軸 ⊥ 共有境界軸」）、Distill が仮説形成観点として付与する**仮説**で確証しない。career と宛先 repo の最終裁定は集約点（取り込み Issue）で行い、promote は確定しない（ADR-20260628-2） |
| `candidate-status` | 必須 | 仮説の処理状態。`pending`（既定。未処理）/ `rejected`（promote の検証で棄却）/ `promoted`（promote が Issue 起票成功後に付与。**必須**。付与しないと候補が `pending` のまま残り次回 promote で二重起票されるため、起票成功後は必ず前進させる。promote-procedure.md §6 参照）。再 distill 時の再提示ループを断つための追跡軸（下記「冪等性」参照） |
| 本文 | 必須 | tags 別の本文。`behavior-diff` は規範差分の具体（次回どう違う行動を取るか）＋理由。`decision-record` は決定知の構造化4欄（下記「tags 別スキーマ」）。混在ゾーン（両値併記）は両本文を併記する。メタ欄の後にエントリ末尾の本文ブロックとして記述する（複数行可） |

### tags 別スキーマ

仮説は `tags` の各要素により本文スキーマと下流の扱いが分岐する。両知識型は同一の `candidates.md` に同居し、provenance・`candidate-status`・upsert・冪等性・ライフサイクル（promote→Issue）を共有する。`tags` は値域 `{behavior-diff, decision-record}` の非空部分集合であり、単一要素（`[behavior-diff]` / `[decision-record]`）と混在ゾーン（`[behavior-diff, decision-record]`）を取りうる。

- **`behavior-diff`（摩擦知）**: 本文は規範差分（次回どう違う行動を取るか）＋理由。既存ルール台帳との突合・既存ルール再発の N 回カウント（provenance 件数から導出）・強制化の対象（#417 / ADR-20260629）。本型の扱いは従来どおりで変更しない。
- **`decision-record`（判断知）**: 本文は文脈付き決定知を構造化した4欄を持つ。behavior-diff 要求（トリガー×振る舞い差分が両方読めること）と N 再発カウントを**免除**する（原理1 の例外口。一回性の設計境界をカウントでなく決定の記録として残す）。

  | 欄 | 内容 |
  |---|---|
  | `decision` | 何を決めたか（採用した結論） |
  | `rejected-alternatives` | 却下した代替案 |
  | `rationale` | 却下・採択の理由 |
  | `context` | どの設計局面か（対象 Issue / ファイル / 議論の文脈） |

  `decision-record` の `scope-hypothesis` は大半が `project-local`（プロジェクト自身の設計判断は閉じた空間＝当該リポの ADR / docs へ向かう）。`career-hypothesis` は `ADR 差分` または `learnings.md` を取りうる。learnings.md（配布物）への翻訳規約（learning-promotion-spec.md・#383）の decision-record 対応は Phase 2 で定義する（本 Phase は candidates → Issue まで）。

- **混在ゾーン（`tags: [behavior-diff, decision-record]`）**: 1観測が両知識型にまたがる領域（DESIGN.md §6 決定事項10）。本文は両型の本文を併記する（規範差分＋理由の behavior-diff 本文と、4欄の decision-record 本文を両方持つ）。promote の型適応検証は tags の各要素へ個別に適用する（下記「promote の検証」および promote-procedure.md）。第2タグの付与は distill の evidence-gated 分岐で陽性証拠がある時のみ行う（distill-procedure.md 参照）。既定は単一タグであり、両値併記を無条件に既定化しない。

### 後方互換規約

旧 `type`（単値）スキーマの既存エントリを壊さず読むための変換規則。`tags` は `type` の一般化（単値＝要素数1の tags 特殊ケース）であり、旧エントリは以下で `tags` へ写して解釈する。

| 旧スキーマの状態 | `tags` としての解釈 |
|---|---|
| `type: <値>`（単値フィールドあり） | `tags: [<値>]`（要素数1の集合） |
| `type`・`tags` とも欠落 | `tags: [behavior-diff]`（既定＝摩擦知） |

- distill・promote とも、読み取り時にこの規則で旧エントリを `tags` として解釈する。物理的な一括変換（既存 `candidates.md` の書き換え）は要求しない（読み取り時変換で後方互換を保つ）。
- distill が既存の旧 `type` エントリを upsert で再書き込みする場合は、`tags` 形式へ移行して書き出す（後方互換の読みと前方の書きが一致する）。

### provenance 規約

- provenance は由来 store エントリの `## <timestamp>` 見出し（ISO 8601）を一意参照キーとして保持する。distill はこのキーで由来観測を特定し、provenance 導出（`promoted` / `pending` 候補を持つ観測の処理源からの除外）に用いる。`promote` は候補側の `candidate-status` を前進させ、`captures.md` は書き換えない。
- **一意化規則**: 見出しキーは capture 実行時刻に、1 run 複数観察時の run 内序数サフィックス（`-NN`）を加えて一意化する（capture SKILL.md Step 1・ADR-20260711-4）。秒精度の実行時刻のみでは 1 run 複数観察で衝突するため序数で割る。これにより同一 store 内で見出しキーが衝突せず、provenance 参照・candidate-status 前進の同定対象が一意に定まる。
- **将来の留保（Phase 3 並行 capture）**: hook 自発化（Phase 3）で同一 store への並行 capture が生じると、run 内序数は run をまたいだ大域一意性を保証しない。その段階では時刻順序を内包する一意 ID（UUIDv7 / ULID 等）への移行を再訪する。本 Phase では生成手段の統合コスト・可読性・ISO 8601 モデルとの整合から実行時刻＋序数を採る（案の比較・却下理由は ADR-20260711-4）。

### Distill の書き込み方式（upsert）

- Distill は仮説を provenance キーで **upsert**（同一 provenance キーの既存仮説があれば置換、なければ追加）して仮説ファイルへ永続化する。単純追記は再実行で重複し、全置換は既存仮説を失うため。provenance キーでの upsert により再 distill が冪等になる。
- **tags の集合マージ（冪等）**: 同一 provenance キーの再仮説形成で既存仮説と新仮説の `tags` を**集合和**でマージする。重複タグは生まない（set 意味論）。旧 `type` 単値エントリを再仮説形成する場合は「後方互換規約」で `tags` へ写してからマージする。これにより、既存の第1タグを失わずに第2タグを付与でき、再実行しても `tags` が単調に安定する（冪等）。

### 冪等性（candidate-status による再提示抑止）

- promote の検証で棄却された仮説の由来観測は、captures 側に状態を持たないため処理源に残りうる（カーソルより新しければルーチン distill の対象、カーソル以下でも distiller 改善時の巻き戻しで再走査されうる）。何もしなければ同一仮説が再生成・再提示される。これを避けるため、仮説ファイルに `candidate-status` 欄を持たせ、promote が棄却した仮説を `rejected` で追跡する。Distill は upsert 時に既存の `rejected` 仮説を尊重し、安易な再提示を避ける。

### 1欄スキーマ（learnings.md）との区別

learnings.md（配布物）は**メタ欄を持たない1欄スキーマ**（learning-store-spec.md「1欄スキーマ」）であり、provenance・scope・撤回追跡は空間・git 履歴が担う。一方、仮説ファイルは個人ローカルの一時領域であり、`promote` が消費するための機械的メタ欄（provenance・scope-hypothesis・career-hypothesis・candidate-status）を持つ。仮説が learnings.md へ昇格する際にこれらメタ欄は落ち、見出しと本文（規範）だけが残る。

### 記述例

```
## git restore でファイル復元する
- tags: [behavior-diff]
- provenance: 2026-06-26T14:32:10Z
- scope-hypothesis: universal
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
- candidate-status: pending

ファイル復元には git checkout ではなく git restore を使う。git checkout は復元とブランチ切替が多重定義され誤操作を招くため。

## プランは追跡対象にしない
- tags: [decision-record]
- provenance: 2026-06-29T08:50:02Z
- scope-hypothesis: project-local
- career-hypothesis: ADR 差分 / repo: 当該プロジェクト repo
- candidate-status: pending

- decision: プランファイルは git 追跡対象（コミット）に変えない。追跡可否は利用者に委ねる。
- rejected-alternatives: プランを追跡対象（コミット）に変える第三案。
- rationale: 追跡するか否かは利用者側の運用判断であり、仕組みで固定すべきでない。
- context: プラン所在問題（#422 周辺）の解決案を巡る設計判断。

## worktree を抜ける前にマージ状態を確認する
- tags: [behavior-diff, decision-record]
- provenance: 2026-07-01T10:12:44Z
- scope-hypothesis: project-local
- career-hypothesis: ADR 差分 / repo: 当該プロジェクト repo
- candidate-status: pending

ExitWorktree はマージ済みかを確認しないため、削除前に gh pr view --json state で確認してから抜ける。
- decision: worktree 削除の前提として PR のマージ状態確認を必須手順に組み込む。
- rejected-alternatives: 削除時に毎回マージ状態を自動チェックする仕組みを ExitWorktree 側へ入れる案。
- rationale: ツール側の自動チェックは適用範囲が広すぎ、運用手順として明示する方が可逆的で軽い。
- context: worktree 運用ルール（ExitWorktree のマージ未確認）を巡る設計判断。
```

3番目の例は混在ゾーン（`tags: [behavior-diff, decision-record]`）。同一観測が「次回こう行動する」規範差分（behavior-diff 本文）と、それを支える設計判断（decision-record 4欄）の両方を含むため、両本文を併記する。

## 構成上の保証と検証手段

生観測が配布物（リポジトリ）に混入しないことを構成で保証し、検証可能にする（AC5）。

### ユーザースコープ store（正準の置き場）

正準の置き場 `~/.claude/projects/<project-id>/growth/captures.md` は本リポジトリの work tree の外にあるため、リポジトリの `git status` には原理上現れない。リポジトリのどのブランチからもトラッキング対象にならないことが、置き場の選定そのものによって保証される。

### in-repo dogfooding 時の防御

growth プラグイン自身を本リポジトリで開発・dogfooding する際、リポジトリ内のパスへ観測を書き出す運用がありうる。その場合に未検証観測が誤ってコミットされないよう、リポジトリルートの `.gitignore` で `plugins/growth/.local/` を追跡対象外にする。検証手順は以下。

なお **Distill の処理源（仮説化対象の work queue）は正準パス（`captures.md`）のみ**である。in-repo の `plugins/growth/.local/` は手動 dogfooding 時に観測を誤コミットから守るための保護領域であって、Distill の走査対象ではない。両方にファイルが存在する場合も Distill は処理源として正準パスだけを読む。

> Distill は処理源（`captures.md`）とは別に、既存ルール台帳（`CLAUDE.md` 2層・`learnings.md`・`candidates.md` 自身）を**読み取り専用の参照源**として突合に用いる（仮説は生成しない・台帳は書き換えない）。処理源とは別レイヤであり、本「構成上の保証」の対象（生観測が配布物に混入しないこと）には影響しない。詳細は distill-procedure.md §2 および ADR-20260629。

```bash
# .gitignore のマッチ規則が返れば追跡対象外であることが確認できる
git check-ignore -v plugins/growth/.local/captures.md

# ダミーファイルを置いても untracked にすら現れないことを確認する
mkdir -p plugins/growth/.local && touch plugins/growth/.local/captures.md
git status --porcelain plugins/growth/.local/   # 出力が空であること
```

## スコープ境界

| 本仕様が定義する（IN） | 本仕様が定義しない（OUT） |
|---|---|
| store の置き場（確定パス・per-project） | Capture の予測誤差検知ロジック本体 |
| 観測エントリの形式（必須欄・Markdown 形式） | committed 学び置き場（`learnings.md`）への物理昇格（Distribute、Phase 2） |
| シグナル種別の値域（5値） | 過去セッションログの横断解析（Phase 3） |
| 出所軸（`origin`）の値域（2値・signal と直交） | 出所に基づく摩擦/判断の分類・重み付け（distill 側） |
| `expected` / `actual` フィールド（該当時必須・transcript 抽出限定） | 客観痕跡向けの出所値の追加（Phase 3） |
| distill 処理源選択（provenance 導出 ＋ 処理済みカーソル）・カーソル格納場所（`distill-state.md`）・前進/巻き戻し/欠損規則 | git revert・CI 失敗の取得（Phase 3 以降） |
| 仮説ファイル（`candidates.md`）の置き場・形式・メタ欄スキーマ・provenance 規約 | promote の検証・Route 注記・起票の具体手順（promote スキルが定義） |
| store が配布物に混入しない構成保証 | |

## 関連

- `plugins/growth/DESIGN.md` — 設計母艦（決定事項3・§3 保存設計・二段ゲート・Capture シグナル定義）
- `docs/adr/ADR-20260601-autonomy-approval-gate-alignment.md` / `docs/adr/ADR-20260602-2-autonomy-ladder-convention.md` — 二段ゲートが依拠する自律度 L0–L3 / 承認ゲート軸
