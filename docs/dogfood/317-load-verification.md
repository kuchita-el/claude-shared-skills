# Issue #317 起動検証ログ（AC3）

dev-workflow プラグインのモデル値変更後、プラグインがロード可能であり、エージェント呼び出しがエラーなく動作することを確認した記録。

## 検証日

2026-06-21

## 検証範囲

AC3: 決定された `model` 値が `plugins/dev-workflow/agents/*.md` の各ファイルに反映され、`./setup-local.sh` でプラグインがロード可能な状態である（起動エラーが出ない）。

## 静的検証（本セッションで実施）

`./setup-local.sh` は `exec claude --plugin-dir ./plugins/dev-workflow` を実行し、現セッションを置き換えてしまうため、本セッション内では実機起動できない。代わりに静的検証で「ロード時のエラー要因がないこと」を確認する。

### 1. `plugin.json` の JSON 妥当性

```bash
$ jq . plugins/dev-workflow/.claude-plugin/plugin.json
```

結果（正常パース、`version: "0.5.1"` 反映済）:

```json
{
  "name": "dev-workflow",
  "version": "0.5.1",
  "description": "Claude Code向けの汎用開発ワークフロースキル集。Issue管理・開発ループ・PR レビュー・依存関係チェック等を提供する。"
}
```

### 2. エージェント定義の YAML フロントマター構造

```bash
$ grep -c "^---$" plugins/dev-workflow/agents/*.md
```

結果（全 6 ファイルで `---` デリミタが 2 個、frontmatter 構造が破れていない）:

```
plugins/dev-workflow/agents/plan.md:2
plugins/dev-workflow/agents/refactorer.md:2
plugins/dev-workflow/agents/code-reviewer.md:2
plugins/dev-workflow/agents/plan-reviewer.md:2
plugins/dev-workflow/agents/test-designer.md:2
plugins/dev-workflow/agents/test-spec-validator.md:2
```

### 3. `model` 値が公式有効値（`inherit / sonnet / opus / haiku`）の範囲内

```bash
$ grep "^model:" plugins/dev-workflow/agents/*.md
```

結果:

```
plugins/dev-workflow/agents/code-reviewer.md:model: sonnet
plugins/dev-workflow/agents/plan.md:model: opus
plugins/dev-workflow/agents/test-designer.md:model: sonnet
plugins/dev-workflow/agents/plan-reviewer.md:model: sonnet
plugins/dev-workflow/agents/test-spec-validator.md:model: sonnet
plugins/dev-workflow/agents/refactorer.md:model: sonnet
```

判定: 全 6 件が公式有効値（`opus` または `sonnet`）に収まっている。`inherit / sonnet / opus / haiku` 以外の値（空、タイポ、具体ID形式）は混入なし。

### 4. 静的検証の結論

- `plugin.json` は有効 JSON、`version: "0.5.1"` 反映。
- 全 6 エージェント定義の YAML フロントマターが構造的に破れていない。
- 全 `model` 値が公式有効値範囲内。

→ プラグインローダーがエラーを返す静的要因は見当たらない。AC3 の起動検証は「静的検証 PASS」を確認。実機起動の最終確認は後続で実施する。

## 実機検証（後続）

ユーザーが本ブランチで `./setup-local.sh` を直接実行し、以下を確認する。

1. Claude Code が `--plugin-dir ./plugins/dev-workflow` でエラーなく起動する。
2. 起動後、`Agent` ツールで `subagent_type: dev-workflow:code-reviewer`（または任意の 1 件）を呼び出し、応答が返る。
3. ロード時の警告・エラーがコンソールに出ない。

実機検証で問題が見つかった場合は、原因（フロントマター値の誤り・依存スキルの不在等）を特定し本ファイルに追記する。

## 補足: `./setup-local.sh` を本セッションで実行しない理由

スクリプトは末尾で `exec claude --plugin-dir ./plugins/dev-workflow` を呼ぶ。これは現在のシェルプロセス（および本 Claude Code セッション）を新しい `claude` プロセスで置き換えるため、本セッションが終了する。本セッション内で実機起動検証はできず、静的検証 + 後続ドッグフードでカバーする。
