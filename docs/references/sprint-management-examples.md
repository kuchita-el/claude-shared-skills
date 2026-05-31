# プロジェクト管理とSprint運用

作業単位の階層・Sprint運用の定義と、ツール別の運用モデルケースを示す。

---

## 作業単位の階層

| 単位 | 定義 | 期間の目安 |
|------|------|-----------|
| テーマ | 関連するデリバリーアイテムの束。1つのビジネス目標や技術的目標に対応する | 数週間〜数ヶ月（複数Sprint） |
| デリバリーアイテム | ユースケース仕様からACを転記したIssueで管理する作業単位。マージ時点で何らかの価値が完結している | 数日〜1 Sprint |
| タスク | デリバリーアイテムを技術的に分解した実装単位。plan-issueで生成する | 数時間（1コミット） |

各単位は機能的な作業にも技術的な作業（Enabler）にも適用できる:

| 単位 | 機能的な例 | 技術的な例（Enabler） |
|------|-----------|---------------------|
| テーマ | ログイン体験の改善 | Next.jsメジャーバージョン移行 |
| デリバリーアイテム | パスワードリセット機能 | App Router移行 |
| タスク | リセットリンク送信APIの実装 | 認証ページのApp Router移行 |

## <a id="sprint-ops"></a>Sprint運用

```
Sprint開始
├─ ユースケース仕様 → Issue起票（ACを転記）
├─ Issue → plan-issue → dev-loop → PR
├─ 生成コードを人間がレビュー（ACとの差分・副作用確認）
├─ PRにIssue番号を紐付けてマージ
└─ 振り返り → 新Issue起票 / 必要ならADR更新 / ドメイン構造へのフィードバック
```

テーマ・Sprint・ロードマップの管理にはプロジェクト管理ツール（GitHub Projects、Jira等）を使用する。ツール選定はプロジェクトに委ねる。以下にツール別の運用モデルケースを示す。

---

## GitHub Projects

### 構成要素の対応

| ワークフローの概念 | GitHub Projectsでの実現 |
|---|---|
| テーマ | Issue（`theme` ラベル）+ Milestone |
| デリバリーアイテム | Issue（ACまで記載、spec.mdを参照） |
| Sprint | Iteration フィールド |
| Sprintボード | Board view（Status列でカンバン） |
| ロードマップ | Timeline view（Milestoneで期間を表示） |
| バグ・リスク | Issue（`bug` / `risk` ラベル） |

### Sprint計画の流れ

1. **Iteration作成**: Project設定でIterationフィールドに次Sprintの期間を追加
2. **Issue選定**: Backlog（Iterationが未設定のIssue）からSprintに含めるIssueを選び、Iterationフィールドに割り当て
3. **優先順位付け**: Board viewでIssueの並び順を調整
4. **Sprint実行**: Issue → plan-issue → dev-loop → PR → レビュー → マージ
5. **振り返り**: 完了/未完了をBoard viewで確認。未完了Issueは次Iterationに移動または再見積もり

### テーマ管理

- テーマ用のIssueを作成し `theme` ラベルを付与。本文にデリバリーアイテムのIssueへのリンクを列挙する
- Milestoneを対応付けることで、Timeline viewでテーマ単位の進捗を俯瞰できる
- テーマIssueのtasklist（`- [ ] #123` 形式）で配下デリバリーアイテムの完了状況を追跡する

### PR → Issue の自動リンク

PRの本文またはブランチ名にIssue番号を含めることで自動リンクされる。`Closes #123` でマージ時にIssueが自動closeされる。

---

## Jira（Atlassian）

### 構成要素の対応

| ワークフローの概念 | Jiraでの実現 |
|---|---|
| テーマ | Epic イシュータイプ |
| デリバリーアイテム | Story イシュータイプ（ACまで記載） |
| Sprint | Scrum Board の Sprint |
| Sprintボード | Scrum Board |
| ロードマップ | Timeline ビュー |
| バグ・リスク | Bug / Task イシュータイプ |

### Sprint計画の流れ

1. **Sprint作成**: Scrum BoardでSprintを作成し、期間を設定
2. **Issue選定**: BacklogからStoryをSprintにドラッグ
3. **Story Point見積もり**: Planning Pokerやチーム合意で見積もり
4. **Sprint開始**: Sprint実行。Jira上のStoryをIn Progressに移動
5. **GitHubとの連携**: PRにJiraのIssueキー（例: `PROJ-123`）を含めると、Jira側でPRのステータスが自動追跡される（GitHub for Jira連携が必要）
6. **振り返り**: Sprint Report / Velocity Chart で完了状況を確認

### GitHub連携時の注意点

JiraのStoryとGitHubのIssueを二重管理しない。以下のいずれかに統一する:

**パターン1: Jira主導（推奨: チームがJiraに慣れている場合）**
- Jira Story = 作業管理の源泉
- GitHub Issue = 作成しない。PRの説明にJira Issueキーを記載
- spec.mdからJira StoryにACを転記

**パターン2: GitHub主導（推奨: 小規模チーム/OSSプロジェクト）**
- GitHub Issue = 作業管理の源泉
- Jira = 上位レベルの進捗管理（テーマ/ロードマップ）のみ使用
- spec.mdからGitHub IssueにACを転記

### Confluenceとの連携

Discovery成果物のうち、Confluenceに原本を置くものとリポジトリに転記するものの使い分けは [外部ツールとの連携](../../CLAUDE.md#external-tools)を参照。
