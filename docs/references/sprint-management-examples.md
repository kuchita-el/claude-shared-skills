# Sprint運用のモデルケース

workflow-design.md 3.8「Sprint運用」のリファレンス。ツール別の運用例を示す。

---

## GitHub Projects

### 構成要素の対応

| ワークフローの概念 | GitHub Projectsでの実現 |
|---|---|
| Epic | Issue（`epic` ラベル）+ Milestone |
| feature | Issue（ACまで記載、spec.mdを参照） |
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

### Epic管理

- Epic Issueを作成し `epic` ラベルを付与。本文にfeature Issueへのリンクを列挙する
- Milestoneを対応付けることで、Timeline viewでEpic単位の進捗を俯瞰できる
- Epic Issueのtasklist（`- [ ] #123` 形式）で配下のfeature Issueの完了状況を追跡する

### PR → Issue の自動リンク

PRの本文またはブランチ名にIssue番号を含めることで自動リンクされる。`Closes #123` でマージ時にIssueが自動closeされる。

---

## Jira（Atlassian）

### 構成要素の対応

| ワークフローの概念 | Jiraでの実現 |
|---|---|
| Epic | Epic イシュータイプ |
| feature | Story イシュータイプ（ACまで記載） |
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
- Jira = 上位レベルの進捗管理（Epic/ロードマップ）のみ使用
- spec.mdからGitHub IssueにACを転記

### Confluenceとの連携

Discovery成果物のうち、Confluenceに原本を置くものとリポジトリに転記するものの使い分けは workflow-design.md 4.3「外部ツールとの連携」を参照。
