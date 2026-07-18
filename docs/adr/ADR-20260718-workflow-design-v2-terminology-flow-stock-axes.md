---
status: 承認済み
validity: 有効
---

# ADR-20260718: workflow-design.md v2 構造 — 用語のフレームワーク非依存化とフロー／ストック軸の分離

## Context

ADR-20260402-workflow-design-v2-structure は `docs/workflow-design.md` の v2 構造として6つの決定を1本の ADR に束ねていた。このうち決定1（Discovery フェーズの守備範囲化＝当該ドキュメントの責務定義 facet）は、その後 ADR-20260602-principles-rationale-hub によって上書きされている（初版の改訂は ADR-20260531-2 だが、同 ADR は ADR-20260602 に Superseded されたため、現行の権威は ADR-20260602）。すなわち責務定義の権威は ADR-20260602 へ移り、ADR-20260402 の決定1 は現行の決定ではなくなった。

一方、ADR 運用の2軸モデル（ADR-20260711-3-adr-two-axis-status-validity-model）は ADR 単位の `validity` しか持たず、1本の ADR の一部決定だけを退役させる部分 validity を持たない。そのため ADR-20260402 は全体が `validity: 有効` のまま、既に権威を失った決定1 を「有効な決定」の体裁で抱え続けていた。ADR-20260402 を単独で読む者は、実際には ADR-20260602 へ権威が移った facet を現行の決定と誤読しうる。

本 ADR は、この部分 core 反転を ADR-20260711-3 決定3「多決定 ADR の部分 core 反転（ADR分割）」の手続きで解消するために起票する。ADR-20260402 の生存決定2〜6 を本 ADR へ**逐語 restate** で re-home し、ADR-20260402 自体は `validity: 上書き済み` として ADR-20260602 と本 ADR の両後継を `superseded-by` に列挙する。

本 ADR は内容の再決定ではなく、決定のファイル間再配置である。決定の本文は ADR-20260402 の原文を一字も改変していない。単独可読性のためトップレベル項目の先頭番号のみ 1〜5 へ振り直しており、ADR-20260402 側の番号（2〜6）は原本の記述としてそのまま残る。

逐語 restate の射程は `## Decision` の決定本文であり、`## Consequences` は対象外とした。決定1 の退役に伴い、ADR-20260402 の `## Consequences` から2点を調整している。(1)「参照可能な設計書になる」を「参照可能な用語体系になる」へ改めた。文書全体を設計書として位置づける責務定義は決定1 とともに ADR-20260602 へ移っており、本 ADR が保持するのは用語と軸に関する決定群のみであるため。(2) 将来の留保事項から、採番方式 `docs/adr/{番号}-{タイトル}.md` の旧記述に関する項目を除いた。同記述は ADR-20260511 で `ADR-YYYYMMDD[-N]` に上書き済みであり、残作業とされていた本文側の整合も、#221 Phase 2 の操作層移転で当該記述が本文から除去され解消している（採番方式の経緯は `## 関連ADR` の ADR-20260711-3 の項に集約した）。

なお、本 ADR のタイトルおよび決定本文が指す `docs/workflow-design.md` は、その後 `docs/principles.md` へ改名され責務も縮退している（`## 関連ADR` の ADR-20260602 の項を参照）。逐語 restate される決定本文の表記に揃えるため、本 ADR では `workflow-design.md` の表記を用いる。

## Decision

`docs/workflow-design.md` の構造として以下を採用する（ADR-20260402 の決定2〜6 を逐語 restate したもの。先頭番号のみ 1〜5 へ振り直している）。

1. **用語のフレームワーク非依存化**: Epic/feature 等のフレームワーク特化用語を排し、以下に統一する
    - フロー（作業管理）の階層: 「テーマ」「デリバリーアイテム」「タスク」（プロジェクト管理の原理）
    - ストック（ドキュメント）の階層: 「ドメイン」「ユースケース」「spec.md」（ソフトウェアアーキテクチャの原理）
    - 整理の原理が異なるため、フローとストックは別の軸として扱う
