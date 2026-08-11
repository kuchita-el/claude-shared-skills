# Claude / Codex 両対応プラグインの再編設計

## 1. 概要

本リポジトリのプラグインを、Claude Code と Codex の双方へチーム向け marketplace から配布できる形へ再編する。

目標は、両ホストからインストールできる外形だけを揃えることではない。同じスキルが両ホストで同じ成果契約を満たし、ホスト固有機能を使う箇所では差分と縮退動作が明示され、リリース前に機械検証できる状態を目指す。

この再編では、肥大化の兆候がある `dev-workflow` を能力単位へ分割する。`growth` は Claude Code の session JSONL と個人ローカル store への依存が強く、今回のチーム向け両対応化から除外する。

## 2. 目的

1. Claude Code と Codex のチーム向け marketplace から各プラグインを導入できるようにする。
2. ワークフローの判断規則を一つの共有コアで管理し、ホスト差分による規則のドリフトを防ぐ。
3. `dev-workflow` を独立して理解・導入・検証できる能力境界へ分割する。
4. 本リポジトリ自身で有用なプラグインから dogfood し、後続移行の不確実性を段階的に減らす。
5. 「両対応完了」の判定を、全チェック項目を列挙する適合性検査で行えるようにする。

## 3. 非目的

- OpenAI の universal plugin directory への公開申請
- `growth` の Codex 対応
- Claude Code と Codex の内部機構を同一にすること
- 初回再編で `implementation` を複数スキルへ細分化すること
- 既存の全設計判断や参照文書を一括して書き直すこと
- MCP server や独自 UI の新設

## 4. 現状と問題

### 4.1 既にある基盤

- 各プラグインに `.codex-plugin/plugin.json` がある。
- `.agents/plugins/marketplace.json` に Codex marketplace が定義されている。
- `run-codex-local.sh` にローカル導入経路がある。
- スキルは `skills/<skill-name>/SKILL.md` を中心に、`references/` と `scripts/` を伴う構造になっている。
- ADR の採番、lint、index 生成は決定的なスクリプトとして分離されている。
- 配布物と配布元の参照方向は `docs/distribution-boundary.md` で規定されている。

### 4.2 解消すべき問題

現在の Codex 対応はパッケージ外形が中心であり、スキル本文と参照文書には次の Claude 固有概念が残る。

- `allowed-tools`
- `AskUserQuestion`
- `Agent tool` と `subagent_type`
- `Skill` tool による他スキル呼び出し
- `${CLAUDE_SKILL_DIR}` と `${CLAUDE_PLUGIN_ROOT}`
- `.claude/` 配下のプロジェクト設定
- Claude Code 固有の hook イベント
- Claude Code 固有の session JSONL

また、Claude manifest の `dev-workflow` は `0.8.0`、Codex manifest は `0.7.0` であり、同じプラグインのmetadataが既にドリフトしている。manifestとmarketplaceを別々に手編集する方式は維持しない。

`dev-workflow` は、Issue管理、ドメイン設計、依存更新調査、実装、PR、CI、レビュー対応、サブエージェント統制を一つの配布単位に含む。発火条件、外部依存、権限、成果物、変更頻度が異なる能力が同居しており、移植と回帰検証の単位として大きすぎる。

## 5. 設計案の比較

### 案A: 現在のプラグイン境界を維持して記法だけを置換する

短期の変更量は小さい。しかし、ホスト分岐が各 `SKILL.md` へ入り、`dev-workflow` の肥大化とmetadataのドリフトを残す。次のホスト仕様変更で同じ問題が再発するため採用しない。

### 案B: Claude版とCodex版を完全に複製する

各ホストへ最大限最適化できる。一方で、DoR、完了判定、ADR状態遷移、レビュー契約などの重要規則が二重管理になる。片方だけが修正される不具合を静的に防げないため採用しない。

### 案C: 能力単位のパッケージ、共有コア、薄いホストアダプタ、生成された配布物

