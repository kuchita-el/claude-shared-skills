# Claude / Codex 両対応プラグインの再編設計

## 1. 概要

本リポジトリのプラグインを、Claude Code と Codex の双方へチーム向け marketplace から配布できる形へ再編する。

目標は、両ホストからインストールできる外形だけを揃えることではない。同じスキルが両ホストで同じ成果契約を満たし、ホスト固有機能を使う箇所では差分と縮退動作が明示され、リリース前に機械検証できる状態を目指す。

`plugins/<name>/` を編集上の正本かつそのまま配布する成果物とする。編集用 `packages/`、生成用 `dist/`、共有規約の生成コピーは設けない。`dev-workflow` は共有規約とサブエージェントの凝集を保つ中核を残し、独立性の高い能力だけを別プラグインへ分離する。`growth` は今回の対象から除外する。

## 2. 目的

1. Claude Code と Codex のチーム向け marketplace から各プラグインを導入できるようにする。
2. ワークフローの判断規則を一つの配布プラグイン内で単一出典として管理する。
3. `dev-workflow` から独立性の高い能力を分離し、共有規約やagentsを跨ぐ過分割を避ける。
4. 本リポジトリ自身で有用なプラグインからdogfoodし、後続移行の不確実性を段階的に減らす。
5. 「両対応完了」を成果、権限、配布、検証の全項目を列挙する適合性検査で判定する。

## 3. 非目的

- OpenAIのuniversal plugin directoryへの公開申請
- `growth` のCodex対応
- Claude CodeとCodexの内部機構を同一にすること
- 編集用ソースと配布用成果物を別ディレクトリへ分けること
- manifestやスキル本文を生成するビルドシステム
- MCP serverや独自UIの新設
- `implementation` の複数スキルへの分割

## 4. 現状と問題

### 4.1 既にある基盤

- 各プラグインに `.codex-plugin/plugin.json` がある。
- `.agents/plugins/marketplace.json` にCodex marketplaceが定義されている。
- `.claude-plugin/marketplace.json` にClaude marketplaceが定義されている。
- `run-codex-local.sh` と `run-claude-local.sh` にローカル導入経路がある。
- スキルは `skills/<skill-name>/SKILL.md` を中心に、`references/` と `scripts/` を伴う。
- ADRの採番、lint、index生成は決定的なスクリプトとして分離されている。
- 配布物と配布元の参照方向は `docs/distribution-boundary.md` で規定されている。

### 4.2 解消すべき問題

現在のCodex対応はパッケージ外形が中心であり、スキル本文と参照文書には次のClaude固有概念が残る。

- `allowed-tools`
- `AskUserQuestion`
- `Agent tool` と `subagent_type`
- `Skill` toolによる他スキル呼び出し
- `${CLAUDE_SKILL_DIR}` と `${CLAUDE_PLUGIN_ROOT}`
- `.claude/` 配下のプロジェクト設定
- Claude Code固有のhookイベント

Claude manifestの `dev-workflow` は `0.8.0`、Codex manifestは `0.7.0` である。二つのmanifestを手編集すること自体ではなく、不一致を拒否する検査がないことが問題である。

`dev-workflow` はIssue管理、ドメイン設計、依存更新調査、実装、PR、CI、レビュー対応を含む。ただし、単純にスキルごとへ分割すると、次の共有資産がプラグイン境界を跨ぐ。

- `behavior-invariants.md`: 全スキルと一部agentsが参照する。
- `completion-judgment.md`: `refine-issue` と `implementation` が参照する。
- `plan-location-resolution.md`: `plan-issue` と `implementation` が参照する。
- `agents/`: Issue精査、計画、レビュー、実装支援の役割を含む。

この依存を無視した分割は、単一出典、配布物の自己完結、既存agent名前空間を同時に壊す。

## 5. 設計案の比較

### 案A: 現在のプラグイン境界を維持して記法だけを置換する

短期の変更量は小さいが、`dev-workflow` の異なる能力と変更頻度を一つの配布単位に残す。ホスト差分を既存ファイルへ足すだけになりやすいため採用しない。

### 案B: Claude版とCodex版、または編集用と配布用を別成果物にする

各ホストへ最適化できる一方、生成、同期、テスト対象、参照パスの新しい複雑性を持ち込む。今回の成果物はMarkdown、JSON、shellが中心であり、コンパイル済み成果物を必要としない。生成コピーで共有規約を配る方式も同じ同期問題を抱えるため採用しない。

### 案C: `plugins/` を正本兼配布物とし、依存の凝集に沿って限定的に分割する

