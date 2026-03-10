# Claude Code スキル・サブエージェント・プラグイン設計ガイド

**作成日:** 2026-03-10
**目的:** Claude Codeの拡張機構（スキル・サブエージェント・プラグイン）の概念整理と設計指針

---

## 概要

Claude Codeには3つの拡張機構がある。それぞれの役割と関係性を理解することで、適切な設計判断ができる。

```
Plugin（配布パッケージ）
├── skills/        ← スキル（知識・手順の注入）
├── agents/        ← サブエージェント（独立した実行コンテキスト）
├── hooks/         ← フック（イベント駆動の自動処理）
├── commands/      ← スラッシュコマンド（スキルの旧形式、互換あり）
├── .mcp.json      ← MCP サーバー（外部ツール連携）
└── .claude-plugin/plugin.json  ← マニフェスト
```

- **プラグイン**: 配布・共有の単位
- **スキル**・**サブエージェント**: 機能の単位

---

## スキル（Skill）

### 概念

Claudeに「特定タスクの遂行方法」を教える再利用可能な指示書。

人間で例えると「業務マニュアル」。Claudeは必要なときにそのマニュアルを参照し、記載された手順に従って作業する。

### SKILL.md の構造

```yaml
---
name: my-skill
description: スキルの説明と、いつ使うべきかの条件
disable-model-invocation: true  # ユーザーのみ発動可
allowed-tools: Read, Grep       # 使用可能なツールを制限
context: fork                   # サブエージェントで実行
agent: Explore                  # context: fork時のエージェントタイプ
---

スキルの本文（Claudeへの指示）
```

### プログレッシブ・ローディング

スキルは常にコンテキストを消費するのではなく、必要なときだけ段階的に読み込まれる。

| レベル | 何が読まれるか | いつ読まれるか | トークンコスト |
|--------|-------------|-------------|-------------|
| L1: メタデータ | `name` と `description` | セッション開始時（常時） | ~100トークン/スキル |
| L2: 指示本文 | SKILL.md本文 | スキル発動時 | ~5,000トークン以下推奨 |
| L3: リソース | 補助ファイル・スクリプト | 必要に応じて | 事実上無制限 |

### 2種類のコンテンツ設計

**リファレンス型**: コーディング規約やAPIパターンなど、Claudeが判断して適用する「知識」。メイン会話内で実行される（インライン）。

```yaml
---
name: api-conventions
description: API設計パターン
---

APIエンドポイント作成時のルール:
- RESTful命名規約
- 統一エラーフォーマット
- リクエストバリデーション
```

**タスク型**: デプロイ手順やコミット手順など、ステップバイステップの「行動指示」。副作用があるため `disable-model-invocation: true` でユーザーのみ発動にすることが多い。

```yaml
---
name: deploy
description: 本番環境へのデプロイ
context: fork
disable-model-invocation: true
---

1. テストスイートを実行
2. アプリケーションをビルド
3. デプロイターゲットへプッシュ
```

### 呼び出し制御

| 設定 | ユーザー | Claude | ユースケース |
|---|---|---|---|
| デフォルト | 可 | 可 | 汎用スキル |
| `disable-model-invocation: true` | 可 | 不可 | デプロイ・コミット等の副作用あり操作 |
| `user-invocable: false` | 不可 | 可 | 背景知識・規約（ユーザーが直接呼ぶ意味がない） |

### ディレクトリ構成

```
my-skill/
├── SKILL.md           # メイン指示（必須、500行以内推奨）
├── reference.md       # 詳細リファレンス（必要時にのみ読み込み）
├── examples.md        # 使用例
└── scripts/
    └── helper.sh      # Claudeが実行するスクリプト
```

SKILL.mdから補助ファイルへリンクすることで、Claudeが必要に応じて参照できる。

### 配置場所と優先順位

| 場所 | パス | 適用範囲 | 優先度 |
|---|---|---|---|
| Enterprise | マネージド設定 | 組織全体 | 最高 |
| Personal | `~/.claude/skills/<name>/SKILL.md` | 全プロジェクト | 高 |
| Project | `.claude/skills/<name>/SKILL.md` | 該当プロジェクトのみ | 中 |
| Plugin | `<plugin>/skills/<name>/SKILL.md` | プラグイン有効時 | 低 |

