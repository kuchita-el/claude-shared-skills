---
name: implementation
description: "Issue/planをTDD実装しレビュー・CI・PRを結審する。コード変更を伴う実装時に使用し、未解決項目を残して完了報告しない。"
allowed-tools:
  # コード読解・編集
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  # git操作
  - Bash(git status*)
  - Bash(git diff*)
  - Bash(git add *)
  - Bash(git commit *)
  - Bash(git log*)
  - Bash(git checkout *)
  - Bash(git switch *)
  - Bash(git fetch *)
  - Bash(git branch*)
  - Bash(git push*)
  - Bash(git restore*)
  - Bash(git worktree list*)
  # GitHub操作
  - Bash(gh issue view *)
  - Bash(gh issue comment *)
  - Bash(gh pr create *)
  - Bash(gh pr view *)
  - Bash(gh pr edit *)
  - Bash(gh pr comment *)
  - Bash(gh pr ready *)
  - Bash(gh pr checks *)
  - Bash(gh api repos/*/pulls/*/comments*)
  - Bash(gh run view *)
  # 委譲・対話
  - Skill
  - Agent
  - AskUserQuestion
---

# 汎用実装

完了契約はAC、review、CI、PRの全項目を `resolved|unresolved|blocked|unknown` で列挙し、1件でも `unresolved`、`blocked`、`unknown` があれば完了報告しない。superpowersやwritingが利用できないhostでは、既存本文の最小inline手順へ縮退するが、agent起動fallbackとは区別して記録する。

Issue・計画ファイル・PRレビュー指摘・会話コンテキストを起点に、実装→セルフレビュー→修正→PR作成までを一貫して実行する。

**出力と範囲の規律**: 出力・成果物の分量と作業範囲は `${CLAUDE_PLUGIN_ROOT}/references/behavior-invariants.md` の不変条件に従う。
計画ファイルの解決規約は `${CLAUDE_PLUGIN_ROOT}/references/plan-location-resolution.md` を直接参照する。

## 引数

- `$ARGUMENTS`: Issue番号/URL、計画ファイルパス、PR番号/URL、または省略（会話コンテキストを使用）

## ワークフロー

```
Phase 0: インプットの理解（再開検知・エスカレーション履歴確認・worktree隔離・パス判定・レビュー契約導出）
Phase 1: 実装/検証（superpowers委譲: S3実装起動 / S4 TDD / S5検証ゲート → コミット）
Phase 2: セルフレビュー（superpowers委譲: S7 requesting-code-review、結果のワークフロー反映は接続契約）
Phase 3: 判定 → ブロッカーなし→Phase 4（Phase 5起点ならPhase 5後半）/ ブロッカーあり→Phase 1（収束しなければエスカレーション）
Phase 4: PR作成（Draft）→ CIゲート → Ready化＋レビュー依頼 + 完了報告（S6 finishing-a-development-branch 委譲 ＋ dev-workflow上乗せのCIゲート ＋ セルフレビューサマリ）
Phase 5: レビュー指摘への対応サイクル（S8 receiving-code-review 委譲: 受理判定 → 深刻度調整 → 修正はPhase 1〜3へ → CIゲート再走行 → スレッド返信）

※ S3〜S8 は委譲先シームの識別子（番号順＝実行順ではない）
※ Phase 5 は Phase 4 の後続ではなく、Phase 0 の種別判定「PRレビュー指摘」から分岐して前半が走り、Phase 1〜3 を挟んで後半が走る（再入構造）
※ superpowers 非導入時は各委譲が最小インラインへ縮退（「フォールバック分岐」節）。収束不能時はエスカレーション機構へ
```

### Phase 0: インプットの理解

引数と会話コンテキストからインプット種別を自動判定する:

