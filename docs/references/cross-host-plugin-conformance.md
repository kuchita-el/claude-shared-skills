# Cross-host plugin conformance contract

Wave 0以降のplugin適合性を、Claude CodeとCodexのhost差分を隠さず検査するための契約。

実体は `docs/references/cross-host-compatibility.json` と `docs/references/cross-host-permission-ledger.json` に置く。matrixの `fixtures` は `scripts/fixtures/skill-portability/<name>/` の再現fixtureを指し、実体が無ければ検査を失敗させる。schema負例と検査器のテスト専用fixtureは実repo検査の入力へfallbackしない。

## Compatibility matrix

matrixはJSON配列として保持し、各行は次の字段を持つ。`residualRisk` は `degraded` または `surface-specific` を宣言する行で必須とする。

| 字段 | 型 | 値域・意味 |
|---|---|---|
| `feature` | string | 検査対象の能力名。空文字不可 |
| `plugin` | string | 任意。片host固有の配布差分を宣言する場合は対象plugin名を指定する |
| `claudeLevel` | enum | `portable` / `adapted` / `degraded` / `surface-specific` |
| `codexLevel` | enum | 同上 |
| `fixtures` | array[string] | 少なくとも1件の再現fixture |
| `residualRisk` | string | `degraded` または `surface-specific` の場合は必須。それ以外では省略可。存在時は空文字不可 |

`portable` は同じ契約で利用できること、`adapted` はhost adapterを介して同じ成果を得ること、`degraded` は自動保証を縮退させ残余リスクを明記すること、`surface-specific` は片host固有であることを示す。

`plugin` を持つ行で `codexLevel` が `surface-specific` の場合、検査器はそのpluginがCodex marketplaceに存在しないことを許容する。`claudeLevel` が `surface-specific` の場合はClaude marketplace側の欠落を許容する。片host固有の例外はplugin名とhost側のlevelをmatrixへ宣言し、検査器へplugin名を直接ハードコードしない。

## Permission ledger

permission ledgerはJSON配列として保持し、各行は次の5字段を必須とする。

| 字段 | 型 | 値域・意味 |
|---|---|---|
| `permission` | string | hostが宣言する許可名 |
| `requiredOperation` | string | その許可で実行する必要操作 |
| `witness` | string | 操作の存在を検証するfixtureまたは観測名 |
| `narrowerAlternative` | string | より狭い代替。無い場合も `なし。` など理由を記す |
| `verdict` | enum | `necessary` / `optional` / `degraded` |

各行は許可の最小性を次の4条件でレビューする。

1. `requiredOperation`が対象pluginの成果に必要である。
2. `witness`がその必要性を再現可能に示す。
3. `narrowerAlternative`を検討し、無い場合も理由を明記する。
4. `verdict`がhost差分と残余リスクを隠していない。

Claudeの`allowed-tools`集合、Codexのsandbox/approval/tool制約集合は、ledgerの宣言集合と双方向に一致させる。Codex側で同一粒度を表現できない場合は、集合を黙って同一視せず`degraded`とする。
## dev-workflow portability

中央compatibility matrixの `dev-workflow-*` 行は、`scripts/fixtures/skill-portability/` のwitness JSONと、成果状態を固定する `scripts/fixtures/dev-workflow/` を分離して参照する。validatorは両fixtureを発見し、host、execution mode、期待判定が空でないことを検査する。Codexのagent定義全文readはClaude native起動には要求せず、per-agent read-only非強制は成果契約ではなくpermission ledgerの `degraded` として扱う。
