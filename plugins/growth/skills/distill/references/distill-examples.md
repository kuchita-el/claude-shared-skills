# Distill サンプル入力と期待結果（手順トレース用）

[`distill-procedure.md`](distill-procedure.md) の判定基準を検証するための worked example。本リポジトリは自動テスト基盤を持たないため、実装者は各例の入力を手順に通し（手順トレース）、期待結果と一致することを目視確認する。

生観測 store は日付バケット（`captures-YYYY-MM-DD.md`）のセグメント群であり（personal-store-spec.md「置き場」）、無状態の append-only 観測コーパス（エントリ単位の `- status:` フィールドを持たない）。distill の処理源選択は**セグメント glob**（`captures-*.md` 列挙＋カーソル日付以降バケットのみ Read＝Read 有界化）・**カーソルによる有界化**（`distill-state.md` の `- distill-cursor:` 行より新しい観測のみを走査）・**provenance 導出による重複排除**（スライス内で `promoted`/`pending` 候補を持つ観測を除外）の合成で定まる（personal-store-spec.md「distill 処理源選択と処理済みカーソル」「retention」・distill-procedure.md §2.1）。

> **セグメント前提（例全体に適用）**: 以下の各例の入力エントリは、見出しキー timestamp の UTC 日付に対応するバケットへ分散配置される（例: `2026-06-29T08:00:00Z` → `captures-2026-06-29.md`）。distill はこれらをセグメント glob `captures-*.md` で列挙し、カーソル日付より古い sealed バケットは Read 対象から外す（Read 有界化）。経年削除（retention・horizon 超かつ全通過済みバケットの `rm`）は**例K**、セグメント跨ぎのカーソル比較・見出しキー一意性・同一 UTC 日の `-NN` 同居は**例L**で扱う。

**例A〜例E の入力はいずれも distill-state.md のカーソルより新しい未 distill 観測であり、provenance 除外対象を持たない**（＝入力エントリ全件が処理源）ものとする。カーソル機構そのもの（前進・provenance 除外・巻き戻し・欠損フォールバック・旧 status 読み飛ばし）を実演する例は**例F〜例J**、経年削除とセグメント跨ぎは**例K・例L**で扱う。入力エントリは #416 以降のスキーマに従い `origin`（`tool-result` / `user-utterance`）欄を持つ。

各例が検証するケース:

| 検証するケース | 例 |
|---|---|
| 表層の語彙差を無視して同一トリガー×振る舞い差分を畳む | 例A |
| 同一 `signal` でも振る舞い差分が異なれば畳まない | 例A |
| 純記述的な観察を棄却する | 例B |
| 実行不能・空の観察を棄却する | 例B |
| 重複＋純記述＋有効の混在から有効分のみクラスタ化する | 例C |
| 各仮説に provenance（畳んだ timestamp 群）・scope-hypothesis・career-hypothesis・candidate-status を付与し candidates.md へ upsert する | 例A・例C |
| 採用仮説0件のとき candidates.md へ書き込まない | 例B |
| 知識型で優先度付け（判断知→高・摩擦知→再発Nで重み付け）し既存ルール台帳との突合で再発知見化する（#417） | 例D |
| 既存ルール台帳と突合し既知ルールの再発を再発知見へ変換する（#417） | 例D |
| 判断群 signal を `decision-record` 型へ整形し、behavior-diff 要求・N 再発を免除して4欄で保存する（ADR-20260701 D4） | 例E |
| カーソルより新しい未 distill 観測（齢の異なる複数）を全処理し、処理後カーソルを最新へ前進する（有界化。B1） | 例F |
| スライス内で `promoted`/`pending` 候補を provenance に持つ観測を除外し、`rejected` 候補のみ/候補なしの観測は残す（重複排除。B2） | 例G |
| distiller 改善時・candidates.md 消失時にカーソルを先頭へ巻き戻して再導出し、`rejected` 不可侵で棄却済み同一仮説を pending 復活させない（B3・B5） | 例H |
| カーソル欠損時に先頭全走査へ劣化し、処理後に distill-state.md を新規作成する（欠損フォールバック。B4） | 例I |
| 旧 `- status:` 行を残す入力でも distill が status を読み飛ばし、provenance＋カーソルのみで処理源を選ぶ（後方互換。B6/AC6） | 例J |
| horizon 超かつ全通過済みバケットを `rm` し、直近 M 日バケットは保持、horizon 超でも未 distill 含むバケットは削除せず Read する（経年削除・保持集合の三分。AC3） | 例K |
| ちょうど M 日前バケットは厳密不等号 `<` により保持側（オフバイワン境界。AC3） | 例K |
| 複数バケット跨ぎで単一カーソル・見出しキー一意性・単調増加が維持され、同一 UTC 日の複数 run が同一バケットに `-NN` で同居する（AC6） | 例L |

---

## 例A: クラスタ化・重複排除

### 入力（store のカーソルより新しいエントリ4件）

```
## 2026-06-26T10:00:00Z
- signal: 訂正
- session: 11111111-1111-1111-1111-111111111111
- origin: user-utterance

ユーザーが「git checkout ではなく git restore を使え」と訂正した。当方はファイル復元に git checkout を提案していた。

## 2026-06-26T10:05:00Z
- signal: 訂正
- session: 11111111-1111-1111-1111-111111111111
- origin: user-utterance

ファイル復元のつもりで git checkout . を実行しようとしたら、git restore を使うよう指摘された。

## 2026-06-26T11:00:00Z
- signal: 訂正
- session: 11111111-1111-1111-1111-111111111111
- origin: user-utterance

ユーザーが「Markdown を -m に直接渡すな」と訂正した。長い本文をコマンド引数に直接渡そうとしていた。

## 2026-06-26T11:10:00Z
- signal: ツール拒否
- session: 11111111-1111-1111-1111-111111111111
- origin: tool-result

長い PR 本文を gh pr create の --body に直接渡そうとして、ヒアドキュメントのクォートが3回壊れて失敗した。--body-file に切り替えて成功した。
```

### 手順トレース

1. **処理源選択（§2.1）**: 4件すべてカーソルより新しく、provenance に `promoted`/`pending` 候補を持つ観測なし → 全4件が処理源。
2. **棄却判定**: 4件すべてトリガー×振る舞い差分が読み取れる → 棄却なし。
3. **知識型で優先度付け（§4）**: 4件とも `behavior-diff`（摩擦知）。痕跡種別（`origin`）は順位に用いない。優先度は再発 N で決まる（クラスタ化後に確定＝下記 step5・procedure §4.1）。
4. **トリガー×振る舞い差分の推論**:
   - エントリ1 → トリガー「ファイルを復元するとき」× 差分「git checkout でなく git restore を使う」
   - エントリ2 → トリガー「ファイルを復元するとき」× 差分「git checkout でなく git restore を使う」（**言い回し違いの重複**）
   - エントリ3 → トリガー「長文を CLI 引数に渡すとき」× 差分「-m 等に直接渡さず一時ファイル経由にする」
   - エントリ4 → トリガー「長文を CLI 引数に渡すとき」× 差分「直接渡さず --body-file（一時ファイル）経由にする」
