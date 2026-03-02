---
description: デイリースクラム前のIssue/PR状況一覧表示
allowed-tools:
  - Bash(gh issue list*)
  - Bash(gh issue view*)
  - Bash(gh pr list*)
  - Bash(gh pr view*)
  - Bash(gh api*)
  - Bash(git fetch*)
  - Bash(git log*)
  - Bash(git branch*)
  - AskUserQuestion
  - Read
---

# Issue/PR状況一覧

デイリースクラム前に、現在のIssue/PR状況を一覧表示します。
結果はコンソールに出力するだけ。活用方法はユーザーに委ねる。

## 引数

- `$ARGUMENTS` に以下のパラメータを指定可能:
  - `--from YYYY-MM-DD --to YYYY-MM-DD`: 対象期間を指定（スプリント期間の代替）。未指定の場合はユーザーに確認する。
  - `--date YYYY-MM-DD`: アクティビティ対象日を指定。未指定の場合は昨日（JST）をデフォルトとする。

## 共通定義

### 日付計算ルール

日付の算出（`--from/--to` のデフォルト値や `--date` のデフォルト値）はBashコマンドを使わず、システムプロンプトの現在日付からClaude自身が計算する。

JST→UTC変換を行い、GitHub API・gitコマンドに渡すためのタイムスタンプを算出する。**形式は必ずISO 8601（`YYYY-MM-DDTHH:MM:SSZ`）を使用する。** `gh` CLIの検索クエリ（`created:`/`merged:`/`closed:`）および `git log` の `--since`/`--until` の両方で時刻レベルの精度でフィルタされる。

- **UTC_START**: 対象日のJST 0:00をUTCに変換した値（= 前日 `T15:00:00Z`）
- **UTC_END**: 対象日のJST 23:59:59をUTCに変換した値（= 当日 `T14:59:59Z`）

例:

- `--date 2026-02-05`（JST）→ `UTC_START=2026-02-04T15:00:00Z`, `UTC_END=2026-02-05T14:59:59Z`
- `--date 2026-03-01`（JST）→ `UTC_START=2026-02-28T15:00:00Z`, `UTC_END=2026-03-01T14:59:59Z`（月またぎ）

### Issue-PR紐づけパターン

PRの本文（body）から関連Issueを抽出する際、以下のパターンを検出する:

- `Closes #123` / `Fixes #123` / `Resolves #123`
- `関連Issue: #123`
- `## Summary` セクション内の `#123` 参照

### コマンド実行ルール

- **パイプやリダイレクトを使わない**。`allowed-tools` のパターンマッチが失敗し、許可確認が発生するため
- JSON加工が必要な場合は `gh` の `--jq` フラグを使う（`python3` や `jq` にパイプしない）
  - 例: `gh pr list --json number,title --jq '.[] | {number, title}'`
- `gh api` やgitコマンドの取得に失敗した場合はエラーにせず、取得できた情報のみで出力する

## 設定ファイル

`.claude/skills/daily-prep/config.yaml` をReadツールで読み込む。

- ファイルが存在しない場合はデフォルト値を使用する（正常動作）
- `issueTrackers` は配列形式で複数のトラッカーを設定可能。現在は `github` のみサポート（Jira対応は将来実装予定）
  - `github` 以外のタイプが設定された場合は警告を出力し、そのタイプをスキップして処理を続行する
- 以降のステップでは `CONFIG.{キー}` として設定値を参照する

**デフォルト値**:

| 設定キー                               | デフォルト値       |
| -------------------------------------- | ------------------ |
| `issueTrackers`                        | `[{type: github}]` |
| `blockers.reviewPendingThresholdHours` | `24`               |

## Phase 1: Issue/PR状況一覧

### 1-1. 引数の確認（from/to）

`$ARGUMENTS`から `--from`、`--to`、`--date` を取得する。`--date` の詳細処理はStep 3-1で行う。

日付の算出は共通定義: 日付計算ルール を参照。

`--from`/`--to` が未指定の場合は **AskUserQuestion ツール**で対象期間を確認する:

