# ADR（Architecture Decision Records）運用ルール

本ディレクトリは横断的・後戻りコスト高な技術的意思決定（アーキテクチャ・設計方針）を ADR として蓄積・参照・廃止する運用基盤。`docs/development/event-storming.md` の「技術的意思決定」集約の実体であり、同集約の状態遷移・コマンド・イベント定義と整合する。

## 配置

- `docs/adr/` 配下にフラット構造で配置する。サブディレクトリは作らない
- 本 README、`template.md`、各 ADR ファイルが同階層に並ぶ

## 採番方式

ファイル名規則: `ADR-YYYYMMDD[-N]-<slug>.md`

- `YYYYMMDD`: ADR 起票日（採番日＝起票日）
- `[-N]`: 同日2件目以降のみ付与。`-2` から開始（1件目は `-N` なし）
- `<slug>`: 短い英数字ハイフン区切り（例: `adr-operation-foundation`、`technical-decision-aggregate-foundation`）

採番例:

| 起票日 | 件数 | ファイル名 |
|---|---|---|
| 2026-05-11 | 1件目 | `ADR-20260511-<slug>.md` |
| 2026-05-11 | 2件目 | `ADR-20260511-2-<slug>.md` |
| 2026-05-11 | 3件目 | `ADR-20260511-3-<slug>.md` |

採番衝突時（同日に並行で起票する場合）の解消手順:

1. `ls docs/adr/ADR-YYYYMMDD-*.md` で対象日の既存 ADR ファイル一覧を取得する
2. 既存ファイルから最大番号を特定する（`-N` なしを `1` として扱い、`-2`、`-3` を順に番号化）
3. 最大番号+1 で発番する（例: 既存が `-N` なしと `-2` の2件なら、3件目は `-3`）

注: ADR 識別子は集約インスタンス識別子（`docs/development/event-storming.md`「技術的意思決定」集約）と一致する文字列。本 README の採番方式は #130 / #169 で確定した運用方針を正とする。

## ライフサイクル

状態遷移は `docs/development/event-storming.md` の「技術的意思決定」集約に準拠し、以下の4状態を持つ。

| 状態 | 定義 | 遷移元 | 遷移先 |
|---|---|---|---|
| Proposed | 提案者により起案され、承認者の判断を待っている状態 | 初期状態 | Accepted |
| Accepted | 承認者により承認され、運用中の意思決定 | Proposed | Deprecated, Superseded |
| Deprecated | 運用中の意思決定が廃止された状態。後継参照は持たない | Accepted | 終了 |
| Superseded | 運用中の意思決定が後続ADRに上書きされた状態。後継ADR識別子を保持 | Accepted | 終了 |

- 状態名は ADR 業界慣例（Nygard ADR / MADR）に倣い英文表記で確定する（他集約の状態名は和文だが、状態名のみ意図的に英文表記）
- Proposed をスキップして直接 Accepted に到達する経路は持たない。即承認のケースは「提案 → 承認」を連続実行として扱う
- 状態遷移の詳細定義（コマンド・イベント・サイドエフェクト）は `docs/development/event-storming.md`「技術的意思決定」集約を参照

## 粒度判定基準

ADR 化要否の判定は以下の4項目チェックリストで行う。

1. 後戻りコストが高い
2. 複数モジュール・複数開発者に波及する
3. 採用理由が時間経過で揮発しやすい
4. ツールで自動強制できない

判定ルール:

- **3点以上**: ADR 化推奨
- **2点以下**: ADR 化しない
- **判断に迷ったら ADR 化しない**: 原則として ADR 化しない方向に倒す。後から必要性が判明したら遡及して ADR 化する

ADR 過多は検索性を損ね、運用基盤の存在意義を失わせるため、判定境界では「書かない」を優先する。

### 起票のタイミングとエスカレーション

ADR 化要否は上記4項目で判定するが、「いつ起票するか」は別の問題である。最初から ADR にしようとせず、まず PR の説明に判断を書く。後から他の機能でも同じ問いが出てきた時点で ADR に昇格させる。

```
特定機能の決定 → まずPRの説明に書く
      ↓
他の機能でも同じ問いが出てきた
      ↓
ADRに昇格（docs/adr/ に起票。採番方式に従う）
```

ADR 化を検討すべき決定が発生したことを示す実務シグナル（いずれかに該当したら粒度判定基準で要否を判定する）:

- 複数の選択肢を検討して片方を却下した
- トレードオフを受け入れた
- 制約や前提条件がある

## 命名規約のADR化基準

命名規約のうち ADR 化対象とするかどうかは、構造的か書式的かで振り分ける。