同名スキルは優先度の高い場所が勝つ。プラグインスキルは`plugin-name:skill-name`のネームスペースを持つため衝突しない。

---

## サブエージェント（Subagent）

### 概念

独立したコンテキストウィンドウで動作する特化型のAIアシスタント。

人間で例えると「専門チームへの業務委任」。メインの会話から切り離されて作業し、結果のサマリーだけを返す。

### サブエージェントの利点

- **コンテキスト保全**: 大量の出力（テスト結果等）をメイン会話から隔離
- **制約の強制**: ツールアクセスを制限して安全に実行
- **専門化**: フォーカスしたシステムプロンプトで特定ドメインに特化
- **コスト制御**: 軽量タスクをHaikuなど高速モデルに振り分け

### 定義方法

```yaml
---
name: code-reviewer
description: コード品質・セキュリティのレビュー。コード変更後にプロアクティブに使用。
tools: Read, Grep, Glob, Bash
model: sonnet
memory: user
---

あなたはシニアコードレビュアーです。
呼び出されたら:
1. git diffで最近の変更を確認
2. 変更されたファイルに集中
3. レビューを開始
```

### 主要フロントマター

| フィールド | 必須 | 説明 |
|---|---|---|
| `name` | はい | 一意の識別子（小文字・ハイフン） |
| `description` | はい | いつ委任すべきかの説明 |
| `tools` | いいえ | 使用許可ツール（省略時は全ツール継承） |
| `disallowedTools` | いいえ | 使用禁止ツール |
| `model` | いいえ | `haiku`, `sonnet`, `opus`, `inherit`（デフォルト: `inherit`） |
| `permissionMode` | いいえ | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `maxTurns` | いいえ | 最大エージェンティックターン数 |
| `skills` | いいえ | 起動時にプリロードするスキル名のリスト |
| `memory` | いいえ | 永続メモリスコープ: `user`, `project`, `local` |
| `background` | いいえ | `true`でバックグラウンド実行 |
| `isolation` | いいえ | `worktree`でgit worktreeに隔離 |
| `hooks` | いいえ | エージェント固有のライフサイクルフック |

### ビルトインサブエージェント

| エージェント | モデル | 用途 |
|---|---|---|
| **Explore** | Haiku | 読み取り専用のコードベース探索・検索 |
| **Plan** | 継承 | プランモードでのコードベース調査 |
| **general-purpose** | 継承 | 複雑なマルチステップタスク |

### モデル選択の指針

| 用途 | モデル | 理由 |
|---|---|---|
| コード探索・検索 | `haiku` | 高速・低コスト |
| レビュー・分析 | `sonnet` | 速度と品質のバランス |
| 設計判断・複雑な推論 | `opus` or `inherit` | 最高品質 |

### 永続メモリ

`memory`フィールドを設定すると、セッションをまたいで学習を蓄積できる。

| スコープ | パス | 用途 |
|---|---|---|
| `user` | `~/.claude/agent-memory/<name>/` | 全プロジェクト共通（推奨デフォルト） |
| `project` | `.claude/agent-memory/<name>/` | プロジェクト固有（VCS共有可） |
| `local` | `.claude/agent-memory-local/<name>/` | プロジェクト固有（VCS共有不可） |

---

## スキルとサブエージェントの関係

### 根本的な違い

| | スキル | サブエージェント |
|---|---|---|
| **コンテキスト** | メイン会話内で実行（共有） | 独立したコンテキストで実行（分離） |
| **目的** | 「何をすべきか」の知識注入 | 「誰に任せるか」の作業委任 |
| **実体** | 指示書（SKILL.md） | 独立したClaude実行環境 |
| **メモリ** | なし | `memory`フィールドで永続記憶可能 |
| **ネスト** | 不可 | 不可（サブエージェントからサブエージェント不可） |

### 組み合わせパターン

スキルとサブエージェントはそれぞれ単体でも使えるが、組み合わせることで「知識」「手順」「実行環境」を分離して管理できる。

#### パターン0: 組み合わせなし（最も多いケース）

- **スキル単体**: メイン会話で知識注入やタスク実行（`context: fork` なし）
- **サブエージェント単体**: `skills`フィールドなしで、自身のシステムプロンプトだけで動作

組み合わせが必要になるのは、スキルの指示をメイン会話から隔離したい場合や、サブエージェントに特定のドメイン知識を確実に持たせたい場合のみ。