5. **クラスタ化**:
   - 1 と 2 はトリガー×差分が一致 → 1仮説へ集約（**表層の語彙差を無視して畳む**）。
   - 1・2（signal=訂正）と 3（signal=訂正）は **同一 signal だが振る舞い差分が異なる** → 畳まない（**signal 一致だけで集約しない**）。
   - 3 と 4 はトリガー×差分が一致 → 1仮説へ集約（**signal/origin が異なっても、振る舞い差分が同じなら畳む**）。
   - この集約仮説（3＋4）は `user-utterance`（3）と `tool-result`（4）の混在クラスタだが、痕跡種別は順位に無関係。`behavior-diff` として provenance=2（複数観察の支持。novel＝台帳未一致のため §7 再発知見化はしない）で重み付けする（§4.1）。
6. **台帳突合**: 両仮説とも参照源（`~/.claude/CLAUDE.md` 等）に一致する既存ルールが無ければ novel → 通常仮説のまま（突合の既知例は例D）。

### 期待結果（仮説2件 < 入力4件、`candidates.md` へ upsert）

各仮説にメタ欄（provenance＝畳んだ観察の `## <timestamp>` 群、scope-hypothesis＝仮説形成観点の仮説タグ、career-hypothesis＝昇格先キャリア＋宛先 repo 仮説、candidate-status＝`pending`）が付く。エントリ1・2 は同一クラスタなので provenance に両 timestamp を列挙する。両仮説とも `behavior-diff`・provenance=2（観察2件が支持＝N=2。台帳未一致 novel のため §7 再発知見化はせず、provenance 件数で単発より上位）のため出力順位は同列。痕跡種別に依らず provenance 件数で順位が決まる。

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

これらは `candidates.md` へ provenance キーで upsert 永続化され、チャットにも提示される。両仮説とも全プロジェクトに効くため scope-hypothesis は `universal`（仮説。最終裁定は下流の人間 refine/review）。career-hypothesis は両仮説ともテキスト規範の汎用ルール（決定表 行4）のため `learnings.md`、宛先は配布元プラグイン repo（仮説。最終裁定は集約点）。
完了報告: 処理源4件 / 棄却0件 / 型内訳 behavior-diff 4観察→2仮説・decision-record 0件 / 優先度 両仮説 provenance=2・novel（同列。台帳未一致のため §7 昇格なし） / 採用仮説2件（2 < 4。再発知見変換0件） / 前進後カーソル 2026-06-26T11:10:00Z（今回走査の最新 timestamp）。

---

## 例B: 棄却

### 入力（store のカーソルより新しいエントリ3件）

```
## 2026-06-26T12:00:00Z
- signal: 期待違反
- session: 22222222-2222-2222-2222-222222222222
- origin: tool-result

npm install が想定より遅かった。

## 2026-06-26T12:05:00Z
- signal: 期待違反
- session: 22222222-2222-2222-2222-222222222222
- origin: tool-result

ビルドログが冗長で読みにくかった。

## 2026-06-26T12:10:00Z
- signal: 反復試行
- session: 22222222-2222-2222-2222-222222222222
- origin: tool-result

同じような作業を何度か繰り返した。
```

### 手順トレース

1. **処理源選択（§2.1）**: 3件すべてカーソルより新しく provenance 除外なし → 全3件が処理源。
2. **棄却判定**:
   - 「npm install が想定より遅かった」→ 事実の記述のみ。「次回どう違う行動を取るか」が読み取れない → **純記述として棄却**。
   - 「ビルドログが冗長で読みにくかった」→ 同上、行動を命じない → **純記述として棄却**。
   - 「同じような作業を何度か繰り返した」→ トリガーも振る舞い差分も一意に読み取れない → **実行不能として棄却**。
3. 分類・クラスタ化対象が残らない（棄却は §3 の合否境界のみで判定し、痕跡種別（`origin`）には依らない。3件とも `tool-result` だが、それは棄却理由ではない＝§3。優先度付け〔§4〕にも痕跡種別は用いない）。

### 期待結果

仮説リストに上記いずれの観察も**現れない**。採用仮説が0件のため `candidates.md` への書き込みは行わない（procedure §9）。
完了報告: 処理源3件 / 棄却3件 / 採用仮説0件（「仮説化できる規範はありませんでした（棄却3件）」と報告。例: §9 エラー・境界処理）。全観察が棄却されたため `candidates.md` は書かず、カーソルも前進させない（§8・§9）。

---

## 例C: 混在（クラスタ化＋棄却）

### 入力（store のカーソルより新しいエントリ4件）

例A のエントリ1・2（`2026-06-26T10:00:00Z` / `10:05:00Z`＝「git checkout でなく git restore」の重複する有効観察、ともに `origin: user-utterance`）＋ 例B の「npm install が想定より遅かった」（`2026-06-26T12:00:00Z`、`origin: tool-result`、純記述）＋ 次の1件:

```
## 2026-06-26T13:00:00Z
- signal: ツール拒否
- session: 33333333-3333-3333-3333-333333333333
- origin: tool-result

git commit のメッセージにヒアドキュメントを使って失敗した。-m を複数回指定する方式に切り替えて成功した。
```

### 手順トレース

1. **処理源選択（§2.1）**: 4件すべてカーソルより新しく provenance 除外なし → 全4件が処理源。
2. **棄却判定**: 「npm install が想定より遅かった」を純記述として棄却（残り有効3件）。
3. **優先度付け（§4）**: git restore クラスタ（エントリ1・2）は `behavior-diff`・provenance=2（観察2件）→ commit の provenance=1 より上位。両者 novel（台帳未一致）のため §7 再発知見化はしない。痕跡種別（`origin`）は順位に用いない。
4. **クラスタ化**: 有効3件のうち、例A エントリ1・2 を「ファイル復元には git restore を使う」へ集約。上記の commit メッセージ観察は別トリガー×差分（「コミットメッセージに複数行を渡すとき」×「ヒアドキュメントでなく -m を複数回指定」）→ 単独仮説。
5. **台帳突合**: 両仮説とも既知ルール無し（novel）と仮定 → 通常仮説のまま。

### 期待結果（仮説2件 < 有効3件 < 入力4件）

出力順位は provenance=2（git restore）→ provenance=1（commit メッセージ）の順。両者 novel（台帳未一致）。痕跡種別に依らず provenance 件数で決まる。

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

完了報告: 処理源4件 / 棄却1件 / 型内訳 behavior-diff 3観察→2仮説・decision-record 0件 / 優先度 git restore provenance=2 > commit provenance=1（両者 novel） / 採用仮説2件（2 < 有効3 < 処理源4。再発知見変換0件） / 前進後カーソル 2026-06-26T13:00:00Z。純記述が仮説に漏れず、有効分のみがクラスタ化され、各仮説に provenance・scope-hypothesis・career-hypothesis・candidate-status が付いて `candidates.md` へ upsert されることを確認する。

---

## 例D: 分類順位と既存ルール再発の知見化（#417）

知識型による優先度付け（出力順位）——摩擦知（`behavior-diff`）は再発 N で重み付けし、痕跡種別（`origin`）は順位に用いない——と、既存ルール台帳との突合による再発知見化を検証する。**前提**: 参照源の user-global ルール `~/.claude/CLAUDE.md`「Bashツールの制約」に「`node -e` / `python -c` 等でインラインスクリプトを組み立てて実行しない。必要ならファイルに書き出して実行する」が既に成文化されているものとする。

### 入力（store のカーソルより新しいエントリ3件）

