---
status: 承認済み
validity: 有効
---

# ADR-20260531: Delivery実装メカニクスを superpowers に委譲し、dev-workflow は Discovery＋接続契約に縮退する

## Context

OSSプラグイン obra/superpowers を調査した（2026-05-31時点: star 213,047 / fork 18,980 / 最終push 2026-05-30 / 最新 v5.1.0 / 非アーカイブ）。superpowers は TDD・git worktree・計画・コードレビュー・subagent駆動実装を備えた成熟した汎用開発メソドロジーであり、クロスハーネス（Claude Code / Codex / Gemini / Cursor / Copilot / OpenCode）対応。

dev-workflow の Delivery 層（plan-issue / dev-loop の実装メカニクス）と superpowers の実行層は中核が重複する。実物レベルの突き合わせでは、dev-loop 固有の上乗せ（独立 test-spec 検証・リトライ統治・振動検知）の多くは品質寄与の薄いセレモニーであり、骨格は superpowers と同等または superpowers が保守で優位と判定した。

一方、superpowers は v5.1.0 の貢献ガイドラインで **domain-specific skills / project-specific configuration / fork-specific changes を明示的に却下対象**とした（過去100PRの94%がAIスロップで却下）。したがって dev-workflow 固有領域（DDD戦略設計・GitHub Issueライフサイクル・依存分析・日本語規約）の上流マージは不可能であり、dev-workflow は superpowers の**補完プラグイン**としてのみ存続しうる。

superpowers のフローは brainstorming（曖昧なアイデアから開始）を起点とし、ドメイン構造を事前に確保する機構を持たない。デリバリーアイテムの積み上げによる局所最適設計（数アイテム後のモデル作り直し）は superpowers の構造的弱点であり、dev-workflow の「70%見通しのドメイン構造を先に確保する」Discovery がこの空白を埋める。

## Decision

dev-workflow を superpowers と正面競合させず、**実装メカニクスは superpowers に乗り、固有の堀に縮退する**。

1. **superpowers に委譲する（再発明・保守しない）**:
    - 汎用実装メカニクス: TDD小サイクル、検証ゲート、リファクタリング、raw なコードレビュー、git worktree 並列、subagent 駆動実装
    - 対応 superpowers スキル: `test-driven-development` / `executing-plans` / `requesting-code-review` / `subagent-driven-development` / `using-git-worktrees` / `finishing-a-development-branch`
    - 計画骨格（マイクロタスク分解の雛形）: superpowers `writing-plans`。ただし plan-issue が生成する検証方針・判断依頼・AC↔テストケース対応表は接続契約として dev-workflow が保持する（項2参照）

2. **dev-workflow が保持する（superpowers に存在しない）**:
    - **Discovery（堀）**: problem-statement、event-storming、domain-modeling、ユースケース仕様、ADR
    - **接続契約（結合組織）**: plan-issue の検証方針・判断依頼、dev-loop のレビュー契約・Issue コメントへのエスカレーション。Discovery と superpowers 実行層を繋ぐ
    - 依存分析（dependency-check）、日本語成果物・運用規約

3. **ドメインモデルに委譲境界を書かない**: `docs/{domain}/event-storming.md` ・ `domain-model.md` はツール非依存を保つ。superpowers への委譲対応は `docs/references/skill-phase-mapping.md`（スキル対応表）に記載し、本 ADR を根拠として参照する（#221 で `docs/workflow-design.md` 本体から同 reference へ移設）。委譲は実装・技術の決定であり、ドメインの事実ではないため、モデル層に漏らさない。

4. **差別化の縦軸**: DDD戦略設計を背骨に先行 → Issue/AC 追跡は需要検証後に接続 → 敵対的検証でドメイン不変条件＋AC充足を保証。

## Consequences

**得られた利益**:

- 実装メカニクスの保守競争から離脱し、保守コストを削減。superpowers の成熟（振る舞いテストによるレビュー品質保証、クロスハーネス対応、worktree の同意・ハーネス連携・安全削除）を取り込める
- 堀（DDD縦軸）にリソースを集中できる
- ドメインモデルがツール非依存を保ち、superpowers の動向から隔離される

**受容したトレードオフ**:

- superpowers への依存（バージョン動向・破壊的変更リスク）。委譲部分の挙動を細かく制御できなくなる
- dev-loop 固有機構（独立 test-spec 検証・リトライ統治・振動検知）は失われる（セレモニーと判定し許容）
- Issue コメントへの非同期エスカレーション等、superpowers に無い接続契約は薄いアダプタとして延命する必要がある

**将来の留保事項**:

- 接続契約の精密な per-aggregate 境界（どこまでを自作アダプタで繋ぐか）は未確定。`docs/references/skill-phase-mapping.md`（スキル対応表）で漸進的に確定する
- Issue/AC 追跡軸（縦軸の軸1）は需要が未検証。DDD背骨を先に固め、ドッグフードで検証してから接続する（star を生むインディー層ではなく、静かなプロ/企業層の需要）
- superpowers の配布形態への接続方式（マーケットプレイス併載 vs 必要スキルの移植）は未確定。ライセンス確認が前提
- 野心: 当面は自分/チーム用ツール、将来 OSS で DDD 縦軸のデファクトを狙う

## 関連ADR

Related: ADR-20260606-3-superpowers-soft-delegation（本ADRがパークした委譲の依存方式・非導入時フォールバックを 606-3 が充足。上書きでない）
Related: ADR-20260607-workflow-unit-validity-reference-mechanism（本ADRがパークした委譲境界の単位/シーム実現を 607 が精緻化。上書きでない）
Related: ADR-20260602-principles-rationale-hub（workflow-design.md の責務定義 facet の現行の住処。本ADRが規定する Delivery 層への委譲境界は、この責務分割に依拠する。旧 ADR-20260402 の決定1の後継）、ADR-20260718-workflow-design-v2-terminology-flow-stock-axes（v2 構造のうち生存する決定群の現行の住処。本ADRは同構造の Delivery 層に superpowers 委譲境界を導入する。ADR分割以前は上書き済みの ADR-20260402-workflow-design-v2-structure を指していた）
Related: ADR-20260513-workflow-design-scope-team（workflow-design.md のスコープ限定の先行例。本ADRも同設計書の責務範囲を規定する）