| 種別 | 判定条件 | 読み込み方法 |
|---|---|---|
| Issue | `#数字`、Issue URL、数字のみ | `gh issue view` |
| 計画ファイル | ファイルパス（`.md` 等） | `Read` |
| PRレビュー指摘 | PR番号/URL or 現在のブランチにPRが存在 | `gh pr view` + 会話コンテキスト。作業リスト導出の前に **Phase 5**（後述）の受理判定を通す |
| 会話コンテキスト | 上記いずれにも該当しない | 直前の会話から要件・指摘を抽出 |

読み込んだ内容から以下を順に確認・判定する:

1. **エスカレーション履歴の確認**（`<!-- implementation:escalation -->` マーカー検索。未回答があれば報告して終了。探索先は投稿先と揃える: Issue起点は Issue コメント、PRレビュー指摘起点は PR コメント）
2. **実行環境の検知**（worktree環境 / 別セッション再開の判別）
3. **ブランチの準備**（新規作業時のみ。新ブランチは `origin/<base>` の最新を起点に切る。経路別の責務の所在・委譲先の基点セマンティクス・base がデフォルトブランチと異なる場合の限界は `phase0-input-detection.md` を参照）
4. **正規パス/簡易パスの判定**（計画ファイルに検証すべき振る舞いが具体的に定義されているかで分岐。PRレビュー指摘・会話コンテキストは常に簡易パス）
5. **作業リストとレビュー契約の作成**（正規パス: 計画タスク分解＋検証方針を契約へ／簡易パス: 受け入れ条件 or 作業項目を契約へ）

各小手順の詳細手順・判定テーブル・契約導出ロジックは `${CLAUDE_SKILL_DIR}/references/phase0-input-detection.md` を参照。仕様に曖昧さや設計判断が必要な箇所があればエスカレーション機構（後述）へ。

### Phase 1: 実装/検証

実装メカニクス（実装起動・TDD・検証ゲート・リファクタリング）は superpowers スキルへ委譲する（参照機構②: メインループから `Skill` ツールで呼ぶ）。implementation が自前で保持するのは、Phase 0 で導出した作業リスト・レビュー契約という接続契約のみ。

委譲先スキルは `Skill` ツール経由で fully-qualified 形式 `superpowers:<スキル名>` で呼ぶ。superpowers 非導入時の縮退挙動は「フォールバック分岐」節を参照。

#### 実装の起動（S3）

- **正規パス（計画ファイルあり）**: 計画のタスク分解を `superpowers:subagent-driven-development`（現セッション完結、1 Issue→1 PR）に委譲する。サブエージェントが使えない環境では `superpowers:executing-plans` にフォールバック。
- **簡易パス（計画なし）**: 作業リストの各項目を TDD 委譲（S4）で直接消化する。

#### TDD（S4）

実装は `superpowers:test-driven-development` に委譲する（参照機構②）。Red-Green-Refactor の規律で作業リスト／計画の各振る舞いをテストで駆動する。ドキュメントのみの変更・typo 修正等、テストが本質的に不要な作業は TDD 委譲を行わず直接修正する。

#### 検証ゲート（S5）

セルフレビューの前に `superpowers:verification-before-completion` に委譲する（参照機構②）。型チェック・lint・テストの結果（証拠）を確認してから完了を主張する。検証コマンド未許可時はスキップしてよい。

#### コミット

検証を通過した変更を、対象ファイルのみステージング（`git add -A` は使わない）して意味のある単位でコミットする。テストコードと対応する実装コードは同じコミットに含める。コミットスタイルはプロジェクトの既存コミットや `CLAUDE.md` の規約に合わせる。

Phase 1 内でエスカレーション（後述）が発動する場合は、エスカレーション手順の後に WIP コミット（`WIP: {作業内容の要約}`）を行ってセッションを終了する（次セッションで作業継続できるようにするため）。

### Phase 2: セルフレビュー

人間のレビュアーに渡す前に差分をセルフレビューして品質を高めるフェーズ（本スキルの主要な付加価値であり、スキップしない）。レビューの**実行**は `superpowers:requesting-code-review` に委譲し（参照機構②）、レビュー結果の**ワークフロー反映**は dev-workflow 側の接続契約として保持する。

接続契約として保持する入出力:

