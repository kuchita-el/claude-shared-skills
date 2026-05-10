各Issueについて以下の形式で結果を返してください:

- number: Issue番号
- title: タイトル
- size: Small / Medium / Large
- is_ready: true / false
- clarification_items: 確認事項のリスト（なければ空配列）

スキル呼び出し側はこの結果を集約し、以下の形式で最終出力する。

```markdown
## Issue精査サマリー

| # | タイトル | サイズ | Ready | 確認事項 |
|---|---------|--------|-------|---------|
| 1 | 機能追加 | Medium | ❌    | 2件     |
| 3 | バグ修正 | Small  | ✅    | なし    |
| 5 | 設計変更 | -      | -     | error   |

### 統計

- 精査対象: {total}件
- 作業可能（Ready）: {ready}件
- 確認事項あり（Not Ready）: {not_ready}件

### 次のアクション

- Not ReadyのIssueは確認事項を解消後、`/refine-issue {number}` で個別に再精査
- ReadyのIssueは作業開始可能
```

**エラーハンドリング**: サブエージェントが失敗した場合、該当Issueはサマリーテーブル内に `error` ステータスで表示し、エラー詳細をテーブル直後に補足する。
