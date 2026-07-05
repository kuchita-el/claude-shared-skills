# Distill サンプル入力と期待結果（手順トレース用）

[`distill-procedure.md`](distill-procedure.md) の判定基準を検証するための worked example。本リポジトリは自動テスト基盤を持たないため、実装者は各例の入力を手順に通し（手順トレース）、期待結果と一致することを目視確認する。入力はすべて `status: unprocessed` とする。入力エントリは #416 以降のスキーマに従い `origin`（`tool-result` / `user-utterance`）欄を持つ。

各例が検証するケース:

| 検証するケース | 例 |
|---|---|
| 表層の語彙差を無視して同一トリガー×振る舞い差分を畳む | 例A |
| 同一 `signal` でも振る舞い差分が異なれば畳まない | 例A |
| 純記述的な観察を棄却する | 例B |
| 実行不能・空の観察を棄却する | 例B |
| 重複＋純記述＋有効の混在から有効分のみクラスタ化する | 例C |
| 各候補に provenance（畳んだ timestamp 群）・scope-hypothesis・career-hypothesis・candidate-status を付与し candidates.md へ upsert する | 例A・例C |
| 採用候補0件のとき candidates.md へ書き込まない | 例B |
| 出所（origin）で環境摩擦／判断誤りに分類し重み付け（出力順位）する（#417） | 例D |
| 既存ルール台帳と突合し既知ルールの再発を再発知見へ変換する（#417） | 例D |
| 判断群 signal を `decision-record` 型へ整形し、behavior-diff 要求・N 再発を免除して4欄で保存する（ADR-20260701 D4） | 例E |

---

## 例A: クラスタ化・重複排除

### 入力（store の `unprocessed` エントリ4件）

```
## 2026-06-26T10:00:00Z
- signal: 訂正
- session: 11111111-1111-1111-1111-111111111111
- status: unprocessed
- origin: user-utterance

ユーザーが「git checkout ではなく git restore を使え」と訂正した。当方はファイル復元に git checkout を提案していた。

## 2026-06-26T10:05:00Z
- signal: 訂正
- session: 11111111-1111-1111-1111-111111111111
- status: unprocessed
- origin: user-utterance

ファイル復元のつもりで git checkout . を実行しようとしたら、git restore を使うよう指摘された。

## 2026-06-26T11:00:00Z
- signal: 訂正
- session: 11111111-1111-1111-1111-111111111111
- status: unprocessed
- origin: user-utterance

ユーザーが「Markdown を -m に直接渡すな」と訂正した。長い本文をコマンド引数に直接渡そうとしていた。

## 2026-06-26T11:10:00Z
- signal: ツール拒否
- session: 11111111-1111-1111-1111-111111111111
- status: unprocessed
- origin: tool-result

長い PR 本文を gh pr create の --body に直接渡そうとして、ヒアドキュメントのクォートが3回壊れて失敗した。--body-file に切り替えて成功した。
```

### 手順トレース

1. **入力選択**: 4件すべて `unprocessed` → 全件が対象。
2. **棄却判定**: 4件すべてトリガー×振る舞い差分が読み取れる → 棄却なし。
3. **分類と重み付け**: エントリ1〜3 は `user-utterance` → 判断誤り（高優先）。エントリ4 は `tool-result` → 環境摩擦（低優先）。混在クラスタの後補正は後段クラスタ化後に行う（下記 step5・procedure §4.1）。
4. **トリガー×振る舞い差分の推論**:
   - エントリ1 → トリガー「ファイルを復元するとき」× 差分「git checkout でなく git restore を使う」
   - エントリ2 → トリガー「ファイルを復元するとき」× 差分「git checkout でなく git restore を使う」（**言い回し違いの重複**）
   - エントリ3 → トリガー「長文を CLI 引数に渡すとき」× 差分「-m 等に直接渡さず一時ファイル経由にする」
   - エントリ4 → トリガー「長文を CLI 引数に渡すとき」× 差分「直接渡さず --body-file（一時ファイル）経由にする」
