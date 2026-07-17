---
status: 承認済み
validity: 有効
---

# ADR-20260621: 「人間判断要観点」の語彙・データ構造（正準用語「判断依頼」の確定）

## Context

plan 段階で「人間判断が必要な観点」を plan ドキュメントに明示する仕組み（親 Epic [#318](https://github.com/kuchita-el/claude-shared-skills/issues/318) 軸1）と、実装後に PR 本文で「人間に確認してほしい観点」セクションを出す仕組み（[#314](https://github.com/kuchita-el/claude-shared-skills/issues/314)）は、同じ「人間判断要観点」というデータ概念を異なるフェーズで扱う。両者が個別に語彙・データ構造を発明すると、レビュアーが plan と PR 本文で同じ観点を二度認知することになり、シフトレフトの効果が相殺される。

既存資産として、plan 側には `plan-output-format.md` の `## 判断依頼` セクション（plan-issue が生成する plan ドキュメントの正規セクション）が既に運用されており、実装後側には dev-loop の `escalation-template.md` の「人間判断の選択肢」セクション、`SKILL.md` の「人間判断」用語（収束失敗時のエスカレーション文脈）が存在する。本 ADR はこれら既存資産の上に語彙を統合し、両フェーズで同一の正準用語・最小データ構造を共有可能にする。

先行 ADR との関係性:

- [#109](https://github.com/kuchita-el/claude-shared-skills/issues/109)（CLOSED）「スキル間インターフェース契約ファイルの設計・作成」の規約（`docs/delivery-workflow/plan-dev-contract.md`）を踏襲し、新規規約フレームワークは発明しない
- [ADR-20260406](./ADR-20260406-review-contract-in-plan-issue.md) で plan-issue 側に移行したレビュー契約と並ぶ、plan-issue 側で確定する語彙資産として位置付ける

関連 Issue [#319](https://github.com/kuchita-el/claude-shared-skills/issues/319) 起票時（2026-06-21）に種別 spike / サイズ Medium / Ready 判定済み。`docs/adr/README.md` 粒度判定基準4項目すべてに該当（後戻りコスト高・複数モジュール波及・採用理由揮発リスク・自動強制不可）するため ADR 化する。

## Decision

「人間判断要観点」の正準用語・最小データ構造・対応表を以下の通り確定する。

### 1. 正準用語

**本 ADR 以降の正準用語は「判断依頼」とする。**

- plan-issue 側の現行 `plan-output-format.md` の `## 判断依頼` セクションで既に運用されている既存資産との段差を最小化する選択
- Issue 表題・親 Epic [#318](https://github.com/kuchita-el/claude-shared-skills/issues/318) で使用される文言「人間判断要観点」は、本 ADR 上の概念名（カテゴリ名）として保持する。データインスタンス・セクション名・テンプレート見出しは「判断依頼」を使用する
- 検討した代替案: 「人間判断要観点」（Issue 表題準拠、plan 側の改名コストあり）、新規造語（既存資産の上書きコスト最大）

### 2. 必須フィールド（4種）

| フィールド | 型 | 値域 | 意味 |
|---|---|---|---|
| 観点ID | 文字列 | Issue 内で一意（例: `J1`, `J2`） | 同一観点への複数回参照を可能にする識別子 |
| 説明 | 自然文 | 自由記述 | 観点の内容。レビュアーが判断対象として認識できる粒度で記述する |
| 検出フェーズ | 列挙 | `refine` \| `plan` \| `impl` | 観点が最初に検出されたワークフローフェーズ |
| 判断者ロール | 列挙 | 例示列挙（下記「判断者ロールの値域」参照、追加可能） | 観点を判断する主体の役割 |

### 3. 任意フィールド

| フィールド | 型 | 値域 | 意味 |
|---|---|---|---|
| 関連AC番号 | 文字列 | AC 番号。単一参照は `AC{番号}`（例: `AC1`）、複数参照はカンマ区切り（例: `AC1, AC2`）。空も可 | 観点が直接関連する受入条件番号。欠落しても運用可（実装段階で局所判断） |

任意扱いとした根拠: 誤判時の修正コストが小さく、実装段階での局所判断で十分機能する（Issue [#319](https://github.com/kuchita-el/claude-shared-skills/issues/319) リファイン記録 2026-06-21 で確認）。

### 4. 検出フェーズの値域

`refine` / `plan` / `impl` の3値とする（後続スキルの文字列比較・出力時の表記揺らぎを防ぐため英語表記に統一）。

- `refine`: refine-issue スキルが DoR チェック中に検出した観点
- `plan`: plan-issue スキルが plan 生成中に検出した観点
- `impl`: dev-loop スキルが実装フェーズ全体（実装中の Phase 1 自己検知・実装後のセルフレビュー／コードレビューを含む）で検出した観点。PR 本文出力時に集約する

選定理由: refine-issue 段階の観点も語彙対象に含めることで、将来 refine フェーズで観点出力が必要になった場合の語彙再定義コストを削減する（スケーラビリティ確保）。実装中／実装後（PR 出力）の細かな区別は、必要に応じて項目側（例: 説明文中のフェーズ言及）で吸収する。

### 5. 判断者ロールの値域

以下を例示列挙とし、追加可能とする。

- `プロダクトオーナー`: 仕様判断・ビジネス価値判断を担う役割
- `アーキテクト`: 技術設計判断・既存アーキテクチャ整合判断を担う役割
- `ドメイン専門家`: ドメイン知識に基づく判断を担う役割
- `レビュアー（汎用）`: 上記いずれにも該当しない、または複数を兼ねる汎用レビュー判断

選定理由: ADR は規範文書として値域定義を提供する方が後続スキル（plan-issue / dev-loop）の実装判断を支援できる。1人運用の本リポジトリでも「どの観点で判断すべきか」のヒントとして機能する。値域の追加はパラメータ追加（非core改訂）にあたり、`docs/adr/README.md`「3段構え編集機構」の非core段（本 ADR を直接編集し `## 変更履歴` に1行追記。ADR-20260711-3 決定3）で行う。

### 6. plan 用語 ↔ 実装後用語の対応表

将来の語彙改変は必ず本 ADR の対応表を更新し、両側で同期する。片側のみの語彙変更を禁止する。

| データ構造フィールド | plan-issue 側の現行語彙・参照箇所 | dev-loop / code-reviewer 側の現行語彙・参照箇所 |
|---|---|---|
| （セクション名） | `## 判断依頼`（`plugins/dev-workflow/skills/plan-issue/references/plan-output-format.md` L11） | （現行該当なし。Issue [#314](https://github.com/kuchita-el/claude-shared-skills/issues/314) AC2 で PR 本文に `### 人間に確認してほしい観点` セクションとして導入予定） |
| 観点ID | （現行未定義、本 ADR で導入） | （現行未定義、本 ADR で導入） |
| 説明 | `## 判断依頼` 配下の `**[判断待ち / 前提確認]**` 項目本文（`plan-output-format.md` L15）、`plan-prompt.md` L9「判断依頼の生成指示」節 | （現行該当なし。Issue [#314](https://github.com/kuchita-el/claude-shared-skills/issues/314) AC2 で `### 人間に確認してほしい観点` 配下の項目本文として導入予定） |
| 検出フェーズ | 暗黙的に `plan`（plan-issue が生成するため） | 暗黙的に `impl`（dev-loop が生成するため） |
| 判断者ロール | （現行未定義、本 ADR で導入） | （現行未定義、本 ADR で導入） |
| 関連AC番号 | （現行未定義、本 ADR で任意フィールドとして導入） | （現行未定義、本 ADR で任意フィールドとして導入） |

注: 既存の `plugins/dev-workflow/skills/dev-loop/references/escalation-template.md` L47 `### 人間判断の選択肢` セクション、および同セクションを参照する `plugins/dev-workflow/skills/dev-loop/SKILL.md` L124 の「人間判断」用語は、**収束失敗時のエスカレーション専用文脈**（dev-loop の失敗手段として「続行 / 破棄して再生成 / 計画の見直し」の3択を提示するもの）で使用されており、本 ADR の「判断依頼」（レビュアーへの判断要請）とは別概念である。対応表からは意図的に除外しており、将来の語彙改変時に dev-loop 側を「判断依頼」に揃える判断は本注に該当する箇所を変更対象としない（既存エスカレーションフローの破壊を避けるため）。両者の関係性整理は将来の dev-loop 仕様改修（[#314](https://github.com/kuchita-el/claude-shared-skills/issues/314) 配下）で行う。

## Consequences

### 得られた利益

- plan ↔ 実装後の語彙統一により、レビュアーが plan ドキュメントと PR 本文で同じ観点を二度認知せず同一視できる（シフトレフトの効果が相殺されない）
- 語彙改変時の単一参照点（本 ADR の対応表）が確立し、片側のみの語彙変更による不整合を防げる
- [#318](https://github.com/kuchita-el/claude-shared-skills/issues/318) 軸1（plan 段階での明示）と [#314](https://github.com/kuchita-el/claude-shared-skills/issues/314)（PR 本文での明示）が同じ語彙・データ構造で実装可能になる
- 必須・任意フィールドの最小定義に絞り、過剰なスキーマ規範を避けることで採用障壁を下げた

### 受容したトレードオフ

- Issue [#319](https://github.com/kuchita-el/claude-shared-skills/issues/319) 表題および親 Epic [#318](https://github.com/kuchita-el/claude-shared-skills/issues/318) の文言「人間判断要観点」と、本 ADR の正準用語「判断依頼」に文言差が生じる（カテゴリ名／インスタンス名の使い分けで運用）
- 既存 `dev-loop/SKILL.md` L124 の「人間判断」用語との段差が残る（収束失敗エスカレーション専用文脈との区別を将来の改修で整理する必要）
- ADR を参照しない開発者・サブエージェントによる独自語彙混入リスクは規律で防ぐしかない（ツール強制不可。粒度判定基準項目4に該当）

### 将来の留保事項

- refine-issue 段階での観点検出が実装された場合、値域 `refine` の運用ルール（DoR チェック結果との結びつけ方）を3段構え編集機構の非core段（直接編集＋`## 変更履歴`）で補足する
- 判断者ロールの値域は1人運用前提の例示列挙のため、複数人運用への移行時に値域拡張または役割定義の精緻化を行う（`docs/adr/README.md`「3段構え編集機構」に従い、値域拡張は非core段＝直接編集＋`## 変更履歴`、決定の骨子を変える場合は core＝新規 ADR）
- `関連AC番号` フィールドの必須化判断は、運用実績で「任意では追跡漏れが多発する」と判明した時点で3段構え編集機構（非core段＝直接編集＋`## 変更履歴`。骨子を変える場合は core＝新規 ADR）で再評価する
- 本 ADR の語彙資産は将来的に `docs/delivery-workflow/plan-dev-contract.md`（スキル間契約ファイル）に取り込む可能性がある（[ADR-20260604](./ADR-20260604-dor-shared-resource-consolidation.md) の共有資源集約原則に従う）

## 関連ADR

- Related: [ADR-20260406-review-contract-in-plan-issue](./ADR-20260406-review-contract-in-plan-issue.md)（レビュー契約を plan-issue 側に移行する先行判断。本 ADR の語彙資産も plan-issue 側で確定する点で位置付けが並ぶ）
- Related: [ADR-20260604-dor-shared-resource-consolidation](./ADR-20260604-dor-shared-resource-consolidation.md)（共有資源をプラグインルートに集約する原則。本 ADR の語彙資産も将来共有資源化する余地に関連）

関連Issue: [#319](https://github.com/kuchita-el/claude-shared-skills/issues/319)（本ADR）、[#318](https://github.com/kuchita-el/claude-shared-skills/issues/318) 軸1（本ADRを参照する側）、[#314](https://github.com/kuchita-el/claude-shared-skills/issues/314)（本ADRを参照する側）、[#109](https://github.com/kuchita-el/claude-shared-skills/issues/109)（CLOSED、先行規約として踏襲）