#### パターン1: スキル → サブエージェント（`context: fork`）

スキルの本文が「タスク指示」としてサブエージェントに渡される。

```yaml
# .claude/skills/deep-research/SKILL.md
---
name: deep-research
context: fork
agent: Explore
---

$ARGUMENTS を徹底調査:
1. 関連ファイルを検索
2. コードを分析
3. 結果をまとめる
```

```
/deep-research 認証モジュール

メイン会話:
  → Exploreエージェントを起動
  → タスク指示 = SKILL.mdの本文

Exploreエージェント（独立コンテキスト）:
  システムプロンプト = Explore固有のもの
  タスク = SKILL.mdの本文
  ツール = Exploreの制約（読み取り専用）
  → 作業実行 → サマリーを返す
```

**用途**: 定型化されたタスクを特定の実行環境で走らせたいとき。

#### パターン2: サブエージェント → スキル（`skills`フィールド）

サブエージェントの起動時に、指定したスキルの全内容がコンテキストに事前注入される。サブエージェントは通常、親会話のスキルを継承しないので、明示的に渡す必要がある。

```yaml
# .claude/agents/api-developer.md
---
name: api-developer
description: API実装を行う
skills:
  - api-conventions
  - error-handling-patterns
model: sonnet
---

APIエンドポイントを実装する。
プリロードされたスキルの規約とパターンに従うこと。
```

```
メイン会話:
  → api-developerエージェントを起動

api-developerエージェント（独立コンテキスト）:
  システムプロンプト = 「APIエンドポイントを実装する...」
  プリロード済み:
    - api-conventionsスキルの全内容
    - error-handling-patternsスキルの全内容
  → これらの知識を踏まえて作業実行
```

**用途**: サブエージェントにドメイン知識を持たせたいとき。

#### パターン1+2の合わせ技

スキル（リファレンス型）をプリロードしたカスタムエージェントを、別のスキル（タスク型）の実行環境として指定する。「知識」「手順」「実行環境」を完全に分離できる。

```yaml
# 1. 規約スキル（リファレンス型・Claudeのみ発動）
# .claude/skills/coding-standards/SKILL.md
---
name: coding-standards
user-invocable: false
---
（コーディング規約の内容）
```

```yaml
# 2. レビューエージェント（規約をプリロード）
# .claude/agents/pr-reviewer.md
---
name: pr-reviewer
description: PRレビュー専門
tools: Read, Grep, Glob, Bash
skills:
  - coding-standards
model: sonnet
---
コーディング規約に基づいてレビューする。
```

```yaml
# 3. レビュースキル（タスク定義、エージェントで実行）
# .claude/skills/review-pr/SKILL.md
---
name: review-pr
context: fork
agent: pr-reviewer
disable-model-invocation: true
---
PR #$ARGUMENTS をレビュー:
1. 変更差分を取得
2. 規約違反を確認
3. 結果をまとめる
```

実行フロー:

```
/review-pr 42
  → pr-reviewerエージェントが起動
  → coding-standardsの知識がプリロードされた状態で
  → SKILL.mdのレビュー手順に従って実行
```

#### パターンの対比

| | パターン1（スキル→エージェント） | パターン2（エージェント→スキル） |
|---|---|---|
| **主導権** | スキルがタスクを定義 | サブエージェントがタスクを定義 |
| **スキルの役割** | タスク指示そのもの | 背景知識として注入 |
| **起動方法** | `/skill-name`でユーザーが起動 | Claudeが自動委任 or ユーザーが指名 |
| **定義場所** | `.claude/skills/` | `.claude/agents/` |

### 使い分け判断表

| 状況 | 使うべきもの |
|---|---|
| コーディング規約をClaudeに覚えさせたい | スキル（リファレンス型） |
| デプロイ手順を定型化したい | スキル（タスク型, `disable-model-invocation: true`） |
| テスト実行結果の大量出力を隔離したい | サブエージェント |
| 複数の独立した調査を並列実行したい | サブエージェント（複数並列起動） |
| 読み取り専用の安全な探索を行いたい | サブエージェント（ツール制限付き） |
| ドメイン知識を特化エージェントに持たせたい | サブエージェント + `skills`フィールド |
| 定型タスクを隔離環境で実行したい | スキル + `context: fork` |
| 知識を持つエージェントで定型タスクを実行したい | パターン1+2の合わせ技 |
| チーム全体に同じワークフローを共有したい | プラグインにまとめて配布 |