5. **クラスタ化**:
   - 1 と 2 はトリガー×差分が一致 → 1候補へ集約（**表層の語彙差を無視して畳む**）。
   - 1・2（signal=訂正）と 3（signal=訂正）は **同一 signal だが振る舞い差分が異なる** → 畳まない（**signal 一致だけで集約しない**）。
   - 3 と 4 はトリガー×差分が一致 → 1候補へ集約（**signal/origin が異なっても、振る舞い差分が同じなら畳む**）。
   - この集約候補（3＋4）は `user-utterance`（3）と `tool-result`（4）の混在クラスタ → §4.1 により `user-utterance` を含むため**判断誤り（高優先）**に倒す。
6. **台帳突合**: 両候補とも参照源（`~/.claude/CLAUDE.md` 等）に一致する既存ルールが無ければ novel → 通常候補のまま（突合の既知例は例D）。

### 期待結果（候補2件 < 入力4件、`candidates.md` へ upsert）

各候補にメタ欄（provenance＝畳んだ観察の `## <timestamp>` 群、scope-hypothesis＝蒸留観点の仮説タグ、career-hypothesis＝昇格先キャリア＋宛先 repo 仮説、candidate-status＝`pending`）が付く。エントリ1・2 は同一クラスタなので provenance に両 timestamp を列挙する。両候補とも判断誤り（高優先）のため出力順位は同列で先頭側。

```
## ファイル復元には git restore を使う
- tags: [behavior-diff]
- provenance: 2026-06-26T10:00:00Z, 2026-06-26T10:05:00Z
- scope-hypothesis: universal
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
- candidate-status: pending

ファイルを復元するとき git checkout ではなく git restore を使う。git checkout はブランチ切り替えと復元が多重定義されており、誤操作で別ブランチへ移る事故を招くため。

## 長文は CLI 引数に直接渡さず一時ファイル経由にする
- tags: [behavior-diff]
- provenance: 2026-06-26T11:00:00Z, 2026-06-26T11:10:00Z
- scope-hypothesis: universal
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
- candidate-status: pending

Markdown 等の長文を CLI オプションに直接渡さない。ファイルへ書き出し --body-file 等で渡す。シェルのクォート・ヒアドキュメント制約による破損と、許可プロンプトの中断を避けるため。
```

これらは `candidates.md` へ provenance キーで upsert 永続化され、チャットにも提示される。両候補とも全プロジェクトに効くため scope-hypothesis は `universal`（仮説。最終裁定は下流の人間 refine/review）。career-hypothesis は両候補ともテキスト規範の汎用ルール（決定表 行4）のため `learnings.md`、宛先は配布元プラグイン repo（仮説。最終裁定は集約点）。
完了報告: 入力 unprocessed 4件 / 棄却0件 / 分類 判断誤り3件・環境摩擦1件 / 採用候補2件（2 < 4。再発知見変換0件）。

---

## 例B: 棄却

### 入力（store の `unprocessed` エントリ3件）

```
## 2026-06-26T12:00:00Z
- signal: 期待違反
- session: 22222222-2222-2222-2222-222222222222
- status: unprocessed
- origin: tool-result

npm install が想定より遅かった。

## 2026-06-26T12:05:00Z
- signal: 期待違反
- session: 22222222-2222-2222-2222-222222222222
- status: unprocessed
- origin: tool-result

ビルドログが冗長で読みにくかった。

## 2026-06-26T12:10:00Z
- signal: 反復試行
- session: 22222222-2222-2222-2222-222222222222
- status: unprocessed
- origin: tool-result

同じような作業を何度か繰り返した。
```

### 手順トレース

1. **入力選択**: 3件すべて `unprocessed` → 全件が対象。
2. **棄却判定**:
   - 「npm install が想定より遅かった」→ 事実の記述のみ。「次回どう違う行動を取るか」が読み取れない → **純記述として棄却**。
   - 「ビルドログが冗長で読みにくかった」→ 同上、行動を命じない → **純記述として棄却**。
   - 「同じような作業を何度か繰り返した」→ トリガーも振る舞い差分も一意に読み取れない → **実行不能として棄却**。
3. 分類・クラスタ化対象が残らない（棄却は `origin` に依らず合否境界で判定する。3件とも `tool-result` だが、環境摩擦であることは棄却理由ではない＝§3）。

### 期待結果

候補リストに上記いずれの観察も**現れない**。採用候補が0件のため `candidates.md` への書き込みは行わない（procedure §9）。
完了報告: 入力 unprocessed 3件 / 棄却3件 / 採用候補0件（「候補化できる規範はありませんでした（棄却3件）」と報告。例: §9 エラー・境界処理）。

---

