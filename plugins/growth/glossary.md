# growth ユビキタス言語（用語集）

growth プラグインのドメイン用語を一箇所に集約した正典。設計の進行で用語が増減・drift しても、各語が「何を指すか」を作者の意図と一致した形で参照できる状態を保つことを目的とする。

## この用語集の読み方・書き方

- **見出しは日本語を正典とし、英語表記を括弧で併記する**（`## 捕捉（capture）`）。意図を日本語で固定し、英語語は追跡用の別名として扱う
- 各エントリは4欄スキーマで記述する:
  - **定義** — その語が何を指すか（1〜2文）
  - **使用箇所** — 主な出現ファイル・節
  - **避ける語** — 同一概念の揺れ・旧称・使うべきでない言い換え（無ければ省略）
- コード識別子（`status` の値 `unprocessed`/`promoted`、ファイル名 `captures.md` 等の機械値）は無理に和訳せず、概念のまとまりを日本語見出しにして値を英語のまま記す
- 正典は `plugins/growth/DESIGN.md` の設計と整合させる。乖離を見つけたら本用語集か DESIGN.md のどちらかを直す

---

## 1. 学習ループの段

growth の中核フロー。`捕捉 → 蒸留 → 経路判定 → 昇格 → 配布 → 測定／撤回` の6段（Phase 1 では経路判定が蒸留に統合され4段）。

### 学習ループ（learning loop）
- **定義**: 上記6段からなる、気付きを保存・検証して配布物へ届けるパイプライン全体。
- **使用箇所**: DESIGN.md §3
- **避ける語**: 「5段ループ」（段数は Phase で変わるため数を名前に含めない）

### 捕捉（capture）
- **定義**: 現セッションの会話履歴から予測誤差シグナルを検知し、生の観察を個人ローカルストアに記録する学習ループの第1段。解釈・原因分析・対策は含めない。
- **使用箇所**: DESIGN.md §3・§4 / skills/capture/SKILL.md
- **避ける語**: 「reflect」（reflect/distill 分離（#347）以前の旧称。現在は capture に統一）

### 蒸留（distill）
- **定義**: 個人ローカルストアの未処理の観察をクラスタ化・重複排除し、実行可能な振る舞い差分の候補へ変換する第2段。Phase 1 では経路判定を統合する。
- **使用箇所**: DESIGN.md §3・§4 / skills/distill/SKILL.md

### 経路判定（route）
- **定義**: 各候補が向かう共有境界（universal / project-local）を判定し、スコープ仮説タグを付与する段。Phase 1 では独立段でなく蒸留に統合されている。
- **使用箇所**: DESIGN.md §3・§4 決定事項8 / references/personal-store-spec.md
- **避ける語**: 「Route判定規則」と混同しないこと。経路判定（route）＝スコープ仮説（universal/project-local）の付与。[[Route判定規則]]＝昇格先キャリアの選択であり別概念

### 昇格（promote）
- **定義**: 蒸留が生成した候補を検証し、検証通過分を `gh` で Issue へ自動起票して既存ワークフローへ渡す第3段（Phase 1 スキル）。
- **使用箇所**: DESIGN.md §3・§4 決定事項8 / skills/promote/SKILL.md
- **避ける語**: 段・スキルとしての「昇格（promote）」と、全移送過程を指す広義の「昇格（promotion）」を区別する。広義は [[昇格（広義）]] を参照

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

### 観察（observation）
- **定義**: 捕捉が記録した「何が起きたか」の生記録。解釈・原因分析・対策を含まない事実のみ。
- **使用箇所**: references/personal-store-spec.md §2 / skills/capture/SKILL.md
- **避ける語**: 「生観察」「生記録」（観察に統一。生である性質は [[生記録性]] で表す）

### 振る舞い差分（behavior delta）
- **定義**: 「次回どう違う行動を取るか」を一文で表す実行可能な規範。ストア → 候補 → learnings.md へ受け継がれる学びの核。
- **使用箇所**: DESIGN.md 原理1 / references/learning-store-spec.md
- **避ける語**: 「行動差分」「差分」（振る舞い差分に統一）

