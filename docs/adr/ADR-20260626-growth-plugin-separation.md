---
status: 承認済み
validity: 有効
---

# ADR-20260626: 内省機能を独立プラグイン growth として分離

## Context

内省→検証→配布の学習ループを担う growth 機能の構想は、設計母艦 `plugins/growth/DESIGN.md`（Phase 0 完了）で原理・スキーマ・境界モデルを固定した。その §7「ADR 化候補」では、本機能を既存の dev-workflow プラグインに混ぜず独立プラグイン growth として分離する判断を、ADR 運用ルールの粒度判定（後戻りコスト高 / 複数モジュール波及 / 採用理由揮発 / ツール自動強制不可）に照らして「3点以上、ADR 級」と評価し、昇格タイミングを「Phase 1 実装 PR 時」と定めた。

本 ADR は、その昇格判断を実体化するものである。厳密には DESIGN.md §7 は昇格点を「Phase 1 実装 PR 時」とするが、本 ADR を起票する Issue #343 はスケルトン作成 PR（Phase 1 の `capture` スキル実装の直前）であり、Phase 1 成果物を収容する器を用意する起点に当たる。Issue #343 の受入条件に ADR 起票が明示されていること、およびスケルトン作成が Phase 1 着手の前提であることを根拠に、このスケルトン作成 PR で昇格する。

分離判断の背景には、複数の選択肢を検討して片方を却下したという ADR 化シグナル（DESIGN.md §8）がある。dev-workflow に混在させる案を検討したが、関心が異なること（開発ワークフロー vs 学習メタ機構）と、growth を dev-workflow に同梱すると growth のスキル description が dev-workflow 利用者のセッションに常時ロードされてしまう点を避けるため却下した。

## Decision

内省機能（growth の学習ループ: 内省 → 仮説 → 検証 → 配布）を dev-workflow プラグインに混在させず、独立したプラグイン `plugins/growth/` として分離する。marketplace カタログには dev-workflow とは別エントリ（`source: ./plugins/growth`）として登録し、単独で導入・無効化できる配布単位とする。

この分離は、関心の分離（開発ワークフローと学習メタ機構の責務境界）に加え、**常時ロードの分離（コンテキスト効率）** を理由とする。Claude Code のスキルはセッション開始時に description（name＋説明）のみが常時ロードされ、`SKILL.md` 本体は呼び出し時の on-demand ロードである。growth を dev-workflow に同梱すると growth の各スキル description が dev-workflow 利用者のセッションに常時加算されるため、独立プラグイン化して growth を必要とする利用者だけがその description をロードする構成とする。本判断はコンテキスト膨張・トークン効率対策にあたる（設計要素別の逆引きは各 ADR 本文を参照する。ADR-20260711-3 決定7）。

## Consequences

- **得られる利益**: 関心が分離され、growth を必要としない利用者は dev-workflow のみを導入できる。growth のスキル description が dev-workflow 利用者のセッションに常時加算されず、コンテキスト効率を損なわない。学習メタ機構の進化（capture スキル・学び置き場・store）を dev-workflow のリリースサイクルから独立させられる。
- **受容したコスト**: プラグインが2個体制になり、marketplace エントリ・バージョニング・配布の管理対象が増える。両プラグインを併用する利用者は2エントリの導入が必要になる。
- **将来の留保事項**: growth と dev-workflow の接続は疎結合（`capture` は `gh` で直接 Issue を起票し、既存の refine-issue / DoR に乗る）を前提とする。将来この疎結合が崩れ密結合が必要になった場合は、本分離判断を再検討する。

## 関連ADR

- Related: ADR-20260601-autonomy-approval-gate-alignment（growth の二段ゲートが依拠する自律度・承認ゲート軸）
- Related: ADR-20260602-2-autonomy-ladder-convention（同上、L2/L3 の承認ゲート規約）
- 関連Issue: #343
