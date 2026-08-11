# 算出機構の実行例

これは算出機構の実証であり、現行条文に対する正しい判定結果ではない。現行条文の下で実行された判定記録はまだ無く、以下は fixture の実測事実へ設定ファイルの閾値を適用した結果である。

## 通常の算出

```text
$ bash plugins/adr/scripts/adr-scoping-cases.sh derive scripts/fixtures/adr-scoping-cases/returns/CASE-A1-1.json --thresholds plugins/adr/skills/manage-adr/references/adr-scoring-thresholds.json --doc-commit 0000000
項目1: 1
項目2: 0
項目3: 0
項目4: 1
合計: 2
行き先: 共有規約文書
```

項目ごとの点数・合計・行き先は JSON に保存されず、実測事実と設定ファイルから都度導出される。