### 規範（norm）
- **定義**: 「次回どう違う行動を取るか」を命じる learnings.md の見出し一文。テキストとして配布される最も弱いキャリア。
- **使用箇所**: references/learning-store-spec.md
- **避ける語**: 「ルール」「規則」「行動指針」（規範に統一）

### 候補（candidate）
- **定義**: 蒸留が生成した、検証待ちの振る舞い差分。`candidates.md` 内のエントリとして存在する。
- **使用箇所**: references/personal-store-spec.md / skills/distill/references/distill-procedure.md
- **避ける語**: 「蒸留候補」「検証候補」「Issue候補」（用途修飾を付けず候補に統一）

### 生捕捉ストア（captures.md）
- **定義**: 個人ローカルに置かれる未検証の生捕捉ファイル。パス `~/.claude/projects/<project-id>/growth/captures.md`。捕捉の書き込み先・蒸留の入力源。
- **使用箇所**: references/personal-store-spec.md
- **避ける語**: 「store」「生捕捉置き場」（文脈で曖昧なときは captures.md と明示）

### 候補ファイル（candidates.md）
- **定義**: 蒸留の出力先・昇格の入力源。個人ローカルの第3の成果物（生捕捉ストアでも learnings.md でもない）。
- **使用箇所**: references/personal-store-spec.md
- **避ける語**: 「候補置き場」（candidates.md と明示）

### 学び置き場（learnings.md）
- **定義**: 検証済みの汎用振る舞い規範を集約した配布物。パス `plugins/growth/learnings.md`。1欄スキーマで記述する。
- **使用箇所**: references/learning-store-spec.md / DESIGN.md
- **避ける語**: 「配布物」「最終置き場」（learnings.md と明示）

---

## 3. 状態フィールドと値

### 処理状態（status）
- **定義**: 生捕捉ストアの各エントリの処理状態。値は `unprocessed`（未処理）/ `promoted`（昇格済み）の2値。昇格が起票成功後に `unprocessed → promoted` を反転する。
- **使用箇所**: references/personal-store-spec.md / skills/promote/references/promote-procedure.md

### 候補状態（candidate-status）
- **定義**: 候補ファイル内の各候補の処理状態。値は `pending`（検証待ち・既定）/ `rejected`（昇格検証で棄却）/ `promoted`（昇格済み。昇格が Issue 起票成功後に付与する任意・推奨値）の3値。
- **使用箇所**: references/personal-store-spec.md / skills/promote/references/promote-procedure.md
- **注記**: `promoted` は当初 personal-store-spec.md のスキーマ表に未記載で promote-procedure.md のみが扱う drift があった（本 PR で正典スキーマ側に任意・推奨値として追補して整合）

### 由来（provenance）
- **定義**: 候補の出自を追跡するメタフィールド。値は生捕捉ストアの `## <timestamp>` 見出し。蒸留の upsert・昇格の状態反転で同一性判定に使う。
- **使用箇所**: references/personal-store-spec.md / skills/promote/references/promote-procedure.md
- **避ける語**: 「出自キー」「由来参照」（由来 / provenance に統一）

---

## 4. スコープと配布構造

### スコープ仮説（scope-hypothesis）
- **定義**: 経路判定が候補に付与する共有範囲の仮説タグ。値は `universal`（全プロジェクト対象）/ `project-local`（チーム・プロジェクト限定）。確証せず仮説のまま終端する。
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
- **定義**: 学びを載せる配布先媒体の分類。learnings.md 行き / ADR 差分 / dev-workflow Issue / 強キャリア の4種。スコープ仮説（空間軸）とは直交する軸。
- **使用箇所**: references/promotion-issue-spec.md「Route判定規則」/ DESIGN.md
- **避ける語**: 「昇格先」「配布媒体」（キャリアに統一）
- **注記**: career の決定モデルは #405 で再設計中（promote 起票時・候補単位から、フリート集約後の「取り込み Issue」での裁定へ移行予定）。確定後に本エントリと「取り込み」関連語を追補する

