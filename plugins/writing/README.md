# writing plugin

日本語文書の起草、機械lint、独立レビューをClaude CodeとCodexへ提供するpluginです。
共通規約の正本は`references/japanese-writing.md`、文書種別の既定は`references/document-type-profiles.md`です。

## 配布物

- `skills/write-doc/SKILL.md`: `documentType`、`structure`、`materials`、`audience`、`outputPath`を受け、起草→lint→review→最大2回修正を調整します。
- `agents/doc-writer.md`: 確定素材だけから起草します。
- `agents/doc-reviewer.md`: 初見入力でF1/F3/F4/F5を判定し、`ruleId,severity,evidence,suggestion`を返します。
- `scripts/lint-ja.sh`: `--diff BASE -- PATH...`（差分既定）または`--file PATH`を受け、一文長違反と識別子候補を報告します。
- `compatibility.json`: Claude CodeとCodexのportable/adapted/degraded境界とfixtureを記録します。
- `permission-ledger.json`: 必須操作、witness、より狭い代替、判定をhost差分ごとに記録します。

## 契約と縮退

素材が空なら`status=blocked`、`missing=[materials]`、`writes=[]`で停止します。
lint違反または2回後も残るreview指摘は`status=unresolved`とし、成功成果として扱いません。
全規則が解消した場合だけ`status=passed`を返します。

Claude Codeは登録agentを使います。CodexはWave 0 adapterが利用できる場合は同じ状態へ写像し、利用できない場合は明示起動と結果記録による`degraded`手動検査へ縮退します。
暗黙発火の自動gateがないhostでは、固定promptを3回実行した証拠を残してください。
F5（主張と根拠の同居）はreviewerの責務であり、lintの機械判定には含めません。

## 適用範囲

新規起草と実際に編集する箇所が対象です。既存文書の一括是正、退役ADRの決定本文、allowlist運用は対象外です。
plugin間のpath参照は作らず、利用側は`writing:write-doc`のsoft dependencyとして呼び出します。

host別の導入位置は両marketplaceの`writing`エントリから解決できます。release時の検証証拠は`docs/development/test-execution.md`にあります。
