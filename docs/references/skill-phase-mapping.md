# スキルとフェーズの対応

主要なワークフローフェーズは共有スキルとして実装されている。汎用実装メカニクスは superpowers に委譲し、dev-workflow は Discovery（堀）と接続契約を担う。委譲境界の根拠は [ADR-20260531](../adr/ADR-20260531-superpowers-delegation-boundary.md) を参照。

| 設計書のフェーズ | 対応スキル | 担い手（ADR-20260531） | 状態 | 入力 | 出力 |
|---|---|---|---|---|---|
| ドメイン構造（イベント・集約） | `event-storming` | dev-workflow（堀） | 実装済み | ドメイン名 | `docs/{domain}/event-storming.md`, `docs/big-picture.md` |
| ドメイン構造（型・ワークフロー） | `domain-modeling` | dev-workflow（堀） | 実装済み | ドメイン名 | `docs/{domain}/domain-model.md` |
| 技術設計+タスク分解 | `plan-issue` | dev-workflow（接続契約: 検証方針・判断依頼）／ 計画骨格は superpowers `writing-plans` に委譲（参照機構③）。**単位は現状維持**（ADR-20260607） | 実装済み | Issue番号 | `docs/plans/issue-{番号}.md`（判断依頼・検証方針を含む） |
| 実装+レビュー+PR | `implementation` | 実装メカニクス（TDD・検証ゲート・rawレビュー・worktree）は superpowers へ委譲／ 接続契約（レビュー契約・Issueエスカレーション）は dev-workflow が保持。**単位は現状維持・参照機構②中心**（ADR-20260607。撤去/保持の線引きは方針C・子D/子E） | 実装済み | Issue番号 or 計画ファイル | 実装コード + テスト + PR |

**委譲先 superpowers スキル**: 計画骨格 `writing-plans`、実装メカニクス `test-driven-development` / `executing-plans` / `requesting-code-review` / `subagent-driven-development` / `using-git-worktrees` / `finishing-a-development-branch`。

各スキルの内部フェーズ・サブエージェント構成の詳細は、各 `plugins/dev-workflow/skills/{skill-name}/SKILL.md` を参照。全スキルの一覧は [README.md「スキル一覧」](../../README.md#スキル一覧) を参照。
