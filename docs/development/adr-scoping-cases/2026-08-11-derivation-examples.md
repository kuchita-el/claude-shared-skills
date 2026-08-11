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

## 点数を模したフィールドを足しても出力が変化しない

点数・合計・行き先を入力へ保存しても、`derive` はそれらを参照せず、実測事実と閾値設定から算出する。次のコマンドで一時ファイルを作り、点数を模したフィールドを追加した入力を渡す。

```text
$ extra_input="$(mktemp -t adr-scoping-case-extra.XXXXXX.json)"
$ jq '. + {"点数_合計": 99, "score": 99}' scripts/fixtures/adr-scoping-cases/returns/CASE-A1-1.json > "$extra_input"
$ bash plugins/adr/scripts/adr-scoping-cases.sh derive "$extra_input" --thresholds plugins/adr/skills/manage-adr/references/adr-scoring-thresholds.json --doc-commit 0000000
項目1: 1
項目2: 0
項目3: 0
項目4: 1
合計: 2
行き先: 共有規約文書
$ rm -f "$extra_input"
```

無改変時の出力と同一であり、点数を模したフィールドは算出へ影響しない。これは契約仕様の「直列化形式」が点数・合計・行き先を保持しないと定めていることにも対応する。

## 実測事実フィールドを改変すると出力が変化する

項目1の追跡下ファイルを閾値の反対側へ変更した入力では、項目1の点数と合計が変化する。

```text
$ altered_input="$(mktemp -t adr-scoping-case-altered.XXXXXX.json)"
$ jq '."項目1_追跡下ファイル" = ["a", "b"] | ."項目1_追跡下ファイル数" = 2' scripts/fixtures/adr-scoping-cases/returns/CASE-A1-1.json > "$altered_input"
$ bash plugins/adr/scripts/adr-scoping-cases.sh derive "$altered_input" --thresholds plugins/adr/skills/manage-adr/references/adr-scoring-thresholds.json --doc-commit 0000000
項目1: 0
項目2: 0
項目3: 0
項目4: 1
合計: 1
行き先: 共有規約文書
$ rm -f "$altered_input"
```

無改変時から項目1が `1` から `0` へ、合計が `2` から `1` へ変化している。実測事実を改変した場合は、点数を模したフィールドの追加とは異なり算出結果へ反映される。
