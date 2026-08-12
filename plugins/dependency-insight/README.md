# dependency-insight

依存パッケージ更新のBreaking Changes、互換性、コード影響、更新順序を分析する単体配布プラグインです。

`dependency-check` とそのnpm referenceだけを配布し、更新実行や無関係なコード変更は行いません。Claude Code と Codex の明示呼び出しを検証します。Web参照や同等の調査面が利用できない場合は、証拠不足として `degraded` に留めます。

Wave 4で `dev-workflow` から履歴保持移設しました。旧 `dev-workflow:dependency-check` の呼び出しは `dependency-insight:dependency-check` へ移行してください。
