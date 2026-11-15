# shared-memory

人間と AI が開発で得た知識・経験・判断基準を、利用者が所有するリポジトリへ蓄積し、次の作業で再利用するための機構。記憶のデータは含まない。

立ち上げの途中であり、配布カタログには登録していない。いま在るのは次の2つである。

- **記録の形式**（`references/format.md`）: 記録と索引の形、置き換えの手順、検査器が違反とするもの。
- **検査器**（`scripts/memory.mjs`）: 記録の形式を検査し、索引を生成する。Node 22 以上で動く。依存は無い。

```bash
node scripts/memory.mjs check <記憶の根>
node scripts/memory.mjs index <記憶の根> --write
```
