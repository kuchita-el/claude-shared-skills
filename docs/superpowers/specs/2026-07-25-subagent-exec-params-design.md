# サブエージェント実行パラメータの統制方針（S1）

## 背景

モデル系統が Fable 5 / Opus 5 / Sonnet 5 / Haiku 4.5 へ更新された。これを機に、`dev-workflow` プラグインのサブエージェントとスキルについて、品質とトークン消費の観点からチューニングを行う。

現状は次のとおりである。

| 対象 | 現行の指定 |
|---|---|
| `code-reviewer` / `plan` / `plan-reviewer` / `test-designer` / `test-spec-validator` | `model: opus` |
| `refactorer` | `model: sonnet` |
| `refine-issue` 全件モード | 本文に「モデル: `sonnet`、最大3並列」と記述。`subagent_type` の指定はない |
| `refine-issue` 単件モード | 本文に「モデルは親と同じ」と記述。`subagent_type` の指定はない |
| `plan-issue` からの `plan-reviewer` 起動 | 本文に「モデルは定義の `inherit` に従う」と記述 |

`effort` はどの定義にも指定がない。また `plan-issue` の本文が述べる `inherit` は、`plan-reviewer` の定義が `model: opus` を持つため実体と食い違っている。

検討全体は次の3層に分かれる。本文書はこのうち S1 のみを対象とする。

- **S1 実行パラメータ層** — frontmatter の `model` / `effort`、スキル本文のモデル指定、`inherit` 記述の齟齬修正
- **S2 プロンプト適応層** — Opus 5 の挙動変化（冗長化・過剰な自己検証・過剰な委譲・作業範囲の拡張）に対する SKILL.md および agents 本文の改訂
- **S3 規律再設定層** — SKILL.md の行数規律と description 字数規律、`context-budget.md` の前提更新

## 解決したい課題

1. **配布先の環境によって挙動が変わる。** 本リポジトリの成果物は配布用プラグインであり、利用者の親セッションがどのモデル・どの effort で動いているかは不定である。`effort` が無指定である以上、各サブエージェントの思考深度は利用者側の設定に従属する。`code-reviewer` が低い effort で走って見落としを出した場合、それは利用者の設定ミスではなくプラグインの欠陥として現れる。
2. **前回のモデル選定の根拠が残っていない。** 現行の `opus` × 5 / `sonnet` × 1 という配分がどのような判断で決まったのかが記録されておらず、今回の検討は一から議論をやり直すことになった。モデル系統の更新は今後も繰り返されるため、根拠を残さなければ同じ議論が再発する。
3. **記述と実体の食い違いがある。** `plan-issue` の `inherit` 記述は実体と異なり、読み手を誤らせる。

## 前提となる仕様（一次情報で確認済み）

公式ドキュメントおよび Agent tool の定義で確認した事実を、設計判断の前提として記録する。

### frontmatter の表現力

`model` と `effort` はいずれも**上書き（固定）**であり、下限や上限を表す機構ではない。

| 項目 | 内容 |
|---|---|
| `model` の値域 | `sonnet` / `opus` / `haiku` / `fable` / 完全なモデル ID / `inherit`。既定は `inherit` |
| `effort` の値域 | `low` / `medium` / `high` / `xhigh` / `max`。既定はセッションからの継承 |
| `effort` の既定値 | `high`（Opus 4.7 のみ `xhigh`） |
| 未対応レベルの扱い | エラーにならず、直下の対応済みレベルへ切り下げられる |
| 対応レベル | Fable 5 / Opus 5 / Sonnet 5 は 5 段階すべてに対応。Haiku は effort 非対応 |
| プラグインでの制限 | プラグイン提供のサブエージェントで無効化されるのは `hooks` / `mcpServers` / `permissionMode` のみ。`model` と `effort` は有効 |

下限を表す機構は存在しない。組織単位の effort 上限は Enterprise 向けの管理者設定として存在するが、これは上限のみである。

### `effort` を指定できる経路

`effort` を指定できるのは frontmatter を持つ登録済みのサブエージェントまたはスキルに限られる。**Agent tool の引数に `effort` は存在しない**（引数は `description` / `isolation` / `model` / `prompt` / `run_in_background` / `subagent_type`）。

したがって `subagent_type` を指定せずに Agent tool を呼ぶ形では、`model` は引数で指定できても `effort` は親からの継承となり、制御できない。

