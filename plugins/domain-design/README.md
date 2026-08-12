# domain-design

イベントストーミングと関数型ドメインモデリングを単体で配布するプラグインです。

両skillは自身の references だけを参照し、実行時に dev-workflow、agent、リポジトリ固有データへ依存しません。Claude Code と Codex の両方で明示呼び出しを検証します。Codexで独立reviewer等が利用できない場合は、各skillの手動確認ルールに従う `degraded` 運用です。

Wave 4で `dev-workflow` から履歴保持移設しました。旧 `dev-workflow:event-storming` / `dev-workflow:domain-modeling` の呼び出しは `domain-design:<skill>` へ移行してください。
