# Distill サンプル入力と期待結果（手順トレース用）

[`distill-procedure.md`](distill-procedure.md) の判定基準を検証するための worked example。本リポジトリは自動テスト基盤を持たないため、実装者は各例の入力を手順に通し（手順トレース）、期待結果と一致することを目視確認する。入力はすべて `status: unprocessed` とする。

各例が検証するケース:

| 検証するケース | 例 |
|---|---|
| 表層の語彙差を無視して同一トリガー×振る舞い差分を畳む | 例A |
| 同一 `signal` でも振る舞い差分が異なれば畳まない | 例A |
| 純記述的な観察を棄却する | 例B |
| 実行不能・空の観察を棄却する | 例B |
| 重複＋純記述＋有効の混在から有効分のみクラスタ化する | 例C |
| 各候補に provenance（畳んだ timestamp 群）・scope-hypothesis・candidate-status を付与し candidates.md へ upsert する | 例A・例C |
| 採用候補0件のとき candidates.md へ書き込まない | 例B |

---

## 例A: クラスタ化・重複排除（AC2）

### 入力（store の `unprocessed` エントリ4件）

```
## 2026-06-26T10:00:00Z
- signal: 訂正
- session: 11111111-1111-1111-1111-111111111111
- status: unprocessed

ユーザーが「git checkout ではなく git restore を使え」と訂正した。当方はファイル復元に git checkout を提案していた。

## 2026-06-26T10:05:00Z
- signal: 訂正
- session: 11111111-1111-1111-1111-111111111111
- status: unprocessed

ファイル復元のつもりで git checkout . を実行しようとしたら、git restore を使うよう指摘された。

## 2026-06-26T11:00:00Z
- signal: 訂正
- session: 11111111-1111-1111-1111-111111111111
- status: unprocessed

ユーザーが「Markdown を -m に直接渡すな」と訂正した。長い本文をコマンド引数に直接渡そうとしていた。

## 2026-06-26T11:10:00Z
- signal: ツール拒否
- session: 11111111-1111-1111-1111-111111111111
- status: unprocessed

長い PR 本文を gh pr create の --body に直接渡そうとして、ヒアドキュメントのクォートが3回壊れて失敗した。--body-file に切り替えて成功した。
```

### 手順トレース

1. **入力選択**: 4件すべて `unprocessed` → 全件が対象。
2. **棄却判定**: 4件すべてトリガー×振る舞い差分が読み取れる → 棄却なし。
3. **トリガー×振る舞い差分の推論**:
   - エントリ1 → トリガー「ファイルを復元するとき」× 差分「git checkout でなく git restore を使う」
   - エントリ2 → トリガー「ファイルを復元するとき」× 差分「git checkout でなく git restore を使う」（**言い回し違いの重複**）
   - エントリ3 → トリガー「長文を CLI 引数に渡すとき」× 差分「-m 等に直接渡さず一時ファイル経由にする」
   - エントリ4 → トリガー「長文を CLI 引数に渡すとき」× 差分「直接渡さず --body-file（一時ファイル）経由にする」
4. **クラスタ化**:
   - 1 と 2 はトリガー×差分が一致 → 1候補へ集約（**表層の語彙差を無視して畳む**）。
   - 1・2（signal=訂正）と 3（signal=訂正）は **同一 signal だが振る舞い差分が異なる** → 畳まない（**signal 一致だけで集約しない**）。
   - 3 と 4 はトリガー×差分が一致 → 1候補へ集約（**signal が訂正/ツール拒否で異なっても、振る舞い差分が同じなら畳む**）。

### 期待結果（候補2件 < 入力4件、`candidates.md` へ upsert）

各候補にメタ欄（provenance＝畳んだ観察の `## <timestamp>` 群、scope-hypothesis＝蒸留観点の仮説タグ、candidate-status＝`pending`）が付く。エントリ1・2 は同一クラスタなので provenance に両 timestamp を列挙する。

```
## ファイル復元には git restore を使う
- provenance: 2026-06-26T10:00:00Z, 2026-06-26T10:05:00Z
- scope-hypothesis: universal
- candidate-status: pending

ファイルを復元するとき git checkout ではなく git restore を使う。git checkout はブランチ切り替えと復元が多重定義されており、誤操作で別ブランチへ移る事故を招くため。

## 長文は CLI 引数に直接渡さず一時ファイル経由にする
- provenance: 2026-06-26T11:00:00Z, 2026-06-26T11:10:00Z
- scope-hypothesis: universal
- candidate-status: pending

Markdown 等の長文を CLI オプションに直接渡さない。ファイルへ書き出し --body-file 等で渡す。シェルのクォート・ヒアドキュメント制約による破損と、許可プロンプトの中断を避けるため。
```