初期に生成・検証基盤が必要になるが、ワークフロー規則を一元化しながら、ホストごとのツール・対話・権限・hook差分を局所化できる。小さい能力から段階移行でき、チーム向け配布とdogfoodの両方に適するため採用する。

## 6. 採用アーキテクチャ

### 6.1 レイヤ

各プラグインを次の3層で構成する。

1. **Workflow core**: 発火条件、入力、判断規則、状態遷移、成功条件、停止条件、成果物schemaを持つ。
2. **Host adapter**: Claude Code / Codex の対話、ツール、権限、サブエージェント、パス、hookへworkflow上の操作を写像する。
3. **Distribution**: 一つのmetadataから各manifestとmarketplace entryを生成し、ホストごとの配布物を組み立てる。

同一性の対象は内部操作ではなく成果契約とする。例えば、独立レビューをClaude Codeでは登録済みサブエージェント、Codexでは別エージェントまたは独立したレビュー文脈で実現してよい。両方が同じレビュー項目と出力schemaを満たせば適合とする。

### 6.2 リポジトリ構成

目標構成は次のとおりとする。移行中は既存の `plugins/` と共存し、各Waveで一つずつ切り替える。

```text
claude-shared-skills/
├── packages/
│   ├── adr/
│   ├── writing/
│   ├── issue-workflow/
│   ├── domain-design/
│   ├── dependency-insight/
│   └── delivery-workflow/
├── shared/
│   ├── contracts/
│   ├── schemas/
│   └── test-support/
├── adapters/
│   ├── claude/
│   └── codex/
├── marketplaces/
│   ├── claude.json
│   └── codex.json
├── dist/
│   ├── claude/
│   └── codex/
├── tests/
│   ├── contracts/
│   ├── fixtures/
│   ├── claude/
│   └── codex/
└── tools/
    ├── build-plugins
    ├── lint-skills
    └── verify-marketplaces
```

`dist/` は生成物であり、正本にしない。チーム向けmarketplaceがリポジトリ内のソースパスを直接要求する場合は、生成検査後のpackageディレクトリを配布元として使い、同内容を二重にコミットしない。採用するCLIの実際の探索規則に合わせ、実装計画時に生成先とcommit対象を確定する。

### 6.3 パッケージ内部

```text
packages/adr/
├── plugin.yaml
├── skills/
│   └── manage-adr/
│       ├── SKILL.md
│       ├── references/
│       │   ├── policy/
│       │   ├── procedure/
│       │   ├── schema/
│       │   ├── examples/
│       │   └── platform/
│       ├── scripts/
│       ├── assets/
│       └── tests/
├── hooks/
└── README.md
```

`plugin.yaml` を名前、version、説明、category、capability、skill一覧の正本とする。次を生成対象とする。

- `.claude-plugin/plugin.json`
- `.codex-plugin/plugin.json`
- Claude marketplace entry
- Codex marketplace entry
- READMEのプラグイン一覧

manifestとmarketplaceの直接編集は検査で拒否する。

## 7. スキル設計規約

### 7.1 `SKILL.md`

`SKILL.md` は次だけを持つ。

- 発火条件を明確にした `name` と `description`
- 入力契約
- ワークフローの大きな段階
- 停止、質問、明示承認の条件
- 成功条件
- 必要な参照ファイルの読み分け

次は置かない。

- 特定ホストのツール名
- 特定ホストだけの環境変数
- 長いコマンド許可リスト
- 詳細schemaや大量の例
- サブエージェントの起動API
- ホスト固有の設定ディレクトリ

### 7.2 supporting resources

`references/` は内容の性質で分ける。

- `policy/`: 判断基準、不変条件、禁止事項
- `procedure/`: 詳細な実行手順、分岐、復旧
- `schema/`: front-matter、成果物、状態機械
- `examples/`: 入出力例、境界例
- `platform/`: 共有表現で吸収できないホスト差分のみ