---

## プラグイン（Plugin）

### 概念

スキル・エージェント・フック・MCPサーバーを1つのパッケージにまとめ、チームやコミュニティに配布する仕組み。

### ディレクトリ構成

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json        # マニフェスト（必須）
├── skills/                # スキル定義
│   └── my-skill/
│       └── SKILL.md
├── agents/                # サブエージェント定義
│   └── my-agent.md
├── hooks/                 # フック定義
│   └── hooks.json
├── commands/              # スラッシュコマンド（スキルの旧形式）
├── .mcp.json              # MCPサーバー設定
├── .lsp.json              # LSPサーバー設定
├── settings.json          # デフォルト設定
└── README.md              # ドキュメント
```

**注意**: `commands/`, `agents/`, `skills/`等はプラグインルート直下に配置する。`.claude-plugin/`の中に入れない。

### plugin.json

```json
{
  "name": "my-plugin",
  "description": "プラグインの説明",
  "version": "1.0.0",
  "author": {
    "name": "作者名"
  }
}
```

`name`がスキルのネームスペースになる（例: `/my-plugin:skill-name`）。

### スタンドアロン vs プラグイン

| | スタンドアロン（`.claude/`） | プラグイン |
|---|---|---|
| **スキル名** | `/hello` | `/plugin-name:hello` |
| **適用範囲** | 個人・プロジェクト固有 | チーム・コミュニティ共有 |
| **配布** | 手動コピー | マーケットプレイス経由 |
| **適した段階** | 試作・実験 | 安定後の共有 |

### 推奨ワークフロー

1. まず`.claude/skills/`や`.claude/agents/`でスタンドアロンとして試作
2. 安定したらプラグインに変換（`/plugin`コマンドまたは手動移行）
3. チーム内マーケットプレイスまたは公式マーケットプレイスで配布

---

## スキルのコンテンツ設計

公式のベストプラクティスに基づく、効果的なスキルコンテンツの書き方。

### 核心原則: 簡潔さ

**Claudeはすでに非常に賢い**。Claudeが既に知っていることは書かない。

書くべき情報かどうかのリトマス試験:

- 「Claudeはこの説明を本当に必要としているか？」
- 「Claudeがこれを既に知っていると仮定できるか？」
- 「この段落はトークンコストに見合うか？」

```yaml
# 良い例（約50トークン）:
## PDFテキスト抽出
pdfplumberでテキストを抽出:
# ```python
# import pdfplumber
# with pdfplumber.open("file.pdf") as pdf:
#     text = pdf.pages[0].extract_text()
# ```

# 悪い例（約150トークン）:
## PDFテキスト抽出
PDF（Portable Document Format）は、テキスト、画像、その他のコンテンツを含む
一般的なファイル形式です。PDFからテキストを抽出するには、ライブラリが必要です。
PDF処理にはpdfplumber, pypdf, PyMuPDFなど多数のライブラリがありますが...
```

### 自由度の設計

タスクの「壊れやすさ（手順を少しでも間違えると失敗するか）」と変動性に応じて、指示の具体性レベルを調整する。

**高い自由度（テキストベースの指示）**: 複数のアプローチが有効で、コンテキストに依存する場合。

```markdown
## コードレビュー
1. コード構造と組織を分析
2. 潜在的なバグやエッジケースを確認
3. 可読性と保守性の改善を提案
4. プロジェクト規約への準拠を確認
```

**中程度の自由度（擬似コードやパラメータ付きスクリプト）**: 好ましいパターンはあるが、多少の変動が許容される場合。

**低い自由度（具体的なスクリプト、パラメータなし）**: 操作が脆弱でエラーが起きやすく、一貫性が重要な場合。

```markdown
## DBマイグレーション
このスクリプトを正確に実行:
# ```bash
# python scripts/migrate.py --verify --backup
# ```
コマンドを変更したり、フラグを追加しないこと。
```

**比喩**: Claudeをロボットに見立てる。
- **崖に囲まれた狭い橋**: 安全な道は1つだけ → 具体的なガードレールと正確な指示（低い自由度）
- **危険のない広い野原**: 多くの道が成功に導く → 大まかな方向を示して信頼する（高い自由度）

### descriptionの書き方

descriptionはスキル選択の最重要フィールド。Claudeは100以上のスキルからdescriptionを見て適切なものを選ぶ。

**ルール**:
- **三人称で書く**（system promptに注入されるため、一人称・二人称は発見問題を起こす）
- **何をするか** と **いつ使うか** の両方を含める
- **具体的なキーワード**を含める

```yaml
# 良い例:
description: PRレビュー結果をGitHubにインラインコメントとして投稿する。PRレビュー完了後に使用。