```
## 2026-06-29T09:00:00Z
- signal: 反復試行
- session: 44444444-4444-4444-4444-444444444444
- origin: tool-result
- actual: hook により python3 -c のインライン実行がブロックされた

python3 -c でワンライナーを組み立てて実行しようとして拒否され、スクリプトをファイルに書き出して実行し直した。

## 2026-06-29T09:30:00Z
- signal: ツール拒否
- session: 44444444-4444-4444-4444-444444444444
- origin: tool-result
- actual: node -e の実行が拒否された

node -e のワンライナーが拒否されたため、一時ファイルへ書き出してから node で実行して回避した。

## 2026-06-29T10:00:00Z
- signal: 訂正
- session: 44444444-4444-4444-4444-444444444444
- origin: user-utterance
- actual: ユーザーが「git add -A ではなく関連ファイルだけをステージングしろ」と訂正した

コミット時に git add -A で全変更をステージングしようとしたら、関連ファイルのみを個別に add するよう訂正された。
```

### 手順トレース

1. **処理源選択＋参照源（§2.1/§2.2）**: 3件すべてカーソルより新しく provenance 除外なし → 全3件が処理源。参照源として `~/.claude/CLAUDE.md`（user-global）・`learnings.md`・`candidates.md` を読み取り専用で読む。
2. **棄却判定**: 3件ともトリガー×振る舞い差分が読み取れる → 棄却なし。
3. **知識型で優先度付け（§4）**: 3件とも `behavior-diff`（摩擦知）。痕跡種別（`origin`）は順位に用いない。優先度は再発 N で決まる——エントリ1・2 は既知ルールに一致し N=2 で再発知見化（後述、強キャリア＝高優先側）、エントリ3（git add -A）は novel な単発 behavior-diff で低優先。
4. **クラスタ化**: エントリ1・2 はトリガー「インラインでスクリプトを組み立てて実行しようとするとき」× 差分「`-c`/`-e` で組み立てず一旦ファイルに書き出して実行する」が一致 → 1仮説へ集約（`signal` が反復試行/ツール拒否で異なっても畳む）。エントリ3 は別トリガー×差分 → 単独仮説。
5. **仮説整形＋メタ付与**: 集約仮説（インライン実行）の scope-hypothesis は全プロジェクトに効くため `universal`。エントリ3 仮説（git add -A）も `universal`。
6. **台帳突合＋再発知見化**:
   - インライン実行仮説（scope=universal）を global 台帳と突合 → `~/.claude/CLAUDE.md`「インラインスクリプトを組み立てて実行しない」と**実質一致＝既知**。「ルール追加候補」にせず**再発知見へ変換**する。N（再発回数）= provenance 件数 = 2。career-hypothesis を再評価し、機械的禁止（hook/lint）へ構造変換可能な強キャリア（決定表 行1）と判定。
   - git add -A 仮説（scope=universal）を台帳と突合 → 一致する既存ルール無し＝**novel** → 通常仮説のまま。

### 期待結果（仮説2件、`candidates.md` へ upsert）

出力順位は再発知見（インライン実行、既知ルール N=2 再発・強キャリア）を先頭、novel な単発 behavior-diff（git add -A、低優先）を後に並べる。痕跡種別に依らず再発 N で順位が決まる。

```
## 既存ルール「インラインスクリプト（python -c / node -e 等）を組み立てて実行しない」が機能していない（2回再発）
- tags: [behavior-diff]
- provenance: 2026-06-29T09:00:00Z, 2026-06-29T09:30:00Z
- scope-hypothesis: universal
- career-hypothesis: 強キャリア / repo: 配布元プラグイン repo（仮説）
- candidate-status: pending

既存ルール（出典: `~/.claude/CLAUDE.md`「Bashツールの制約」=「node -e / python -c 等でインラインスクリプトを組み立てて実行しない」）に該当する摩擦が、当該期間に 2 回再発した（provenance の2件）。テキスト規範として成文化済みにもかかわらず再発しているため、hook/lint 等の決定論的ガードレールへの構造変換（強キャリア化）が示唆される。本仮説は事実集計（再発回数）までを記し、撤去・強化の裁定はしない（裁定は下流 promote → Issue → 人間）。

## コミットは関連ファイルのみをステージングする（git add -A を使わない）
- tags: [behavior-diff]
- provenance: 2026-06-29T10:00:00Z
- scope-hypothesis: universal
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
- candidate-status: pending

コミット時は git add -A を使わず、関連ファイルのみを個別にステージングする。無関係な変更の混入を防ぐため。
```

再発知見仮説は**別ファイル・別ルートを作らず**、git add -A 仮説と同一スキーマ（見出し＋provenance＋scope-hypothesis＋career-hypothesis＋candidate-status＋本文）で `candidates.md` に並ぶ。promote 以降のライフサイクル（検証→Issue 起票）も他仮説と同列（AC5）。N=2 は専用フィールドでなく provenance の件数から導出している。突合した台帳ルールへの参照（出典パス＋規範文）は本文に明記し、監査可能性を担保する。
完了報告: 処理源3件 / 棄却0件 / 型内訳 behavior-diff 3観察→2仮説・decision-record 0件 / 優先度 高1（再発知見・N=2）・低1（novel 単発 behavior-diff） / 採用仮説2件（うち再発知見へ変換1件） / 前進後カーソル 2026-06-29T10:00:00Z。

---

## 例E: 判断知の decision-record 化（ADR-20260701 D4）

判断群 signal を `decision-record` 型へ整形し、behavior-diff 要求（§3.1）と N 再発カウント（§7）を免除して4欄で保存することを検証する。**主眼**: 一回性の設計境界は §3.1（トリガー×振る舞い差分）では棄却され消滅していた（#432）が、§3.2 の例外口で `decision` のみを合否境界に採ることで保存される。

### 入力（store のカーソルより新しいエントリ1件）

```
## 2026-06-29T08:50:02Z
- signal: 設計判断
- session: 55555555-5555-5555-5555-555555555555
- origin: user-utterance
- expected:
- actual:

プラン所在問題の解決案を巡り、プランを追跡対象（コミット）に変える第三案を当方が提示したが、ユーザーは追跡対象化を却下し、追跡可否は利用者の運用判断に委ねるべきと述べた。
```

### 手順トレース

1. **処理源選択（§2.1）**: 1件がカーソルより新しく provenance 除外なし → 処理源1件。参照源（台帳）も読むが本例の判定には使わない。
2. **知識型の導出＋棄却（§3）**: `signal: 設計判断` → **判断群 → 知識型は判断知 → `decision-record`**（導出規則は personal-store-spec.md「シグナル種別」）。よって **§3.2** を適用する。この観察は「次回どう違う行動を取るか」の再現可能な振る舞い差分に落ちない一回性の設計境界であり、§3.1（behavior-diff）なら**実行不能として棄却**されていた（#432 で消滅していた症状）。§3.2 では `decision`（プランを追跡対象に変えない）が読み取れる → **合格**。
3. **優先度付け（§4）**: 知識型＝`decision-record`（判断知）→ 高優先（復元不能性・ADR-20260701 決定1）。痕跡種別（`origin`）は優先度に用いない。
4. **クラスタ化（§5）**: 単独。同一 `decision` の重複なし。トリガー×差分では畳まない（decision-record はトリガー×差分で畳まず、N 再発カウントもしない）。
5. **仮説整形＋メタ付与（§6）**: `tags: [decision-record]`。本文を4欄（`decision` / `rejected-alternatives` / `rationale` / `context`）へ整形。`scope-hypothesis` は**プロジェクト自身の設計判断＝閉じた空間**のため `project-local`。`career-hypothesis` は決定表で**後戻りコスト高・却下選択肢ありの設計決定 → 行3（`ADR 差分`）**。
6. **台帳突合（§7）**: `decision-record` は **N 再発カウント免除**。§7 を通さず §6 整形のまま §8 へ送る（既にリポに記録済みか＝復元可能性の検証は promote の型適応検証の責務。ADR-20260701 D5）。

