# growth ユビキタス言語（用語集）

growth プラグインのドメイン用語を一箇所に集約した正典。設計の進行で用語が増減・drift しても、各語が「何を指すか」を作者の意図と一致した形で参照できる状態を保つことを目的とする。

> **用語移行中（読む前に）**: DESIGN.md §3 の学習ループ図が用語の現行正典。本用語集のドメイン概念語を新語へ移行中——**観察 → 捕捉記録** / **候補 → 仮説** / **取り込み → 制度化** / **予測誤差 → 予測誤差シグナル**。ファイル名・フィールド名等のコード識別子（`captures.md`／捕捉置き場、`candidates.md`／候補ファイル、`candidate-status`、`observation` 等）は**据え置き**で、§8 対応表がその識別子↔概念語の対応を担う（概念＝仮説、格納ファイル＝candidates.md、のように domain/impl を分離）。各スキル・spec・ADR-20260628-2 の旧語、および `intake` スキル改名・`キャリア`／`スコープ` の日本語化は follow-up の「ユビキタス言語移行」epic で行う。

## この用語集の読み方・書き方

- **見出しは日本語を正典とし、英語表記を括弧で併記する**（`## 捕捉（capture）`）。意図を日本語で固定し、英語語は追跡用の別名として扱う
- 各エントリは4欄スキーマで記述する:
  - **定義** — その語が何を指すか（1〜2文）
  - **使用箇所** — 主な出現ファイル・節
  - **避ける語** — 同一概念の揺れ・旧称・使うべきでない言い換え（無ければ省略）
- コード識別子（`status` の値 `unprocessed`/`promoted`、ファイル名 `captures.md` 等の機械値）は無理に和訳せず、概念のまとまりを日本語見出しにして値を英語のまま記す。各識別子の日本語対応は §8「コード識別子と日本語の対応表」で照合する
- 正典は `plugins/growth/DESIGN.md` の設計と整合させる。乖離を見つけたら本用語集か DESIGN.md のどちらかを直す

---

## 1. 学習ループの段

growth の中核フロー。`捕捉 → 蒸留 → 昇格 → 配布 → 測定／撤回` の5段。スコープ仮説の付与（旧「経路判定」）は独立段でなく蒸留に内在する（用語として退役。下記「〔退役〕経路判定 / route」を参照）。

### 学習ループ（learning loop）
- **定義**: 上記6段からなる、気付きを保存・検証して配布物へ届けるパイプライン全体。
- **使用箇所**: DESIGN.md §3
- **避ける語**: 「5段ループ」（段数は Phase で変わるため数を名前に含めない）

### 捕捉（capture）
- **定義**: 現セッションの会話履歴から予測誤差シグナルを検知し、捕捉記録（何が起きたかの生記録）を個人ローカルの捕捉置き場に残す学習ループの第1段。解釈・原因分析・対策は含めない。
- **使用箇所**: DESIGN.md §3・§4 / skills/capture/SKILL.md
- **避ける語**: 「reflect」（reflect/distill 分離（#347）以前の旧称。現在は capture に統一）

### 蒸留（distill）
- **定義**: 個人ローカルの捕捉置き場の未処理の捕捉記録をクラスタ化・重複排除し、実行可能な振る舞い差分の仮説へ変換する第2段。各仮説には共有範囲の [[スコープ仮説（scope-hypothesis）]]（2観点 project-local / universal）と昇格先の [[キャリア仮説（career-hypothesis）]] の2タグ（いずれも未確証の仮説）を付与する（旧「経路判定」も career の判定も独立段でなく蒸留に内在する責務。#411）。
- **使用箇所**: DESIGN.md §3・§4 / skills/distill/SKILL.md
- **避ける語**: 「route」「経路判定」「ルーティング」（スコープ仮説の付与を独立段・用語として呼ばない。蒸留の責務に内在）

