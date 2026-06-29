# セッションログ形式の一次調査（spike #378）

> **位置づけ**: growth Phase 3「過去セッションログの横断解析」（DESIGN.md 決定事項2・§3「客観痕跡の取得」）の前提となる一次調査の記録。後続実装（#350 横断解析）の入口仕様。

## 調査時点・対象バージョン

- **調査日**: 2026-06-27
- **対象**: Claude Code セッションログ（観測バージョン **2.1.150 〜 2.1.195**、調査時の現行 2.1.195）

> ⚠️ **揮発性の注意**: 本ログ形式は Claude Code の**公式に文書化されていない内部実装詳細**であり、バージョン依存で変わりうる。約1ヶ月で 2.1.150→2.1.195（45パッチ）進行している実績がある。下記「スナップショット」節のフィールド名・構造・record 種別は実装時に再検証すること。判断（実現可能性・制約・前提条件）は形式の細部が変わっても揺らがないため恒久情報として扱ってよいが、抽出ロジックを細部のフィールド名に強く依存させない設計が望ましい。

---

## 1. 結論：実現可能性の判定

**横断解析の実現可能性 ＝ 条件付き可。**

- **可である根拠**: 形式（JSONL・per-project・構造化フィールド）も走査コストも問題なし。原理3の予測誤差シグナル（拒否・訂正・再試行・ツールエラー・タイムスタンプ）はすべて取得可能（§4）。全ログの全文走査が実測 0.08 秒（§5）で、原理6（個人版フリート学習）のコスト条件を満たす。
- **条件**: 生ログは**約30日でローテーション消滅する揮発資産**（§3）。原理6 を満たすには「ログ消滅前にシグナルを抽出し、個人 store に永続化する」運用が前提になる。

## 2. 後続実装（#350 横断解析）への前提条件

1. **走査対象**: 親セッション `~/.claude/projects/*/*.jsonl` に加え、**サブエージェントログ `~/.claude/projects/*/*/subagents/agent-*.jsonl` も含める**。後者は `<session-uuid>/subagents/` 配下に分離保存され `*/*.jsonl` の glob では拾えないが、サブエージェントが起こした拒否・訂正・ツールエラーはこちらに記録されるため、走査から外すと取りこぼす（本環境実測で 195 ファイル・ツール呼び出し 1,922 件・`is_error` 46 件・`thinking` 159 件）。全 project-id 横断（worktree は別 project-id として並ぶため自動的に含まれる）。
2. **30日ローテに先んじた抽出**: 生ログは既定30日で削除される（§3）。一度きりの解析では30日より前が欠落する。Phase 3 の自発トリガーは、取りこぼしを避けるため**30日より十分短い周期**（マージンを見て週次程度）で走査し、抽出済みシグナルを個人 store に永続化する設計とする。これは決定事項2 / 決定事項4（自発トリガー）に効く設計ドライバ。
3. **抽出ロジック**: §4 のフィールドマッピングに準拠。ただし§4は版依存スナップショットであり、実装時に再検証する。
4. **compaction 耐性のため raw 全行スキャン**: 会話の compaction はディスクログを書き換えないが（§6）、session loader の patched chain を経由すると compaction 前の生エントリを取りこぼす。抽出器は `compact_boundary` を無視して raw JSONL を全行走査し、シグナルは生エントリから取る（§6）。

---

## 3. 保持期間・ローテーション