- question: "対象期間を指定してください（スプリント期間など）"
- options: 直近1週間 / 直近2週間 / その他（手入力）

> **AskUserQuestion が利用できない場合**: デフォルトの対象期間（直近2週間）を使用してください。

`--from`/`--to` は `gh issue list` / `gh pr list` の `--search "created:FROM..TO"` でサーバーサイドフィルタする。出力のヘッダにフィルタ条件を表示する（例: `Issue/PR状況一覧（YYYY-MM-DD〜YYYY-MM-DD）`）。

### 1-2. オープンIssueの取得

#### GitHub

```bash
gh issue list --state open --search "created:YYYY-MM-DD..YYYY-MM-DD" --limit 50 --json number,title,assignees,labels,body,url
```

- `gh issue view` は `gh issue list` の `body` が不十分な場合のフォールバック用に許可している

### 1-3. 親子関係の解析

各Issueの本文（body）から子Issueへの参照を抽出する。以下のパターンを検出する:

- `- [ ] #123` / `- [x] #123` 形式のタスクリスト
- `## 子Issue` / `## サブタスク` セクション内の `#123` 参照

親子関係がある場合は、以下のルールで整理する:

- 子Issueを持つIssueを「親Issue」として扱う
- 親Issueの下に子Issueをインデントして表示
- 親子関係がないIssueはフラットに表示
- 親子関係は1階層のみ対応（孫Issueは考慮しない）
- クローズ済みの子Issueはオープン一覧に含めない
- 複数の親から参照されている場合は、最初に検出された親の下に表示する
- 親子関係の検出に失敗した場合は、フラットに表示する（エラーにしない）

### 1-4. オープンPRの取得・状態判定

#### GitHub

```bash
gh pr list --state open --search "created:YYYY-MM-DD..YYYY-MM-DD" --limit 50 --json number,title,author,isDraft,reviewDecision,reviewRequests,body,url,createdAt --jq '[.[] | . + {status: (if .isDraft then "draft" elif .reviewDecision == "APPROVED" then "approved" elif (.reviewRequests | length) > 0 then "review_pending" elif .reviewDecision == "CHANGES_REQUESTED" then "changes_requested" else "open" end), hours_since_created: (((now - (.createdAt | fromdateiso8601)) / 3600) | floor)}]'
```

`--jq` により、各PRに以下のフィールドが付与される:

- `status`: PR状態
- `hours_since_created`: PR作成からの経過時間（時間単位、切り捨て）

各 `status` 値と表示の対応:

| `status`            | 状態表示        | アクション対象   |
| ------------------- | --------------- | ---------------- |
| `draft`             | 🔨 Draft        | 作成者           |
| `approved`          | ✅ Approved     | 作成者（マージ） |
| `review_pending`    | 👀 レビュー待ち | レビュワー       |
| `changes_requested` | 🔄 変更要求     | 作成者           |
| `open`              | 🔵 Open         | 作成者           |

判定の優先順位（`--jq` の `if/elif` 順序）:

1. `isDraft: true` → `draft`
2. `reviewDecision: "APPROVED"` → `approved`
3. `reviewRequests` が1件以上 → `review_pending`（CHANGES_REQUESTED + 再レビュー依頼済みもここに分類）
4. `reviewDecision: "CHANGES_REQUESTED"` → `changes_requested`
5. 上記以外 → `open`

### 1-5. PR関連Issueの抽出

#### GitHub

PRの本文から関連Issueを抽出する（共通定義: Issue-PR紐づけパターン 参照）。

### 1-6. 結果の出力

取得した情報を以下のテンプレートに従ってMarkdown形式でコンソールに出力する。