### 期待結果（仮説1件、`candidates.md` へ upsert）

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

この仮説は personal-store-spec.md「tags 別スキーマ」記述例と整合する（4欄・scope=project-local・career=ADR 差分）。behavior-diff 仮説（例A・C・D）と同一の `candidates.md` に同居し、provenance・candidate-status・upsert・ライフサイクル（promote→Issue）を共有する。一方、§3.2 の免除口と §7 の N 再発免除により、一回性の設計境界が棄却・畳み込みで失われない。
完了報告: 処理源1件 / 棄却0件 / 型内訳 behavior-diff 0件・decision-record 1件 / 優先度 高（decision-record・復元不能性） / 採用仮説1件（再発知見変換0件） / 前進後カーソル 2026-06-29T08:50:02Z。

---

## 例F: カーソル前進（有界化・B1）

齢の異なる複数の未 distill 観測がカーソルより新しければ全て処理され、処理後カーソルが今回走査した最新 timestamp へ前進することを検証する。カーソル以下（古い）の観測は候補スライスに入らない（有界化＝走査済みノイズの再走査と未処理観測の齢による無音脱落を同時に止める）。

### 事前状態

**distill-state.md（カーソル）**:

```
- distill-cursor: 2026-06-30T00:00:00Z
```

**candidates.md**: 下記スライスの観測を provenance に持つ候補は無い（空、または無関係な既存候補のみ）→ provenance 除外は発生しない。

### 入力（セグメント captures-*.md、齢の異なる観測4件が日付バケットに分散）

以下の4件は日付バケット `captures-2026-06-29.md` / `captures-2026-06-30.md` / `captures-2026-07-01.md` / `captures-2026-07-02.md` に1件ずつ分散する。

```
## 2026-06-29T08:00:00Z
- signal: 訂正
- session: 66666666-6666-6666-6666-666666666666
- origin: user-utterance

（カーソル 2026-06-30T00:00:00Z より古い観測。前回までの distill で処理済み＝カーソル以下。）

## 2026-06-30T10:00:00Z
- signal: 訂正
- session: 66666666-6666-6666-6666-666666666666
- origin: user-utterance

ユーザーが「エラーメッセージは原文のまま引用しろ、意訳するな」と訂正した。当方はツールのエラーを日本語に意訳して報告していた。

## 2026-07-01T09:00:00Z
- signal: ツール拒否
- session: 66666666-6666-6666-6666-666666666666
- origin: tool-result

rm -rf の実行が承認プロンプトで拒否された。個別ファイル削除に切り替えて回避した。

## 2026-07-02T15:00:00Z
- signal: 訂正
- session: 66666666-6666-6666-6666-666666666666
- origin: user-utterance

ユーザーが「変数名は省略せずフルスペルにしろ」と訂正した。省略名で命名していた。
```

### 手順トレース

1. **バケット列挙＋カーソル読取（§2.1 手順1/2/4）**: Glob `captures-*.md` で4バケットを列挙。`distill-cursor: 2026-06-30T00:00:00Z`。**Read 有界化**: バケット日付 ≥ カーソル日付（2026-06-30）のバケットのみ Read → `captures-2026-06-29.md` は sealed（日付 < カーソル日付）で**Read 対象外**。`captures-2026-06-30/07-01/07-02.md` の3バケットを Read する。
2. **候補スライスの決定（有界化・§2.1 手順5）**: 読んだバケット内で per-entry にカーソルより新しい観測のみを候補スライスにする。`2026-06-29T08:00:00Z`（Read すらされず・カーソル以下）は**スライス外＝走査しない**。残る3件（`06-30T10:00` / `07-01T09:00` / `07-02T15:00`）が候補スライス。齢は異なるが、いずれもカーソルより新しいため全て入る（齢での無音脱落は起きない）。
3. **provenance 除外（重複排除・§2.1 手順6）**: 3件とも `promoted`/`pending` 候補を持たない → 除外なし。処理源＝3件。
4. **棄却判定**: 3件ともトリガー×振る舞い差分が読み取れる → 棄却なし。台帳突合は novel と仮定。
5. **クラスタ化**: 3件はトリガー×差分が相異なる → 集約なし、3仮説。
6. **カーソル前進（§8）**: 処理後、カーソルを候補スライスの最新 timestamp `2026-07-02T15:00:00Z` へ前進させ `distill-state.md` を書き戻す。前進主体は distill のみ。

### 期待結果（仮説3件、`candidates.md` へ upsert／カーソル前進）

3件の観測がそれぞれ pending 仮説になる（各 provenance は単一 timestamp、scope-hypothesis・career-hypothesis・`candidate-status: pending` を付与。3件とも `behavior-diff`・N=1〔単発・novel〕で同列＝低優先。痕跡種別は順位に用いない）。**処理後カーソルは `2026-07-02T15:00:00Z`**。次回ルーチン distill はこのカーソルより新しい観測のみを走査するため、今回の3件を再走査せず同一仮説を再生成しない（有界化）。

完了報告: 処理源3件（カーソルより新しく provenance 除外後）/ 棄却0件 / 型内訳 behavior-diff 3件・decision-record 0件 / 優先度 3件とも N=1（単発・同列） / 採用仮説3件（再発知見変換0件）/ 前進後カーソル 2026-07-02T15:00:00Z。カーソル以下の `2026-06-29T08:00:00Z` は走査対象外（有界化）。

---

## 例G: provenance 除外（重複排除・B2）

カーソルより新しいスライス内でも、既に `promoted`/`pending` 候補を provenance に持つ観測は処理源から除外され、`rejected` 候補のみを持つ観測・候補を持たない観測は処理源に残る（重複排除。§2.1 手順6）ことを検証する。カーソル（有界化）と provenance（重複排除）は役割が異なり合成される点を、両者が同時に働くスライスで示す。

### 事前状態

**distill-state.md（カーソル）**:

```
- distill-cursor: 2026-07-03T00:00:00Z
```

**candidates.md（既存候補3件。うち2件が live〔promoted/pending〕、1件が rejected）**:

```
## コミットに Co-Authored-By を付ける
- tags: [behavior-diff]
- provenance: 2026-07-03T10:00:00Z
- scope-hypothesis: project-local
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
- candidate-status: promoted

コミット時は末尾に Co-Authored-By 行を付ける。（promote が Issue 起票成功後に promoted へ前進済み）

## ブランチ切り替えには git switch を使う
- tags: [behavior-diff]
- provenance: 2026-07-04T09:00:00Z
- scope-hypothesis: universal
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
- candidate-status: pending

ブランチ切り替えには git checkout ではなく git switch を使う。

## 全ファイルを一括フォーマットする
- tags: [behavior-diff]
- provenance: 2026-07-05T11:00:00Z
- scope-hypothesis: project-local
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
- candidate-status: rejected

差分外のファイルまで一括フォーマットする。（promote の検証で棄却＝rejected）
```

### 入力（セグメント captures-*.md、いずれもカーソル 2026-07-03T00:00:00Z より新しい4件。バケット captures-2026-07-03〜07-06.md に分散）

