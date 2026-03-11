---
description: 依存パッケージ更新のBreaking Changes・互換性・コード影響を自動分析する。パッケージのバージョンを上げたい・更新影響を調べたい・アップデートのリスクを知りたいときに使用
allowed-tools:
  - Read
  - Grep
  - Glob
  - WebFetch
---

# 依存パッケージ更新 影響分析パイプライン

指定パッケージの更新について、バージョン解決からコード影響分析まで自動分析し、推奨アクションを提示する。

## 引数

- `$ARGUMENTS`: パッケージ名（例: `react`, `typescript`, `@types/node`）

## 手順

### Phase 0: パッケージマネージャ検出

プロジェクトルートのロックファイルからPMを自動検出する:

| ロックファイル | PM |
|---|---|
| `pnpm-lock.yaml` | pnpm |
| `package-lock.json` | npm |
| `yarn.lock` | yarn |
| `bun.lock` / `bun.lockb` | bun |

PM別コマンド対応表:

| 操作 | npm | pnpm | yarn | bun |
|---|---|---|---|---|
| 現在バージョン確認 | `npm ls {pkg}` | `pnpm ls {pkg}` | `yarn why {pkg}` | `bun pm ls` |
| レジストリ情報取得 | `npm info {pkg}` | `pnpm info {pkg}` | `yarn npm info {pkg}` | `npm info {pkg}` |
| 依存元特定 | `npm explain {pkg}` | `pnpm why {pkg}` | `yarn why {pkg}` | `bun pm ls` |

検出できない場合はエラーメッセージを出力して終了する。

### Phase 1: バージョン解決

1. **現在バージョンの確認**: コマンド対応表に従いインストール済みバージョンを取得
2. **最新バージョンの確認**: レジストリからバージョン情報を取得
3. **変更種別の判定**: セマンティックバージョニングに基づき判定
   - **メジャー**: 破壊的変更の可能性あり → Phase 2で詳細分析
   - **マイナー**: 新機能追加。通常は互換性あり
   - **パッチ**: バグ修正のみ

### Phase 2: Breaking Changes分析

1. **リポジトリURL取得**: Phase 1のレジストリ情報から `homepage` または `repository.url` を取得
2. **リリースノート・CHANGELOGの確認**: WebFetchで以下を順に確認（取得できたものを使用）:
   - GitHubリリースページ（`/releases`）
   - `CHANGELOG.md`
   - マイグレーションガイド（存在する場合）
3. **破壊的変更の抽出**: 「BREAKING」「breaking change」「removed」「deprecated」等のキーワードを含む項目を抽出
4. **影響度の判定**: 各破壊的変更について、API削除・シグネチャ変更・デフォルト値変更等の種類を分類

> マイナー・パッチ更新の場合はこのPhaseをスキップする。ただしリリースノートにdeprecation警告がある場合は記録する。

### Phase 3: peerDeps互換性チェック

1. **更新先のpeerDeps確認**: レジストリ情報から更新先バージョンの `peerDependencies` を取得
2. **現在のプロジェクトとの互換性検証**: `package.json` の依存バージョンと照合
3. **非互換の特定**: peerDepsの要求範囲を満たさないパッケージを一覧化

### Phase 4: 逆peerDeps特定

1. **対象パッケージに依存しているパッケージの特定**: コマンド対応表の「依存元特定」で逆依存を取得
2. **互換性の確認**: 逆依存パッケージが更新先バージョンをサポートしているか確認

### Phase 5: コード影響分析

1. **import/require箇所の検索**: Grepで対象パッケージのimport/require文を検索
2. **使用APIの特定**: import先のモジュール・関数・型を抽出
3. **Breaking Changesとの突合**: Phase 2で抽出した破壊的変更に該当する使用箇所を特定
4. **影響ファイル一覧の作成**: ファイルパスと該当行、必要な変更の概要を整理

### Phase 6: 出力

以下の形式で分析結果を提示する。該当しないセクションは省略してよい。

```markdown
## {パッケージ名}

| 項目 | 結果 |
|---|---|
| 現在バージョン | {current_version} |
| 最新バージョン | {latest_version} |
| 変更種別 | メジャー / マイナー / パッチ |
| Breaking Changes | {件数}件 |
| peerDeps非互換 | {件数}件 |
| 逆peerDeps影響 | {件数}件 |
| コード影響箇所 | {件数}ファイル |
| 総合リスク | 高 / 中 / 低 |

### Breaking Changes

| 変更内容 | 種類 | 影響箇所 |
|---|---|---|
| {変更の説明} | API削除 / シグネチャ変更 / デフォルト値変更 | {ファイル数}ファイル |

### peerDeps互換性

| パッケージ | 要求バージョン | 現在バージョン | 状態 |
|---|---|---|---|
| {pkg} | {required} | {current} | 互換 / 非互換 |

### 逆peerDeps影響

| パッケージ | peerDeps要求 | 更新後の互換性 |
|---|---|---|
| {pkg} | {peer_range} | 互換 / 非互換 / 要確認 |

### コード影響箇所

| ファイル | 行 | 使用API | 必要な変更 |
|---|---|---|---|
| {file_path} | {line} | {api_name} | {変更内容} |

### 推奨アクション

**判定**: アップデート推奨 / 段階的アップデート推奨 / 慎重に検討

1. [最初にやるべきこと]
2. [次にやるべきこと]
```

推奨アクションの判定基準:

- **アップデート推奨**: Breaking Changesなし、peerDeps互換、逆peerDeps影響なし
- **段階的アップデート推奨**: 影響はあるが対応可能。具体的な手順を提示
- **慎重に検討**: 広範な影響あり。代替案やタイミングの提案を含める

## 注意事項

- **PMコマンドの実行許可**: PM固有のコマンド（`npm ls`, `pnpm info` 等）は `allowed-tools` に含めていない。`settings.json` の `allowedTools` でプロジェクトごとに許可設定すること（例: `Bash(npm ls*)`, `Bash(npm info*)`, `Bash(npm explain*)`, `Bash(pnpm *)`, `Bash(yarn *)`, `Bash(bun *)`）
- **WebFetchの制限**: リリースノートのページが大きすぎる場合は取得に失敗することがある。その場合はCHANGELOGやマイグレーションガイドを試す
- **モノレポ対応**: モノレポの場合は対象ワークスペースの `package.json` を基準に分析する。ルートの `package.json` だけでなく、影響を受けるワークスペースも確認する