# 悪い例:
description: コメントを投稿する
```

```yaml
# 良い例:
description: Extract text and tables from PDF files, fill forms, merge documents.
             Use when working with PDF files or when the user mentions PDFs, forms,
             or document extraction.

# 悪い例:
description: Helps with documents
```

### 命名規約

```yaml
# 良い例: 動名詞形（何をするか明確）
name: processing-pdfs
name: analyzing-spreadsheets

# 良い例: 名詞句
name: pdf-processing
name: spreadsheet-analysis

# 悪い例: 曖昧
name: helper
name: utils
name: tools
```

### プログレッシブ・ディスクロージャーの実践

SKILL.mdは「目次」として機能し、詳細は別ファイルに委ねる。

**パターン1: ハイレベルガイド + 参照**

```markdown
# PDF処理

## クイックスタート
pdfplumberでテキストを抽出:
（基本的なコード例）

## 高度な機能
**フォーム記入**: [FORMS.md](FORMS.md) を参照
**APIリファレンス**: [REFERENCE.md](REFERENCE.md) を参照
**使用例**: [EXAMPLES.md](EXAMPLES.md) を参照
```

**パターン2: ドメイン別の組織化**

```
bigquery-skill/
├── SKILL.md（概要とナビゲーション）
└── reference/
    ├── finance.md（売上・請求メトリクス）
    ├── sales.md（パイプラインデータ）
    └── product.md（利用状況分析）
```

ユーザーが売上について質問したとき、Claudeは`reference/finance.md`だけを読み、他のファイルはコンテキストを消費しない。

**パターン3: 条件付き詳細**

```markdown
# DOCX処理

## ドキュメント作成
docx-jsで新規作成。[DOCX-JS.md](DOCX-JS.md) を参照。

## ドキュメント編集
簡単な編集はXMLを直接変更。

**変更履歴付き編集**: [REDLINING.md](REDLINING.md) を参照
**OOXML詳細**: [OOXML.md](OOXML.md) を参照
```

### 参照の深さは1段階まで

深いネスト参照は、Claudeが`head -100`等で部分的にしか読まず、情報の欠落を招く。

```markdown
# 悪い例: 参照が深すぎる
SKILL.md → advanced.md → details.md（実際の情報はここ）

# 良い例: SKILL.mdから直接参照
SKILL.md → advanced.md
SKILL.md → reference.md
SKILL.md → examples.md
```

### 長い参照ファイルには目次を付ける

100行以上のファイルには冒頭に目次を配置。Claudeが部分読みしても全体の構造を把握できる。

```markdown
# APIリファレンス

## 目次
- 認証とセットアップ
- コアメソッド（CRUD）
- 高度な機能（バッチ操作、Webhook）
- エラーハンドリング
- コード例

## 認証とセットアップ
...
```

### ワークフローとフィードバックループ

複雑なタスクは明確なステップに分解し、チェックリストを提供する。

```markdown
## フォーム記入ワークフロー

進捗チェックリスト:
- [ ] Step 1: フォームを分析（analyze_form.py実行）
- [ ] Step 2: フィールドマッピング作成（fields.json編集）
- [ ] Step 3: マッピング検証（validate_fields.py実行）
- [ ] Step 4: フォーム記入（fill_form.py実行）
- [ ] Step 5: 出力検証（verify_output.py実行）
```

**フィードバックループ**: バリデーション → エラー修正 → 再バリデーションのパターンは品質を大幅に向上させる。

```markdown
1. 編集を実行
2. **即座にバリデーション**: `python scripts/validate.py`
3. バリデーション失敗時:
   - エラーメッセージを確認
   - 問題を修正
   - 再度バリデーション