### 〔退役〕経路判定 / route
- **disposition**: 棄却（退役）。スコープ仮説の付与は蒸留に内在し、独立段・用語として残す必要がないと判断（#408 レビュー）。DESIGN.md 決定事項（Route を distill へ統合）・learning-store-spec（蒸留は project-local と universal の2観点に分かれる）が裏付け。
- **整合待ち（#409）**: DESIGN.md・personal-store-spec・learning-store-spec・learning-promotion-spec・promote 一式の「Route」語は未整合。#409 で「スコープ仮説の付与（蒸留の責務）」言語へ伝播する（棄却 disposition の初回適用ケース）。
- **生き残る語**: 蒸留が付与する2つの仮説 [[スコープ仮説（scope-hypothesis）]]（空間軸）と [[キャリア仮説（career-hypothesis）]]（キャリア軸）。#411 で career の判定も distill へ移り、旧「Route判定規則」も削除された（scope・career とも routing は蒸留に内在）。

### 昇格（promote）
- **定義**: 蒸留が生成した仮説を検証し、検証通過分を `gh` で Issue へ自動起票して既存ワークフローへ渡す第3段（Phase 1 スキル）。仮説の scope/career タグは確定せず注記のまま運ぶ（ルーティング不可知。#411）。最終裁定は集約点＝制度化（`intake` が起こす Issue）が担う。
- **使用箇所**: DESIGN.md §3・§4 決定事項8 / skills/promote/SKILL.md
- **避ける語**: 段・スキルとしての「昇格（promote）」と、全移送過程を指す広義の「昇格（promotion）」を区別する。広義は [[昇格（広義）]] を参照

### 制度化（institutionalization）
- **定義**: 昇格した仮説が Issue として合流し、人が最終裁定する集約点（学習ループの裁定点＝二段ゲート L2）。ここで scope/career の仮説が確定に変わり、個体の学びが集団の規範になる。実装は `intake` スキル＋既存ワークフロー（refine / DoR / PR）。
- **使用箇所**: DESIGN.md §3 / skills/intake/SKILL.md / ADR-20260628-2
- **避ける語**: 「取り込み」「取り込み Issue」（移行前の旧称。制度化に統一。実装スキル名 `intake` は据え置き）

### 配布（distribute）
- **定義**: 検証済みの学びを `learnings.md` 等の配布物へ物理的に追加する第4段（Phase 2）。
- **使用箇所**: DESIGN.md §3 / references/learning-promotion-spec.md
- **避ける語**: 「昇格実行」「配布反映」（配布に統一）

### 測定（measure）／撤回（retire）
- **定義**: 配布後に学びの発火回数・効果を観測し（測定）、効かない・害ある学びを配布物から物理除去する（撤回）第5段（Phase 3）。
- **使用箇所**: DESIGN.md §3
- **避ける語**: 撤回の実体は [[整理]]（忘却・畳み込み）として記述される。除去を指すときは忘却/畳み込みを使う

---

## 2. データと成果物

### 捕捉記録（capture record）
- **定義**: 捕捉が予測誤差シグナルを検知し「何が起きたか」の生記録として残した物。解釈・原因分析・対策を含まない事実のみ。第1段の唯一の成果物で蒸留の入力。
- **使用箇所**: references/personal-store-spec.md §2 / skills/capture/SKILL.md
- **避ける語**: 「観察」（移行前の旧称。捕捉記録に統一）「生観察」「生記録」。フィールド識別子は `observation` のまま据え置き（§8）

### 振る舞い差分（behavior delta）
- **定義**: 「次回どう違う行動を取るか」を一文で表す実行可能な規範。捕捉置き場 → 仮説 → learnings.md へ受け継がれる学びの核。
- **使用箇所**: DESIGN.md 原理1 / references/learning-store-spec.md
- **避ける語**: 「行動差分」「差分」（振る舞い差分に統一）