- **入力**: Phase 0 で導出したレビュー契約（完了チェックリスト）と、差分取得用のベースブランチ名・要件情報をレビューに渡す。
- **深刻度調整**: レビュー結果を `${CLAUDE_SKILL_DIR}/references/review-severity-adjustment.md` のルールに従い周辺コード文脈で再評価し、ブロッカー/改善提案の2段で確定する。元の指摘内容は除外・改変しない（詳細運用は参照先）。
- **出力の反映**: 深刻度調整後のレビュー結果（ブロッカー／改善提案）を Phase 3 の判定へ引き渡す。
- **エスカレーション**: 仕様の曖昧さで判断できない指摘はエスカレーションへ。深刻度調整は判断可能な指摘にのみ適用し、曖昧指摘はそのままエスカレーション（適用順序: 深刻度調整→曖昧指摘判定）。

非導入時は最小インライン（メインループ自身による差分セルフレビュー）へ縮退する（「フォールバック分岐」節）。深刻度調整は委譲の有無に関わらず接続契約として常に適用する。

### Phase 3: 判定

レビュー結果の**ブロッカーの有無**で判定する。改善提案のみの場合は修正ループに戻さない。

- **ブロッカーなし**（指摘なし、または改善提案のみ） → Phase 4 へ（**Phase 5 起点の場合のみ復帰先が異なる**。Phase 5 節を参照）
- **ブロッカーあり** → ブロッカーの指摘を作業リストとして Phase 1（実装）に戻す

implementation は自前の周回統治（リトライ回数・振動検知等）を持たない。反復の制御は委譲先 superpowers のオーケストレーションに委ね、implementation はブロッカー判定→修正／エスカレーションの分岐という接続契約のみを保持する。反復しても収束しない場合（同じ失敗・同じ指摘が解消しない）は、**エスカレーション機構**（後述）へ。「収束しないときは人間に渡す」原則は superpowers の有無に関わらず適用する。

エスカレーション時は `${CLAUDE_SKILL_DIR}/references/escalation-template.md` の「収束失敗」セクションに沿って「収束しなかった理由」「未解消ブロッカー一覧」「人間判断の選択肢」を記載する。投稿後、WIP コミット（`WIP: {作業内容の要約}`、Phase 1 参照）を行ってブランチに残し、次セッションでの再開・破棄判断を人間に委ねる。未解消ブロッカーを抱えた PR はレビュアーに渡さない。

改善提案は Phase 4 の PR 本文に記載し、人間のレビュアーに判断を委ねる。

### Phase 4: PR作成（Draft → CIゲート → Ready）+ 完了報告

**完了報告前のプランAC確認**: PR 作成前に、プランファイルまたは Issue のAC全項目が resolved であることを `${CLAUDE_PLUGIN_ROOT}/references/completion-judgment.md` の原則（loop 層・プランAC軸）に従い1件ずつ確認する。未解決のACが残る場合は Phase 1 に戻すかエスカレーションする。

プランに「テストケース対応表」がある場合、対応表に記載された各テストケースと実際に実装したテスト仕様の整合を確認し、不一致（計画した観点の実装漏れ・AC の意図との乖離）があればブロッカーまたは判断依頼として報告する。

ブランチの完了（PR 作成／マージ／クリーンアップの選択提示）は `superpowers:finishing-a-development-branch` に委譲する（S6・参照機構②）。ただし PR は **既定で Draft 作成**し、その後 dev-workflow 固有の上乗せ層として **CI ゲート**を実行する: まず**猶予付き再ポーリング**で required check の有無を判定し（run 登録ラグを考慮し、猶予窓を通じ不在なら **CI 未設定と確定して即 Ready 化**）、存在すれば `gh pr checks <pr> --watch --required` を `run_in_background` で回して結審を待ち、**緑 → Ready 化＋レビュー依頼 ／ 赤（exit 1）→ Phase 1〜3 修正ループへ差し戻し ／ 判定不能（その他非0）→ 再試行/判断依頼 ／ 収束不能 → エスカレーション** へ分岐する。Draft ＝ CI 未検証、Ready ＝ CI 緑という**コンテンツ状態に基づく判断**であり、feedback「Draft/Ready はコンテンツ状態で判断（一律 Draft 禁止）」と矛盾しない。責務分界（draft 作成不可時の `gh pr create --draft` フォールバック含む）・分岐表・採用方式の根拠・レビュー依頼ルールは `${CLAUDE_SKILL_DIR}/references/phase4-ci-gate.md` を参照。