```
## 2026-07-03T10:00:00Z
- signal: 訂正
- session: 88888888-8888-8888-8888-888888888888
- origin: user-utterance

ユーザーがコミットの Co-Authored-By 行の記載漏れを訂正した（同一トリガーの観測。既に promoted 候補あり）。

## 2026-07-04T09:00:00Z
- signal: 訂正
- session: 88888888-8888-8888-8888-888888888888
- origin: user-utterance

ブランチ切り替えで git checkout を使い git switch を使うよう指摘された（既に pending 候補あり）。

## 2026-07-05T11:00:00Z
- signal: 訂正
- session: 88888888-8888-8888-8888-888888888888
- origin: user-utterance

差分外まで一括フォーマットして関係ないファイルが変更され、対象ファイルのみ整形するよう指摘された（rejected 候補と同一トリガー×差分）。

## 2026-07-06T14:00:00Z
- signal: 訂正
- session: 88888888-8888-8888-8888-888888888888
- origin: user-utterance

ユーザーが「テーブルのカラム順は入力・出力の順に揃えろ」と訂正した（候補なしの新規観測）。
```

### 手順トレース

1. **カーソル読取（§2.1 手順4）**: `2026-07-03T00:00:00Z`。
2. **候補スライス（有界化・§2.1 手順5）**: 4件すべてカーソルより新しい → スライスに4件。
3. **provenance 除外（重複排除・§2.1 手順6）**: 各観測の `## <timestamp>` を candidates.md の各候補 provenance と突合する。
   - `2026-07-03T10:00:00Z` → `promoted` 候補「Co-Authored-By」あり → **除外**（重複候補生成の防止）。
   - `2026-07-04T09:00:00Z` → `pending` 候補「git switch」あり → **除外**。
   - `2026-07-05T11:00:00Z` → `rejected` 候補「一括フォーマット」**のみ** → **残す**（再走査に開く）。
   - `2026-07-06T14:00:00Z` → 候補なし → **残す**。

   処理源＝2件（`07-05T11:00` と `07-06T14:00`）。
4. **棄却判定**: 両者ともトリガー×差分が読める → 棄却なし。
5. **整形＋台帳突合**:
   - `07-06T14:00` → novel → 新規 pending 仮説。
   - `07-05T11:00` → 再導出すると既存 `rejected` 候補「一括フォーマット」と同一トリガー×差分 → **§7.4 rejected 不可侵**。upsert は既存 `rejected` を尊重し、同一仮説を pending で復活させない（新規 pending を作らない）。
6. **カーソル前進（§8）**: 候補スライス（4件）の最新 timestamp `2026-07-06T14:00:00Z` へ前進。

### 期待結果（新規 pending 仮説1件、`candidates.md` へ upsert／カーソル前進）

candidates.md 事後: `promoted`「Co-Authored-By」・`pending`「git switch」・`rejected`「一括フォーマット」の3候補は**不変**（live 候補は provenance 除外で再仮説形成されず、rejected は不可侵で pending 復活せず）。`07-06T14:00` 由来の新規 pending 仮説が1件追加される。**処理後カーソルは `2026-07-06T14:00:00Z`**。

完了報告: 処理源2件（候補スライス4件 − provenance 除外2件）/ 棄却0件 / 採用仮説1件（新規 pending。rejected 不可侵により `07-05T11:00` は pending 復活せず）/ 前進後カーソル 2026-07-06T14:00:00Z。live 候補（promoted/pending）を持つ2観測は重複排除で処理源から外れることを確認する。

---

## 例H: 巻き戻し再導出＋rejected 不可侵（B3・B5）

distiller 改善時（candidates.md は健在）・candidates.md 消失時の2つの巻き戻しトリガー（§2.1 巻き戻し・§9）を検証する。巻き戻し再導出でも provenance 導出が live 候補（`promoted`/`pending`）の重複を止め、`candidate-status: rejected` 不可侵（§7.4・ADR-20260629 決定3）が棄却済み**同一**仮説の pending 復活を止める。

### ケースH-1: distiller 改善による巻き戻し（candidates.md 健在）

**事前状態**

distiller を改善したので、開発者が明示操作としてカーソルを**保持集合の先頭相当**（保持バケット群の最古観測より古い値。retention horizon 先頭）へ巻き戻す（§2.1 巻き戻し。改善判定は自動化しない。horizon 超バケットは経年削除済みで再導出対象外）。

distill-state.md（巻き戻し後）:

```
- distill-cursor: 2026-01-01T00:00:00Z
```

candidates.md（既存候補2件）:

```
## 差分外のファイルまで一括フォーマットする
- tags: [behavior-diff]
- provenance: 2026-07-08T10:00:00Z
- scope-hypothesis: project-local
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
- candidate-status: rejected

差分外のファイルまで一括フォーマットする。（promote が棄却＝rejected）

## PR 本文はファイル経由で渡す
- tags: [behavior-diff]
- provenance: 2026-07-09T09:00:00Z
- scope-hypothesis: universal
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
- candidate-status: promoted

PR 本文は --body-file でファイル経由で渡す。（promoted）
```

入力（セグメント captures-*.md、巻き戻し後カーソルより新しい2件。バケット captures-2026-07-08.md / captures-2026-07-09.md）:

```
## 2026-07-08T10:00:00Z
- signal: 訂正
- session: 99999999-9999-9999-9999-999999999999
- origin: user-utterance

差分外まで一括フォーマットして指摘された。整形前に対象範囲を確認しなかったのが一因で、改善 distiller は「整形コマンドは実行前に dry-run で対象範囲を確認する」という**別軸（プロセス／ツール）の規範**も読み取れる。

## 2026-07-09T09:00:00Z
- signal: ツール拒否
- session: 99999999-9999-9999-9999-999999999999
- origin: tool-result

PR 本文の直接渡しが壊れ --body-file に切り替えた（既に promoted 候補あり）。
```

**手順トレース**

1. **巻き戻し（§2.1）**: 開発者が改善後カーソルを先頭相当へ巻き戻す。
2. **候補スライス（有界化）**: 全観測がカーソルより新しい → 2件ともスライス。
3. **provenance 除外（重複排除・§2.1 手順6）**: `07-09T09:00` → `promoted` 候補「PR 本文はファイル経由」あり → **除外**。`07-08T10:00` → `rejected` 候補のみ → **残す**。処理源＝`07-08T10:00`。
4. **再導出**: 改善 distiller が `07-08T10:00` を再導出する。**同一軸（整形スコープ）／別軸（プロセス）で挙動が分かれる**。
   - **同一軸＝復活させない**: 既存 `rejected` 候補「差分外のファイルまで一括フォーマットする」と**同一トリガー×差分**の scope 限定仮説（「整形を差分内に限定する」＝対象ファイルのみ整形する。例G の `07-05T11:00` と同一規範）は、§7.4 rejected 不可侵により pending 復活させない（棄却済み同一仮説は再生成しない）。表層の語彙差（「対象ファイルのみ整形する」／「差分に限定する」）は §5・§7.1 で無視し、rejected 候補と実質一致と判定する（例G と同一の同一性基準）。
   - **別軸＝生成してよい**: 改善 distiller が読み取る**別軸の新仮説**「整形コマンドは実行前に dry-run で対象範囲を確認する」は、rejected 仮説とトリガー（「整形コマンドを実行する前」）も振る舞い差分（「dry-run で対象範囲を確認する」＝整形スコープの限定ではなくプロセス上の事前確認ステップ）も**直交**するため、別仮説として新規 pending で出せる（rejected 不可侵は同一軸・同一仮説の復活のみを止め、別軸の新仮説生成は妨げない）。
5. **カーソル再前進（§8）**: 再導出後、カーソルを最新 timestamp `2026-07-09T09:00:00Z` へ戻す（前進と同じ）。