テンプレートとしてコピー・変換するファイルは `assets/` へ置く。決定的な計算、正規化、lint、schema検証は `scripts/` へ置く。モデル判断をスクリプトへ隠さない。

### 7.3 ホスト中立の操作語彙

共有コアでは、ホストAPIではなく意味上の操作を記述する。

| 意味上の操作 | Claude Codeでの候補 | Codexでの候補 |
|---|---|---|
| ユーザーの明示承認を得る | 対話ツールまたは通常質問 | 対話ツールまたは通常質問 |
| 独立レビュー文脈を起動する | Agent / subagent | agent delegationまたは独立レビュー |
| 別能力へ委譲する | Skill invocation | skill invocation |
| スキル同梱資産を解決する | Claude環境変数 | Codexが提供するskill pathまたは相対解決 |
| commit前に検査する | PreToolUse hook | Codex hookまたは明示ゲート |

実装計画では、各候補が現行CLIで利用可能かを確認してadapter契約を確定する。利用不能な場合は暗黙に省略せず、縮退動作を定義する。

## 8. 互換性レベル

各機能は次のいずれかを宣言する。

- `portable`: 同じworkflow coreを追加分岐なしで実行できる。
- `adapted`: ホストごとに実現方法は異なるが、同じ成果契約を満たす。
- `degraded`: 一方のホストで一部保証が弱くなるが、縮退内容と代替検証を明示する。
- `surface-specific`: 特定ホストだけで提供し、他方では非対応と明示する。

プラグインごとにcompatibility matrixを公開する。`degraded` または `surface-specific` を隠したまま「完全両対応」と表現しない。

## 9. プラグイン境界

### 9.1 `adr`

- `manage-adr`
- ADR状態・遷移・相互参照規約
- 採番、index生成、lint
- 利用可能なホストでのcommit gate

### 9.2 `writing`

- `review-japanese-document` を新設する。
- 日本語文書の共通品質規約
- 文書種別プロファイル

現状のように参照ファイルだけを配るのではなく、単独で明示・暗黙発火できる利用者ゴールを持たせる。他プラグインは `writing` のインストールを暗黙の必須条件にせず、必要な不変条件を自パッケージ内で完結させる。

### 9.3 `issue-workflow`

- `create-issue`
- `refine-issue`
- `plan-issue`
- DoR、Issue種別、planレビュー契約

Issueの作成、準備判定、実装可能な計画への変換という一つのライフサイクルとしてまとめる。

### 9.4 `domain-design`

- `event-storming`
- `domain-modeling`
- ドメイン成果物のschemaとlint

GitHub Issueや実装ループから独立させる。

### 9.5 `dependency-insight`

- `dependency-check`
- package ecosystem別の調査規約
- 互換性、breaking changes、更新順序の出力契約

更新実行を行わない分析専用プラグインとする。

### 9.6 `delivery-workflow`

- 当初は現在の `implementation` を一つのスキルとして移す。
- 実装、検証、レビュー、CI、PR、エスカレーションの接続契約を持つ。
- Superpowersなど他プラグインへの依存は、必須・任意・縮退動作をmetadataと本文で明示する。

`implement-change`、`respond-to-review`、`prepare-pr` への追加分割は、移行後の発火衝突、context量、変更頻度の実測を得てから別判断とする。

## 10. 移行順序

優先度は次の積で決める。

1. 本リポジトリでのdogfood価値
2. ホスト固有依存の少なさ
3. 後続プラグインの基盤になる度合い
4. 成果を機械検証しやすい度合い

### Wave 0: 生成・検証基盤

- `plugin.yaml` schema
- manifestとmarketplace生成
- portable skill lint
- 壊れた参照と配布境界の検査
- ホスト固有語の禁止・許可領域検査
- package単位のtest runner
- Claude/Codexローカル起動経路の対称化
- compatibility matrixのschema

個別移植より先に行い、各プラグインが別の互換方式を発明することを防ぐ。

### Wave 1: ADR

