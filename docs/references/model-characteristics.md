# Claude モデル特性とモデル振り分け指針

スキル・サブエージェント設計時に「どのモデルにどの作業を割り当てるか」を判断するための参照ドキュメント。

- 作成日: 2026-07-22（全情報は同日に一次情報で確認。モデルラインナップ・価格は変動するため、参照時は鮮度に注意）
- 出典: 文末の出典一覧を参照。公式情報と推論は本文中で区別して明記する

## 1. 現行モデルの基本情報

| モデル | モデルID | 位置付け（公式） | 価格 入力/出力（per MTok） | コンテキスト長 | 最大出力 | 速度 | 知識カットオフ |
|---|---|---|---|---|---|---|---|
| Claude Fable 5 | `claude-fable-5` | 長時間稼働エージェント向けの次世代知能 | $10 / $50 | 1M | 128K | 最も遅い | 2026年1月 |
| Claude Opus 4.8 | `claude-opus-4-8` | 複雑なエージェント型コーディング・エンタープライズ業務 | $5 / $25 | 1M | 128K | 中程度 | 2026年1月 |
| Claude Sonnet 5 | `claude-sonnet-5` | 速度と知能の最良の組み合わせ | $3 / $15（2026-08-31まで導入価格 $2 / $10） | 1M | 128K | 速い | 2026年1月 |
| Claude Haiku 4.5 | `claude-haiku-4-5` | フロンティア級知能に迫る最速モデル | $1 / $5 | 200K | 64K | 最速 | 2025年2月 |

補足（公式確認済み）:

- 出力単価の相対比は Haiku : Sonnet : Opus : Fable = 1 : 3 : 5 : 10。
- Claude Mythos 5 は Fable 5 と同一スペック・同一価格の招待制限定モデル（一般利用は Fable 5）。
- Fable 5 は安全性分類器の発火時に Opus へ自動フォールバックする（セッションの5%未満、以降そのセッションは Opus 継続）。
- Haiku 4.5 のみコンテキスト長 200K・最大出力 64K と他モデルより狭く、知識カットオフも約1年古い。

## 2. 各モデルの強み・弱み（公式claimの要約）

- **Fable 5**: 曖昧な問題（サブトルなバグ、未知のドメイン、アーキテクチャ判断）に強い。結果を指示すれば経路を自分で計画し、検証も自発的に行う。大きめのタスクを分割せず渡せる。弱みは速度とコスト、およびデフォルトモデルでないこと（`/model fable` で明示選択）。
- **Opus 4.8**: 長時間自律実行・ナレッジワークに強い最上位 Opus。fast mode（最大2.5倍高速・高コスト、品質同一）に対応する唯一の現行モデル。Fable 5 のコスト・速度面の代替。
- **Sonnet 5**: 「正確に記述できる編集、機械的な変更、既にコンテキストにあるコードへの質問」に適する（公式ブログ）。日常コーディングの既定モデル。
- **Haiku 4.5**: 「能力要件が控えめな素直な作業」に適する（公式ブログ）。公式ドキュメントは探索系サブエージェントの低コスト化例として `model: haiku` を明示している。

## 3. Claude Code での利用形態

### サブエージェントの model フィールド

`agents/*.md` frontmatter の `model` に指定できる値は `sonnet` / `opus` / `haiku` / `fable` / フルモデルID / `inherit`（未指定時のデフォルトは `inherit` = 親セッションと同一モデル）。

モデル解決の優先順位（高い順）:

1. `CLAUDE_CODE_SUBAGENT_MODEL` 環境変数
2. Agent tool 呼び出し時の `model` パラメータ
3. サブエージェント定義（frontmatter）の `model`
4. メイン会話のモデル

### effort フィールド

frontmatter の `effort`（`low`〜`max`、モデル依存）でそのサブエージェント実行中のみ effort を上書きできる。未指定時はセッション継承のため、検証系エージェントの厳密さが親セッションの設定に依存する点に注意（`effort: high` の明示で固定できる）。

