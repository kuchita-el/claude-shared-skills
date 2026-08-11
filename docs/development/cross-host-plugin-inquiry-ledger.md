# Cross-host plugin Wave 0 問い台帳

## 決着状態

Wave 0 の調査問いは、決着値を省略せず次の5件へ固定する。自動観測できない挙動は成功へ畳まず、結論そのものを `degraded` として後続gateへ伝播する。

| 問い | 決着値 | 直接証拠 | pivot | 導出 | 後続制約 |
|---|---|---|---|---|---|
| Q1 Codexがplugin内のskill rootをどのように公開するか | 解いた | `codex plugin --help`、`.agents/plugins/marketplace.json`、各entryの `source.path` | — | marketplaceのlocal pathをplugin rootとして導入し、skillはplugin配下から解決する | Codex側の正本はmarketplace entryとplugin manifestのpath |
| Q2 Codexでスキルごとの権限境界をどこまで静的に制約できるか | 解いた | Codex CLI 0.147.0の `exec --sandbox` / approval options、marketplace entryの `policy` | Q1 | plugin単位のsandbox/approval制約は宣言できるが、Claudeの`allowed-tools`と同一粒度ではない | permission ledgerはhost別宣言と狭い代替を必須化し、差分は`degraded`とする |
| Q3 Codexで暗黙発火の試行を自動実行し、発火有無を観測できるか | 解いた | `codex exec --help`にskill-load観測APIがない。固定prompt自動試行は観測結果を返さず、成功扱いにしない | — | 自動観測APIは利用不能と決着し、暗黙発火は手動smokeへ縮退する | release gateは自動合格を表示せず、`degraded`証拠を保存する |
| Q4 Claude Codeで `${CLAUDE_PLUGIN_ROOT}` がSKILL.mdのRead経路で展開されるか | 解いた | Claude Code 2.1.227のplugin root仕様を前提にした既存ADR、`--plugin-dir`の公開インターフェース。固定prompt 3回は応答待ちでタイムアウトし、反証結果は得られなかった | — | 既存ADRの決定を維持し、実行不能なprobeは成功証拠に数えない | ADR-202606040737-01の参照形式を変更しない。否定確定ではないためJ1は不発火 |
| Q5 各pluginのversioning規約の正本と暫定規則との差分は何か | 解いた | 両marketplaceのplugin entry、両manifest、現行version `0.1.0`、Gitでのplugin配下差分 | — | `plugins/<name>/.claude-plugin/plugin.json` と `.codex-plugin/plugin.json`を同一versionの正本とし、配布物差分時にbumpする | 初回導入は`0.1.0`、配布物変更はversion更新、配布元外変更は要求しない |

## 証拠の再現手順

```text
claude --version
codex --version
codex plugin --help
claude -p --no-session-persistence --plugin-dir ./plugins/dev-workflow --tools '' \
  --output-format json '参照基点と${CLAUDE_PLUGIN_ROOT}展開可否を、不明なら不明と答える。変更禁止。'
```

実測環境は 2026-08-11、Claude Code 2.1.227、Codex CLI 0.147.0。Claudeの固定promptは3回試行したが、いずれもAPI応答待ちでタイムアウトした。したがってこの証拠は展開成功の証明ではなく、観測不能時に自動合格させないための記録である。

## 根の問いへの統合結論

以降のWaveが採用するhost adapterとrelease gateは次のとおり。

1. root解決はClaudeの `${CLAUDE_PLUGIN_ROOT}` とCodexのmarketplace `source.path` をhost adapterとして分離する。
2. 権限はhost別permission ledgerで宣言し、Codexで同等性を保証できない操作は `degraded` と残余リスクを記録する。
3. 明示呼び出しは自動検査する。暗黙発火は観測APIが得られるまで `degraded` 手動smokeとし、自動合格にしない。
4. version正本は両manifestの一致値、release gateはplugin配下差分とversion bumpの組み合わせとする。

全Q1〜Q5は `未決` 以外で決着しており、根の問いへの統合結論も上記で固定した。