既存の配布構造を保ち、manifest間の整合は生成ではなくlintで保証する。共有規約とagentsを使う中核は `dev-workflow` に残し、依存の薄いドメイン設計と依存更新分析だけを分離する。構造変更を抑えながら責務を明確化できるため採用する。

## 6. 採用アーキテクチャ

### 6.1 配布単位

`plugins/<name>/` は次の二つを兼ねる。

1. 開発者が直接編集する正本
2. marketplaceが利用者へ配る自己完結したプラグイン

中間生成物を置かない。プラグイン内の参照は、そのプラグインだけをインストールした環境で解決できなければならない。

```text
claude-shared-skills/
├── .claude-plugin/
│   └── marketplace.json
├── .agents/
│   └── plugins/
│       └── marketplace.json
├── plugins/
│   ├── adr/
│   ├── writing/
│   ├── dev-workflow/
│   ├── domain-design/
│   └── dependency-insight/
├── scripts/
│   ├── validate-plugin-manifests.sh
│   ├── validate-skills.sh
│   ├── tests/
│   └── fixtures/
└── docs/
```

Claude marketplaceの探索位置は `.claude-plugin/marketplace.json`、Codex marketplaceの探索位置は `.agents/plugins/marketplace.json` のまま維持する。別の `marketplaces/` ディレクトリは作らない。

### 6.2 プラグイン内部

```text
plugins/adr/
├── .claude-plugin/plugin.json
├── .codex-plugin/plugin.json
├── skills/
│   └── manage-adr/
│       ├── SKILL.md
│       ├── references/
│       └── assets/
├── scripts/
├── hooks/
└── README.md
```

テストとfixtureは配布物へ入れない。既存の `docs/distribution-boundary.md` に従い、リポジトリルートの `scripts/tests/` と `scripts/fixtures/` に置く。参照方向は「配布物外のテストから配布物内の実装」だけにする。

### 6.3 manifest

Claude用とCodex用のmanifestは各ホストに自然な形式で直接編集する。共通metadataファイルやmanifest生成器は作らない。代わりに `validate-plugin-manifests.sh` が次を双方向に検査する。

- plugin名とversionの一致
- marketplaceに列挙されたplugin集合の一致
- marketplaceから参照されるディレクトリの存在
- `skills` を宣言したmanifestと実ディレクトリの整合
- plugin内のskill名の一意性
- READMEの一覧との整合

一方のmarketplaceにだけあるplugin、一方のmanifestだけversionが異なるplugin、検査対象が0件になった場合は非0で終了する。

## 7. スキルとホスト差分

### 7.1 共通本文

一つの `SKILL.md` をClaude CodeとCodexの双方が読む。本文は発火条件、入力、判断規則、停止条件、成果契約を共通化する。

ホスト固有機能を一律に本文から排除しない。両ホストで同じ意味上の操作を実現できない場合、ホスト名、実現方法、縮退動作を明記する。存在しない抽象APIを作ったことにしない。

### 7.2 パス解決

スキル同梱資産は、スキルディレクトリからの相対位置を規範上の表記とする。

- スキル内参照: `<skill-root>/references/...`
- プラグイン共有参照: `<skill-root>/../../references/...`
- プラグイン共有script: `<skill-root>/../../scripts/...`

Claude adapterでは `<skill-root>` を `${CLAUDE_SKILL_DIR}` へ写像する。`${CLAUDE_PLUGIN_ROOT}` はSKILL.md内の解決手段として使わない。Codex adapterの正式なskill root解決方法はWave 0の調査で確定する。相対解決が保証されない場合は、Codexがスキル一覧で提供するskill pathを使う明示手順を定める。

### 7.3 対話とサブエージェント

共有本文では「ユーザーの明示承認を得る」「独立レビューを行う」のように成果上必要な操作を先に定義し、その直後にホスト別実現方法を記載する。

`dev-workflow` のplugin名を維持するため、既存の `agents/` 配置と `dev-workflow:<name>` 名前空間は変更しない。`domain-design` と `dependency-insight` へ移すスキルが既存agentsを実行時に必要としないことを移設前の参照検査で確認する。参照が見つかった場合は分割を完了扱いにせず、境界を再検討する。

### 7.4 権限契約

`allowed-tools` はClaude Codeで権限と疎結合を静的に執行しているため、一律に削除しない。

各スキルは次を宣言する。

- 成果に必要な意味上の能力
- Claude Codeの `allowed-tools`
- Codexで対応するsandbox、approval、tool制約
- 一方に同等の静的制約がない場合の縮退と残余リスク

