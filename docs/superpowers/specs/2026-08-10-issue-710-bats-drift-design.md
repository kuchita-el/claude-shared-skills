# Issue #710: bats 代理指標 drift 解消設計

## 目的

`main` の bats スイートを緑へ戻し、`report` の差件数が変わるたびに、差件数を検査対象としていない異常系テストが壊れる状態を解消する。

## 対象と制約

- 対象は `scripts/tests/adr-scoping-cases-basic.bats` の 09b と、`scripts/tests/adr-scoping-cases-edge.bats` の 40a／40b／40c。
- `plugins/adr/scripts/adr-scoping-cases.sh` と fixture は変更しない。
- 面⑪の差件数検査は、`report` の集計本文を検証する唯一のサイトとして維持する。

## 採用案

異常系4サイトでは `差 N 件` という表示文言を直接一致させない。正常経路で同じ `report` を実行した出力を baseline とし、各異常条件で得た出力が baseline と一致することを確認する。

これにより、各サイトが本来検査している性質（`var=value` パス、異常な `$TMPDIR`、特殊文字を含む題材集合パス）と、期待帰結を読めることの確認を分離する。集計本文の表示文言だけを変更しても異常系4サイトは影響を受けず、期待帰結ファイルを読めない変異では異常経路と正常経路の出力が不一致になるため検出できる。

## 実装方針

1. 09b・40a/b・40c のラベルから旧来の差件数表現を除き、各サイトの検査対象を明記する。
2. 09b と 40a/b は、異常条件を付けない同等の `report` 出力を取得し、異常条件下の出力と比較する。
3. 40c は特殊文字を含む題材集合パスでの `report` 出力を、通常の題材集合パスでの出力と比較する。
4. 既存の rc、プロンプト、診断内容の検査は維持する。

## 検証

- `mise exec -- bats scripts/tests/adr-scoping-cases-basic.bats`
- `mise exec -- bats scripts/tests/adr-scoping-cases-edge.bats`
- `mise exec -- bash scripts/run-tests.sh`
- `scripts/tests/` 内の 09b・40a・40b・40c が `差 [0-9]+ 件` に一致させていないことを確認する。
- 変更差分をレビューし、Issue #710 の受入条件を1件ずつ確認する。