### 上書きの優先順位

| 対象 | 優先順位（高い順） |
|---|---|
| `model` | `CLAUDE_CODE_SUBAGENT_MODEL` 環境変数 → 呼び出し時の `model` 引数 → frontmatter → 親セッションのモデル |
| `effort` | `CLAUDE_CODE_EFFORT_LEVEL` 環境変数 → frontmatter → セッション設定 → モデル既定 |

環境変数はいずれも frontmatter より優先される。また `max` はセッション限定で永続せず、環境変数経由でのみ持続する。

### プラグインサブエージェントの識別

プラグインのサブエージェントはスコープ付き識別子（`dev-workflow:code-reviewer`）で登録される。利用者がプロジェクト側に同名のファイルを置いても識別子が異なるため衝突せず、別のエージェントとして共存する。同名による上書きの経路は存在しない。

### スキル frontmatter

SKILL.md も `model` / `effort` / `context: fork` / `agent` を受け付ける。ただし `model` と `effort` の効果は「そのターンの残り」に限られ、次のプロンプトでセッション値へ戻る。`context: fork` はスキル本文をサブエージェントの指示として実行するもので、会話履歴を参照できず、既定では背景実行となり、利用できるツールも縮小される。

## 決定

### 決定1: 実行パラメータを固定値で明示し、値を必要最小水準として選ぶ

全サブエージェント定義に `model` と `effort` を明示する。値は、その役割が成立するために必要な最小水準として選ぶ。

frontmatter が表現できるのは固定値のみであり、必要最小水準を保証しようとすれば、それを上回る設定で動かしている利用者を引き下げる副作用が避けられない。この副作用は次の理由から許容する。

- 常に高い設定で動かしている利用者は環境変数を用いているはずであり、環境変数は frontmatter より優先されるため影響を受けない。
- `max` はセッション限定で永続しないため、影響を受けるのは「そのセッションで `/effort max` を選び、かつサブエージェントを起動した」場合に限られる。

サブエージェントは役割の狭い専用の実行単位であり、必要な思考深度は役割の側で決まる。セッションの effort は利用者が今どのような作業をしているかを表す値であって、そのサブエージェントが何をすべきかを表す値ではない。両者を連動させる積極的な理由がない。

### 決定2: 割り当て値

| 対象 | 意図 | `model` | `effort` | 根拠 |
|---|---|---|---|---|
| `plan` | 必要最小水準 | `opus` | `xhigh` | 探索と設計を伴う自律的な生成であり、思考の深さが最も効く。公式指針が coding および agentic 用途に `xhigh` を推奨する領域に当たる |
| `code-reviewer` | 必要最小水準 | `opus` | `high` | 独立した検証であり、見落としの少なさが価値になる。`high` が既定であり、知的能力と消費の均衡点である |
| `plan-reviewer` | 必要最小水準 | `opus` | `high` | 同上。読み取り中心で探索性は低い |
| `test-spec-validator` | 必要最小水準 | `opus` | `high` | 同上 |
| `test-designer` | 必要最小水準 | `opus` | `high` | 要件からテストケースへの変換であり、`plan` ほどの探索性はない |
| `refactorer` | 必要最小水準 | `sonnet` | `high` | 振る舞いの保持を判断しながら進めるため機械的作業には該当しない。Sonnet 5 の coding 能力で必要水準に届く |
| `issue-refiner`（新設） | **許容最大水準** | `sonnet` | `medium` | DoR 照合が主で定型性が高い。全件モードでは 15 件 × 最大 3 並列と量が出るため、上限を設ける効果が最も大きい |

`issue-refiner` のみ意図が逆になる。ここは値を「許容する最大水準」として選び、利用者が高い設定で動かしていても抑制する。

### 決定3: `refine-issue` 用の専用サブエージェント定義を新設する

`refine-issue` は現在 `subagent_type` を指定せず Agent tool を直接呼んでおり、既定の general-purpose で動く。Agent tool の引数に `effort` がないため、この形では決定2の `medium` を実現できない。

`plugins/dev-workflow/agents/issue-refiner.md` を新設し、`model: sonnet` / `effort: medium` を持たせて `subagent_type: dev-workflow:issue-refiner` で起動する形に改める。

精査手順は既に `references/refine-prompt.md` にあり、プロンプトもメイン側で組み立てているため、定義本文は薄く保つ。役割と参照先の明示に留め、手順を二重に書かない。