4. **バリデーション成功後にのみ次へ進む**
```

### スクリプトとClaude Codeの連携設計

スキル配下にスクリプトを配置する場合、Claude Codeとの連携インターフェースを意識して設計する。一般的なコーディング規約（可読性・保守性等）とは別に、Claude Code固有の考慮点がある。

#### Claudeとスクリプトの接点は3つだけ

```
SKILL.md → 「このスクリプトを実行せよ」
                ↓
         scripts/analyze.py（実行）
                ↓
         ┌─────────────────────────┐
         │ 1. 標準出力 → コンテキストに入る（唯一の直接接点） │
         │ 2. 中間ファイル → Claudeが読み書きできる       │
         │ 3. 終了コード → 成功/失敗の判断に使われる      │
         └─────────────────────────┘
```

スクリプト本体はコンテキストに入らない。つまりこの3つのインターフェースの設計がClaude Codeとの連携品質を直接決める。

#### 標準出力の設計

標準出力はClaudeがスクリプトの結果を受け取る唯一の直接チャネル。

- Claudeが次のアクションを判断しやすい構造化データ（JSON等）で返す
- 不要な出力（プログレスバー、デバッグログ等）を標準出力に流さない。コンテキストを無駄に消費する
- 大量出力になる場合はファイルに書き出し、サマリーだけを標準出力に返す

```python
# 良い例: Claudeが次のアクションを判断できる
import json
print(json.dumps({
    "status": "error",
    "field": "signature_date",
    "message": "Field not found",
    "available_fields": ["customer_name", "order_total"]
}))

# 悪い例: 大量のログがコンテキストを埋める
for row in data:
    print(f"Processing row {row.id}...")
print("Done!")
```

#### 中間ファイルによるステップ間連携

複数ステップのワークフローでは、1つのスクリプトで全てをやるのではなく、中間ファイルを介して複数のスクリプトを協調させる。

```
analyze.py → fields.json → validate.py → fill.py → output.pdf
                ↑                                       ↓
         Claudeがここを              verify.py → OK / エラー
         読んで確認・修正できる
```

中間ファイルが「Claudeが介入できるポイント」になる。直接パイプでつなぐ（`analyze.py | fill.py`）と、Claudeが途中で検証・修正する余地がなくなる。

#### 終了コードの活用

Claudeは終了コードを見て成功/失敗を判断する。特にフィードバックループ（実行→検証→修正→再実行）のワークフローでは、終了コードがループの継続/終了判断に使われる。

```python
import sys

if errors:
    print(json.dumps({"status": "error", "errors": errors}))
    sys.exit(1)  # Claudeが「失敗した」と認識 → 修正を試みる
else:
    print(json.dumps({"status": "ok", "result": result}))
    sys.exit(0)  # Claudeが「成功した」と認識 → 次のステップへ
```

#### SKILL.mdでの言及方法

スクリプトに言及するとき、「実行」なのか「参照（中身を読む）」なのかを明示する。曖昧だとClaudeがスクリプト全体を読んでコンテキストに入れてしまう可能性がある。

```markdown
# 明確にする
**実行**: `python scripts/analyze.py input.pdf`
**参照**: アルゴリズムの詳細は scripts/analyze.py のコメントを参照

# 曖昧（Claudeがどちらか迷う）
scripts/analyze.py を使ってフォームを分析する
```

基本的には実行させる方が効率的。読ませるとスクリプト全体がコンテキストに入る。

### テンプレートパターン

出力フォーマットが重要な場合、テンプレートを提供する。厳密さのレベルを要件に合わせる。

```markdown
## コミットメッセージ形式

以下の例に従って生成:

**例1:**
入力: JWT認証を追加
出力: feat(auth): JWT認証を実装

**例2:**
入力: レポートの日付表示バグを修正
出力: fix(reports): タイムゾーン変換の日付フォーマットを修正
```

例を示すことで、説明だけよりも求めるスタイルと詳細さが正確に伝わる。

### 用語の一貫性

1つの用語を選び、スキル全体で統一する。

```markdown
# 良い例: 一貫
- 常に「APIエンドポイント」
- 常に「フィールド」
- 常に「抽出する」

# 悪い例: 混在
- 「APIエンドポイント」「URL」「APIルート」「パス」が混在
- 「フィールド」「ボックス」「要素」「コントロール」が混在
```

### 時間依存情報を避ける

古くなる情報をスキルに含めない。

```markdown
# 悪い例:
2025年8月以前は旧APIを使用。以降は新APIを使用。

