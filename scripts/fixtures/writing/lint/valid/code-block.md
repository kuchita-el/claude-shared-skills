# 手順

次のコマンドで準備する。

```bash
pnpm --dir tools/example install --frozen-lockfile
pnpm --dir tools/example test     # 規則ごとの見本の照合と入口の試験
pnpm --dir tools/example build    # 依存を同梱した1ファイルを作る
```