```markdown
# Issue/PR状況一覧（YYYY-MM-DD）

## オープンIssue一覧

| #              | タイトル          | 担当者 | ラベル   |
| -------------- | ----------------- | ------ | -------- |
| **[#10](URL)** | 親Issueタイトル   | @user  | `label1` |
| ├ [#11](URL)   | 子Issue1タイトル  | @user  | `label2` |
| └ [#12](URL)   | 子Issue2タイトル  | -      | -        |
| **[#20](URL)** | 独立Issueタイトル | @user  | `label3` |

**合計**: XX件（親Issue: X件、子Issue: X件、独立: X件）

## オープンPR一覧

| #              | タイトル   | 作成者 | 状態            | 関連Issue  |
| -------------- | ---------- | ------ | --------------- | ---------- |
| **[#30](URL)** | PRタイトル | @user  | ✅ Approved     | [#10](URL) |
| **[#31](URL)** | PRタイトル | @user  | 👀 レビュー待ち | [#20](URL) |
| **[#32](URL)** | PRタイトル | @user  | 🔨 Draft        | -          |
| **[#33](URL)** | PRタイトル | @user  | 🔄 変更要求     | [#15](URL) |

**合計**: XX件（Approved: X件、レビュー待ち: X件、変更要求: X件、Draft: X件、Open: X件）
```

- 担当者がいない場合は「-」
- ラベルがない場合は「-」
- 親子関係があるIssueは階層表示（├ / └）。最後の子のみ `└`、それ以外は `├`

## Phase 2: ブロッカー・注意事項

Step 1-4で付与済みの `status` と `hours_since_created` を使って判定する。状態判定と経過時間は `--jq` で決定論的に計算済みであり、Claudeはこれらの値を参照するだけでよい。

### 2-1. ブロッカーの抽出

#### 🚨 ブロッカー: レビュー待ち放置

判定条件（全てAND）:

- `status` が `review_pending`
- `hours_since_created` > `CONFIG.blockers.reviewPendingThresholdHours`

レビューリクエスト時刻はPR作成時刻 (`createdAt`) で近似する（Draft→Ready移行後の経過時間は正確ではない可能性がある）。

### 2-2. 注意事項の抽出

#### ⚠️ 注意(1): Draft PR

判定条件:

- `status` が `draft`

#### ⚠️ 注意(2): PR未作成のアサイン済みIssue

判定条件:

- `assignees` が1人以上（Step 1-2のデータ）
- Step 1-3で親Issueと判定されたものを除外
- Step 1-4 + 1-5の結果から、そのIssueに紐づくオープンPRが存在しない

紐づけの判定方法:

- Step 1-5のPR→Issue紐づけ（共通定義: Issue-PR紐づけパターン 参照）の逆引き
- いずれかのオープンPRがそのIssue番号を参照していれば「PR作成済み」と判定

### 2-3. 結果の出力

Step 2-1, 2-2で抽出した情報を以下のテンプレートに従ってMarkdown形式で出力する。

```markdown
## 🚨 ブロッカー

### レビュー待ち放置（{CONFIG.blockers.reviewPendingThresholdHours}時間超過）

| PR         | タイトル   | 作成者  | 経過時間 | レビュワー             |
| ---------- | ---------- | ------- | -------- | ---------------------- |
| [#30](URL) | PRタイトル | @author | 36時間   | @reviewer1, @reviewer2 |

**合計**: X件

## ⚠️ 注意

### Draft PR

| PR         | タイトル   | 作成者  | 経過時間 |
| ---------- | ---------- | ------- | -------- |
| [#32](URL) | PRタイトル | @author | 12時間   |

### PR未作成のアサイン済みIssue

| #          | タイトル      | 担当者    |
| ---------- | ------------- | --------- |
| [#15](URL) | Issueタイトル | @assignee |

**合計**: Draft PR X件、PR未作成Issue X件
```

出力制御:

- 🚨 ブロッカーが0件 → セクション省略
- ⚠️ 注意が全て0件 → セクション省略
- 注意内の各サブセクションも0件なら省略
- 全て0件 → Phase 2の出力なし
- 経過時間は時間単位（切り捨て）で表示

## Phase 3: アクティビティ

### 3-1. アクティビティ対象日の計算

`$ARGUMENTS` から `--date` を取得する。未指定の場合は昨日（JST）をデフォルトとする。`--date` と `--from/--to` は独立したパラメータ（それぞれ別の目的で使用）。

日付計算とJST→UTC変換は共通定義: 日付計算ルール を参照。

### 3-2. コミット履歴の取得