## 例C: 混在（クラスタ化＋棄却）

### 入力（store の `unprocessed` エントリ4件）

例A のエントリ1・2（`2026-06-26T10:00:00Z` / `10:05:00Z`＝「git checkout でなく git restore」の重複する有効観察、ともに `origin: user-utterance`）＋ 例B の「npm install が想定より遅かった」（`2026-06-26T12:00:00Z`、`origin: tool-result`、純記述）＋ 次の1件:

```
## 2026-06-26T13:00:00Z
- signal: ツール拒否
- session: 33333333-3333-3333-3333-333333333333
- status: unprocessed
- origin: tool-result

git commit のメッセージにヒアドキュメントを使って失敗した。-m を複数回指定する方式に切り替えて成功した。
```

### 手順トレース

1. **入力選択**: 4件すべて `unprocessed`。
2. **棄却判定**: 「npm install が想定より遅かった」を純記述として棄却（残り有効3件）。
3. **分類**: git restore クラスタ（エントリ1・2）は `user-utterance` → 判断誤り（高優先）。commit メッセージ観察は `tool-result` → 環境摩擦（低優先）。
4. **クラスタ化**: 有効3件のうち、例A エントリ1・2 を「ファイル復元には git restore を使う」へ集約。上記の commit メッセージ観察は別トリガー×差分（「コミットメッセージに複数行を渡すとき」×「ヒアドキュメントでなく -m を複数回指定」）→ 単独候補。
5. **台帳突合**: 両候補とも既知ルール無し（novel）と仮定 → 通常候補のまま。

### 期待結果（候補2件 < 有効3件 < 入力4件）

出力順位は判断誤り（git restore、高優先）→環境摩擦（commit メッセージ、低優先）の順。

```
## ファイル復元には git restore を使う
- tags: [behavior-diff]
- provenance: 2026-06-26T10:00:00Z, 2026-06-26T10:05:00Z
- scope-hypothesis: universal
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
- candidate-status: pending

ファイルを復元するとき git checkout ではなく git restore を使う。…（理由）

## コミットメッセージに複数行を渡すときはヒアドキュメントを避け -m を複数回指定する
- tags: [behavior-diff]
- provenance: 2026-06-26T13:00:00Z
- scope-hypothesis: universal
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
- candidate-status: pending

git commit のメッセージにヒアドキュメントを使わず、-m を複数回指定して行を分ける。シェルのヒアドキュメント制約による失敗を避けるため。
```

完了報告: 入力 unprocessed 4件 / 棄却1件 / 分類 判断誤り2件・環境摩擦1件 / 採用候補2件（2 < 有効3 < 入力4。再発知見変換0件）。純記述が候補に漏れず、有効分のみがクラスタ化され、各候補に provenance・scope-hypothesis・career-hypothesis・candidate-status が付いて `candidates.md` へ upsert されることを確認する。

---

## 例D: 分類順位と既存ルール再発の知見化（#417）

出所（`origin`）による分類・重み付け（出力順位）と、既存ルール台帳との突合による再発知見化を検証する。**前提**: 参照源の user-global ルール `~/.claude/CLAUDE.md`「Bashツールの制約」に「`node -e` / `python -c` 等でインラインスクリプトを組み立てて実行しない。必要ならファイルに書き出して実行する」が既に成文化されているものとする。

### 入力（store の `unprocessed` エントリ3件）

```
## 2026-06-29T09:00:00Z
- signal: 反復試行
- session: 44444444-4444-4444-4444-444444444444
- status: unprocessed
- origin: tool-result
- actual: hook により python3 -c のインライン実行がブロックされた

python3 -c でワンライナーを組み立てて実行しようとして拒否され、スクリプトをファイルに書き出して実行し直した。

## 2026-06-29T09:30:00Z
- signal: ツール拒否
- session: 44444444-4444-4444-4444-444444444444
- status: unprocessed
- origin: tool-result
- actual: node -e の実行が拒否された

node -e のワンライナーが拒否されたため、一時ファイルへ書き出してから node で実行して回避した。

## 2026-06-29T10:00:00Z
- signal: 訂正
- session: 44444444-4444-4444-4444-444444444444
- status: unprocessed
- origin: user-utterance
- actual: ユーザーが「git add -A ではなく関連ファイルだけをステージングしろ」と訂正した

コミット時に git add -A で全変更をステージングしようとしたら、関連ファイルのみを個別に add するよう訂正された。
```