副次的な利点として `tools` を読み取り専用に絞れる。現状の general-purpose は全ツールを持つが、精査は Issue の JSON と DoR 定義、出力形式テンプレートを読むだけで足りる。権限の最小化は CLAUDE.md の `allowed-tools` の原則にも沿う。具体的なツール一覧は `refine-prompt.md` の手順を確認したうえで実装時に確定する。

単件モードと全件モードは同一の精査作業であるため、件数の違いによらず同じ定義を用いる。これにより単件モードの「モデルは親と同じ」という記述も解消される。

### 決定4: Fable 5 を採らない

現行の役割はいずれも単発の生成または検証であり、Fable 5 が想定する長時間の自律実行には該当しない。100 万トークンあたり入力 10 ドル・出力 50 ドルという価格を配布先に強制する正当化が立たない。

Fable 5 を用いたい利用者は `CLAUDE_CODE_SUBAGENT_MODEL` で全サブエージェントを切り替えられる。この手段を README で案内する。

### 決定5: `maxTurns` を採らない

`maxTurns` は暴走時のトークン上限として機能するが、適正値を決める根拠が現時点で存在しない。値が低すぎれば処理の途中終了として現れ、これは消費の削減ではなく品質の劣化である。観測手段を持たない状態で上限を置くのは、得られる削減より品質劣化の危険が大きい。

将来、実行時間やターン数の観測手段を得た段階で再検討する。

### 決定6: 実行パラメータの統制点をサブエージェント側に集約する

SKILL.md の frontmatter には `model` と `effort` を置かない。理由は 3 つある。

1. **効果の範囲がターン単位である。** `create-issue` / `domain-modeling` / `event-storming` / `plan-issue` / `manage-adr` / `intake` / `implementation` は対話や承認の待ち合わせで複数のターンにまたがるため、最初のターンにしか効かない。一貫した統制にならない。
2. **効果がメイン側の軽量な処理に限られる。** サブエージェント側を明示的に固定したことにより、スキルの `model` 指定はサブエージェントの実行には届かない（解決順で frontmatter が優先される）。残るのはバッチ分割・結果集約・整形といった処理であり、ここを下げても削減幅は小さい。
3. **統制点の分散は追跡コストを生む。** 同じ種類の値がサブエージェント側とスキル側の 2 箇所に散ると、どちらが効いているかの追跡が難しくなる。

### 決定7: `context: fork` は S1 の範囲外とする

`context: fork` はメイン側の文脈消費を抑える手段であり、実行パラメータではなく文脈設計の論点に属する。`context-budget.md` が扱ってきた領域と重なる。

会話履歴を参照できないという制約により、`AskUserQuestion` を用いるスキル（`create-issue` / `domain-modeling` / `event-storming` / `plan-issue` / `manage-adr` / `intake`）と承認ゲートを持つ `implementation` は適用外となる。候補として残るのは `dependency-check` 程度であり、S1 の主目的に対する寄与が小さい。S3 または独立した課題として扱う。

## 変更対象

| # | 変更内容 | 対象 |
|---|---|---|
| 1 | `model` と `effort` を明示（決定2の表に従う） | `plugins/dev-workflow/agents/` 配下の既存 6 ファイル |
| 2 | 新規作成。`model: sonnet` / `effort: medium`、読み取り専用のツール指定、役割と参照先の明示 | `plugins/dev-workflow/agents/issue-refiner.md` |
| 3 | 単件・全件とも `subagent_type: dev-workflow:issue-refiner` での起動に改める。モデル指定と「モデルは親と同じ」の記述を削除 | `plugins/dev-workflow/skills/refine-issue/SKILL.md` |
| 4 | `inherit` 記述を実体に合わせて修正 | `plugins/dev-workflow/skills/plan-issue/SKILL.md` |
| 5 | 新規作成。最小構成の導入と「サブエージェントの実行パラメータ」節 | `plugins/dev-workflow/README.md` |
| 6 | 決定と根拠の記録 | `docs/adr/` |

`growth` プラグインはサブエージェント定義を持たずスキルのみで構成されるため、決定6により S1 の対象外となる。`adr` プラグインも同様である。

### README に記載する内容

`plugins/dev-workflow/README.md` は新規作成となる。`plugins/adr/README.md` が既に存在するため、プラグイン単位の README は本リポジトリの既存の運用に沿う。