| 種別 | 特徴 | 例 | 配置 |
|---|---|---|---|
| 構造的命名規約 | 横断・後戻りコスト高 | ファイル配置規約、集約名、ドメイン用語統一 | ADR 化（`docs/adr/`） |
| 書式的命名規約 | 局所・ツール強制可能 | 変数命名、import 順、空白・改行 | Linter／フォーマッタ規約配置（ADR 外） |

ツールで自動強制できる規約は ADR 外。粒度判定基準の項目4（ツールで自動強制できない）に照らして振り分ける。

## 廃止・上書き手順

### Deprecated（後継なし廃止）

1. 対象 ADR の `## Status` を `Deprecated` に書き換える
2. `## Status` 直下または `## Consequences` 末尾に廃止理由・廃止日時を追記する
3. 後継 ADR は存在しないため `## 関連ADR` の変更は不要

### Superseded（後継ありで上書き）

1. 新 ADR を起票する（採番方式に従う）
2. 新 ADR の `## 関連ADR` に `Supersedes: <旧ADR識別子>` を記載する
3. 旧 ADR の `## Status` を `Superseded` に書き換え、`Superseded by: <新ADR識別子>` を併記する
4. 旧 ADR の `## 関連ADR` に `Superseded by: <新ADR識別子>` を記載する

後継ADR識別子は文字列参照のみ。集約インスタンスへの直接参照は持たない（自己参照・循環参照の構造的不整合を防ぐ）。

### Amended（部分改訂）

複数の決定を束ねた ADR のうち、**一部の決定（facet）のみ**を後続 ADR で改訂し、残りの決定は有効なまま維持したい場合に用いる。Superseded（全体上書き）と異なり、旧 ADR の Status は **Accepted のまま変更しない**。

1. 新 ADR を起票する（採番方式に従う）
2. 新 ADR の `## 関連ADR` に `Amends: <旧ADR識別子>（<改訂facet>を改訂）` を記載する
3. 旧 ADR の `## Status` は **変更しない**（Accepted を維持）。本文の決定も改変しない
4. 旧 ADR の `## 関連ADR` に `Amended by: <新ADR識別子>（<改訂facet>を改訂）` を併記する

Superseded との違い:

| | Superseded | Amended |
|---|---|---|
| 旧ADRの Status | `Superseded` へ変更 | `Accepted` 維持 |
| 改訂範囲 | 全体（旧ADRは無効化） | 一部の決定のみ（残りは有効） |
| 併記方向 | `Supersedes` / `Superseded by` | `Amends` / `Amended by` |

部分改訂が複数 facet に波及し旧 ADR の大半を無効化するなら、Amended ではなく Superseded を選ぶ。

## テンプレート

新規 ADR を起票する際は [`./template.md`](./template.md) をコピーして使用する。MADR 準拠の必須項目（Title / Status / Context / Decision / Consequences）と本プロジェクト追加項目（関連ADR）を含む。

## モデル制約由来の設計判断インデックス

スキル/エージェント/参照ファイル群には「モデル（LLM）の制約への対処」が暗黙的に含まれている（自己評価バイアス、コンテキスト膨張、早期収束、指示の確率性、ハルシネーション等）。モデル更新時に「どのガードレールを見直すか・どの閾値を変更しうるか」を即座に判断できるよう、本索引で明示言及 ADR を設計要素別にクロスリファレンスする。

索引対象は **モデル制約に明示言及している ADR 11 件**。暗黙該当 ADR（モデル制約由来と読めるが本文に明示記述のないもの）は対象外とする（判定境界が個別解釈に依存するため）。

### 自己評価バイアス対策

同モデルに自作物を評価させない／独立 reviewer・validator の分離／人間承認ゲートの介在。

- [ADR-20260406-review-contract-in-plan-issue](./ADR-20260406-review-contract-in-plan-issue.md): 実装者自身による完了条件導出を禁じ、plan-issue 段で人間承認済み契約を作成し自己評価バイアスを除去
- [ADR-20260407-dev-loop-input-path-split](./ADR-20260407-dev-loop-input-path-split.md): 入力種別で正規/簡易パスを分け、自己評価バイアス残存と過剰準備コストのトレードオフを明示化
- [ADR-20260601-autonomy-approval-gate-alignment](./ADR-20260601-autonomy-approval-gate-alignment.md): 自律度（承認ゲート有無）をドメインモデルではなく責任分担マトリクスで表現し、AI暴走と人間承認を層分離
- [ADR-20260602-2-autonomy-ladder-convention](./ADR-20260602-2-autonomy-ladder-convention.md): L2 の「提案→承認」二段で AI 自走を人間承認で抑止、L3 は検証能力成熟時のみ承認段を縮退する規約を固定

### コンテキスト膨張・トークン効率対策

サブエージェント委譲／on-demand ロード／references 分離／二重読み回避／単一ソース化。