### 手順トレース

1. **入力選択（処理源＋参照源）**: 3件すべて `unprocessed` → 全件が処理対象。参照源として `~/.claude/CLAUDE.md`（user-global）・`learnings.md`・`candidates.md` を読み取り専用で読む。
2. **棄却判定**: 3件ともトリガー×振る舞い差分が読み取れる → 棄却なし。
3. **分類と重み付け**:
   - エントリ1・2 → `tool-result` → **環境摩擦（低優先）**。
   - エントリ3 → `user-utterance` → **判断誤り（高優先）**。
4. **クラスタ化**: エントリ1・2 はトリガー「インラインでスクリプトを組み立てて実行しようとするとき」× 差分「`-c`/`-e` で組み立てず一旦ファイルに書き出して実行する」が一致 → 1候補へ集約（`signal` が反復試行/ツール拒否で異なっても畳む）。エントリ3 は別トリガー×差分 → 単独候補。
5. **候補整形＋メタ付与**: 集約候補（インライン実行）の scope-hypothesis は全プロジェクトに効くため `universal`。エントリ3 候補（git add -A）も `universal`。
6. **台帳突合＋再発知見化**:
   - インライン実行候補（scope=universal）を global 台帳と突合 → `~/.claude/CLAUDE.md`「インラインスクリプトを組み立てて実行しない」と**実質一致＝既知**。「ルール追加候補」にせず**再発知見へ変換**する。N（再発回数）= provenance 件数 = 2。career-hypothesis を再評価し、機械的禁止（hook/lint）へ構造変換可能な強キャリア（決定表 行1）と判定。
   - git add -A 候補（scope=universal）を台帳と突合 → 一致する既存ルール無し＝**novel** → 通常候補のまま。

### 期待結果（候補2件、`candidates.md` へ upsert）

出力順位は判断誤り（git add -A、高優先）を先頭、環境摩擦由来の再発知見（インライン実行、低優先）を後に並べる。

```
## コミットは関連ファイルのみをステージングする（git add -A を使わない）
- tags: [behavior-diff]
- provenance: 2026-06-29T10:00:00Z
- scope-hypothesis: universal
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
- candidate-status: pending

コミット時は git add -A を使わず、関連ファイルのみを個別にステージングする。無関係な変更の混入を防ぐため。

## 既存ルール「インラインスクリプト（python -c / node -e 等）を組み立てて実行しない」が機能していない（2回再発）
- tags: [behavior-diff]
- provenance: 2026-06-29T09:00:00Z, 2026-06-29T09:30:00Z
- scope-hypothesis: universal
- career-hypothesis: 強キャリア / repo: 配布元プラグイン repo（仮説）
- candidate-status: pending

既存ルール（出典: `~/.claude/CLAUDE.md`「Bashツールの制約」=「node -e / python -c 等でインラインスクリプトを組み立てて実行しない」）に該当する摩擦が、当該期間に 2 回再発した（provenance の2件）。テキスト規範として成文化済みにもかかわらず再発しているため、hook/lint 等の決定論的ガードレールへの構造変換（強キャリア化）が示唆される。本候補は事実集計（再発回数）までを記し、撤去・強化の裁定はしない（裁定は下流 promote → Issue → 人間）。
```

再発知見候補は**別ファイル・別ルートを作らず**、git add -A 候補と同一スキーマ（見出し＋provenance＋scope-hypothesis＋career-hypothesis＋candidate-status＋本文）で `candidates.md` に並ぶ。promote 以降のライフサイクル（検証→Issue 起票）も他候補と同列（AC5）。N=2 は専用フィールドでなく provenance の件数から導出している。突合した台帳ルールへの参照（出典パス＋規範文）は本文に明記し、監査可能性を担保する。
完了報告: 入力 unprocessed 3件 / 棄却0件 / 分類 判断誤り1件・環境摩擦2件 / 型内訳 behavior-diff 2件・decision-record 0件 / 採用候補2件（うち再発知見へ変換1件）。

---

## 例E: 判断知の decision-record 化（ADR-20260701 D4）

判断群 signal を `decision-record` 型へ整形し、behavior-diff 要求（§3.1）と N 再発カウント（§7）を免除して4欄で保存することを検証する。**主眼**: 一回性の設計境界は §3.1（トリガー×振る舞い差分）では棄却され消滅していた（#432）が、§3.2 の例外口で `decision` のみを合否境界に採ることで保存される。