**期待結果**: `promoted`「PR 本文はファイル経由」不変（除外）。`rejected`「差分外のファイルまで一括フォーマットする」不変（不可侵）。同一軸の scope 限定仮説（例G と同一規範）は pending 復活せず、改善 distiller が立てた**別軸の新仮説**「整形コマンドは実行前に dry-run で対象範囲を確認する」のみが新規 pending として追加されうる。カーソル `2026-07-09T09:00:00Z`。棄却済み**同一軸**仮説は巻き戻しでも復活せず、**別軸**の新仮説は生成できる（両立）ことを確認する。

### ケースH-2: candidates.md 消失による巻き戻し（B5）

`candidates.md` が消失した場合（重複排除の参照源が失われた）、§9 に従いカーソルを**保持集合の先頭**（retention horizon 先頭）へ巻き戻し、保持バケット群（`captures-*.md`）から再導出する。**H-1 と同一の観測**（`07-08T10:00` の一括フォーマット摩擦）を入力に、candidates.md の有無だけが挙動を分けることを示す。

**事前状態**

distill-state.md（消失検知で先頭へ巻き戻し後）:

```
- distill-cursor: 2026-01-01T00:00:00Z
```

candidates.md: **消失（ファイル不存在）**。消失前は下記の裁定済み候補を持っていたが、参照源喪失により追跡不能（バックアップが無ければ復元不能）:

```
## 差分外のファイルまで一括フォーマットする
- tags: [behavior-diff]
- provenance: 2026-07-08T10:00:00Z
- scope-hypothesis: project-local
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
- candidate-status: rejected

差分外のファイルまで一括フォーマットする。（消失前は promote が rejected 済み）
```

入力（保持バケット群 captures-*.md、巻き戻し後カーソルより新しい1件。H-1 と同一 timestamp の観測。バケット captures-2026-07-08.md）:

```
## 2026-07-08T10:00:00Z
- signal: 訂正
- session: 99999999-9999-9999-9999-999999999999
- origin: user-utterance

差分外まで一括フォーマットして指摘された。
```

**手順トレース**

1. **消失検知＋巻き戻し（§9）**: `candidates.md` 不存在 → 参照源喪失。カーソルを保持集合の先頭（retention horizon 先頭。図示上は `2026-01-01T00:00:00Z`）へ巻き戻し、保持バケット群（`captures-*.md`）から再導出する。
2. **候補スライス（有界化）**: 先頭巻き戻し → 全観測（1件）がスライス。
3. **provenance 除外（重複排除・§2.1 手順6）**: 参照源 candidates.md が無い → 突合対象ゼロ＝**除外判定不能で除外なし**。全件（1件）が処理源。
4. **再導出**: `07-08T10:00` を再導出すると scope 限定仮説「差分外のファイルまで一括フォーマットする」が導かれる。消失前は `rejected` だったが、その追跡が失われ §7.4 の不可侵に頼れないため、**同一仮説が pending として再生成される**（H-1 なら不可侵で復活させなかった同一軸仮説が、参照源喪失により復活してしまう）。
5. **カーソル前進＋新規作成（§8）**: 処理後、カーソルを最新 timestamp `2026-07-08T10:00:00Z` へ設定し `candidates.md`（および必要なら `distill-state.md`）を新規作成する。

**期待結果**: `candidates.md` が新規生成され、消失前は `rejected` だった同一仮説「差分外のファイルまで一括フォーマットする」が `pending` として復活する。カーソル `2026-07-08T10:00:00Z`。

**留意点（§9・意図した再生成）**: candidates.md が無いため、(a) provenance 除外の参照源が失われ全観測が処理源になり、(b) `rejected`/`promoted` の追跡も失われ §7.4 の不可侵に頼れず、全観察が pending 再生成されうる。これは消失に対する安全側の劣化であり**意図した再生成**である。消失前の裁定（`rejected`/`promoted`）を保ちたい場合は candidates.md のバックアップからの復旧を要する（distill は復元しない）。再導出後カーソルを最新へ戻す。

**H-1 との対比**: candidates.md 健在の巻き戻し（H-1）は不可侵と重複排除が効くため棄却済み**同一軸**仮説が復活しない（別軸の新仮説のみ生成）が、candidates.md 消失（H-2）は参照源喪失によりこれらが効かず同一軸仮説まで pending 再生成される。両者の差は**参照源の有無**であり、rejected 不可侵の防御は candidates.md が健在な場合にのみ成立する。

---

## 例I: カーソル欠損フォールバック（B4）

カーソル（`distill-state.md` またはその `- distill-cursor:` 行）が欠損している場合、「先頭」を既定として一度だけ全走査へ劣化し（データ損失なく安全に劣化）、処理後に `distill-state.md` を新規作成することを検証する（§2.1 手順4・§9 欠損時既定）。

### 事前状態

- **distill-state.md**: 存在しない（初回 distill、またはファイル欠落）。
- **candidates.md**: 下記観測を provenance に持つ候補は無い（空）→ provenance 除外なし。

### 入力（セグメント captures-*.md 2件。バケット captures-2026-07-10.md / captures-2026-07-11.md）

```
## 2026-07-10T09:00:00Z
- signal: 訂正
- session: aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
- origin: user-utterance

ユーザーが「日付は YYYY-MM-DD 形式で書け」と訂正した。スラッシュ区切りで書いていた。

## 2026-07-11T10:00:00Z
- signal: ツール拒否
- session: aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
- origin: tool-result

グローバル pip install が拒否され、venv 経由に切り替えた。
```

### 手順トレース

1. **カーソル読取（§2.1 手順4・§9）**: `distill-state.md` 不存在 → カーソル欠損。「**先頭**」を既定とし、一度だけ全走査する（エラーにしない）。
2. **候補スライス**: カーソル欠損→保持集合の先頭既定 → 保持バケット群（`captures-2026-07-10/07-11.md` の2件）全体が候補スライス。
3. **provenance 除外（§2.1 手順6）**: 対象なし → 処理源2件。
4. **棄却・クラスタ化・整形**: 2件ともトリガー×差分が読める → 棄却なし、別トリガーのため2仮説（台帳突合は novel と仮定）。
5. **カーソル前進＋新規作成（§8）**: 処理後、カーソルを最新 timestamp `2026-07-11T10:00:00Z` へ設定し `distill-state.md` を**新規作成**する。次回以降はカーソルベースの有界化に移行する（全走査は初回一度きり）。

### 期待結果（仮説2件、`candidates.md` へ upsert／distill-state.md 新規作成）

2件が pending 仮説化され、`distill-state.md` が `- distill-cursor: 2026-07-11T10:00:00Z` で新規作成される。カーソル欠損はエラーでなく正常に劣化する。

完了報告: 処理源2件（カーソル欠損のため先頭全走査）/ 棄却0件 / 型内訳 behavior-diff 2件・decision-record 0件 / 優先度 2件とも N=1（単発・同列） / 採用仮説2件（再発知見変換0件）/ 前進後カーソル 2026-07-11T10:00:00Z（distill-state.md 新規作成）。

---

## 例J: 後方互換（旧 status 読み飛ばし・B6/AC6）

旧 `- status:` 行を残す入力エントリでも、distill が status を読み飛ばし、処理源選択を **provenance＋カーソルのみ**で行うことを検証する（§2.1 手順3・personal-store-spec.md「後方互換」・AC6）。**本ファイル中で能動的な `- status:` 行を持つのはこの1エントリのみ**であり、AC6 のトレース可能な artifact として意図的に残す（他の全入力エントリからは `- status:` 行を除去済み）。