接続契約として、PR 本文に以下のセルフレビュー結果サマリを含める（委譲先の出力に上乗せ）:

- `## 対応 Issue AC`（プランの「分割の文脈」由来の対応ACリスト、またはIssue全AC。詳細は `${CLAUDE_SKILL_DIR}/references/pr-body-template.md` 参照）
- `## セルフレビュー実施済み`（周回数・修正ブロッカー数）
- `### 修正した指摘`（重大度・指摘・対応内容・コミットの4列テーブル）
- `### 深刻度調整（誤検知格下げ）`（格下げがある場合のみ。Phase 2 の調整出力を人間レビュアー向けに要約。格下げがなければ省略）
- `改善提案（未対応）` セクション（純粋な改善提案を記載、人間レビュアーへ判断委譲）

詳細は `${CLAUDE_SKILL_DIR}/references/pr-body-template.md` を参照（PR 本文テンプレート全文、および「深刻度調整セクション」と `review-severity-adjustment.md` ブロック形式との役割分担を含む）。

### Phase 5: レビュー指摘への対応サイクル（受理判定 → 修正 → スレッド返信）

インプット種別が「PRレビュー指摘」のときに走る、指摘の受理から返信までのサイクル。受理判定を **S8** として `superpowers:receiving-code-review` に委譲する（参照機構②）。前半（指摘の取得 → 受理判定 → 深刻度調整 → 作業リスト化）と後半（修正コミット & push → スレッド返信）に分かれる。

**制御フロー（再入構造）**: Phase 5 は Phase 4 の線形な後続ではなく、前半と後半の間に Phase 1〜3 を挟む。

- **入口**: Phase 0 でインプット種別が「PRレビュー指摘」と判定されたら、Phase 1 の作業リスト消化へ直行せず Phase 5 前半へ入る。
- **前半の出口**: 深刻度調整でブロッカーと確定した指摘のみを作業リストへ載せ Phase 1 へ渡す。ブロッカーが0件の場合は Phase 1 を経由せず直接後半へ進み、修正コミットが無いため後半の CI ゲート再走行も行わない。確認が要る指摘が残る場合は、ブロッカーが同時に確定していても修正せずエスカレーションへ進む（部分実装して残りを後で聞かない）。
- **後半への復帰**: Phase 3 の「ブロッカーなし」判定は、Phase 5 起点の場合に限り Phase 4 ではなく **Phase 5 後半**へ抜ける。PR は既に存在するため S6（`finishing-a-development-branch` による PR 作成）へは再入しない。Phase 3 節の既存記述（ブロッカーなし → Phase 4）は Phase 5 起点でない場合の既定として残り、本項はその上に加わる分岐である。
- **後半の CI ゲート**: 修正コミットを push した後、スレッド返信へ進む前に Phase 4 の CI ゲートを再走行する。射程は `${CLAUDE_SKILL_DIR}/references/phase4-ci-gate.md` の 2.（猶予付き再ポーリング）〜4.（exit code 分岐）で、5.（Ready 化・レビュー依頼）と S6 へは再入しない。Phase 4 と行き先が変わるのは緑のときだけで、緑はスレッド返信へ抜ける（赤→差し戻し／判定不能→再試行・判断依頼／収束不能→エスカレーションは Phase 4 と同一）。

