# Cross-host plugin conformance contract

Wave 0以降のplugin適合性を、Claude CodeとCodexのhost差分を隠さず検査するための契約。

## Compatibility matrix

matrixはJSON配列として保持し、各行は次の字段を必須とする。

| 字段 | 型 | 値域・意味 |
|---|---|---|
| `feature` | string | 検査対象の能力名。空文字不可 |
| `claudeLevel` | enum | `portable` / `adapted` / `degraded` / `surface-specific` |
| `codexLevel` | enum | 同上 |
| `fixtures` | array[string] | 少なくとも1件の再現fixture |
| `residualRisk` | string | `degraded` または `surface-specific` の場合は必須。空文字不可 |

`portable` は同じ契約で利用できること、`adapted` はhost adapterを介して同じ成果を得ること、`degraded` は自動保証を縮退させ残余リスクを明記すること、`surface-specific` は片host固有であることを示す。

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
