# プラン作成サブエージェントのプロンプト構築・起動手順（plan-issue）

plan-issue SKILL.md のステップ5（plan サブエージェントによるプラン作成）から参照される、プロンプト組み立ておよびエージェント起動の詳細手順。`plan-prompt.md`（plan エージェント本体のシステムプロンプト）とは役割が異なり、本ファイルはスキル側（呼び出し元）でのプロンプト構築・起動分岐を扱う。

---

`${CLAUDE_SKILL_DIR}/references/plan-prompt.md` をReadで読み込み、プロンプトを構築する。

**プロンプト構築:**

```
{plan-prompt.md の内容}
```

`{OUTPUT_FORMAT}` プレースホルダを `${CLAUDE_SKILL_DIR}/references/plan-output-format.md` の内容で置換する。

その後、モードに応じて以下を追加する:

**通常モード / 固定入力モード:**

```
## Issue情報

{gh issue viewの結果 または JSONの内容}

## 補足指示

{補足指示（あれば）}
```

**Issueなしモード:**

```
## 入力（フリーテキスト補足指示）

{フリーテキスト全文}

Issue番号は存在しない。プランのタイトル・AC・スコープはこの入力から導出すること。入力にAC相当の記述がない場合、テストケース対応表は既定文言「該当なし。AC定義後に再生成すること」とすること。
```

続けて、全モード共通で以下を追加する:

```
## ベースブランチ

{決定したベースブランチ名}

実行した全てのBashコマンドとツール呼び出しを、実行順に「実行ログ」セクションとして最終出力に含めること。
```

**サブエージェントの起動:**

Agent tool（`subagent_type: dev-workflow:plan`）でプラン作成を実行する。モデルは定義の `inherit` に従う。custom plan agent は `skills: [writing-plans]` により計画骨格生成を superpowers `writing-plans` へ委譲する（S1=③ preload）。superpowers 未導入時は preload が skip され、エージェント定義のフォールバック（最小インライン計画）で動作する。

Agent toolが使えない場合や起動に失敗した場合は、`plugins/dev-workflow/agents/plan.md` の定義内容をプロンプト本文へ埋め込んでインラインで直接実行する（サブエージェント側からの定義ファイル再Readは行わない）。インライン実行時は preload が効かないため、計画骨格は同定義のフォールバック手順に従って生成する。