接続契約として、**深刻度調整は指摘の出どころによらず一律に適用する**（`${CLAUDE_SKILL_DIR}/references/review-severity-adjustment.md`）。ただし外部指摘を格下げした場合は格下げの理由を当該指摘のスレッドへ返信し、解決とみなすかどうかの判断を投稿者に残す（自分のセルフレビューが生成した指摘には返信義務が無い）。

詳細手順（指摘の取得コマンド・委譲の入出力・4遷移・返信の投稿手段・エスカレーション接続）は `${CLAUDE_SKILL_DIR}/references/phase5-review-cycle.md` を参照。

## エスカレーション機構

自律的に判断できない場面（仕様の曖昧さ、収束しない反復＝同じ失敗・同じ指摘が解消しない、レビューで判断できない指摘）で、質問を投稿してセッションを終了する仕組み。対話セッション中は `AskUserQuestion` で即時確認し、非対話時（自動実行等）は以下のルールで投稿先を決定する:

| インプット種別 | 投稿先 |
|---|---|
| Issue起点 | Issueコメント（`gh issue comment`） |
| PRレビュー指摘起点 | PRコメント（`gh pr comment`） |
| 会話コンテキスト起点（Issue/PRなし） | WIPコミットして終了（投稿先がないため） |

`${CLAUDE_SKILL_DIR}/references/escalation-template.md` のテンプレートに沿ってコメントを作成し、投稿してセッションを終了する。

## フォールバック分岐（superpowers 非導入時）

superpowers はソフト依存である（ADR-202606062346-01 方針C）。未導入の環境では各委譲（S3〜S8・worktree）の `Skill` 呼び出しは skip され、**最小インライン**へ縮退する:

- **実装の起動・TDD（S3・S4）**: メインループ自身が基本 TDD（失敗するテストを先に書く→最小実装→リファクタリング）で作業リストを消化する。
- **検証ゲート（S5）**: 型チェック・lint・テストを実行し、証拠を確認してから完了とする（コマンド未許可ならスキップ）。
- **セルフレビュー（S7）**: メインループ自身がレビュー契約と差分を突き合わせる（深刻度2段は `agents/code-reviewer.md` に準拠、深刻度調整も同様に適用）。
- **PR化（S6）**: PR 未作成なら `gh pr create --draft` で Draft 作成 → 猶予付き再ポーリングで checks 有無を判定（不在なら即 `gh pr ready`）→ 存在すれば `gh pr checks <pr> --watch --required` を `run_in_background` で待機し exit 0 なら `gh pr ready`＋レビュー依頼／exit 1 なら修正ループへ差し戻し。既存 PR なら変更を push する。委譲が縮退しても Draft → CIゲート → Ready の骨格は保持する（詳細は `${CLAUDE_SKILL_DIR}/references/phase4-ci-gate.md`）。
- **受理判定（S8）**: メインループ自身が指摘の技術的妥当性をコード本体で確認し、不明点があれば止める。深刻度調整とスレッド返信は接続契約として保持し、無検証のまま作業リストへ変換しない。
- **worktree**: Phase 0「ブランチの準備」の通常のブランチ作成手順にフォールバックする。

縮退するのは実装メカニクスの精緻さのみ。接続契約（レビュー契約・Issueエスカレーション・判断依頼）と「収束しないときは人間にエスカレーションする」原則は superpowers の有無に関わらず常に保持する。

## 注意事項

- **型チェック・テスト・lintコマンドの実行許可**: プロジェクト固有のため `allowed-tools` に含めず、`settings.json` の `allowedTools` で個別許可する（例: `Bash(npx tsc*)`, `Bash(npm test*)`）
- **複数行コンテンツの受け渡し**: HEREDOC を使わず、Write で一時ファイルに書き出して `--body-file` で渡すか `-m` を複数回指定する
  - `gh api` は `--body-file` を持たないため `-F body=@{ファイル名}` でファイルから読ませる（`-F` でパラメータを付けるとメソッドは POST へ自動切替されるため `--method POST` は書かない）
- **pushの失敗**: 権限不足・保護ブランチ等で `git push` 失敗時はユーザーに状況を報告し手動pushを依頼する