### 強キャリア（strong carrier）
- **定義**: skill / hook / lint / test などコードレベルの決定論的ガードレール。「二度と起こせない構造」として learnings.md には載らず、テキスト規範からは除去される。
- **使用箇所**: references/promotion-issue-spec.md / references/learning-store-spec.md
- **避ける語**: 「構造化キャリア」「コード配布」（強キャリアに統一）

### Route判定規則（route decision table）
- **定義**: 候補の性質（キャリア変換可能性・適用範囲）を入力に、4つの昇格先キャリアを一意に出力する順序付き決定表。
- **使用箇所**: references/promotion-issue-spec.md「Route判定規則」
- **避ける語**: [[経路判定（route）]]（スコープ仮説付与）と混同しない。こちらはキャリア選択

---

## 6. 検証と整理

### 検証（verification）
- **定義**: 昇格が各候補について行う、予測（効く場面）と反証条件（いつ反例が立つか）の両立可能性の評価。起票前のゲート。
- **使用箇所**: skills/promote/references/promote-procedure.md §3 / DESIGN.md 原理2
- **避ける語**: 「昇格ゲート」を検証の意味で使わない。起票前ゲート＝検証、起票後ゲート＝[[二段ゲート]]の L2（refine/DoR/PR）

### 反証可能性（falsifiability）
- **定義**: 検証で求める候補の必須性質。「この条件で反例が作られうる」という明確な反証経路が存在すること。
- **使用箇所**: skills/promote/references/promote-procedure.md §3

### 二段ゲート（two-gate system）
- **定義**: growth の承認構造。保存（自動）→ 仕組み化（承認 or マルチエージェントレビュー）の2段。捕捉・ストアは自動、PR マージで仕組み化を承認。
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
- **定義**: 学びがストア → 候補 → Issue → learnings.md へ段階的に移送される過程全体。段・スキルとしての [[昇格（promote）]] より広い。
- **使用箇所**: DESIGN.md §3
- **避ける語**: 文中で「昇格」が段（promote）と過程（promotion）のどちらを指すか曖昧なときは明示する

### 予測誤差（prediction error）
- **定義**: 捕捉の探知対象。「驚き」の源泉。訂正・ツール拒否・反復試行・期待違反・客観痕跡の5シグナル種別で表現される。
- **使用箇所**: DESIGN.md §3 / skills/capture/SKILL.md
- **避ける語**: 「驚き」は説明語として可。シグナルの種別値は [[シグナル（signal）]]

### シグナル（signal）
- **定義**: 予測誤差の種別値。訂正 / ツール拒否 / 反復試行 / 期待違反 / 客観痕跡 の5値。
- **使用箇所**: references/personal-store-spec.md / skills/capture/SKILL.md

### フリート学習（fleet learning）
- **定義**: 単一ユーザーの N セッションより、M ユーザーの集合ログの方が学びが豊かという学習戦略。Phase 3 で横断解析として実装予定。
- **使用箇所**: DESIGN.md 原理6

---

## 未収録（継続拡充候補）

初版では中核と英語ジャーゴン・表記揺れを優先した。以下は #409 の保守機構で順次定義する長い裾の用語（一部）:

universal / project-local（スコープ仮説の値・個別エントリ化）、パブリック／グローバル空間、閉じた空間、origin 面 / consumer 面、客観痕跡、生記録性、confabulation（作話）、仮説、記法ルール、1欄スキーマ、メタ欄、upsert、冪等性、一般化、抽出、見出し圧縮、疎結合、compaction（Claude Code 機能）、自発トリガー、横断解析、in-repo dogfooding、project-id、仮説検証ループ

#405 確定後に追補: 取り込み（intake）、取り込み Issue、career 4キャリアの各個別エントリ