### fast mode

Opus 4.8/4.7 限定のリサーチプレビュー。「同一品質・低レイテンシ・高コスト」であり、モデル選択や effort の代替ではない。Opus 4.7 の fast mode は 2026-07-24 に削除予定。

## 4. 作業種別ごとの振り分け指針

公式に確認できる大枠は「Sonnet=機械的な編集・既存コンテキストへの質問」「Haiku=素直な作業」「Fable/Opus=曖昧な問題・アーキテクチャ判断」の3区分のみ。以下の詳細割当はこの大枠とモデル特性からの**推論**であり、公式の網羅的マッピングではない。

| 作業種別 | 推奨モデル | 出典区分 |
|---|---|---|
| 機械的編集（typo・フォーマット・置換） | Haiku 4.5 | 公式+推論 |
| grep・ファイル探索・位置特定 | Haiku 4.5 | 公式（sub-agents ドキュメントの明示例） |
| 要約（既存コンテキスト内） | Haiku 4.5 または Sonnet 5 | 公式+推論 |
| 浅い調査・DoR突合等の定型精査 | Sonnet 5 | 推論 |
| 深い調査（未知ドメイン・根本原因） | Fable 5（コスト重視なら Opus 4.8） | 公式（ブログ） |
| 通常の実装 | Sonnet 5 | 公式（ブログ） |
| サブトルなバグ・複雑なリファクタ | Fable 5 / Opus 4.8 | 公式（ブログ） |
| レビュー（軽微な差分） | Sonnet 5 | 推論 |
| レビュー（大規模・懐疑的検証） | Opus 4.8（最重要箇所は Fable 5） | 一部公式+推論 |
| 設計・アーキテクチャ判断 | Fable 5（代替 Opus 4.8） | 公式（ブログ） |
| オーケストレーション（多エージェント統括） | Opus 4.8 / Fable 5（判断が軽ければ Sonnet 5） | 公式+推論 |

コスト効率の考え方:

- 単価だけでなく試行錯誤の回数を加味する。Fable は複雑な多段階問題でステップ数が少なく済むため、タスク総コストでは安くなり得る（公式ブログ）。
- effort はモデル選択と独立のレバー（例: Sonnet 5 + `low` でさらに安く、Opus 4.8 + `xhigh` で精度域を上げる）。

## 5. 本リポジトリでの適用状況（2026-07-22 時点）

`plugins/dev-workflow/agents/*.md` の現行 model 設定は Issue #317 の実機並行評価（Opus版/Sonnet版の比較）に基づく:

| エージェント | model | 経験的裏付け |
|---|---|---|
| code-reviewer / test-designer | opus | Sonnet版で実バグ見逃しを実測、降格不可判定（#317） |
| plan-reviewer / test-spec-validator | opus | 「重要」指摘の見落としを実測、降格不可判定（#317） |
| refactorer | sonnet | 3種コーパスで振る舞い不変を実測（#317） |
| plan | opus | #317 評価対象外。裏付けなし（将来の評価候補） |

この実測結果は §4 の推論的指針（レビュー・検証系→Opus、機械的変換→Sonnet）と整合している。model 設定を変更する際は `docs/dogfood/317-evaluation-methodology.md` の手法で再評価し、`plugin.json` の version を上げること。

## 出典

- https://platform.claude.com/docs/en/about-claude/models/overview （モデル一覧・価格・コンテキスト長）
- https://www.anthropic.com/news/claude-fable-5-mythos-5 （Fable 5 / Mythos 5 発表）
- https://code.claude.com/docs/en/sub-agents （model/effort フィールド仕様・解決順序）
- https://code.claude.com/docs/en/model-config （エイリアス・フォールバック・effort）
- https://code.claude.com/docs/en/fast-mode （fast mode 仕様）
- https://claude.com/blog/claude-model-and-effort-level-in-claude-code （作業種別との対応付けの主要根拠）