### 規範（norm）
- **定義**: 「次回どう違う行動を取るか」を命じる learnings.md の見出し一文。テキストとして配布される最も弱いキャリア。
- **使用箇所**: references/learning-store-spec.md
- **避ける語**: 「ルール」「規則」「行動指針」（規範に統一）

### 仮説（hypothesis）
- **定義**: 蒸留が生成した、検証待ちの振る舞い差分（原理2「気付きは仮説」の語）。まだ確証されておらず、制度化で確定に変わる。`candidates.md` 内のエントリとして存在する（格納ファイルは候補ファイル＝§8。識別子据え置き）。
- **使用箇所**: references/personal-store-spec.md / skills/distill/references/distill-procedure.md
- **避ける語**: 「候補」（移行前の旧称。仮説に統一）「蒸留候補」「検証候補」「Issue候補」（用途修飾を付けない）

### 捕捉置き場（captures.md）
- **定義**: 個人ローカルに置かれる、未検証の生の捕捉（捕捉記録）を蓄積するファイル。パス `~/.claude/projects/<project-id>/growth/captures.md`。捕捉の書き込み先・蒸留の入力源。
- **使用箇所**: references/personal-store-spec.md
- **避ける語**: 「store」「ストア」「生捕捉ストア」（カタカナ表記・旧称を避け捕捉置き場に統一。文脈で曖昧なときは captures.md と明示）

### 候補ファイル（candidates.md）
- **定義**: 蒸留の出力先・昇格の入力源。個人ローカルの第3の成果物（捕捉置き場でも learnings.md でもない）。
- **使用箇所**: references/personal-store-spec.md
- **避ける語**: 「候補置き場」（candidates.md と明示）

### 学び置き場（learnings.md）
- **定義**: 検証済みの汎用振る舞い規範を集約した配布物。パス `plugins/growth/learnings.md`。1欄スキーマで記述する。
- **使用箇所**: references/learning-store-spec.md / DESIGN.md
- **避ける語**: 「配布物」「最終置き場」（learnings.md と明示）

---

## 3. 状態フィールドと値

### 処理状態（status）
- **定義**: 捕捉置き場の各エントリの処理状態。値は `unprocessed`（未処理）/ `promoted`（昇格済み）の2値。昇格が起票成功後に `unprocessed → promoted` を反転する。
- **使用箇所**: references/personal-store-spec.md / skills/promote/references/promote-procedure.md

### 候補状態（candidate-status）
- **定義**: 候補ファイル内の各仮説の処理状態。値は `pending`（検証待ち・既定）/ `rejected`（昇格検証で棄却）/ `promoted`（昇格済み。昇格が Issue 起票成功後に付与する任意・推奨値）の3値。
- **使用箇所**: references/personal-store-spec.md / skills/promote/references/promote-procedure.md
- **注記**: `promoted` は当初 personal-store-spec.md のスキーマ表に未記載で promote-procedure.md のみが扱う drift があった（本 PR で正典スキーマ側に任意・推奨値として追補して整合）

### 由来（provenance）
- **定義**: 仮説の出自を追跡するメタフィールド。値は捕捉置き場の `## <timestamp>` 見出し。蒸留の upsert・昇格の状態反転で同一性判定に使う。
- **使用箇所**: references/personal-store-spec.md / skills/promote/references/promote-procedure.md
- **避ける語**: 「出自キー」「由来参照」（由来 / provenance に統一）

---

## 4. スコープと配布構造

### スコープ仮説（scope-hypothesis）
- **定義**: 蒸留が仮説に付与する共有範囲の仮説タグ。値は `universal`（全プロジェクト対象）/ `project-local`（チーム・プロジェクト限定）。確証せず仮説のまま終端する。
- **使用箇所**: references/personal-store-spec.md / references/promotion-issue-spec.md
- **避ける語**: 「スコープタグ」「適用範囲仮説」（スコープ仮説に統一）