これらは `candidates.md` へ provenance キーで upsert 永続化され、チャットにも提示される。両候補とも全プロジェクトに効くため scope-hypothesis は `universal`（仮説。最終裁定は下流の人間 refine/review）。
完了報告: 入力 unprocessed 4件 / 棄却0件 / 採用候補2件（2 < 4）。

---

## 例B: 棄却（AC4）

### 入力（store の `unprocessed` エントリ3件）

```
## 2026-06-26T12:00:00Z
- signal: 期待違反
- session: 22222222-2222-2222-2222-222222222222
- status: unprocessed

npm install が想定より遅かった。

## 2026-06-26T12:05:00Z
- signal: 期待違反
- session: 22222222-2222-2222-2222-222222222222
- status: unprocessed

ビルドログが冗長で読みにくかった。

## 2026-06-26T12:10:00Z
- signal: 反復試行
- session: 22222222-2222-2222-2222-222222222222
- status: unprocessed

同じような作業を何度か繰り返した。
```

### 手順トレース

1. **入力選択**: 3件すべて `unprocessed` → 全件が対象。
2. **棄却判定**:
   - 「npm install が想定より遅かった」→ 事実の記述のみ。「次回どう違う行動を取るか」が読み取れない → **純記述として棄却**。
   - 「ビルドログが冗長で読みにくかった」→ 同上、行動を命じない → **純記述として棄却**。
   - 「同じような作業を何度か繰り返した」→ トリガーも振る舞い差分も一意に読み取れない → **実行不能として棄却**。
3. クラスタ化対象が残らない。

### 期待結果

候補リストに上記いずれの観察も**現れない**。採用候補が0件のため `candidates.md` への書き込みは行わない（procedure §7）。
完了報告: 入力 unprocessed 3件 / 棄却3件 / 採用候補0件（「候補化できる規範はありませんでした（棄却3件）」と報告。例: §7 エラー・境界処理）。

---

## 例C: 混在（AC2＋AC4）

### 入力（store の `unprocessed` エントリ4件）

例A のエントリ1・2（`2026-06-26T10:00:00Z` / `10:05:00Z`＝「git checkout でなく git restore」の重複する有効観察）＋ 例B の「npm install が想定より遅かった」（`2026-06-26T12:00:00Z`、純記述）＋ 次の1件:

```
## 2026-06-26T13:00:00Z
- signal: ツール拒否
- session: 33333333-3333-3333-3333-333333333333
- status: unprocessed

git commit のメッセージにヒアドキュメントを使って失敗した。-m を複数回指定する方式に切り替えて成功した。
```

### 手順トレース

1. **入力選択**: 4件すべて `unprocessed`。
2. **棄却判定**: 「npm install が想定より遅かった」を純記述として棄却（残り有効3件）。
3. **クラスタ化**: 有効3件のうち、例A エントリ1・2 を「ファイル復元には git restore を使う」へ集約。上記の commit メッセージ観察は別トリガー×差分（「コミットメッセージに複数行を渡すとき」×「ヒアドキュメントでなく -m を複数回指定」）→ 単独候補。

### 期待結果（候補2件 < 有効3件 < 入力4件）

```
## ファイル復元には git restore を使う
- provenance: 2026-06-26T10:00:00Z, 2026-06-26T10:05:00Z
- scope-hypothesis: universal
- candidate-status: pending

ファイルを復元するとき git checkout ではなく git restore を使う。…（理由）

## コミットメッセージに複数行を渡すときはヒアドキュメントを避け -m を複数回指定する
- provenance: 2026-06-26T13:00:00Z
- scope-hypothesis: universal
- candidate-status: pending

git commit のメッセージにヒアドキュメントを使わず、-m を複数回指定して行を分ける。シェルのヒアドキュメント制約による失敗を避けるため。
```

完了報告: 入力 unprocessed 4件 / 棄却1件 / 採用候補2件（2 < 有効3 < 入力4）。純記述が候補に漏れず、有効分のみがクラスタ化され、各候補に provenance・scope-hypothesis・candidate-status が付いて `candidates.md` へ upsert されることを確認する。

---

## 関連

- [`distill-procedure.md`](distill-procedure.md) — 各例が検証する判定基準の本体
- `${CLAUDE_PLUGIN_ROOT}/references/personal-store-spec.md` — 期待結果（候補）が整合すべき候補ファイル（`candidates.md`）のメタ欄スキーマ・provenance 規約・upsert 方式
- `${CLAUDE_PLUGIN_ROOT}/references/learning-store-spec.md` — 候補見出し・本文が昇格時に残る規範形（1欄スキーマ・記法例）・2空間モデル（scope-hypothesis の値域）