- [ADR-20260525-subagent-claude-md-injection](./ADR-20260525-subagent-claude-md-injection.md): サブエージェントへの CLAUDE.md 自動注入挙動を利用し、明示 Read による二重読み・許可プロンプト中断を排除
- [ADR-20260525-2-subagent-agents-consolidation](./ADR-20260525-2-subagent-agents-consolidation.md): サブエージェント定義をプラグインルートに集約し、メイン側 Read と二重読みによるトークン浪費を排除
- [ADR-20260604-dor-shared-resource-consolidation](./ADR-20260604-dor-shared-resource-consolidation.md): DoR 定義をプラグインルートで単一ソース化し、作成側と精査側で判定基準がドリフトする早期収束を防止
- [ADR-20260606-2-instruction-tidying](./ADR-20260606-2-instruction-tidying.md): 指示削除ゲートを設けて指示肥大化とモデル更新時のドリフトを抑制し、確率的な指示効力低下を防ぐ

### 早期収束・手抜き対策

全項目列挙強制／一部判定打ち切り防止／DoR 項目強制／単一ソース化によるドリフト防止。

- [ADR-20260604-dor-shared-resource-consolidation](./ADR-20260604-dor-shared-resource-consolidation.md): DoR 定義をプラグインルートで単一ソース化し、作成側と精査側で判定基準がドリフトする早期収束を防止

### 指示忠実性低下対策

指示の確率性への対応／構造による違反不可能化／指示棚卸し／重要事項の再掲。

- [ADR-20260602-principles-rationale-hub](./ADR-20260602-principles-rationale-hub.md): principles.md を根拠ハブに縮退し「広さ」と「原則の射程」の混同による横断原則の取りこぼしを防止
- [ADR-20260606-2-instruction-tidying](./ADR-20260606-2-instruction-tidying.md): 指示削除ゲートを設けて指示肥大化とモデル更新時のドリフトを抑制し、確率的な指示効力低下を防ぐ
- [ADR-20260606-protection-priority-ladder](./ADR-20260606-protection-priority-ladder.md): 「指示は確率的にしか効かない」前提で構造・型による違反不可能化を指示追加より優先する原則を確定

### ハルシネーション対策

一次情報による再検証／推測禁止／Grep/Glob 実検証／実在確認の強制。

該当 ADR なし（スキル定義側で対処: `plan-prompt.md`、`plan-reviewer.md`、ユーザー CLAUDE.md「検証」節 等）。**ADR 化候補**。

### 並列数・モデル指定の固定

モデル選定の固定／並列度上限／バッチサイズ制限／許可プロンプト挙動への配慮。

該当 ADR なし（スキル定義側で対処: `refine-issue/SKILL.md`「最大3並列、モデル: sonnet」等の個別固定）。**ADR 化候補**。

### モデル/ハーネスの固有挙動への対処

プロンプトキャッシュ TTL／許可プロンプトのパース挙動／文字列⇔整数の誤判定／HEREDOC 制約／コンテキスト自動注入。

- [ADR-20260421-agent-modeling-principle](./ADR-20260421-agent-modeling-principle.md): ループ上限・打ち切り等のエージェント固有制御パラメータをドメインモデルから排しスキル実装側に隔離
- [ADR-20260525-subagent-claude-md-injection](./ADR-20260525-subagent-claude-md-injection.md): サブエージェントへの CLAUDE.md 自動注入挙動を利用し、明示 Read による二重読み・許可プロンプト中断を排除

### スコープ逸脱対策（ツール制限）

エージェントへの読み取り専用制限／Bash 実行範囲制限／破壊的操作の禁止。

該当 ADR なし（エージェント定義側で対処: `code-reviewer.md`（読み取り専用）、`refactorer.md`（Bash は `git diff/status/restore*` のみ）、`test-designer.md`（読み取り専用）等）。**ADR 化候補**。

### モデル更新時の見直しフロー

モデル更新（コンテキスト窓拡張・検証精度向上・指示遵守性向上・自己評価バイアス減少等）が行われた際、本索引のカテゴリ順に各 ADR を再評価する。

1. **設計要素別に該当 ADR を引く**: 上記カテゴリから対象設計要素の ADR を特定する
2. **各 ADR の前提（モデル制約）が依然有効か判定**: ADR 本文の Context / Decision を読み、新モデルでも同じ制約が成立するか確認する
3. **不要化・閾値変更の候補をリストアップ**: 制約が緩和された設計要素は、[Superseded / Amended の手続き](#廃止上書き手順)で更新候補とする
4. **「該当 ADR なし」カテゴリは ADR 起票を検討**: 既存スキル/エージェントの該当箇所を洗い出し、ADR 化要否を [粒度判定基準](#粒度判定基準) で判定する
