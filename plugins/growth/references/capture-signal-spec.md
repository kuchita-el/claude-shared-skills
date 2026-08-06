# 学習シグナル抽出仕様

capture が痕跡から観察スキーマの `origin`（痕跡種別）・`expected`（予測）・`actual`（実際）を抽出する際の、**抽出元**を定義する。

## 位置づけ

- 本仕様が定めるのは**抽出元だけ**である。観察スキーマの各欄の意味・記録規約・生記録性は [`personal-store-spec.md`](personal-store-spec.md) が持つ。
- 抽出元のフィールド名は、痕跡ソース（session jsonl）の**公式に文書化されていない内部実装詳細**であり、バージョン依存で変わりうる。したがって抽出ロジックを個々のフィールド名へ強く依存させない（フィールド名が変わっても、痕跡種別の2値判別・`expected` の再構成・`actual` の逐語引用という取り方そのものは変わらない）。以下ではこれを**揮発性の注意**と呼ぶ。

## 学習シグナルのフィールドマッピング

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
| 痕跡種別＝tool-result | `user.message.content[]` の `type=tool_result` / top-level `toolUseResult` の存在 → `tool-result` | 構造化 |
| 痕跡種別＝user-utterance | `type=user` の text / string content（`tool_result` 以外の発話）→ `user-utterance` | 自然文 |
| expected（予測） | `assistant.message.content[]` の `type=thinking` / `tool_use.input`（予測の手掛かり） | 自然文 / 構造化 |
| actual（実際） | `tool_result`（`is_error` 含む）/ 後続の user 発話（実際の結果） | 構造化 / 自然文 |

> **痕跡種別 / expected / actual の抽出元（capture 新スキーマ #416）**: capture 観察スキーマの `origin`（痕跡種別）・`expected`・`actual` フィールドは上表のフィールドから抽出する。痕跡種別はツール結果由来（`tool-result`）かユーザー発話由来（`user-utterance`）かの2値で、いずれも transcript に実在するフィールドへ対応し、capture が引用元を持つ（捏造でない）ことを裏付ける。`actual` は逐語断片を含む引用（要点が transcript に実在する文字列）、`expected` は上表の手掛かり（`type=thinking` / `tool_use.input`）に基づく再構成、`origin` は痕跡がどのフィールドに現れたかの2値判別である（引用可能性の非対称は personal-store-spec.md「生記録性」節）。上表は版依存スナップショットであり、抽出ロジックを上記フィールド名へ強依存させない設計方針（「位置づけ」の揮発性の注意）と整合させる。

補助的に `permissionMode` / `mode`（権限・モード）、`gitBranch` / `cwd`（文脈）、`attributionSkill` / `attributionPlugin`（どのスキル・プラグイン起因か）、`system` の `away_summary`（区切りごとの自動要約）も取得可能。

> **git revert** は本ログ外（`git log`）が一次ソース。ログ内 Bash `tool_use` からも部分検知できるが、Phase 3 では git log を主とする。

## 関連

- [`personal-store-spec.md`](personal-store-spec.md) — 観察スキーマ（`origin` / `expected` / `actual` を含む）の意味・記録規約・生記録性の単一出典