最初の適合例とする。このリポジトリで利用頻度が高く、front-matter、index、lint exit codeで結果を観測でき、決定的処理も既にスクリプト化されている。

初回はスキル操作と明示lintを必須契約にする。commit hookが一方で利用できない場合は、明示ゲートを縮退動作としてcompatibility matrixへ記録する。

### Wave 2: Writing

ADR、Issue、設計文書のdogfoodに使える `review-japanese-document` を成立させる。以後の移行文書もこのスキルで検証できるようにする。

### Wave 3: Issue Workflow

次の順で適合させる。

1. `create-issue`
2. `refine-issue` 単件
3. `plan-issue`
4. `refine-issue` バッチ・並列

対話、DoR、成果物契約を単件で固めてから、ホスト差分の大きいサブエージェント並列へ進む。

### Wave 4: Domain Design

`event-storming` と `domain-modeling` を移す。成果物がMarkdownであり、既存の `docs/big-picture.md` などを回帰fixtureとして利用しやすい。

### Wave 5: Dependency Insight

公式情報へのアクセス、引用、鮮度確認などの外部依存があるため、両ホストの検索・出典契約を確立した後に移す。

### Wave 6: Delivery Workflow

最後に `implementation` を移す。編集、Git、GitHub、CI監視、サブエージェント、他スキル委譲、承認、worktree、完了判定というホスト差分が集中しているため、先行Waveでadapterと検査方式を実証してから着手する。

### Wave 7: 旧 `dev-workflow` の廃止

- 旧plugin IDから新plugin群への対応表を公開する。
- 一定期間は旧manifestをdeprecated aliasまたは案内専用として残す。
- チーム利用者の移行確認後にmarketplaceから外す。
- 未移行項目を別Issueへ切り出して旧pluginを完了扱いにする場合は、利用者の明示承認を得る。

## 11. テスト戦略

### 11.1 静的検査

- manifest schema
- plugin versionの一致
- plugin名とskill名の一意性
- marketplaceとpackageの双方向一致
- 壊れた相対参照
- 配布物から配布元への逆参照
- workflow core内の未許可ホスト固有語
- `SKILL.md` の必須metadata
- descriptionの発火条件と境界
- 生成物が正本metadataから再生成可能であること

### 11.2 契約fixture

各スキルの代表ケースを次の形で持つ。

```text
tests/cases/create-basic-adr/
├── input.md
├── workspace-before/
├── expected-files/
└── assertions.yaml
```

自然文全文の一致は要求しない。次を検査する。

- 必須成果物の存在
- schemaと状態遷移
- 全判定項目の列挙
- 未解決項目がある場合のNot Ready / 未完了判定
- 明示承認なしで禁止された変更を行わないこと
- 必須検証コマンドの結果
- 既存ファイルの保全

### 11.3 ホスト別smoke test

Claude CodeとCodexで同じ代表ケースを実行し、共通assertionへ通す。ツール呼び出し列や文章表現の一致は求めず、成果契約の一致を求める。

ネットワークやGitHub状態に依存するケースは、純粋なfixture検査と実環境smoke testを分ける。実環境テストが未実施の場合に全体を緑と表示しない。

## 12. リリースとチーム配布

1. packageごとに独立versionを持つ。
2. metadataから両ホストのmanifestとmarketplaceを生成する。
3. 静的検査、契約fixture、両ホストsmoke testを実行する。
4. compatibility matrixを更新する。
5. 変更されたpackageだけをリリースする。
6. チーム向けmarketplaceで新versionを利用可能にする。
7. 既存versionからの移行・破壊的変更をrelease noteへ記載する。

リポジトリ全体を一つのversionで更新しない。能力単位の変更と配布単位を揃える。

## 13. 完了判定

一つのプラグインを「Claude / Codex 両対応」と判定するには、次の全項目を1件ずつ評価し、すべて合格していなければならない。

