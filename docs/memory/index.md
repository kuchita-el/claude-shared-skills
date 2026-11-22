# 索引

<!-- 検査器が生成する。手で編集しない。作り直すには index --write を使う。 -->

| 識別子 | 種類 | 主張 | 当てはまる条件 | 検証 |
|---|---|---|---|---|
| [MEM-202611211012-01](records/MEM-202611211012-01-handwritten-index-mismatch.md) | experience | 利用規則だけを読んだ別の AI が書いた記録は形式の検査を通り、手で書いた索引だけが、生成した索引と一致しなかった | shared-memory の利用規則・形式・索引の保ち方を変えるとき | verified |
| [MEM-202611211045-01](records/MEM-202611211045-01-task-memory-handoff-symbols.md) | experience | 別の文脈は Task Memory だけを読んで検証を引き継げたが、追跡していない計画の記号に頼る文は、そのファイルだけでは解けなかった | Task Memory の書き方と、Task Memory を読む手順を決めるとき | verified |
| [MEM-202611211114-12](records/MEM-202611211114-12-lint-ja-skips-code-blocks.md) | experience | 一文長の検査器はコードブロックの中を数えず、地の文に書いた長いコマンドは1文として数える | このリポジトリの文書を、一文長の検査（plugins/writing/scripts/lint-ja.mjs）に通すとき | verified |
| [MEM-202611211524-01](records/MEM-202611211524-01-subagent-effective-params-from-session-record.md) | experience | サブエージェントの定義の model と effort が効いたかは、子プロセスのセッションの記録で確かめられ、主のモデルを別の系列にすると出力の流れだけでも model を見分けられる | 配布プラグインのサブエージェントが、定義の front-matter どおりの水準で動いたかを確かめるとき | verified |
