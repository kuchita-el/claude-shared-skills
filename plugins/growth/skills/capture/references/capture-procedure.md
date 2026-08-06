# capture 判定基準の詳細

capture SKILL.md の Step 2（シグナル検知）・Step 3（生観察の生成）・Step 4（store 書き込み）から参照される判定基準・規約の単一出典。記述例は `${CLAUDE_SKILL_DIR}/references/capture-examples.md` を参照する。

## シグナル検知の判定基準（Step 2）

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

### ハーネス強制摩擦の既定除外（直交2ゲート・D3）

origin=tool-result のうち、ハーネスが既に強制済みの摩擦は capture 段で**既定除外する**（store に書かない）。後から決定的に再導出可能なため。機械的に判別可能な telemetry に限る:

- File-not-read ガード（"File has not been read yet" 等）
- worktree 破棄ガード
- ツールスキーマ検証エラー（入力スキーマ不適合）
- 常設 deny ルール（settings.json）による自動拒否（対話的な許可プロンプトを伴わないもの）
- API 一時障害（HTTP 529 等の retriable エラー）

これらはハーネス発のガード/deny/エラーとして機械判別できる。ユーザーが許可プロンプトを対話的に拒否した拒否（常設 deny ルールでない）は判断であり `ツール拒否` として観測対象に残す（除外しない）。**ただしハーネス非強制のルール再発（ガードを持たない CLAUDE.md ルール等の反復違反＝#417 の的）は除外しない**（保持する）。除外は機械判別可能な telemetry に限定し、判別が曖昧な摩擦は落とさず残す（精査は Distill）。

## 痕跡種別（origin）の判定（Step 3）

各シグナルが transcript のどの痕跡（tool-result / user-utterance）として現れたかで痕跡種別を2値に判定する（値域は personal-store-spec.md「痕跡種別」節を単一出典とする）。

| origin | 判定 |
|---|---|
| `tool-result` | ツール結果（`type=tool_result` / `toolUseResult` / `is_error` 等）に現れた予測誤差。環境（権限・hook・コマンド失敗）との摩擦 |
| `user-utterance` | ユーザー発話（`type=user` の text、tool_result 以外）に現れた予測誤差。当方の判断・提案への訂正 |

痕跡種別（軸）は `signal` 種別と直交する独立軸であり、signal を置換・改名しない。

## expected / actual の抽出（Step 3）

各シグナルについて、当方が予測した結果（`expected`）と実際に起きた結果（`actual`）を transcript から取り出す。引用可能性は**非対称**である（spec「生記録性」節）:

- `actual`（実際の結果）は transcript に実在する痕跡（`tool_result`〔`is_error` 含む〕/ 後続のユーザー発話）の**逐語断片を含む引用**で記す（要点が transcript に実在する文字列であればよく、地の文で囲んでよい。全文の逐語転記は不要。複数行は単一行に畳み込む。spec「パース規約」節参照）。
- `expected`（予測した結果）は逐語では存在しないことが多いため、痕跡（`type=thinking` / `tool_use.input`）に基づき「何を予測していたか」を**再構成**してよい（逐語引用に限らない）。抽出元は capture-signal-spec.md。

- **捏造禁止**: 痕跡（手掛かり）が無い `expected` / `actual` は**空にする**（フィールド自体は常設、値は該当時のみ）。`ツール拒否`・`反復試行` や判断知（`選好`・`却下理由`・`目標表明`・`設計判断`）等で予測の手掛かりが無い観察では expected / actual が空になりうる。手掛かりの無い予測を埋めようとして解釈を混入させない（生記録性の契約）。
- origin・expected・actual はいずれも、再構成は「何が起きたか／何を予測したか」の事実の言語化までに限り、摩擦/学びの価値判断・原因分析・改善案は加えない（Distill の責務）。

## エントリ形式と書き込み方式（Step 4）

**エントリ形式**（1観察 = 1エントリ）:

```
## <timestamp>
- signal: <シグナル種別>
- session: <session-UUID>
- origin: <tool-result | user-utterance>
- expected: <予測（transcript 抽出。抽出不能なら空）>
- actual: <実際（transcript 抽出。抽出不能なら空）>

<observation 本文（複数行可）>
```

`origin` は Step 3 の判定に従い2値で記す。`expected` / `actual` は Step 3 で抽出した引用を記し、抽出不能なら値を空にする（行自体は残す）。

**書き込み方式**（当日バケット `captures-YYYY-MM-DD.md` へ append）:

- **バケット未存在（当日初回）**: Write ツールで新規作成する。
- **バケット存在**: Read ツールで既存内容を全文読み取り、末尾に新規エントリを連結して Write ツールで全書換する。既存エントリは変更せず保持する（末尾追記のみで既存本文を書き換えない＝破壊的一括変換をしない）。

複数シグナルを検知した場合、各エントリを別の `## <timestamp>` 見出しで記録する（1観察 = 1エントリ）。同一実行時刻となる複数エントリには Step 1 の run 内序数サフィックス（`-NN`）を付し、見出しキーを一意化する（provenance キー衝突の防止）。**同一 run の全エントリは Step 1 で一度取得した同一 timestamp（`-NN` で一意化）を共有するため、同一 UTC 日・同一バケットに同居する**（run 内でバケット跨ぎは起こらない。バケット切り替えは UTC 日付の境界でのみ起こる）。

## 関連

- [`capture-examples.md`](capture-examples.md) — 本ファイルの判定基準に対応する記述例（observation 本文・エントリ）
- `${CLAUDE_PLUGIN_ROOT}/references/personal-store-spec.md` — 本文中の「spec」の実体。シグナル種別・痕跡種別の値域、生記録性・パース規約、project-id とパスの解決手順、バケット名生成規約の単一出典
- `${CLAUDE_PLUGIN_ROOT}/references/capture-signal-spec.md` — 痕跡ソース session jsonl からの `origin`（痕跡種別）/ `expected` / `actual` の抽出元
