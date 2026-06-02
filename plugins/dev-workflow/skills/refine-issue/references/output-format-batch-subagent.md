<!--
このファイルは refine-issue スキルの 全件モードにおけるサブエージェント返却形式テンプレート。
SKILL.md 手順3 において全件モードのサブエージェントが自身で Read し、refine-prompt.md の {OUTPUT_FORMAT} プレースホルダ位置に適用する形で出力形式として運用する。
スキル側（メイン）はサブエージェントの返却を集約し、output-format-batch.md の最終出力形式に変換する。
このコメントブロックを除く以下の本文をテンプレートとして遵守すること。
-->

各Issueについて以下のフィールドを持つ構造化データとして結果を返してください。形式は YAML / JSON など機械的に集約可能な構造であれば任意。

- `number`: Issue番号
- `title`: タイトル
- `size`: Small / Medium / Large（判定不能時は `-`）
- `is_ready`: true / false
- `clarification_items`: 確認事項のリスト（なければ空配列）

精査対象Issueが複数の場合、各Issueのオブジェクトを配列で返すこと。