### 共有境界（shared boundary）
- **定義**: 学びを「誰」に「どの範囲で」共有するかを決める分界線。母集団＝共有境界。スコープ仮説がこれを表現する。
- **使用箇所**: DESIGN.md §3「母集団 = 共有境界」

### 2空間モデル（2-space model）
- **定義**: 学び置き場が持つ2つの独立した共有領域。パブリック／グローバル空間（本リポジトリの learnings.md）と閉じた空間（チーム管理リポジトリ）。
- **使用箇所**: references/learning-store-spec.md
- **避ける語**: [[2面モデル]]（origin/consumer の面）と別概念。空間＝共有範囲、面＝書込/読取の役割

### 2面モデル（2-face model）
- **定義**: learnings.md が持つ2つの面。origin 面（編集・権威ファイル側、本リポジトリ）と consumer 面（読み取り専用ミラー、各利用者のプラグインキャッシュ）。
- **使用箇所**: references/learning-store-spec.md
- **避ける語**: [[2空間モデル]]と混同しない

### fan-out
- **定義**: origin 面の learnings.md から consumer 面（各利用者）への一方向配布フロー。
- **使用箇所**: references/learning-store-spec.md「2面モデル」/ DESIGN.md
- **避ける語**: 適切な和訳が定まっていない（暫定で英語のまま）。日本語化の要否は #409 で判定

### fan-in
- **定義**: consumer 面での観測値（発火・効果）を origin へ還流させるフィードバックフロー。Phase 3 の使用台帳→集約ダイジェスト。
- **使用箇所**: references/learning-store-spec.md / DESIGN.md 決定事項7
- **避ける語**: 適切な和訳が定まっていない（暫定で英語のまま）。日本語化の要否は #409 で判定

### 活性化モデル（activation model）
- **定義**: learnings.md が consumer のコンテキストへロードされる仕組み。Phase 1-2 は全文常時注入、Phase 3 は見出し常時注入＋本文オンデマンド読み込み。
- **使用箇所**: DESIGN.md 決定事項7 / references/learning-store-spec.md

---

## 5. キャリア（配布先媒体）

### キャリア（career）
- **定義**: 学びを載せる配布先媒体の分類。`強キャリア` / `改善還元` / `ADR 差分` / `learnings.md` の4種。スコープ仮説（空間軸）とは直交する軸（キャリア軸 ⊥ 空間軸）。
- **使用箇所**: skills/distill/references/distill-procedure.md「career-hypothesis の判定（決定表）」/ references/promotion-issue-spec.md / DESIGN.md
- **避ける語**: 「昇格先」「配布媒体」（キャリアに統一）。「dev-workflow Issue」は旧名（#411 で「改善還元」へ。任意プラグイン／コミュニティの改善で dev-workflow に限らない）
- **注記**: career は蒸留が仮説へ [[キャリア仮説（career-hypothesis）]] として付与する（#405/#411、ADR-20260628-2）。promote は確定せず注記で運び（ルーティング不可知）、career と宛先 repo の最終裁定は集約点＝制度化が担う

### 強キャリア（strong carrier）
- **定義**: skill / hook / lint / test などコードレベルの決定論的ガードレール。「二度と起こせない構造」として learnings.md には載らず、テキスト規範からは除去される。
- **使用箇所**: references/promotion-issue-spec.md / references/learning-store-spec.md
- **避ける語**: 「構造化キャリア」「コード配布」（強キャリアに統一）

### キャリア仮説（career-hypothesis）
- **定義**: 蒸留が仮説に付与する、昇格先キャリアと宛先 repo の仮説タグ。`<career> / repo: <宛先 repo 仮説>` の1行形式。4分類（`強キャリア` / `改善還元` / `ADR 差分` / `learnings.md`）の判定表は distill-procedure.md「career-hypothesis の判定（決定表）」が単一出典。[[スコープ仮説（scope-hypothesis）]]と対称・直交（キャリア軸 ⊥ 空間軸）。distill 時点では仮説で確証せず、最終裁定は集約点＝制度化（ADR-20260628-2）。
- **使用箇所**: skills/distill/references/distill-procedure.md / references/personal-store-spec.md
- **避ける語**: 「Route判定規則」（#411 で削除された旧称。career の判定は distill の career-hypothesis へ移動）