適合性検査では成果契約と権限契約を別々に判定する。成果が同じでも権限境界が広がった場合は完全適合としない。

## 8. 互換性レベル

各機能はホストごとに次のいずれかを宣言する。

- `portable`: 同じ成果契約と権限契約を追加分岐なしで満たす。
- `adapted`: 実現方法は異なるが、同じ成果契約と同等の権限契約を満たす。
- `degraded`: 成果または権限の一部保証が弱くなり、代替検証と残余リスクを明示する。
- `surface-specific`: 特定ホストだけで提供し、他方では非対応と明示する。

契約fixtureの期待値は互換性レベルで変える。

| レベル | 対応ホスト | 非対応ホスト |
|---|---|---|
| `portable` | 共通fixtureに合格 | 該当なし |
| `adapted` | 共通成果assertionとホスト別権限assertionに合格 | 該当なし |
| `degraded` | 縮退後の成果、代替検証、残余リスク表示に合格 | 該当なし |
| `surface-specific` | 当該機能のfixtureに合格 | 非対応であることを正しく報告し、変更を行わないfixtureに合格 |

`degraded` や `surface-specific` の存在自体は不合格ではない。宣言と実際が一致しないこと、必要なfixtureがないことを不合格とする。

## 9. プラグイン境界

### 9.1 `adr`

- `manage-adr`
- ADR状態・遷移・相互参照規約
- 採番、index生成、lint
- 利用可能なホストでのcommit gate

### 9.2 `writing`

既存の `2026-08-07-writing-plugin-design.md` を正本として継承する。

- `write-doc`
- `doc-writer`
- `doc-reviewer`
- `japanese-writing.md`
- `document-type-profiles.md`
- `lint-ja.sh`

他プラグインからは `writing:write-doc` をソフト依存として呼び、未導入なら消費側の最小手順へ縮退する既存設計を維持する。Codex manifestには `skills: "./skills/"` を追加し、実際のskillディレクトリとの整合を検査する。

### 9.3 `dev-workflow`

- `create-issue`
- `refine-issue`
- `plan-issue`
- `implementation`
- DoR、完了判定、plan保存先、振る舞いの不変条件
- 既存の `agents/` と `dev-workflow:<name>` 名前空間

Issueの作成、準備判定、計画、実装、PRまでを一つの開発ライフサイクルとして残す。共有規約を別プラグインへ複製せず、単一出典と配布物の自己完結を保つ。

### 9.4 `domain-design`

- `event-storming`
- `domain-modeling`
- ドメイン成果物のschemaとlint

移設時に `behavior-invariants.md` のうちドメイン設計に必要な規範を調べる。全スキル共通であり続ける規範を複製しない。ドメイン設計固有の成果契約へ言い換えて各skill内へ置ける場合のみ移設する。言い換えられず共有単一出典が実行に必要なら、両スキルを `dev-workflow` に残して分離を見送る。

### 9.5 `dependency-insight`

- `dependency-check`
- package ecosystem別の調査規約
- 互換性、breaking changes、更新順序の出力契約

`behavior-invariants.md` との関係は `domain-design` と同じ判定を行う。自己完結できなければ分離を見送る。

## 10. 移行順序

優先度は、本リポジトリでのdogfood価値、ホスト依存の少なさ、後続の基盤になる度合い、成果を機械検証しやすい度合いで決める。

### Wave 0: 事実調査と適合性検査

開始前に次の問いを全件決着させる。

1. Codexがplugin内のskill rootをどのように公開するか。
2. Codexでスキルごとの権限境界をどこまで静的に制約できるか。
3. Codexで暗黙発火の試行を自動実行し、発火有無を観測できるか。
4. Claude Codeで `${CLAUDE_PLUGIN_ROOT}` がSKILL.mdのRead経路で展開されるか。

調査結果を入力に次を実装する。

- manifest / marketplace整合lint
- 検査対象0件を失敗にするskill lint
- 壊れた参照と配布境界の検査
- host固有語の許可領域検査
- capability / permission compatibility matrix schema
- Claude/Codexローカル起動経路の対称化
- `plugins/` を名指す既存スクリプト、テスト、設定、文書の参照台帳

各問いは「解いた」「推移的に決定済み」「前提消滅」「未決」のいずれかを持つ。未決が一つでも残る場合、Wave 0は未完了とする。

### Wave 1: ADR

最初の適合例とする。このリポジトリで利用頻度が高く、front-matter、index、lint exit codeで結果を観測できる。

このWaveでCodex hookの有無と保証範囲を調査する。hookを使えない場合は、明示lintを必須契約とする `degraded` としてfixture、代替検証、残余リスクを記録する。