- [ ] Claude marketplaceから導入できる。
- [ ] Codex marketplaceから導入できる。
- [ ] 代表的な明示呼び出しが両ホストで成功する。
- [ ] 代表的な暗黙発火が両ホストで成功する。
- [ ] 全契約fixtureが両ホストの成果物に対して合格する。
- [ ] `degraded` / `surface-specific` 機能がcompatibility matrixに明記される。
- [ ] manifestとmarketplaceが一つのmetadataから生成される。
- [ ] workflow coreに未許可のホスト固有依存がない。
- [ ] package単体で配布先から全参照を解決できる。
- [ ] 既存利用者向けの移行経路と破壊的変更が記録される。
- [ ] packageのREADMEが導入方法、能力、権限、縮退動作を説明する。
- [ ] リリース対象versionで両ホストsmoke testの証拠が残る。

保留または不合格が1件でもあれば、全体を未完了とする。残項目を別Issueへ切り出して当該pluginを完了扱いにする場合は、実行前に利用者の明示承認を得る。

## 14. 最初の実装単位

最初の実装Issueは次の一単位とする。

> 両対応プラグインのmetadata生成・適合性検証基盤を作り、ADRプラグインを最初の適合例としてClaude CodeとCodexの双方で契約検証する。

このIssueに含めるもの:

- `plugin.yaml` とschema
- manifest / marketplace生成
- portable skill lint
- compatibility matrix
- ADRのパス、対話、ツール表現のhost adapter化
- ADRの契約fixture
- Claude Code / Codex smoke test
- 既存手書きmanifestからの移行

含めないもの:

- Writing以降のplugin移行
- universal plugin directoryへの公開
- `growth` 対応
- `implementation` の再設計

## 15. リスクと対策

### 15.1 生成層が新たな複雑性になる

生成対象をmanifest、marketplace、一覧のみに限定する。`SKILL.md` 本文全体をテンプレート生成しない。workflow coreは人間が直接読めるMarkdownを正本にする。

### 15.2 ホスト差分の抽象化が最低共通機能化を招く

互換性レベルを `portable` だけに限定しない。`adapted` と明示的な `degraded` / `surface-specific` を許容し、強い機能を失わず差分を公開する。

### 15.3 プラグイン分割で利用者の導入負担が増える

marketplaceに推奨bundleまたは一括導入runnerを用意する。依存は暗黙化せず、package metadataで宣言する。

### 15.4 二つのホストを使うE2Eが不安定になる

決定的な契約fixtureを主検査とし、host smoke testは代表ケースに絞る。外部状態依存の失敗と成果契約違反を別々に報告する。

### 15.5 移行中に旧・新pluginの発火が競合する

同じskill名を旧pluginと新pluginから同時配布しない。Waveごとにmarketplace entry、runner、READMEを同時に切り替え、旧plugin側には非重複の移行案内だけを残す。

## 16. 判断を後続へ委ねる項目

以下は設計の欠落ではなく、実装時に現行CLI仕様と実測を入力として決める項目である。

1. `plugin.yaml` の実装形式と生成ツールの言語
2. `dist/` をcommitするか、検証時だけ生成するか
3. Codexのskill/plugin root解決を相対パスだけで統一できるか
4. Codex hookでClaude Codeのcommit gateと同等保証を持てるか
5. Codexサブエージェント定義をpackage内へ同梱する正式形式
6. 旧 `dev-workflow` のdeprecated aliasをmarketplaceが許容するか

これらは最初の実装計画で調査項目として全件列挙し、各問いを「解いた」「推移的に決定済み」「前提消滅」「未決」のいずれかへ決着させる。未決が残る場合、Wave 0完了とは判定しない。

## 17. 参照

- OpenAI Developers, Plugin architecture: https://developers.openai.com/plugins/concepts/plugins
- OpenAI Developers, Build skills: https://developers.openai.com/plugins/build/skills
- OpenAI Developers, Package your plugin: https://developers.openai.com/plugins/build/plugins
- `docs/distribution-boundary.md`
- `plugins/dev-workflow/references/completion-judgment.md`
- `scripts/run-tests.sh`
