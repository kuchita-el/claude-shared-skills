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

判定基準の詳細は `${CLAUDE_SKILL_DIR}/references/capture-procedure.md` を、記述例は `${CLAUDE_SKILL_DIR}/references/capture-examples.md` を参照する（手順本文を SKILL.md に二重化しない）。

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

**timestamp**（見出しキー。ISO 8601 UTC の capture 実行時刻）:

```bash
date -u +"%Y-%m-%dT%H:%M:%SZ"
```

1 run で **2件以上**の観察を記録する場合、同一実行時刻での provenance キー衝突を防ぐため、各見出しに run 内序数サフィックス `-NN`（run 内で桁幅を揃えたゼロ埋め序数・`-01` 始まり・記録順。既定2桁、1 run で100件以上記録する場合のみ桁を拡張）を付す（例: 同一実行時刻の2観察は `## 2026-07-11T09:19:03Z-01` と `## 2026-07-11T09:19:03Z-02` の別キーになり衝突しない）。1件のみの run はサフィックスを付さない。サフィックスは固定幅で辞書順が記録順に一致するため、カーソル比較（同一キー空間・単調増加）を壊さない。規則の根拠と却下代替は ADR-20260711-4。

**バケット名の組み立て**:

上で取得した見出しキー timestamp（`date -u` 由来）の**日付部分 `YYYY-MM-DD`**（先頭10文字。または `date -u +"%Y-%m-%d"`）を抽出し、バケット名 `captures-YYYY-MM-DD.md` を組み立てる（例: `2026-07-11T09:19:03Z` → `captures-2026-07-11.md`）。バケット名は見出しキー timestamp の**純関数**であり、capture はローテーション状態を持たない（無状態）。生成規約は personal-store-spec.md「置き場」の「バケット名生成規約」を単一出典とする。

**パスの組み立て**:

- store バケットパス: `~/.claude/projects/<project-id>/growth/captures-YYYY-MM-DD.md`
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

走査対象は2群:

- **A. 予測誤差検出器（摩擦知）**: `訂正` / `ツール拒否` / `反復試行` / `期待違反`
- **B. 教示信号検出器（予測誤差の形を持たない会話知）**: `選好` / `却下理由` / `目標表明` / `設計判断`

各シグナルの識別の手掛かり、判断知の origin・`expected` / `actual` の扱い、`客観痕跡` の Phase 1 非投入、およびハーネス強制摩擦の既定除外（直交2ゲート・D3。機械判別可能な telemetry に限定し、対話的なツール拒否は除外しない）は `${CLAUDE_SKILL_DIR}/references/capture-procedure.md` を参照する。

**0件の場合**: 観測ゼロを報告して終了する（空エントリを store に書かない）。

### Step 3: 生観察の生成

Step 2 で検知した各シグナルについて observation を生成し、あわせて痕跡種別・予測・実際を抽出する。

**記述対象**: 「何が起きたか」のみ。ユーザーの発話・ツール結果・当方の応答から観察できる事実を記述する。  
**記述禁止**: 原因・対策・分類・改善提案・昇格判断を含めない。

**痕跡種別（origin）の判定**: 各シグナルが transcript のどの痕跡として現れたかで `tool-result` / `user-utterance` の2値に判定する（値域は personal-store-spec.md「痕跡種別」節を単一出典とする）。痕跡種別（軸）は `signal` 種別と直交する独立軸であり、signal を置換・改名しない。

**expected / actual の抽出**: 各シグナルについて、当方が予測した結果（`expected`）と実際に起きた結果（`actual`）を transcript から取り出す。`actual` は逐語断片を含む引用、`expected` は痕跡に基づく再構成を許すという**非対称**の規約があり、手掛かりが無い場合は捏造せず空にする。

2値の判定基準・引用可能性の非対称・捏造禁止の詳細は `${CLAUDE_SKILL_DIR}/references/capture-procedure.md` を、observation 本文の例は `${CLAUDE_SKILL_DIR}/references/capture-examples.md` を参照する。

### Step 4: store 書き込み

**ディレクトリ作成**（存在しない場合）:

```bash
mkdir -p ~/.claude/projects/<project-id>/growth/
```

**エントリの書き込み**: 当日バケット `captures-YYYY-MM-DD.md` へ 1観察 = 1エントリで append する。エントリは `## <timestamp>` 見出しと `signal` / `session` / `origin` / `expected` / `actual` の各欄、observation 本文で構成する。バケット未存在時は Write で新規作成し、存在する場合は Read で全文読み取り末尾に連結して全書換する（既存エントリは変更しない）。複数エントリを記録する場合は Step 1 の run 内序数サフィックス（`-NN`）で見出しキーを一意化する。

エントリ形式の全文・書き込み方式・run 内の同一バケット同居の不変条件は `${CLAUDE_SKILL_DIR}/references/capture-procedure.md` を、記述例（tool-result 由来／判断知）は `${CLAUDE_SKILL_DIR}/references/capture-examples.md` を参照する。

## 完了報告

書き込んだエントリ数・各シグナル種別・store パスを報告する。ハーネス強制摩擦として既定除外した観察があれば、その件数も併記する（D3 の除外が効いたことを可視化するため）。

```
3件の観察を記録しました。
- 訂正 × 1
- ツール拒否 × 2
store: ~/.claude/projects/-home-user-myproject/growth/captures-2026-06-26.md
```

## 関連

- `${CLAUDE_SKILL_DIR}/references/capture-procedure.md` — 判定基準の詳細（シグナル検知の2群・ハーネス強制摩擦の既定除外・痕跡種別の判定・expected / actual の抽出・エントリ形式と書き込み方式）の単一出典
- `${CLAUDE_SKILL_DIR}/references/capture-examples.md` — 記述例（observation 本文・tool-result 由来のエントリ・判断知のエントリ）
- `${CLAUDE_PLUGIN_ROOT}/references/personal-store-spec.md` — 出力先 store の形式・シグナル種別／痕跡種別の値域・project-id とパスの解決手順・バケット名生成規約・パース規約
- `${CLAUDE_PLUGIN_ROOT}/references/session-log-format.md` — 痕跡ソース session jsonl の形式（§4.3 が `origin`（痕跡種別）/ `expected` / `actual` の抽出元）
- `${CLAUDE_PLUGIN_ROOT}/DESIGN.md` — 設計母艦（§2 原理3・§3 学習ループ／保存設計／客観痕跡の取得／二段ゲート・§4 プラグイン構成）