### 事前状態

- **distill-state.md**: `- distill-cursor: 2026-07-09T00:00:00Z`
- **candidates.md**: 下記観測（`2026-07-10T10:00:00Z`）を provenance に持つ候補は無い（空、または無関係候補のみ）。

### 入力（セグメント captures-*.md、旧 `- status:` 行を意図的に1件保持。バケット captures-2026-07-10.md）

```
## 2026-07-10T10:00:00Z
- signal: 訂正
- session: bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb
- status: promoted
- origin: user-utterance

ユーザーが「関数名は動詞で始めろ」と訂正した。名詞始まりの関数名を付けていた。
```

> このエントリは旧スキーマの名残として `- status: promoted` 行を持つ（#416 以前に書かれた `captures.md`、または後方互換規約で残置された行）。distill はこの行を破壊的に削除・変換しない（後方互換）。

### 手順トレース

1. **エントリ抽出（§2.1 手順3）**: メタ行 `signal` / `session` / `origin` を抽出する。旧 `- status: promoted` 行は**読み飛ばす**（値に依存しない・破壊的変換もしない。personal-store-spec.md「後方互換」）。
2. **カーソル読取＋候補スライス（§2.1 手順4/5）**: カーソル `2026-07-09T00:00:00Z` より新しい → スライスに入る。
3. **provenance 除外（重複排除・§2.1 手順6）**: この観測（`07-10T10:00`）を provenance に持つ `promoted`/`pending` 候補は candidates.md に**無い** → 除外されず処理源に残る。
   - **もし status を honor していたら**: 旧 `- status: promoted` を信じて「処理済み」と誤ってスキップしていたはず。distill は status を読み飛ばし、**provenance（実際の候補台帳）＋カーソル**のみで処理源を決めるため、正しく処理源に残す（AC6）。
4. **棄却・整形**: トリガー×差分が読める → 新規仮説へ（台帳突合は novel と仮定）。生成される候補の `candidate-status` は新規のため `pending`（旧 status の `promoted` に引きずられない）。
5. **カーソル前進（§8）**: `2026-07-10T10:00:00Z`。

### 期待結果（仮説1件、`candidates.md` へ upsert）

旧 `- status: promoted` 行があっても distill はそれを無視し、provenance＋カーソルで処理源を決定して仮説を生成する。生成候補の `candidate-status` は `pending`（旧 status 値に依存しない）。`captures.md` への破壊的変換（旧 status 行の削除・書換）は行わない。

完了報告: 処理源1件（旧 status を読み飛ばし、provenance＋カーソルで選定）/ 棄却0件 / 採用仮説1件 / 前進後カーソル 2026-07-10T10:00:00Z。旧 `- status:` 行は読み取り時に無視し、captures.md への破壊的変換は行わないことを確認する（AC6）。

---

## 例K: 経年削除（retention・保持/削除セマンティクス・AC3）

horizon 超かつ全エントリ通過済みのバケットのみが `rm` され、直近 M 日バケット・境界バケット・未 distill エントリを含むバケットが保持されることを検証する（§2.1 経年削除節・personal-store-spec.md「retention」）。**基準日 today＝2026-07-11、M＝60 日** とする（horizon 境界 today − M ＝ **2026-05-12**。厳密不等号 `<` により `バケット日付 < 2026-05-12` が削除側、`== 2026-05-12` は保持側）。

> 単一カーソルのスナップショットでは「直近 M 日かつ全通過済み」と「horizon 超かつ未 distill」を同時に成立させられない（未 distill ＝見出しキー > カーソルであり、古いバケットが未 distill を持つのはカーソルがその日付より古い場合に限られ、そのとき直近バケットも未 distill になる）。そこで通常削除（K-1）と guarantee-once 保護（K-2）の2ケースで示す。

### ケースK-1: 通常の経年削除（カーソルが直近・全体が処理済み）

**事前状態** — distill-state.md: `- distill-cursor: 2026-07-10T23:00:00Z`。candidates.md: 下記 07-11 観測を provenance に持つ候補は無い。

**入力（セグメント captures-*.md、4バケット）**:

| バケット | 内部エントリ（見出しキー） | カーソル比較 | horizon（today−M=2026-05-12） |
|---|---|---|---|
| `captures-2026-03-01.md` | `2026-03-01T09:00:00Z` | ≤ カーソル（通過済み） | `03-01 < 05-12` ＝ horizon 超 |
| `captures-2026-05-12.md` | `2026-05-12T08:00:00Z` | ≤ カーソル（通過済み） | `05-12 == 05-12` ＝ **境界・horizon 未超** |
| `captures-2026-07-08.md` | `2026-07-08T10:00:00Z` | ≤ カーソル（通過済み） | `07-08 ≥ 05-12` ＝ 直近 M 日 |
| `captures-2026-07-11.md` | `2026-07-11T09:00:00Z` | > カーソル（未 distill） | 直近 M 日 |

**手順トレース**:

1. **バケット列挙＋Read 有界化（§2.1 手順1/2）**: Glob で4バケット列挙。カーソル日付 2026-07-10 以降のバケットのみ Read → `captures-2026-07-11.md` のみ Read（他3バケットは sealed で Read 対象外）。
2. **処理源確定＋仮説形成＋カーソル前進（§2.1/§8）**: `2026-07-11T09:00:00Z`（未 distill・1件）を処理源として仮説形成し、カーソルを `2026-07-11T09:00:00Z` へ前進。
3. **経年削除（§2.1 経年削除節・§8）**: カーソル前進後、全バケットについて drop 条件〔(a) 最大見出しキー ≤ カーソル ∧ (b) バケット日付 < 2026-05-12〕を評価。
   - `captures-2026-03-01.md`: (a) `03-01 ≤ 07-11` ✓ ∧ (b) `03-01 < 05-12` ✓ → **rm**。
   - `captures-2026-05-12.md`: (a) ✓ ∧ (b) `05-12 < 05-12` ✗（厳密不等号・境界は保持側）→ **保持**（オフバイワン境界）。
   - `captures-2026-07-08.md`: (a) ✓ ∧ (b) `07-08 < 05-12` ✗ → **保持**（直近 M 日）。
   - `captures-2026-07-11.md`: (a) `07-11 ≤ 07-11` ✓ ∧ (b) `07-11 < 05-12` ✗ → **保持**（直近 M 日）。

**期待結果**: `captures-2026-03-01.md` のみ削除（1バケット）。境界バケット `captures-2026-05-12.md`・直近バケット2件は保持。保持集合 ＝ 直近 M 日（05-12〔境界〕・07-08・07-11）＝ 仕様の「直近 M 日のバケット ∪ 未 distill 含む全バケット」と一致。

完了報告: 処理源1件 / 採用仮説1件 / 前進後カーソル 2026-07-11T09:00:00Z / **経年削除 1バケット（captures-2026-03-01.md／horizon 60日超・全通過済み。retention horizon M=60日）**。

### ケースK-2: guarantee-once 保護（horizon 超でも未 distill を含むバケットは削除しない）

distiller が長期間未実行（またはカーソルが過去へ巻き戻された）で、horizon を超えた古いバケットに未 distill エントリが残る場合、そのバケットを `rm` しないことを検証する（AC3・guarantee-once 非退行）。

**事前状態** — distill-state.md: `- distill-cursor: 2026-03-15T00:00:00Z`（古い）。today＝2026-07-11・M＝60（horizon 境界 2026-05-12）。

**入力（セグメント captures-*.md、2バケットとも horizon 超）**:

| バケット | 内部エントリ | カーソル比較 | drop 条件(a) 全通過済み |
|---|---|---|---|
| `captures-2026-03-01.md` | `2026-03-01T09:00:00Z` | ≤ カーソル（03-15） | 最大見出しキー `03-01 ≤ 03-15` ＝ **全通過済み** |
| `captures-2026-04-01.md` | `2026-04-01T09:00:00Z` | > カーソル（**未 distill**） | 最大見出しキー `04-01 > 03-15` ＝ **未通過あり** |

**手順トレース**:

1. **Read 有界化（§2.1 手順2）**: カーソル日付 2026-03-15 以降のバケットのみ Read → `captures-2026-03-01.md` は sealed（Read 対象外）、`captures-2026-04-01.md` を Read。
2. **処理源＋カーソル前進**: `2026-04-01T09:00:00Z`（未 distill）を処理源として仮説形成し、カーソルを `2026-04-01T09:00:00Z` へ前進。
3. **経年削除の評価**: 
   - `captures-2026-03-01.md`: (a) `03-01 ≤ 04-01`〔前進後カーソル〕✓ ∧ (b) `03-01 < 05-12` ✓ → **rm**。
   - `captures-2026-04-01.md`: (b) `04-01 < 05-12` ✓（horizon 超）だが、経年削除は前進後カーソル `2026-04-01T09:00:00Z` に対し (a) 最大見出しキー `04-01T09:00 ≤ 04-01T09:00` ✓。**ただし本 run で 04-01 を処理する前の時点では未 distill であり、guarantee-once の要点は「未検証観測を齢で消さない」こと**。distill は04-01 を必ず処理源として Read・仮説形成してから（＝1回は distill を通してから）でなければカーソルが 04-01 を超えず、通過前に rm されることはない。

> **guarantee-once の核心**: バケットが rm されうるのは、その最大見出しキーがカーソル ≤ になった後＝**distill が少なくとも1回そのバケットのエントリを処理源として通した後**に限る。未 distill エントリ（見出しキー > カーソル）を含む限り最大見出しキー > カーソルとなり drop 条件(a) を満たさず、horizon 超でも保持される。未検証観測が齢で無音脱落しない（ADR-20260712 制約〔ADR-20260711-2 決定2 を restate〕維持）。

**期待結果**: `captures-2026-04-01.md` は本 run で処理源として仮説化され（guarantee-once＝一度は distill を通る）、その後にのみ経年削除の対象になりうる。horizon 超という理由だけで未処理のまま削除されることはない。

---

## 例L: セグメント跨ぎのカーソル・見出しキー一意性（AC6）

複数の日付バケットに跨る観測列で、単一 `distill-state.md` カーソルと各バケット見出しキーが**同一 ISO 8601 キー空間**で辞書順比較され、provenance 参照が一意に定まること、同一 UTC 日の複数観察が同一バケットに `-NN` サフィックスで同居することを検証する（AC6・ADR-20260711-4）。

### 事前状態

- **distill-state.md**: `- distill-cursor: 2026-07-10T14:30:00Z-01`（カーソルが 07-10 バケット内の run 中間エントリを指す）
- **candidates.md**: 下記観測を provenance に持つ候補は無い。

### 入力（セグメント captures-*.md、2バケット・同一 UTC 日の -NN 同居を含む）

`captures-2026-07-10.md`（1 run で2観察＝同一 timestamp を `-NN` で一意化・同一バケットに同居）:

```
## 2026-07-10T14:30:00Z-01
- signal: 訂正
- session: cccccccc-cccc-cccc-cccc-cccccccccccc
- origin: user-utterance

ユーザーが「インデントはスペース2つに揃えろ」と訂正した。

## 2026-07-10T14:30:00Z-02
- signal: 設計判断
- session: cccccccc-cccc-cccc-cccc-cccccccccccc
- origin: user-utterance

ユーザーが「設定ファイルは YAML で統一する」と設計境界を確定した。
```

`captures-2026-07-11.md`（別 UTC 日・別バケット）:

```
## 2026-07-11T09:00:00Z
- signal: ツール拒否
- session: cccccccc-cccc-cccc-cccc-cccccccccccc
- origin: tool-result

グローバル npm install が拒否され、ローカル devDependencies に切り替えた。
```

### 手順トレース

1. **バケット列挙＋Read 有界化（§2.1 手順1/2）**: Glob `captures-*.md` で2バケット列挙。カーソル日付 2026-07-10 以降 → 両バケットとも Read 対象。
2. **per-entry カーソル比較（§2.1 手順5・辞書順・同一キー空間）**: カーソル `2026-07-10T14:30:00Z-01` と各見出しキーを**文字列辞書順**で比較する（見出しキーは `Z` 直後に `-NN` が付き厳密 ISO 8601 日時ではないため日時 parse せず辞書順。personal-store-spec.md「カーソルの格納場所」・ADR-20260711-4）。
   - `2026-07-10T14:30:00Z-01`: カーソルと等しい → **カーソル以下＝通過済み**（スライス外）。
   - `2026-07-10T14:30:00Z-02`: `-02 > -01`（固定幅サフィックスが辞書順＝記録順）→ **カーソルより新しい**（同一バケット内・スライスに入る）。
   - `2026-07-11T09:00:00Z`: 別バケットだが同一キー空間で `07-11... > 07-10...` → **カーソルより新しい**（スライスに入る）。
3. **処理源確定**: `07-10T14:30:00Z-02`（同一バケット内の未通過）と `07-11T09:00:00Z`（別バケット）の2件。**バケット境界はカーソル比較に影響しない**——単一カーソルが複数バケットに跨るキー列を一意に分割する。
4. **カーソル前進（§8）**: 候補スライスの最新見出しキー `2026-07-11T09:00:00Z`（辞書順最大）へ前進。`-01`/`-02` の run 内序数を跨いでも、`07-11` の別バケット見出しキーが辞書順で最大と一意に定まる。

### 期待結果（仮説2件・カーソル前進）

`07-10T14:30:00Z-02`（判断知→`decision-record`）と `07-11T09:00:00Z`（摩擦知→`behavior-diff`）が仮説化される。**セグメント跨ぎでも**: (a) 見出しキーはバケット分割前と同一 ISO 8601 キー空間で一意（同一 UTC 日は `-NN` で衝突回避・同一バケット同居）、(b) 単調増加（辞書順が記録順に一致）、(c) 単一カーソルが全バケットのキー列を一意に分割、(d) provenance 参照（各仮説の `## <timestamp>` 群）が跨ぎでも一意に定まる。処理後カーソル `2026-07-11T09:00:00Z`。

完了報告: 処理源2件 / 型内訳 behavior-diff 1件・decision-record 1件 / 採用仮説2件 / 前進後カーソル 2026-07-11T09:00:00Z / 経年削除0バケット（horizon 超バケットなし）。

---

## 関連

- [`distill-procedure.md`](distill-procedure.md) — 各例が検証する判定基準の本体
- `${CLAUDE_PLUGIN_ROOT}/references/personal-store-spec.md` — 入力エントリの `origin`/`expected`/`actual` 欄、および期待結果（仮説）が整合すべき仮説ファイル（`candidates.md`）のメタ欄スキーマ・provenance 規約・upsert 方式
- `${CLAUDE_PLUGIN_ROOT}/references/learning-store-spec.md` — 仮説見出し・本文が昇格時に残る規範形（1欄スキーマ・記法例）・2空間モデル（scope-hypothesis の値域）