---

## 6. 検証と整理

### 検証（verification）
- **定義**: 昇格が各仮説について行う、予測（効く場面）と反証条件（いつ反例が立つか）の両立可能性の評価。起票前のゲート。
- **使用箇所**: skills/promote/references/promote-procedure.md §3 / DESIGN.md 原理2
- **避ける語**: 「昇格ゲート」を検証の意味で使わない。起票前ゲート＝検証、起票後ゲート＝[[二段ゲート]]の L2（refine/DoR/PR）

### 反証可能性（falsifiability）
- **定義**: 検証で求める仮説の必須性質。「この条件で反例が作られうる」という明確な反証経路が存在すること。
- **使用箇所**: skills/promote/references/promote-procedure.md §3

### 二段ゲート（two-gate system）
- **定義**: growth の承認構造。保存（自動）→ 仕組み化（承認 or マルチエージェントレビュー）の2段。捕捉・置き場への保存は自動、PR マージで仕組み化を承認。
- **使用箇所**: DESIGN.md「二段ゲート」/ references/personal-store-spec.md
- **避ける語**: 「2段階承認」（二段ゲートに統一）

### 整理（cleanup）
- **定義**: learnings.md のライフサイクル操作の総称。忘却（除去）と畳み込み（上位への昇華）からなり、足場を痩せさせる営み。
- **使用箇所**: references/learning-store-spec.md「整理」/ DESIGN.md 原理5

### 忘却（forgetting）
- **定義**: 整理の一形。反証された・無効果だった学びをエントリごと物理除去する。
- **使用箇所**: references/learning-store-spec.md「整理」

### 畳み込み（folding）
- **定義**: 整理の一形。具体ルールを上位原理や強キャリア（skill/lint/test）へ昇華的に移送し、テキスト規範エントリを除去する。
- **使用箇所**: references/learning-store-spec.md「整理」/ DESIGN.md 原理4・5
- **避ける語**: 「高度化」「構造化」（畳み込みに統一）

---

## 7. 横断・広義の語

### 昇格（広義）（promotion）
- **定義**: 学びが捕捉置き場 → 仮説 → Issue → learnings.md へ段階的に移送される過程全体。段・スキルとしての [[昇格（promote）]] より広い。
- **使用箇所**: DESIGN.md §3
- **避ける語**: 文中で「昇格」が段（promote）と過程（promotion）のどちらを指すか曖昧なときは明示する

### 予測誤差シグナル（prediction-error signal）
- **定義**: 学習ループの起点。モデルの予測と現実のズレ（予測誤差）を示す観測可能な外部痕跡。推論時は誤差を直接測れないため、訂正・ツール拒否・反復試行・期待違反・客観痕跡の5シグナル種別の痕跡から間接的に検知する。ML の残差と違いこの段では誤差の実在を断定せず代理として捕捉し、判断は下流へ後回しする。符号付きで、負の失敗だけでなく正の驚きも含みうる。
- **使用箇所**: DESIGN.md §3 / skills/capture/SKILL.md
- **避ける語**: 「予測誤差」単独（移行前の旧称。起点ノードは予測誤差シグナルに統一）。種別値は [[シグナル（signal）]]。「驚き」は説明語として可

### シグナル（signal）
- **定義**: 予測誤差の種別値。訂正 / ツール拒否 / 反復試行 / 期待違反 / 客観痕跡 の5値。
- **使用箇所**: references/personal-store-spec.md / skills/capture/SKILL.md