### Wave 2: Writing

既存のwriting設計とIssue #683、#684、#685を入力に、`write-doc`、`doc-writer`、`doc-reviewer` を両ホストへ適合させる。新しい基盤スキル名や別レビュー構造を導入しない。

### Wave 3: `dev-workflow` 中核

次の順で適合させる。

1. `create-issue`
2. `refine-issue` 単件
3. `plan-issue`
4. `refine-issue` バッチ・並列
5. `implementation`

単件の対話・DoR・成果契約を固めてから、agents、他スキル委譲、CI、PRを含む経路へ進む。

### Wave 4: 独立能力の分離判定

`domain-design` と `dependency-insight` の自己完結性を、参照グラフと実行不能性テストで評価する。分離可能と決着したプラグインだけを移設する。分離が不可能なら `dev-workflow` に残すことを正常な結論とし、コピーで境界を作らない。

### Wave 5: チーム移行

- runnerと両marketplaceを更新する。
- 旧plugin IDから新pluginへの対応表を公開する。
- 同じskill名を旧・新pluginから同時配布しない。
- チーム利用者の移行確認後に旧entryを外す。

未移行項目を別Issueへ切り出してプラグインを完了扱いにする場合は、利用者の明示承認を得る。

## 11. テスト戦略

### 11.1 配置

テストとfixtureはすべて配布物外へ置く。

```text
scripts/
├── tests/
│   ├── plugin-manifests.bats
│   ├── skill-portability.bats
│   ├── adr-contract.bats
│   └── local-plugin-runners.bats
└── fixtures/
    ├── plugin-manifests/
    ├── skill-portability/
    └── adr-contract/
```

### 11.2 静的検査

- manifest schemaとversion一致
- plugin名とskill名の一意性
- marketplaceとpluginディレクトリの双方向一致
- 壊れた相対参照
- 配布物から配布元への逆参照
- host固有語の許可領域
- `allowed-tools` と本文の操作の整合
- 検査対象が期待集合と一致し、0件走査にならないこと
- runner、設定、文書内の旧plugin path残存

### 11.3 契約fixture

自然文全文の一致ではなく、次を検査する。

- 必須成果物とschema
- 状態遷移
- 全判定項目の列挙
- 未解決項目がある場合のNot Ready / 未完了判定
- 明示承認なしで禁止された変更を行わないこと
- 必須検証コマンドの結果
- 権限契約と実際のtool利用
- compatibility matrixに応じた非対応・縮退動作

### 11.4 明示呼び出しと暗黙発火

代表ケースは各skillにつき次から1件以上を選ぶ。

- descriptionに列挙した典型的な日本語トリガー
- skill名を含まない自然文
- 隣接skillと識別すべき境界ケース

明示呼び出しの成功は、skillがロードされ、契約fixtureの必須成果または停止結果を返すこととする。

暗黙発火は、Wave 0で観測APIを確認できた場合だけrelease gateとする。同一の固定promptを各ホスト3回実行し、3回すべてで対象skillがロードされ、隣接skillが誤発火しないことを合格とする。モデル、CLI version、設定、promptを証拠へ記録する。観測APIがない場合は `degraded` として手動smoke testへ落とし、自動合格とは表示しない。

## 12. 完了判定

一つのプラグインを「Claude / Codex 両対応」と判定するには、次の全項目を1件ずつ評価する。

### 配布

- [ ] Claude marketplaceの正式探索位置から導入できる。
- [ ] Codex marketplaceの正式探索位置から導入できる。
- [ ] 両manifestの名前、version、skill参照が整合する。
- [ ] plugin単体で配布先から全参照を解決できる。

### 成果

- [ ] 代表的な明示呼び出しが両ホストで成功する。
- [ ] 暗黙発火が自動gateまたは明記された `degraded` 手動検査を満たす。
- [ ] compatibility matrixが要求する全fixtureに合格する。
- [ ] 全判定項目を省略せず列挙し、未解決時に完了扱いしない。

### 権限

- [ ] 意味上必要な能力とホスト別権限が列挙される。
- [ ] Claude Codeの `allowed-tools` が必要最小限である。
- [ ] Codexのsandbox、approval、tool制約が必要最小限である。
- [ ] 権限が同等でない場合、`degraded` と残余リスクが明記される。

### 運用

- [ ] `degraded` / `surface-specific` がREADMEとcompatibility matrixに明記される。
- [ ] 既存利用者向けの移行経路と破壊的変更が記録される。
- [ ] リリース対象versionで両ホストの検証証拠が残る。
- [ ] 検査対象集合の完全性を検査し、0件走査を成功にしない。