まずリモートの最新情報を取得し、全ブランチのコミットをローカルで検索する:

```bash
git fetch --all --prune --quiet
git log --all --since="UTC_START" --until="UTC_END" --no-merges --format='%H %an %s'
```

- `--all`: 全ブランチ（main、featureブランチ、Dependabotブランチ等）を対象とする
- `--prune`: 削除済みブランチの追跡を除去する
- `--no-merges`: マージコミットを自動除外する
- 作者名はGitのauthor name（GitHub usernameではない）で取得される

#### GitHub

各コミットについて、関連するPRを取得する:

```bash
gh api "repos/{owner}/{repo}/commits/{sha}/pulls" --jq '.[0] | {number, title, url, body}'
```

- `{owner}/{repo}` は現在のリポジトリから取得する
- 関連PRが見つかった場合、PRの本文から関連Issueを抽出する（共通定義: Issue-PR紐づけパターン 参照）
- API呼び出し回数を抑えるため、同一PRに属するコミットは初回取得結果をキャッシュする
- API取得に失敗したコミットは未紐付けコミットとして扱う（ブランチ名で分類）

関連PRが見つからないコミットは、ブランチ名で分類する:

```bash
git branch -r --contains {sha}
```

- 複数ブランチが返る場合は、`origin/main` 以外のブランチを優先する
- `origin/` プレフィックスは除去して表示する（例: `feature/100-daily-prep-phase2`）

### 3-3. PR作成/マージの取得

#### GitHub

```bash
# 対象日に作成されたPR
gh pr list --state all --search "created:UTC_START..UTC_END" --limit 50 --json number,title,author,createdAt,url,body

# 対象日にマージされたPR
gh pr list --state merged --search "merged:UTC_START..UTC_END" --limit 50 --json number,title,author,mergedAt,url,body
```

- PR本文から関連Issueを抽出する（共通定義: Issue-PR紐づけパターン 参照）
- 同日に作成・マージされたPRは両方のクエリに含まれるが、Step 3-5で `🆕 作成` と `✅ マージ` を別行として出力するため、重複除去は不要

### 3-4. Issueステータス変更の取得

#### GitHub

```bash
# 対象日にクローズされたIssue
gh issue list --state closed --search "closed:UTC_START..UTC_END" --limit 50 --json number,title,assignees,closedAt,url

# 対象日にオープンされたIssue
gh issue list --state all --search "created:UTC_START..UTC_END" --limit 50 --json number,title,assignees,createdAt,url
```

### 3-5. 結果の出力

Step 3-2〜3-4で取得した情報をIssue/PRベースでグルーピングして出力する。

グルーピングルール:

- Issue/PRごとにアクティビティ（コミット、PR作成/マージ、Issueクローズ/オープン）をまとめる
- コミットのIssue紐付け: コミットが属するPR → PRの関連Issue で間接的に紐付け
- PRがIssueに紐づく場合はIssueの下にまとめ、紐づかないPRは独立して表示する
- Issue/PRに紐づかないコミットはブランチ名でグルーピングする
- アクティビティはIssue/PRベースでグルーピングする（人ベースではない）

Phase 1の出力（Step 1-6）の後に、以下のテンプレートで追加出力する:

```markdown
## アクティビティ（YYYY-MM-DD）

### [#10 ユーザー認証機能](URL)

- コミット4件
- 🆕 [PR#30](URL) 作成
- 🔴 Issueクローズ

### [#20 ダッシュボード改善](URL)

- ✅ [PR#25](URL) マージ

### [PR#35 リファクタリング](URL)

- コミット2件

### 未紐付けコミット

- `feature/42-new-page`: 1件
- `chore/update-dependencies`: 1件

---

**サマリ**: コミット X件、PR作成 X件、PRマージ X件、Issueクローズ X件、Issueオープン X件
```

- 全カテゴリにアクティビティがない場合は「アクティビティはありません」と表示する
- 絵文字: 🆕=PR作成、✅=PRマージ、🔴=Issueクローズ、🟢=Issueオープン
- 「未紐付けコミット」セクションはIssue/PRに紐づかないコミットがある場合のみ表示する