2. **フロー軸とストック軸の接続**: デリバリーアイテム（Issue）が、どのユースケースの spec.md を参照するか、で接続される。1対1ではなく多対多関係を許容
3. **ドキュメント配置原則「フェーズではなくドメインで分類」**: `docs/discovery/` は不要。Discovery/Delivery は時間軸であって空間軸（ドメイン分類）に反映しない。ドメインで分類した配下にユースケースを置く
4. **ユースケースレベルのストック情報の集約**: `docs/{domain}/use-cases/{name}/spec.md` にドメインマッピング（どの集約・状態遷移・コマンドを担うか）、受け入れ基準、外部リソースリンク（Figma等）を集約。Issue の AC は作業駆動用（フロー）、spec.md がストック
5. **廃止事項**:
    - `requirements-writer` スキルの構想を廃止（spec.md + Issue の AC で代替）
    - `docs/discovery/user-stories.md` 廃止（spec.md に統合）
    - workflow-design.md からテンプレート・CI 設定例を外部化（ストック責務外）

## Consequences

**得られた利益**:

- フロー（Issue/タスク管理）とストック（spec.md/ドメインモデル）が別軸として整理され、双方を独立進化させられる
- フレームワーク非依存用語により SAFe/Scrum/Kanban いずれのチームでも参照可能な用語体系になる
- ドメイン分類採用により Discovery 成果物が Delivery でも自然に参照される（時間軸が空間軸を侵食しない）

**受容したトレードオフ**:

- v1 を読み慣れたメンバーには用語移行コストが発生
- 「テーマ・デリバリーアイテム・タスク」は具体的ツール（Linear/GitHub Issues 等）との直接マッピングを持たず、運用時に翻訳が必要
- spec.md 配置・命名規約（`docs/{domain}/use-cases/{name}/spec.md`）の固定化により、ドメイン階層の構造変更時の追従コストが残る

**将来の留保事項**:

- spec.md のライフサイクル管理（Issue #95 OPEN）、Delivery→Discovery のフィードバックループ詳細（Issue #94 CLOSED で初期定義）は別Issueで継続検討

## 関連ADR

- Supersedes: ADR-20260402-workflow-design-v2-structure（ADR分割〔ADR-20260711-3 決定3〕により、原 ADR の生存決定2〜6 を逐語 restate で re-home。先頭番号のみ 1〜5 へ振り直し、本文は不変。原 ADR の決定1〔Discovery フェーズの守備範囲化＝責務定義 facet〕は ADR-20260602-principles-rationale-hub が担い、原 ADR の `superseded-by` は本 ADR と ADR-20260602 の両後継を列挙する）
- Related: ADR-20260711-3-adr-two-axis-status-validity-model（ADR分割の手続き＝決定3 の出典。あわせて採番方式 `ADR-YYYYMMDD[-N]` は `docs/workflow-design.md:166-186` にあった旧採番方式 `docs/adr/{番号}-{タイトル}.md` を上書きする（旧記述の実在場所は ADR-20260511 が明示しており、ADR-20260402 の `## Decision` には採番方式の記述はない。ADR-20260402 は `## Consequences` の将来の留保事項として上書きの事実に言及していたのみ）。同方式は上書き済みの ADR-20260511 が定めたもので、決定8「採番方式・配置（ADR-20260511 から不変で引き継ぐ）」として現行 ADR へ不変のまま引き継がれた）
- Related: ADR-20260602-principles-rationale-hub（ADR-20260402 の責務定義 facet の現行権威。`docs/workflow-design.md` は #221 Phase 3 で `docs/principles.md` へ改名され、責務は Explanation 根拠ハブへ縮退した）
- 関連Issue: #524（ADR分割による re-home）、PR #89（workflow-design.md v2 改訂本体）、#94（Delivery→Discovery フィードバックループ）、#95（spec.md ライフサイクル）、#100（AIエラー時の再開・引き継ぎ）
