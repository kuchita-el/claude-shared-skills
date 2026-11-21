# shared-memory

人間と AI が開発で得た知識・経験・判断基準を、利用者が所有するリポジトリへ蓄積し、次の作業で再利用するための機構。記憶のデータは含まない。

立ち上げの途中であり、配布カタログには登録していない。いま在るのは次の2つである。

- **記録の形式**（`references/format.md`）: 記録・索引・採用の台帳の形、置き換えの手順、記録の版の書き方、採用した記録の変化の判定、検査器が違反とするもの。
- **検査器**（`scripts/memory.mjs`）: 記録と台帳の形式を検査し、索引を生成する。記録の版を返し、採用した記録の変化を報告する。Node 22 以上で動く。Node の組み込みのほかに依存は無い。ただし、`version` と `adopted` は git を要する。

```bash
node scripts/memory.mjs check <記憶の根>
node scripts/memory.mjs index <記憶の根> --write
node scripts/memory.mjs version <記憶の根> <識別子> --ref <ref>
node scripts/memory.mjs adopted <プロジェクト側の記憶の根> <Global Memory の根> --ref <ref>
```
