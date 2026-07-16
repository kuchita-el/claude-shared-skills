# ドッグフード観察ログ: <Issue番号> <タイトル>

#267（再配線後スキルの実Issueドッグフード検証）の観察記録テンプレート。新規Issue着手時にコピーして `records/<issue番号>-<slug>.md` として埋める。

`records/` 配下は git 管理外（`records/.gitignore` 参照）。観察結果は当該変更の PR 本文へ記録する。本ディレクトリ直下に置くテンプレート・手順書のみが追跡対象。

## メタ

- 対象リポ:
- 対象Issue: <URL>
- 実施日: YYYY-MM-DD
- 担当: kuchita-el + Claude (model: )
- 使用フロー: plan-issue → implementation（再配線後）
- 想定観察制約: （例: TDD適合性なし＝テスト網羅性は観察対象外、等）

## 実行記録

### Phase 1: plan-issue

- 起動コマンド:
- 計画生成エージェント: `dev-workflow:plan` / built-in `Plan` / その他
- writing-plans preload 結果: 成功 / フォールバック / 不明
- レビュー結果: PASS / FAIL（回数）
- 観察:
  - [ ] writing-plans の preload 警告の有無
  - [ ] 計画品質（マイクロタスク分解の妥当性、AC↔テストケース対応表の有無）
  - [ ] 接続契約の保持確認（検証方針・判断依頼）
- 自由記述:

### Phase 2: implementation

- 起動コマンド:
- worktree: 使用 / 不使用（理由）
- 委譲対象スキル稼働状況:
  - [ ] test-driven-development（S4） — N/A の場合はその旨記載
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
| 独立 test-spec 検証撤去 | テスト観点漏れが review/runtime で初検出されたか | | 後退あり/なし/N/A |
| リトライ統治撤去 | 失敗ループ・暴走・人間介入頻度 | | 後退あり/なし |
| 振動検知撤去 | 同一箇所の往復編集 | | 後退あり/なし |
| レビュー契約（保持） | requesting-code-review が blocker を実際に検出したか | | 機能した/しなかった |

## 結論

- 品質後退: あり / なし / 一部
- 詳細:
- 別Issue化が必要な事項:
- 観察制約（観察できなかった軸）:
