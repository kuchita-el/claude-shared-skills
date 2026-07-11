---
description: capture は現セッション会話履歴（session jsonl）から予測誤差検出器（訂正・ツール拒否・反復試行・期待違反）と教示信号検出器（選好・却下理由・目標表明・設計判断）で学習シグナルを検知し、解釈を加えない生観察として個人ローカル store に記録する。ハーネス強制済みの摩擦は既定除外する。判断は後回しにし「何が起きたか」のみを記す。セッション中の学習シグナルを貯めたいとき・growth の学習ループを手動起動するときに明示起動する（Phase 1）。
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

現セッション会話履歴から学習シグナル（予測誤差検出器・教示信号検出器の2系統）を検知し、生観察を個人ローカル store へ記録する。

## 目的・原則

- **目的**: 学習シグナルの痕跡を「判断前」の状態で保存する。仮説形成は Distill が担う。
- **2軸の検知**: 摩擦知（予測誤差検出器＝訂正・ツール拒否・反復試行・期待違反）と、予測誤差の形を持たない判断知（教示信号検出器＝選好・却下理由・目標表明・設計判断）の両方を拾う。復元不能性・価値の判定は Distill / promote に委ね、capture では行わない（ADR-20260701 D2）。
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

**シグナル走査（2群）**:

jsonl の内容（JSON Lines 形式）から、摩擦知（A）と判断知（B）の2群を**再現率寄り**（拾い過ぎ許容）で走査する。確実なものより多めに拾い、精査・価値判定は Distill / promote に委ねる。signal 値域の正準定義は personal-store-spec.md「シグナル種別」節を参照する（capture では値域を再定義しない）。

必要に応じてキーワードで絞り込む（例）:

```bash
grep -i "denied\|permission\|拒否\|訂正\|違う\|ではなく\|error\|再試行\|したい\|方針\|却下\|べき" \
  ~/.claude/projects/<project-id>/<session-UUID>.jsonl
```

**A. 予測誤差検出器（摩擦知＝摩擦サブセット）**: 予測誤差の形を持つ摩擦を拾う。user 訂正系は復元不能性とも重なるため引き続き有効（退行させない）。

| シグナル | 識別の手掛かり |
|---|---|
| `訂正` | ユーザーが当方の出力・提案を修正した発話（「違う」「〜ではなく〜」「〜を使え」等）または当方が誤りを認めた発話 |
| `ツール拒否` | ツール呼び出しが拒否された記録（denied、permission denied、hook ブロック等の痕跡） |
| `反復試行` | 同一目的の操作を複数回繰り返した記録（同じコマンド・同じ修正が連続する等） |
| `期待違反` | 予測した結果と実際の結果が食い違った痕跡（エラー後の対処、「想定と異なる」等の発話） |

**B. 教示信号検出器（予測誤差の形を持たない会話知）**: user 発話が決定内容（選好・理由付き却下・目標/意図/継続方針・設計境界の確定）を帯びていれば **recall 優先で軽く**拾う。復元不能性・配布価値の判定は distill/promote に委ね、capture では行わない（判断は後回し）。

| シグナル | 識別の手掛かり |
|---|---|
| `選好` | ユーザーが選択肢間の選好・傾きを表明した（「A より B」「こっちでいく」等） |
| `却下理由` | ユーザーが提案・設計を理由付きで却下した（「〜だから却下」「それはしない、理由は〜」等） |
| `目標表明` | ユーザーが目標・意図・継続方針を表明した（「〜したい」「方針は〜」「今後は〜」等） |
| `設計判断` | ユーザーが設計境界・方針を確定する判断を示した（「〜は〜に委ねる」「〜はやらない」等の境界確定） |

> 判断知は origin=user-utterance に現れる。予測誤差の形を持たないため `expected` / `actual` は空になりうる（捏造しない）。
> `客観痕跡`（git revert・CI 失敗等）は store のシグナル値域に含まれるが Phase 1 では投入しない（取得は Phase 3）。

**ハーネス強制摩擦の既定除外（直交2ゲート・D3）**: origin=tool-result のうち、ハーネスが既に強制済みの摩擦は capture 段で**既定除外する**（store に書かない）。後から決定的に再導出可能なため。機械的に判別可能な telemetry に限る:

- File-not-read ガード（"File has not been read yet" 等）
- worktree 破棄ガード
- ツールスキーマ検証エラー（入力スキーマ不適合）
- 常設 deny ルール（settings.json）による自動拒否（対話的な許可プロンプトを伴わないもの）
- API 一時障害（HTTP 529 等の retriable エラー）

これらはハーネス発のガード/deny/エラーとして機械判別できる。ユーザーが許可プロンプトを対話的に拒否した拒否（常設 deny ルールでない）は判断であり `ツール拒否` として観測対象に残す（除外しない）。**ただしハーネス非強制のルール再発（ガードを持たない CLAUDE.md ルール等の反復違反＝#417 の的）は除外しない**（保持する）。除外は機械判別可能な telemetry に限定し、判別が曖昧な摩擦は落とさず残す（精査は Distill）。