### 入力（store の `unprocessed` エントリ1件）

```
## 2026-06-29T08:50:02Z
- signal: 設計判断
- session: 55555555-5555-5555-5555-555555555555
- status: unprocessed
- origin: user-utterance
- expected:
- actual:

プラン所在問題の解決案を巡り、プランを追跡対象（コミット）に変える第三案を当方が提示したが、ユーザーは追跡対象化を却下し、追跡可否は利用者の運用判断に委ねるべきと述べた。
```

### 手順トレース

1. **入力選択**: 1件 `unprocessed` → 処理対象。参照源（台帳）も読むが本例の判定には使わない。
2. **知識型の導出＋棄却（§3）**: `signal: 設計判断` → **判断群 → 知識型は判断知 → `decision-record`**（導出規則は personal-store-spec.md「シグナル種別」）。よって **§3.2** を適用する。この観察は「次回どう違う行動を取るか」の再現可能な振る舞い差分に落ちない一回性の設計境界であり、§3.1（behavior-diff）なら**実行不能として棄却**されていた（#432 で消滅していた症状）。§3.2 では `decision`（プランを追跡対象に変えない）が読み取れる → **合格**。
3. **分類と重み付け（§4）**: `origin: user-utterance` → 判断誤り（高優先）側。知識型（出力形）とは直交。
4. **クラスタ化（§5）**: 単独。同一 `decision` の重複なし。トリガー×差分では畳まない（decision-record はトリガー×差分で畳まず、N 再発カウントもしない）。
5. **候補整形＋メタ付与（§6）**: `tags: [decision-record]`。本文を4欄（`decision` / `rejected-alternatives` / `rationale` / `context`）へ整形。`scope-hypothesis` は**プロジェクト自身の設計判断＝閉じた空間**のため `project-local`。`career-hypothesis` は決定表で**後戻りコスト高・却下選択肢ありの設計決定 → 行3（`ADR 差分`）**。
6. **台帳突合（§7）**: `decision-record` は **N 再発カウント免除**。§7 を通さず §6 整形のまま §8 へ送る（既にリポに記録済みか＝復元可能性の検証は promote の型適応検証の責務。ADR-20260701 D5）。

### 期待結果（候補1件、`candidates.md` へ upsert）

```
## プランは追跡対象にしない
- tags: [decision-record]
- provenance: 2026-06-29T08:50:02Z
- scope-hypothesis: project-local
- career-hypothesis: ADR 差分 / repo: 当該プロジェクト repo（仮説）
- candidate-status: pending

- decision: プランファイルは git 追跡対象（コミット）に変えない。追跡可否は利用者に委ねる。
- rejected-alternatives: プランを追跡対象（コミット）に変える第三案。
- rationale: 追跡するか否かは利用者側の運用判断であり、仕組みで固定すべきでない。
- context: プラン所在問題（#422 周辺）の解決案を巡る設計判断。
```

この候補は personal-store-spec.md「tags 別スキーマ」記述例と整合する（4欄・scope=project-local・career=ADR 差分）。behavior-diff 候補（例A・C・D）と同一の `candidates.md` に同居し、provenance・candidate-status・upsert・ライフサイクル（promote→Issue）を共有する。一方、§3.2 の免除口と §7 の N 再発免除により、一回性の設計境界が棄却・畳み込みで失われない。
完了報告: 入力 unprocessed 1件 / 棄却0件 / 分類 判断誤り1件・環境摩擦0件 / 型内訳 behavior-diff 0件・decision-record 1件 / 採用候補1件（再発知見変換0件）。

---

## 関連

- [`distill-procedure.md`](distill-procedure.md) — 各例が検証する判定基準の本体
- `${CLAUDE_PLUGIN_ROOT}/references/personal-store-spec.md` — 入力エントリの `origin`/`expected`/`actual` 欄、および期待結果（候補）が整合すべき候補ファイル（`candidates.md`）のメタ欄スキーマ・provenance 規約・upsert 方式
- `${CLAUDE_PLUGIN_ROOT}/references/learning-store-spec.md` — 候補見出し・本文が昇格時に残る規範形（1欄スキーマ・記法例）・2空間モデル（scope-hypothesis の値域）
