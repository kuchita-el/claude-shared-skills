# DDDドキュメントリント運用ガイド

`scripts/lint-domain-doc.sh` をローカル開発（pre-commit hook）と CI（GitHub Actions）に組み込むための設定例。

## スクリプト概要

`scripts/lint-domain-doc.sh` は DDD ドキュメントの **記法逸脱・命名規約違反** を機械検出する bash スクリプト。

- **検査対象（既定）**:
  - `docs/development/event-storming.md`
  - `docs/development/domain-model.md`
  - `docs/qa/event-storming.md`
- **検出項目**:
  - 禁止記号: `->`、`=>`、`<>`、`Result<`、行頭の `type`、` ```fsharp ` ラベル（Mermaid ブロック内は除外）
  - 命名規約: 集約セクション（`## XXX集約`）配下の `### コマンド` / `### 発火するイベント` 配下のコードブロック内、行頭定義行の語尾判定（**日本語名のみ**）
    - コマンド名: 動詞句（う段9文字終止形 `う/く/ぐ/す/つ/ぬ/ぶ/む/る`）
    - イベント名: 過去形（`〜した` / `〜された`）
  - 廃止セクション: `### 状態遷移` 残存（コマンドセクションへ統合済み）
  - 廃止記法: `〜失敗理由 =` 独立型定義（コマンドの `失敗時:` 配下に箇条書きで記述する）
  - 契機フィールド必須化: 集約配下のコマンドエントリに `契機:` フィールドが必須。値は4種列挙値（`外部指示` / `イベント受信(...)` / `ポリシー(...)` / `スケジュール`）
- **exit code**:
  - `0`: 違反0件
  - `1`: 違反検出
  - `2`: 入力ファイル不存在
  - `3`: GNU grep（`grep -P` 対応）不在
- **依存**: `bash` ≥ 4.x、GNU grep（Linux または `brew install grep` 済みの macOS）

## 基本実行例

```sh
# 既定の3ファイルを検査
bash scripts/lint-domain-doc.sh

# 個別ファイルのみ検査（pre-commit から staged ファイルを渡す等）
bash scripts/lint-domain-doc.sh docs/development/domain-model.md
```

違反が検出されると `{ファイル}:{行番号}: {違反種別}: ...` 形式で標準出力に出力され、exit code が非0になる。

## pre-commit hook 設定例

### A. `.git/hooks/pre-commit` 直貼り版（個人開発者向け）

`.git/hooks/pre-commit` に以下を配置し、`chmod +x .git/hooks/pre-commit` で実行権を付与する。

```sh
#!/usr/bin/env bash
set -euo pipefail

# DDDドキュメントの staged 差分のみリント
targets=(
    "docs/development/event-storming.md"
    "docs/development/domain-model.md"
    "docs/qa/event-storming.md"
)

# staged ファイルから対象パスを抽出
mapfile -t staged < <(
    git diff --cached --name-only --diff-filter=ACM | \
        grep -Fxf <(printf '%s\n' "${targets[@]}") || true
)

if [ "${#staged[@]}" -gt 0 ]; then
    bash scripts/lint-domain-doc.sh "${staged[@]}"
fi
```

DDD ドキュメント以外を編集する commit には影響しない（staged に対象ファイルがなければスキップ）。

### B. `pre-commit` フレームワーク版（チーム共有向け）

[pre-commit](https://pre-commit.com/) を使う場合、リポジトリ直下の `.pre-commit-config.yaml` に local hook として登録する。

```yaml
repos:
  - repo: local
    hooks:
      - id: lint-domain-doc
        name: DDD ドキュメントリント
        entry: bash scripts/lint-domain-doc.sh
        language: system
        files: '^docs/(development|qa)/(event-storming|domain-model)\.md$'
        pass_filenames: true
```

`pass_filenames: true` により、staged の対象ファイルだけがスクリプト引数として渡される。導入後は `pre-commit install` でフックを有効化する。

## CI 設定例（GitHub Actions）

`.github/workflows/lint-ddd-doc.yml` 雛形:

```yaml
name: DDD doc lint

on:
  pull_request:
    paths:
      - "docs/development/event-storming.md"
      - "docs/development/domain-model.md"
      - "docs/qa/event-storming.md"
      - "scripts/lint-domain-doc.sh"

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run lint-domain-doc.sh
        run: bash scripts/lint-domain-doc.sh
```

`ubuntu-latest` は GNU grep を含むため追加セットアップ不要。違反検出時は exit code 1 でジョブが失敗する。

## 既知の制約

- **GNU grep 依存**: 日本語文字判定に `grep -P`（PCRE）を使用。BSD grep / macOS デフォルト grep では動作しない（exit 3 でエラー終了）。macOS では `brew install grep` 後に PATH 上で GNU grep が優先されるよう設定する。
- **自動テスト**: `scripts/test-lint-domain-doc.sh` で fixture（`scripts/fixtures/lint-domain-doc/{valid,invalid}/*.md`）に対する exit code とメッセージ部分一致をアサートする。CI 連携は未導入（ローカル実行のみ）。
- **許容誤検知（う段拡張による副作用）**: 名詞末尾がう段9文字に該当するケース（例: 末尾「す」「く」等の漢字訓読み稀少例）はリントでは違反として検出されない可能性がある。本規約は「規約として人が守る」前提で運用。形態素解析による厳密判定は将来課題。
- **失敗理由独立型は違反**: `〜失敗理由 =` のような独立型定義は廃止記法として違反検出される（コマンドの `失敗時:` 配下に箇条書きで記述すること）。
- **英語名は対象外**: 命名規約検査は日本語含有行のみ。英語名（`createPlan` 等）はスキップされる。

## 動作確認済み

- 2026-04-29: 既存DDDドキュメント3本に対する実測で命名規約違反 11 件を検出（禁止記号は0件）。
- 2026-04-29: A 案 pre-commit スニペットを `.git/hooks/pre-commit` に貼り付け、違反入りファイルを `git add` → `git commit` 試行で commit が失敗することを確認。違反0件のファイルでは commit が正常完了することを確認。
- 2026-04-30: 記法刷新（#168）に伴い、検査ロジックを更新（う段9文字終止形・状態遷移廃止検出・失敗理由独立型廃止検出・契機フィールド必須化）。fixture テストランナー `scripts/test-lint-domain-doc.sh` を導入し、valid 4件 + invalid 4件で全パスを確認。
