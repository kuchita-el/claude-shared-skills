---
description: capture は現セッション会話履歴（session jsonl）から予測誤差シグナル（訂正・ツール拒否・反復試行・期待違反）を検知し、解釈を加えない生観察として個人ローカル store に記録する。判断は後回しにし、「何が起きたか」のみを記す。セッション中の予測誤差を貯めたいとき・growth プラグインの学習ループを手動で起動したいときに明示起動する（Phase 1）。
allowed-tools:
  - Read
  - Write
  - Bash(mkdir *)
  - Bash(date *)
  - Bash(printenv *)
  - Bash(git rev-parse *)
  - Bash(grep *)
---

# capture

現セッション会話履歴から予測誤差シグナルを検知し、生観察を個人ローカル store へ記録する。

## 目的・原則

- **目的**: 予測誤差（驚き）の痕跡を「判断前」の状態で保存する。蒸留・候補化は Distill が担う。
- **生記録性**: observation には「何が起きたか」のみを記録する。原因分析・対策・分類・昇格判断を書かない。解釈は Distill に委ねる（DESIGN.md 原理3・Capture 原則「判断は後回し」）。
- **Phase 1 スコープ**: 痕跡ソースは現セッションの session jsonl のみ。明示起動のみ（hook 自発化は Phase 3）。`客観痕跡` は store のシグナル値域に含むが本段では投入しない。

## 手順

### Step 1: 入力収集

以下を順に取得する。

**リポジトリルートと project-id**:

`<project-id>` の解決手順（`git rev-parse --path-format=absolute --git-common-dir` を用いる）は、個人ローカル store 仕様の「project-id とパスの解決手順」を単一出典とする（`${CLAUDE_PLUGIN_ROOT}/references/personal-store-spec.md`）。同手順に従い `<project-id>` を解決する（capture・distill 双方が同一手順で同一 project-id を得る）。

**session UUID**:

```bash
printenv CLAUDE_CODE_SESSION_ID
```

> Phase 3（hook 自発化）移行時は `CLAUDE_CODE_CHILD_SESSION=1` 環境下での session UUID 解決を要再確認。

**timestamp**（ISO 8601 UTC）:

```bash
date -u +"%Y-%m-%dT%H:%M:%SZ"
```

**パスの組み立て**:

- store パス: `~/.claude/projects/<project-id>/growth/captures.md`
- jsonl パス: `~/.claude/projects/<project-id>/<session-UUID>.jsonl`

> jsonl の保存場所は Claude Code の内部仕様に依存する。不明な場合は `~/.claude/projects/<project-id>/` 配下を確認すること。

### Step 2: jsonl 読取とシグナル検知

**ファイル存在確認**:

Read ツールで jsonl パスを読み取る。ファイルが存在しない・読み取れない場合は「セッションログが見つかりません（確認パス: ...）」と報告して終了する。ファイルが存在しない場合でもエントリを store に書かない。

**シグナル走査**:

jsonl の内容（JSON Lines 形式）から4種のシグナルを**再現率寄り**（拾い過ぎ許容）で走査する。確実なものより多めに拾い、精査は Distill に委ねる。

必要に応じてキーワードで絞り込む（例）:

```bash
grep -i "denied\|permission\|拒否\|訂正\|違う\|error\|再試行" \
  ~/.claude/projects/<project-id>/<session-UUID>.jsonl
```

各メッセージから以下のシグナルを識別する:

| シグナル | 識別の手掛かり |
|---|---|
| `訂正` | ユーザーが当方の出力・提案を修正した発話（「違う」「〜ではなく〜」「〜を使え」等）または当方が誤りを認めた発話 |
| `ツール拒否` | ツール呼び出しが拒否された記録（denied、permission denied、hook ブロック等の痕跡） |
| `反復試行` | 同一目的の操作を複数回繰り返した記録（同じコマンド・同じ修正が連続する等） |
| `期待違反` | 予測した結果と実際の結果が食い違った痕跡（エラー後の対処、「想定と異なる」等の発話） |

> `客観痕跡`（git revert・CI 失敗等）は store のシグナル値域に含まれるが Phase 1 では投入しない（取得は Phase 3）。

**0件の場合**: 捕捉ゼロを報告して終了する（空エントリを store に書かない）。

### Step 3: 生観察の生成

Step 2 で検知した各シグナルについて observation を生成する。

**記述対象**: 「何が起きたか」のみ。ユーザーの発話・ツール結果・当方の応答から観察できる事実を記述する。  
**記述禁止**: 原因・対策・分類・改善提案・昇格判断を含めない。

例:
```
ユーザーが「git checkout ではなく git restore を使え」と訂正した。
当方はファイル復元に git checkout を提案していた。
```

### Step 4: store 書き込み

**ディレクトリ作成**（存在しない場合）:

```bash
mkdir -p ~/.claude/projects/<project-id>/growth/
```

**エントリ形式**（1観察 = 1エントリ）:

```
## <timestamp>
- signal: <シグナル種別>
- session: <session-UUID>
- status: unprocessed

<observation 本文（複数行可）>
```

`status` は常に `unprocessed` で書き込む（既存エントリの status を変更しない）。

**書き込み方式**:

- **store 未存在**: Write ツールで新規作成する。
- **store 存在**: Read ツールで既存内容を全文読み取り、末尾に新規エントリを連結して Write ツールで全書換する。既存エントリ（`promoted` 含む）は保持する。

複数シグナルを検知した場合、各エントリを別の `## <timestamp>` 見出しで記録する（1観察 = 1エントリ）。

## 完了報告

書き込んだエントリ数・各シグナル種別・store パスを報告する。

```
3件の観察を記録しました。
- 訂正 × 1
- ツール拒否 × 2
store: ~/.claude/projects/-home-user-myproject/growth/captures.md
```