保留または不合格が一つでもあれば、全体を未完了とする。`surface-specific` の非対応ホストは、非対応を正しく報告して変更を行わないfixtureの合格をもって解決済みとする。残項目を別Issueへ切り出して当該pluginを完了扱いにする場合は、実行前に利用者の明示承認を得る。

## 13. 最初の実装単位

最初の実装Issueは次の一単位とする。

> 両対応プラグインの事実調査と適合性検査を整備し、ADRプラグインを最初の適合例としてClaude CodeとCodexの双方で契約検証する。

含めるもの:

- Wave 0の4調査問いの決着台帳
- manifest / marketplace整合lint
- skill lintの対象集合保証
- capability / permission compatibility matrix
- plugin path参照台帳と既存検査の張替え
- ADRのパス、対話、tool、権限契約
- ADRの契約fixture
- Claude Code / Codex smoke test

含めないもの:

- Writing以降のplugin移行
- `dev-workflow` の分割
- universal plugin directoryへの公開
- `growth` 対応
- `implementation` の再設計

## 14. ADR化要否

本設計のうち、少なくとも次の二つは却下代替を持つ設計判断である。

1. `plugins/` を正本兼配布物とし、編集用・生成用の別成果物を設けない。
2. `dev-workflow` をスキル単位に分けず、共有規約とagentsの凝集に沿って限定的に分割する。

それぞれの粒度判定は次のとおりである。

| 項目 | 判定 | 根拠 |
|---|---|---|
| 後戻りコストが高い | 該当 | ディレクトリ構造、marketplace、runner、参照パスへ波及する。 |
| 複数の適用先に波及する | 該当 | 複数plugin、manifest、検査器へ適用される。 |
| 採用理由が時間経過で揮発しやすい | 非該当 | 本設計文書に却下理由とともに保持する。 |
| ツールで自動強制できない | 該当 | 設計時点では強制が未実装である。 |

各判断は3点でADR化推奨に当たる。ただし `adr-scoping.md` の起票タイミングに従い、最初の出現である本PRでは本設計とPR説明に保持する。Wave 0の実装Issue着手時に `manage-adr` へ再入力し、新規ADRをそれぞれ独立した反転単位として起票する。二つを一本のADRへ束ねない。

今回の構成は `dev-workflow` のplugin名、ルート `agents/` 配置、`dev-workflow:<name>` 名前空間を維持するため、ADR-202605250838-01のcoreを変更しない。テストを配布物外へ置くため、ADR-202608061516-01と `docs/distribution-boundary.md` の方向も変更しない。共有規約を複製しないため、ADR-202607261002-02が求める単一出典とも矛盾しない。

## 15. リスクと対策

### 過分割を避けた結果、`dev-workflow` がなお大きい

ファイル数ではなく実行時依存で境界を決める。まず中核4スキルをホスト両対応へ適合させ、移行後のcontext量、変更頻度、発火衝突を計測する。共有規約を壊さず分けられる新しい境界が見つかった場合だけ再判定する。

### manifestの手編集で再びドリフトする

生成ではなくCI失敗で阻止する。検査対象0件も失敗にし、片側だけを見て緑になる経路を作らない。

### ホスト差分の抽象化が最低共通機能化を招く

`adapted`、`degraded`、`surface-specific` を許容し、強い機能を失わず差分を公開する。成果と権限を別軸で評価する。

### プラグイン分割で利用者の導入負担が増える

runnerで推奨pluginを一括導入できる経路を維持する。分離判定で自己完結できない能力は無理に分けない。

### 二つのホストを使うE2Eが不安定になる

決定的な契約fixtureを主検査とし、host smoke testは代表ケースに絞る。CLI versionとモデルを証拠へ残し、外部状態依存の失敗と成果契約違反を分けて報告する。

## 16. 参照

- OpenAI Developers, Plugin architecture: https://developers.openai.com/plugins/concepts/plugins
- OpenAI Developers, Build skills: https://developers.openai.com/plugins/build/skills
- OpenAI Developers, Package your plugin: https://developers.openai.com/plugins/build/plugins
- `docs/superpowers/specs/2026-08-07-writing-plugin-design.md`
- `docs/distribution-boundary.md`
- `plugins/dev-workflow/references/completion-judgment.md`
- `docs/adr/ADR-202605250838-01-subagent-agents-consolidation.md`
- `docs/adr/ADR-202607261002-02-behavior-invariant-placement.md`
- `docs/adr/ADR-202608061516-01-distribution-boundary-inexecutability-test.md`
