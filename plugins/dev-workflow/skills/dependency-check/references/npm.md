# npm エコシステム コマンドリファレンス

npm / pnpm / yarn / bun 共通のコマンド対応表。SKILL.mdの各Phaseから参照される。

## PM検出

| ロックファイル | PM |
|---|---|
| `pnpm-lock.yaml` | pnpm |
| `package-lock.json` | npm |
| `yarn.lock` | yarn |
| `bun.lock` / `bun.lockb` | bun |

複数存在する場合は、上の優先順位に従う。

## コマンド対応表

### バージョン情報の取得

| 操作 | npm | pnpm | yarn | bun |
|---|---|---|---|---|
| インストール済みバージョン | `npm ls {pkg}` | `pnpm ls {pkg}` | `yarn why {pkg}` | `bun pm ls` |
| レジストリ情報 | `npm view {pkg}` | `pnpm info {pkg}` | `yarn npm info {pkg}` | `npm view {pkg}` |
| 特定バージョンの情報 | `npm view {pkg}@{ver}` | `pnpm info {pkg}@{ver}` | `yarn npm info {pkg}@{ver}` | `npm view {pkg}@{ver}` |
| 特定バージョンのpeerDeps | `npm view {pkg}@{ver} peerDependencies` | `pnpm info {pkg}@{ver} peerDependencies` | `yarn npm info {pkg}@{ver} --fields peerDependencies` | `npm view {pkg}@{ver} peerDependencies` |
| リポジトリURL | `npm view {pkg} repository.url` | `pnpm info {pkg} repository.url` | `yarn npm info {pkg} --fields repository` | `npm view {pkg} repository.url` |

### 依存関係の調査

| 操作 | npm | pnpm | yarn | bun |
|---|---|---|---|---|
| 依存元の特定 | `npm explain {pkg}` | `pnpm why {pkg}` | `yarn why {pkg}` | `bun pm ls` |
| 依存ツリー全体 | `npm ls --all` | `pnpm ls --depth Infinity` | `yarn info --all` | `bun pm ls --all` |

### ボトルネック分析（Phase 4用）

PMの解決エンジンを使って、目標バージョンをインストールした場合の依存解決エラーを取得する。

| 操作 | npm | pnpm | yarn | bun |
|---|---|---|---|---|
| dry-run install | `npm install {pkg}@{ver} --dry-run` | `pnpm add {pkg}@{ver} --dry-run` | `yarn add {pkg}@{ver} --mode update-lockfile` | `bun add {pkg}@{ver} --dry-run` |

- **npm**: `--dry-run` は実際のインストールを行わず、依存解決の結果だけを表示する。`ERESOLVE` エラーが出た場合、どのパッケージのpeerDepsが衝突しているかが示される
- **pnpm**: `--dry-run` で依存解決のプレビューを表示。エラー時はどのpeerDeps要求が満たされないかを表示する
- **yarn**: v3+では `--mode update-lockfile` でlockfileの更新プレビューを確認できる。依存解決エラー時は衝突の詳細が表示される
- **bun**: `--dry-run` で依存解決結果をプレビュー表示する

dry-runの出力からエラーが得られない場合は、`npm ls` 等で依存ツリーを確認し、peerDeps不整合を手動で照合する。