# 良い例:
## 現在の方法
v2 APIエンドポイントを使用: `api.example.com/v2/messages`

## 旧パターン（非推奨）
<details>
<summary>レガシーv1 API（2025-08廃止）</summary>
v1 APIは `api.example.com/v1/messages` を使用していた。
</details>
```

### 選択肢を与えすぎない

```markdown
# 悪い例: 選択肢が多すぎる
pypdf、pdfplumber、PyMuPDF、pdf2imageなど使えます...

# 良い例: デフォルトを提示（エスケープハッチ付き）
テキスト抽出にはpdfplumberを使用。
スキャンPDFでOCRが必要な場合はpdf2image + pytesseractを使用。
```

### スキル開発の反復プロセス

公式が推奨する開発フロー:

1. **スキルなしでタスクを完了**: Claude Aと通常のプロンプティングで作業。繰り返し提供した情報に注目
2. **再利用可能なパターンを特定**: どのコンテキストが将来の類似タスクに役立つか
3. **Claude Aにスキル作成を依頼**: 「このパターンをキャプチャするスキルを作成して」
4. **簡潔さをレビュー**: 不要な説明を削除
5. **Claude Bでテスト**: 新しいインスタンスにスキルを読み込ませて実際のタスクで検証
6. **観察→改善→テストのサイクル**: 実際のエージェント動作に基づいて反復改善

### チェックリスト

スキルを共有する前の確認項目:

**コア品質**:
- [ ] descriptionが具体的で、キーワードを含む
- [ ] descriptionに「何をするか」と「いつ使うか」の両方がある
- [ ] SKILL.md本文が500行以内
- [ ] 詳細情報は別ファイルに分離されている
- [ ] 時間依存情報が含まれていない
- [ ] 用語が一貫している
- [ ] 例が具体的で抽象的でない
- [ ] ファイル参照が1段階の深さ

**ワークフロー**:
- [ ] 複雑タスクに明確なステップがある
- [ ] バリデーション/検証ステップが含まれている
- [ ] フィードバックループが品質重要なタスクに含まれている

---

## 設計のベストプラクティス（サマリー）

### スキル設計

1. **簡潔にする**: Claudeが既に知っていることは書かない
2. **自由度を適切に設定**: タスクの壊れやすさに応じて具体性を調整
3. **descriptionで発動条件を明示**: 三人称で「何を」「いつ」を含める
4. **呼び出し制御を適切に設定**: 副作用ある操作は`disable-model-invocation: true`
5. **SKILL.mdは500行以内**: 詳細は補助ファイルに分離
6. **`context: fork`はタスク型のみ**: リファレンス型をforkしても意味がない
7. **参照は1段階まで**: 深いネストはClaudeの部分読みを招く
8. **反復的に開発する**: 実際の使用を観察して改善する

### サブエージェント設計

1. **専門性に集中**: 各エージェントは1つの特定タスクに秀でるべき
2. **ツールを最小限に絞る**: レビュー→Edit不要、調査→Write不要
3. **descriptionで「プロアクティブに使用」と記載**: 自動委任されやすくなる
4. **永続メモリを活用**: レビューパターンやデバッグ知見を蓄積させると使うほど賢くなる
5. **VCSにチェックイン**: プロジェクトエージェントはチームで共有・改善

### プラグイン設計

1. **スタンドアロンから始める**: 安定してからプラグイン化
2. **セキュリティ考慮**: プラグインのMCPサーバーやスクリプトはAnthropicが検証していない
3. **READMEを整備**: インストール・使用方法を明記

---

## 参考リンク

- [Extend Claude with skills - Claude Code Docs](https://code.claude.com/docs/en/skills)
- [Agent Skills Overview - Claude API Docs](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
- [Skill authoring best practices - Claude API Docs](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [Create custom subagents - Claude Code Docs](https://code.claude.com/docs/en/sub-agents)
- [Create plugins - Claude Code Docs](https://code.claude.com/docs/en/plugins)
- [anthropics/skills - GitHub](https://github.com/anthropics/skills)
- [anthropics/claude-plugins-official - GitHub](https://github.com/anthropics/claude-plugins-official)