S1 の主目的は実行パラメータの調整であり、README はその付随物である。プラグイン全体の紹介を書き起こすと作業が膨らむため、新規 README は次の内容に絞る。

- プラグインの概要（数行）
- サブエージェントごとの `model` / `effort` と、その値を選んだ意図（必要最小水準か許容最大水準か）
- `CLAUDE_CODE_SUBAGENT_MODEL` および `CLAUDE_CODE_EFFORT_LEVEL` による上書き手段と、それが frontmatter より優先されること

## 検証項目

### 配布先の環境に依存しないこと

利用者側の設定を変えて起動し、サブエージェントが frontmatter の指定値で動くことを確認する。

| 観点 | 期待する挙動 |
|---|---|
| 親を Sonnet 5 で起動 | `plan` などは frontmatter に従い `opus` で動く |
| 親を `low` effort で起動 | サブエージェントは frontmatter の指定値で動き、`low` に引きずられない |
| 親を Haiku で起動 | 同上。切り下げは発生しない |
| `CLAUDE_CODE_EFFORT_LEVEL` を設定 | frontmatter より優先され、全サブエージェントがその値で動く |
| `CLAUDE_CODE_SUBAGENT_MODEL` を設定 | frontmatter より優先され、全サブエージェントがそのモデルで動く |

### `issue-refiner` の精査品質

同一の Issue に対して変更前後で精査を実行し、次を確認する。

- DoR の不足項目として検出される項目の集合が、変更前と一致すること。差分がある場合は、その項目が実際に不足しているかを人手で確認する
- 出力形式（`output-format-single.md` および `output-format-batch-subagent.md`）に沿った構造で返却されること
- 読み取り専用のツール指定で手順が完走すること

### `issue-refiner` の起動経路

- 単件モードと全件モードの双方で `subagent_type: dev-workflow:issue-refiner` が解決され、起動に失敗しないこと
- 全件モードで最大 3 並列の制約が維持されること

## 却下した案

| 案 | 却下理由 |
|---|---|
| `model: inherit` として親セッションに追随させる | 配布物であり親の設定が不定であるため、検証系のサブエージェントが Haiku で動く可能性を排除できない。Haiku は effort 非対応かつ文脈長が 20 万トークンに留まる |
| `effort` を指定せずセッション継承のままにする | 課題1（配布先の環境によって挙動が変わる）が解決しない |
| 判断・検証系のみ `effort` を継承のままにし、機械的作業にのみ低い値を固定する | 高価なモデルを浅い思考で動かす組み合わせが生じ、消費の効率が最も悪い状態になる |
| 全サブエージェントで `model` を揃え `effort` のみで差をつける | モデル間の単価差を取り逃す |
| `refine-issue` は専用定義を作らず、Agent tool の `model` 引数のみで `sonnet` を指定する | `effort` を制御できず、量が最も出る役割が課題1を抱えたまま残る |

## ADR 化の判定

粒度判定基準の 4 項目に照らした結果は次のとおりである。

| 項目 | 判定 | 理由 |
|---|---|---|
| 後戻りコストが高い | 非該当 | frontmatter の値は 1 行で戻せる |
| 複数モジュール・複数開発者に波及する | 該当 | 7 エージェントと 2 スキル、README に及び、配布先の全利用者に波及する |
| 採用理由が時間経過で揮発しやすい | 該当 | 今回の検討自体、前回のモデル選定の根拠が残っておらず一から議論をやり直すことになった |
| ツールで自動強制できない | 該当 | 値が必要最小水準として妥当かを機械的に検証する手段がない |

3 点であり、ADR 化を推奨する水準に達する。加えてモデル系統の更新は再発が確実であり、「他の機能でも同じ問いが出てきた時点で昇格させる」という起票タイミングの条件を今回すでに満たしている。

決定 1 から 7 は同一の論点から導かれる一連の帰結であるため、ADR は 1 本にまとめ、決定 4・5・6・7 は却下または見送りの判断として本文に含める。

## 範囲外

- S2 プロンプト適応層。Opus 5 の挙動変化に対する SKILL.md および agents 本文の改訂
- S3 規律再設定層。SKILL.md の行数規律と description の字数規律、`context-budget.md` の前提更新
- `context: fork` の導入検討（決定7）
- `growth` プラグインおよび `adr` プラグイン