**0件の場合**: 観測ゼロを報告して終了する（空エントリを store に書かない）。

### Step 3: 生観察の生成

Step 2 で検知した各シグナルについて observation を生成し、あわせて出所・予測・実際を抽出する。

**記述対象**: 「何が起きたか」のみ。ユーザーの発話・ツール結果・当方の応答から観察できる事実を記述する。  
**記述禁止**: 原因・対策・分類・改善提案・昇格判断を含めない。

**出所（origin）の判定**: 各シグナルが transcript の**どこに現れたか**で出所を2値に分類する（値域は personal-store-spec.md「出所」節を単一出典とする）。

| origin | 判定 |
|---|---|
| `tool-result` | ツール結果（`type=tool_result` / `toolUseResult` / `is_error` 等）に現れた予測誤差。環境（権限・hook・コマンド失敗）との摩擦 |
| `user-utterance` | ユーザー発話（`type=user` の text、tool_result 以外）に現れた予測誤差。当方の判断・提案への訂正 |

出所軸は `signal` 種別と直交する独立軸であり、signal を置換・改名しない。

**expected / actual の抽出**: 各シグナルについて、当方が予測した結果（`expected`）と実際に起きた結果（`actual`）を transcript から取り出す。引用可能性は**非対称**である（spec「生記録性」節）:

- `actual`（実際の結果）は transcript に実在する痕跡（`tool_result`〔`is_error` 含む〕/ 後続のユーザー発話）の**逐語断片を含む引用**で記す（要点が transcript に実在する文字列であればよく、地の文で囲んでよい。全文の逐語転記は不要。複数行は単一行に畳み込む。spec「パース規約」節参照）。
- `expected`（予測した結果）は逐語では存在しないことが多いため、痕跡（`type=thinking` / `tool_use.input`）に基づき「何を予測していたか」を**再構成**してよい（逐語引用に限らない）。抽出元は session-log-format.md §4.3。

- **捏造禁止**: 痕跡（手掛かり）が無い `expected` / `actual` は**空にする**（フィールド自体は常設、値は該当時のみ）。`ツール拒否`・`反復試行` や判断知（`選好`・`却下理由`・`目標表明`・`設計判断`）等で予測の手掛かりが無い観察では expected / actual が空になりうる。手掛かりの無い予測を埋めようとして解釈を混入させない（生記録性の契約）。
- origin・expected・actual はいずれも、再構成は「何が起きたか／何を予測したか」の事実の言語化までに限り、摩擦/学びの価値判断・原因分析・改善案は加えない（Distill の責務）。

例（observation 本文）:
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
- origin: <tool-result | user-utterance>
- expected: <予測（transcript 抽出。抽出不能なら空）>
- actual: <実際（transcript 抽出。抽出不能なら空）>

<observation 本文（複数行可）>
```

`status` は常に `unprocessed` で書き込む（既存エントリの status を変更しない）。`origin` は Step 3 の判定に従い2値で記す。`expected` / `actual` は Step 3 で抽出した引用を記し、抽出不能なら値を空にする（行自体は残す）。

記述例（tool-result 由来。上記 user-utterance 由来の訂正例と対比できる）:

```
## 2026-06-26T15:10:02Z
- signal: ツール拒否
- session: 2265f83f-c5a8-41a0-b284-b5d90882a2da
- status: unprocessed
- origin: tool-result
- expected: rm のツール呼び出しが許可され実行される
- actual: tool_result.is_error=true、permission denied で拒否された

rm コマンドのツール呼び出しをユーザーが許可プロンプトで対話的に拒否した（常設 deny ルールによる自動拒否は D3 で既定除外。本例は対話的拒否のため観測対象）。
```

記述例（判断知。予測誤差の形を持たず `expected` / `actual` は空）:

```
## 2026-06-29T08:50:02Z
- signal: 設計判断
- session: 2265f83f-c5a8-41a0-b284-b5d90882a2da
- status: unprocessed
- origin: user-utterance
- expected:
- actual:

ユーザーが「プランを追跡対象に変えることはない。追跡可否は利用者に委ねる」と設計境界を確定した。
```

**書き込み方式**:

- **store 未存在**: Write ツールで新規作成する。
- **store 存在**: Read ツールで既存内容を全文読み取り、末尾に新規エントリを連結して Write ツールで全書換する。既存エントリ（`promoted` 含む）は保持する。

複数シグナルを検知した場合、各エントリを別の `## <timestamp>` 見出しで記録する（1観察 = 1エントリ）。

## 完了報告

書き込んだエントリ数・各シグナル種別・store パスを報告する。ハーネス強制摩擦として既定除外した観察があれば、その件数も併記する（D3 の除外が効いたことを可視化するため）。

```
3件の観察を記録しました。
- 訂正 × 1
- ツール拒否 × 2
store: ~/.claude/projects/-home-user-myproject/growth/captures.md
```
