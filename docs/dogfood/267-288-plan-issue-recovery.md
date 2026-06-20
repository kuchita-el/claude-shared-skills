# ドッグフード観察ログ: #288 plan-issue: 却下後のリカバリパス（再生成/手動修正）を定義する

#267（再配線後スキルの実Issueドッグフード検証）の観察記録。

## メタ

- 対象リポ: kuchita-el/claude-shared-skills
- 対象Issue: https://github.com/kuchita-el/claude-shared-skills/issues/288
- 実施日: 2026-06-20（着手）
- 担当: kuchita-el + Claude (model: claude-opus-4-7)
- 使用フロー: plan-issue → dev-loop（再配線後）
- 開始ブランチ: `feature/288-plan-issue-rejection-recovery`
- 開始コミット: afc5450 (Merge PR #306, v0.4.1 bump)
- 想定観察制約:
  - 本Issueは SKILL.md 編集が主体でテストコードを書く対象がない
  - → S4（test-driven-development）の委譲挙動・テスト網羅性後退は観察対象外
  - 観察可能: 計画品質・writing-plans 委譲・レビュー指摘・往復回数・人間介入頻度・finishing/verification 委譲

## 実行記録

### Phase 1: plan-issue

- 起動コマンド: `/dev-workflow:plan-issue 288`（スキル経由）
- 計画生成エージェント: `dev-workflow:plan`（custom agent、ID: a4930d268dcce5f12）
- writing-plans preload 結果: **成功**（エージェントが `<command-name>writing-plans</command-name>` `<skill-format>true</skill-format>` および skill 本体の preload を確認、フォールバック未使用）
- 計画生成所要: 203秒 / 111k tokens / 17 tool uses
- レビュー結果: **PASS（1周収束、指摘なし）** / レビュアーID: ae7ca754d0df0de43 / 64k tokens / 15 tool uses / 92秒
- 観察:
  - [x] writing-plans の preload 警告の有無 → 警告なし、preload 成功
  - [x] 計画品質 → タスク分解3件・AC↔テストケース対応表10件・判断依頼4件（判断待ち2＋前提確認2）。レビュー1周PASS
  - [x] 接続契約の保持確認 → 検証方針・判断依頼セクションともに dev-workflow plan-output-format に従って生成。writing-plans 委譲下でも dev-workflow 接続契約が機能している
- 自由記述:
  - 引数解析〜Issue情報取得まではメインループで実行（特に詰まりなし）
  - エージェントには Issue #97 と event-storming.md の確認も指示済み → 一次情報で実在確認の上で参照
  - writing-plans のメソドロジー（bite-sized 粒度・ファイル構造事前マッピング）と dev-workflow の出力形式が干渉なく両立。委譲の構造設計が機能している
  - 判断依頼 4 件（判断待ち2 + 前提確認2）。判断待ち2件は AskUserQuestion で1回のみで確定（推奨案2件採用）。前提確認2件はそのまま採用

### Phase 2: dev-loop

- 起動コマンド:
- worktree: 使用 / 不使用
- 委譲対象スキル稼働状況:
  - [ ] test-driven-development（S4） — **N/A**（テスト対象コードなし）
  - [ ] verification-before-completion（S5）
  - [ ] finishing-a-development-branch（S6）
  - [ ] requesting-code-review（S7）
  - [ ] using-git-worktrees
- フェーズ別所感:
  - 計画適用:
  - 実装:
  - 検証ゲート:
  - PR化:
  - レビュー反映:
- 自由記述:

## 撤去機構の影響評価

| 機構 | 後退兆候の観点 | 観測事象 | 評価 |
|---|---|---|---|
| 独立 test-spec 検証撤去 | テスト観点漏れが review/runtime で初検出されたか | N/A（テスト対象コードなし） | N/A |
| リトライ統治撤去 | 失敗ループ・暴走・人間介入頻度 | | |
| 振動検知撤去 | 同一箇所の往復編集 | | |
| レビュー契約（保持） | requesting-code-review が blocker を実際に検出したか | | |

## 結論

- 品質後退: （実施後記入）
- 詳細:
- 別Issue化が必要な事項:
- 観察制約: TDD/テスト網羅性軸は本Issueでは観察不可。当軸の観察は別Issue（実コードを含むリポでの追加観察）が必要。