- セッションファイルは設定 **`cleanupPeriodDays`（既定 30 日・最小 1 日）** に従い、**期間を過ぎたものが起動時に削除される**（[公式ドキュメント](https://code.claude.com/docs/en/settings)で確認、2026-06-27）。`0` はバリデーションエラーで拒否。
- ローカル実測でも最古ログが約27日前（調査日 6/27 / 最古 5/31）で、既定30日と整合。
- 圧縮・段階ローテーション（`.gz` 等）の痕跡はなく、**期限切れファイルのまるごと削除**のみ。
- 永続化を完全に止めたい場合は環境変数 `CLAUDE_CODE_SKIP_PROMPT_HISTORY` / 非対話モードの `--no-session-persistence`（本調査の主眼ではないが参考）。

---

## 4. スナップショット（版依存・実装時に再検証）

### 4.1 保存場所・形式

- **パス**: `~/.claude/projects/<project-id>/<session-uuid>.jsonl`
- **project-id**: 作業ディレクトリ（cwd）の絶対パスのスラッシュ `/` を `-` に置換したもの。例: `/home/kuchita/Development/claude-shared-skills` → `-home-kuchita-Development-claude-shared-skills`。
- **per-project**: グローバル集約ではない。ただし全プロジェクトが `~/.claude/projects/` 配下に並ぶため、横断走査は1ディレクトリ階層で完結する。worktree は別 project-id ディレクトリに分離される。
- **形式**: JSONL（1行1レコード）。**1ファイル ＝ 1セッション**（`sessionId` は全イベントレコードでファイル名の UUID と一致）。
- **付随**: `<session-uuid>/` サブディレクトリにスナップショット類（file-history 等）と、**サブエージェントログ `<session-uuid>/subagents/agent-*.jsonl`**（＋ メタ `agent-*.meta.json`）。サブエージェントログは親セッションの JSONL とは別ファイルで、サブエージェントのツール呼び出し・結果・思考・ツールエラーを含む。予測誤差シグナル（§4.3）を漏れなく取得するには親と併せて走査する（§2 走査対象を参照）。

### 4.2 レコード種別（観測例：370行のセッション）

`assistant` / `user` を主軸に、`system`・`mode`・`worktree-state`・`ai-title`・`last-prompt`・`attachment`・`queue-operation`・`pr-link`・`file-history-snapshot` 等。各レコードに `timestamp`・`version`・`sessionId`・`uuid`・`parentUuid`（会話ツリーの親子）・`cwd`・`gitBranch` 等のメタを持つ。

### 4.3 予測誤差シグナルのフィールドマッピング（原理3）

| シグナル | 取得元 | 形式 |
|---|---|---|
| タイムスタンプ | 全レコード `.timestamp` | ISO 8601 UTC ミリ秒（例 `2026-06-26T11:51:06.912Z`） |
| ツール呼び出し | `assistant.message.content[]` の `type=tool_use`（`name` / `input` / `id`） | 構造化 |
| ツール結果 | `user.message.content[]` の `type=tool_result`、および同レコード top-level の `toolUseResult`（構造化結果） | 構造化 |
| ツール拒否（ユーザー中断） | マーカー文字列 `"Request interrupted by user"` / `"The user doesn't want to proceed"` | 文字列 |
| ツール失敗 | `tool_result.is_error: true` | bool |
| ユーザー訂正 | `type=user` の text / string content（`tool_result` 以外の発話） | 自然文 |
| 再試行 | `tool_use.id` ↔ `tool_result.tool_use_id` の紐付け＋連続する同一ツール呼び出し | 相関で導出 |
| 思考過程 | `assistant.message.content[]` の `type=thinking` | 自然文 |
| 出所＝tool-result 由来 | `user.message.content[]` の `type=tool_result` / top-level `toolUseResult` の存在 → `tool-result` | 構造化 |
| 出所＝user 発話由来 | `type=user` の text / string content（`tool_result` 以外の発話）→ `user-utterance` | 自然文 |
| expected（予測） | `assistant.message.content[]` の `type=thinking` / `tool_use.input`（予測の手掛かり） | 自然文 / 構造化 |
| actual（実際） | `tool_result`（`is_error` 含む）/ 後続の user 発話（実際の結果） | 構造化 / 自然文 |

> **出所 / expected / actual の抽出元（capture 新スキーマ #416）**: capture 観察スキーマの `origin`（出所）・`expected`・`actual` フィールドは上表のフィールドから抽出する。出所はツール結果由来（`tool-result`）かユーザー発話由来（`user-utterance`）かの2値で、いずれも transcript に実在するフィールドへ対応し、capture が引用元を持つ（捏造でない）ことを裏付ける。本節は版依存スナップショットであり、抽出ロジックを上記フィールド名へ強依存させない設計方針（本節冒頭⚠️）と整合させる。

補助的に `permissionMode` / `mode`（権限・モード）、`gitBranch` / `cwd`（文脈）、`attributionSkill` / `attributionPlugin`（どのスキル・プラグイン起因か）、`system` の `away_summary`（区切りごとの自動要約）も取得可能。

> **git revert** は本ログ外（`git log`）が一次ソース。ログ内 Bash `tool_use` からも部分検知できるが、Phase 3 では git log を主とする。

---

## 5. 横断走査コスト（原理6の成立条件）

調査時点のローカル環境での実測：

- 規模: 41 project ディレクトリ / **1,682 ファイル / 約 267 MB**。
- 全ファイルへの `grep` 全文走査が **wall clock 0.08 秒・最大 RSS 約 5 MB**。

→ jq / grep ベースのバッチ走査はコスト的に完全に現実的。原理6（過去セッション群をまたいだ走査）のコスト前提を満たす。

---

## 6. compaction とログ保持（追記専用・抽出への影響）

会話の compaction（コンテキストウィンドウが埋まったときの自動圧縮、および手動 `/compact`）は、オンディスクの JSONL を**書き換えない**。検証（2026-06-28、公式ドキュメント＋実ログ観察）:

- JSONL は**追記専用**。compaction が起きても compaction 前の生エントリ（`user` / `assistant` / `tool_use` / `tool_result`）はディスク上に**そのまま残る**。削除・置換は発生しない。
- compaction は `{type:"system", subtype:"compact_boundary"}` の**マーカーを1行追記するだけ**（`compactMetadata` に `trigger`〔auto / manual〕・`preTokens` / `postTokens`・preserved segment の UUID〔head / anchor / tail〕を持つ）。
- 実例: 手動 `/compact` のセッションで `preTokens 104,487 → postTokens 3,882`・preserved 3 件だが、境界前の生エントリ（全 139 行中 115 行目が境界、前 114 行）はディスクに残存。
- compaction 後も同一 `<session-uuid>.jsonl` に追記が続く（新ファイルへ切り替わらない）。session loader は読み込み時に preserved segment だけを繋ぎ直す——これは**コンテキスト再構成**であってディスク操作ではない。

**抽出精度への含意**: 本設計の抽出は決定事項2 によりログの**事後解析**（ディスク JSONL を読む）を主軸とするため、compaction によって**抽出精度は劣化しない**——予測誤差シグナル（§4.3）は全てディスクの生エントリに残る。これは決定事項2 の頑健性であり、mid-session ライブ相乗りを退けた #381 の採用形（境界・別時間の事後解析）への追加論拠でもある（ライブ相乗りでモデルのコンテキストから読む設計だと、compaction 後はコンテキストに要約しか残らず生信号を失い精度が劣化する）。

**実装要件**: 上記の精度不変は「抽出が生のフラット JSONL を**全行**読む」場合に限る。session loader の patched chain（preserved＋境界後のみの compaction 後ビュー）を経由すると境界前の生エントリを取りこぼすため、抽出器は **`compact_boundary` を無視して raw JSONL を全行スキャン**する（§2 前提条件4）。`away_summary`（§4.3）や `compact_boundary` の要約・メタは lossy であり、シグナルは常に生エントリから取る。

---

## 関連

- 親エピック: #350（growth Phase 3）／本 spike: #378
- DESIGN.md「§3 客観痕跡の取得」「§6 決定事項2・4」「実装時に一次確認する事項」
- 原理2（再現したら本物）・原理3（客観痕跡 > 主観内省）・原理6（個人版フリート学習）