### フリート学習（fleet learning）
- **定義**: 単一ユーザーの N セッションより、M ユーザーの集合ログの方が学びが豊かという学習戦略。Phase 3 で横断解析として実装予定。
- **使用箇所**: DESIGN.md 原理6

---

## 8. コード識別子と日本語の対応表

英語のまま使うコード識別子（フィールド名・値・ファイル名）の日本語対応。「この英語値は何を指すか」を意図と照合する場。概念としての定義は各エントリ（§1〜§7）を参照。

### フィールド名

| コード識別子 | 日本語 | 意味・対応エントリ |
|---|---|---|
| `signal` | シグナル種別 | 予測誤差の種別 → シグナル（signal） |
| `session` | 出所セッション参照 | どのセッションの捕捉記録か（UUID） |
| `observation` | 捕捉記録 | 何が起きたかの生記録 → 捕捉記録（capture record）。フィールド識別子は据え置き |
| `status` | 処理状態 | 捕捉置き場の処理状態 → 処理状態（status） |
| `provenance` | 由来 | 仮説の出自参照 → 由来（provenance） |
| `scope-hypothesis` | スコープ仮説 | 共有範囲の仮説タグ → スコープ仮説（scope-hypothesis） |
| `candidate-status` | 候補状態 | 仮説の処理状態 → 候補状態（candidate-status）。フィールド識別子は据え置き（概念は仮説） |
| `career-hypothesis` | キャリア仮説 | 昇格先キャリア＋宛先 repo の仮説 → キャリア仮説（career-hypothesis） |

### フィールドの値

| コード識別子 | 日本語 | 属する欄 |
|---|---|---|
| `unprocessed` | 未処理（既定） | status |
| `promoted` | 昇格済み | status / candidate-status（後者は任意・推奨値） |
| `pending` | 検証待ち（既定） | candidate-status |
| `rejected` | 棄却 | candidate-status |
| `universal` | 全世界 × 全プロジェクト対象 | scope-hypothesis |
| `project-local` | チーム・プロジェクト限定 | scope-hypothesis |

`signal` の値（`訂正` / `ツール拒否` / `反復試行` / `期待違反` / `客観痕跡`）は日本語を正準とする（personal-store-spec.md「シグナル種別」）。英語コードは持たない。

### ファイル名・その他

| コード識別子 | 日本語 | 意味・対応エントリ |
|---|---|---|
| `captures.md` | 捕捉置き場 | → 捕捉置き場（captures.md） |
| `candidates.md` | 候補ファイル | → 候補ファイル（candidates.md） |
| `learnings.md` | 学び置き場 | → 学び置き場（learnings.md） |
| `project-id` | プロジェクト識別子 | 作業ディレクトリ絶対パスのスラッシュを `-` に置換した識別子 |
| `fan-out` | （暫定で英語のまま） | origin → consumer の一方向配布。和訳要否は #409 |
| `fan-in` | （暫定で英語のまま） | consumer → origin のフィードバック還流。和訳要否は #409 |

---

## 未収録（継続拡充候補）

初版では中核と英語ジャーゴン・表記揺れを優先した。以下は #409 の保守機構で順次定義する長い裾の用語（一部）:

パブリック／グローバル空間、閉じた空間、origin 面 / consumer 面、客観痕跡、生記録性、confabulation（作話）、記法ルール、1欄スキーマ、メタ欄、upsert、冪等性、一般化、抽出、見出し圧縮、疎結合、compaction（Claude Code 機能）、自発トリガー、横断解析、in-repo dogfooding、仮説検証ループ

※ コード識別子の値（universal / project-local、status・candidate-status の各値、project-id 等）は §8 の対応表で照合できる。

#405/#411 がマージ済みのため追補可能（#409 で拡充）: 改善還元 / ADR 差分 / 強キャリア / learnings.md 行き 各キャリアの個別エントリ、宛先 repo 仮説
