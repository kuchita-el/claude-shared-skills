# DDDドキュメントリント運用ガイド

`scripts/lint-domain-doc.sh` をローカル開発（pre-commit hook）と CI（GitHub Actions）に組み込むための設定例。

## スクリプト概要

`scripts/lint-domain-doc.sh` は DDD ドキュメントの **記法逸脱（構造検証）** を機械検出する bash スクリプト。命名規約（イベント=過去形、コマンド=動詞句〔う段終止形〕等）は形態素解析を要する言語学的判定のため機械検証対象外とし、規約として人が守る運用に委ねる（背景は `skills/domain-modeling/references/domain-model-notation.md` の「Linter による機械検証の撤退について」を参照）。

- **検査対象（既定）**:
  - `docs/development/event-storming.md`
  - `docs/development/domain-model.md`
  - `docs/qa/event-storming.md`
- **検出項目**:
  - 禁止記号: `->`、`=>`、`<>`、`Result<`、行頭の `type`、` ```fsharp ` ラベル（Mermaid ブロック内は除外）
  - 廃止記法: `〜失敗理由 =` 独立型定義（Either.Left 系の同期失敗はコマンドの `失敗時:` 配下に箇条書きで記述する）
- **exit code**:
  - `0`: 違反0件
  - `1`: 違反検出
  - `2`: 入力ファイル不存在
- **依存**: `bash` ≥ 4.x

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

`ubuntu-latest` 標準環境で追加セットアップ不要。違反検出時は exit code 1 でジョブが失敗する。

## 既知の制約

- **自動テスト**: `scripts/test-lint-domain-doc.sh` で fixture（`scripts/fixtures/lint-domain-doc/{valid,invalid}/*.md`）に対する exit code とメッセージ部分一致をアサートする。CI 連携は未導入（ローカル実行のみ）。
- **命名規約は機械検証対象外**: イベント=過去形、コマンド=動詞句〔う段終止形〕等の命名規約はLinterの機械検証から撤退済（背景: `domain-model-notation.md` の「Linter による機械検証の撤退について」）。命名遵守は規約参照と人間レビューで補完する。
- **失敗理由独立型は違反**: `〜失敗理由 =` のような独立型定義は廃止記法として違反検出される。Either.Left 系の同期失敗はコマンドの `失敗時:` 配下に箇条書きで記述する（空なら省略）。ドメインイベント系失敗（`〜が失敗した` 等、境界を超えて他者が観測する事実）は `イベント:` 配下に発火イベントとして列挙する（`失敗時:` 配下への混入は意味境界違反だが、本リントは意味境界の機械検査は行わない。レビューで補完すること）。

## 動作確認済み

- 2026-04-29: 既存DDDドキュメント3本に対する実測で命名規約違反 11 件を検出（禁止記号は0件）。
- 2026-04-29: A 案 pre-commit スニペットを `.git/hooks/pre-commit` に貼り付け、違反入りファイルを `git add` → `git commit` 試行で commit が失敗することを確認。違反0件のファイルでは commit が正常完了することを確認。
- 2026-04-30: 記法刷新（#168）に伴い、検査ロジックを更新（う段9文字終止形・状態遷移廃止検出・失敗理由独立型廃止検出・契機フィールド必須化）。fixture テストランナー `scripts/test-lint-domain-doc.sh` を導入し、valid 4件 + invalid 4件で全パスを確認。
- 2026-05-09: 命名規約検査（イベント名・コマンド名・状態遷移名）と廃止セクション存在検査を削除（#192）。Linter は構造検証（禁止記号・廃止記法独立型定義・契機フィールド必須化）に専念。fixture を valid 4件 + invalid 2件に再編し全パスを確認。
- 2026-05-09: 契機フィールド検査削除（#187）。Linter は禁止記号検査・廃止記法検出（失敗理由独立型）の2系統に絞り込み。fixture を valid 4件 + invalid 1件に再編し全パスを確認。
- 2026-05-09: GNU grep / `LC_ALL` 依存撤去（#195）。lint 本体から PCRE 対応性検査と `LC_ALL=C.UTF-8` 明示を削除し、運用ガイドから macOS セットアップ手順を削除。fixture テスト 5/5 パス・既定3ファイル違反0件を確認（macOS 実機確認は別Issueでマトリクス化検討）。
