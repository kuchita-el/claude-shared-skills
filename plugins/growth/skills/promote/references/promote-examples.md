# Promote サンプル入力と期待結果（手順トレース用）

[`promote-procedure.md`](promote-procedure.md) の判定基準を検証するための worked example。本リポジトリは自動テスト基盤を持たないため、実装者は各例の入力を手順に通し（手順トレース）、期待結果と一致することを目視確認する。特に**負の振る舞い**（検証棄却時に起票しない／起票失敗時に status を反転しない）を重点的にトレースする。

各例が検証するケース:

| 検証するケース | 例 |
|---|---|
| 検証通過候補を自動起票し、起票成功後に provenance 経由で status を反転する | 例A |
| 反証可能性・予測力を欠く候補は起票せず、candidate-status を rejected にし status を反転しない | 例B |
| 起票が失敗したとき、由来 store エントリの status を反転しない（再実行可能を保つ） | 例C |
| 1候補が複数 observation を畳む（provenance 複数）とき、起票成功で全 store エントリを反転する | 例D |

入力の `candidates.md` は distill が生成した状態（`candidate-status: pending`）を前提とする。

---

## 例A: 検証通過 → 自動起票 → status 反転（単一 provenance）

### 入力（candidates.md の `pending` 候補1件）

```
## ファイル復元には git restore を使う
- provenance: 2026-06-26T14:32:10Z
- scope-hypothesis: universal
- candidate-status: pending

ファイル復元には git checkout ではなく git restore を使う。git checkout は復元とブランチ切替が多重定義され誤操作を招くため。
```

対応する `captures.md` のエントリ（抜粋）:

```
## 2026-06-26T14:32:10Z
- signal: 訂正
- session: 2265f83f-c5a8-41a0-b284-b5d90882a2da
- status: unprocessed

ユーザーが「git checkout ではなく git restore を使え」と訂正した。
```

### 手順トレース

1. **候補読取**: `candidate-status: pending` の1件が対象。
2. **検証**: 予測「ファイルを復元する場面で効く」・反証条件「git checkout が復元用途で安全と示せれば反証」が立つ → **合格**。
3. **Route 注記**: `scope-hypothesis: universal` → Issue 本文に「適用範囲（仮説・未確証）: universal」を注記。
4. **自動起票**: 本文を一時ファイルへ Write → `gh issue create --title "ファイル復元には git restore を使う" --body-file <tmp>`。人間承認ゲートなし。成功し `#401` が払い出される。
5. **status 反転**: provenance `2026-06-26T14:32:10Z` が指す `captures.md` エントリの `- status: unprocessed` を `- status: promoted` へ反転。

### 期待結果

- Issue `#401` が起票される（本文に規範＋スコープ仮説注記＋検証の予測/反証観点を含む）。
- `captures.md` の当該エントリが `status: promoted` になる。
- 候補の `candidate-status` を `promoted` へ更新（任意・推奨）。

完了報告: 検証1件 / 不合格0件 / 起票1件（#401）/ status 反転 store エントリ1件。

---

## 例B: 検証棄却（起票しない・status 反転しない）

### 入力（candidates.md の `pending` 候補1件）

```
## ログをちゃんと読む
- provenance: 2026-06-26T15:00:00Z
- scope-hypothesis: universal
- candidate-status: pending

エラーが出たときはログをちゃんと読むのが大事だと感じた。
```

### 手順トレース

1. **候補読取**: 1件が対象。
2. **検証**: 「ログをちゃんと読む」は予測（どの状況で効くか）が具体化できず、反証条件も作れない（常に正しく見える訓辞）→ **不合格**。
3. 起票段へ進めない。候補の `candidate-status: pending` を `rejected` へ更新。
4. status 反転は行わない。

### 期待結果

- Issue は起票され**ない**。
- 候補の `candidate-status` が `rejected` になる（次回の再提示・再評価を抑止）。
- `captures.md` の由来エントリ（`2026-06-26T15:00:00Z`）は `status: unprocessed` の**まま**（反転しない）。

完了報告: 検証1件 / 不合格1件（candidate-status: rejected）/ 起票0件 / status 反転0件（「配布可能な候補はありませんでした（不合格1件）」）。

---

## 例C: 起票失敗時の status 非反転

### 入力

例A と同じ候補（検証は合格する）。ただし `gh issue create` が認証エラー／ネットワーク障害で失敗する状況。

### 手順トレース

1〜3. 例A と同じ（検証合格・Route 注記まで進む）。
4. **自動起票**: 本文を一時ファイルへ Write → `gh issue create` が**失敗**。一時ファイルは残す。
5. **status 反転**: 起票が成功していないため、provenance が指す store エントリの `status` を**反転しない**（procedure §6 ディシジョンテーブル「Yes/No → しない」）。

### 期待結果

- Issue は起票されない。
- `captures.md` の由来エントリは `status: unprocessed` の**まま**（再実行で再度起票を試みられる）。
- 候補の `candidate-status` も `pending` のまま（合格だが未起票）。procedure §6 ステップ3「起票成功した候補の `candidate-status` を `promoted` へ更新（任意・推奨）」は起票成功を条件とするため、起票失敗時はこの更新条件を満たさず `pending` を維持する。
- 一時ファイルのパスを示して再実行可能にする。

完了報告: 検証1件 / 合格1件 / 起票失敗1件（status 反転0件・再実行可）。

---

## 例D: 複数 provenance の一括反転

### 入力（candidates.md の `pending` 候補1件・クラスタ畳み込み）

```
## 長文は CLI 引数に直接渡さず一時ファイル経由にする
- provenance: 2026-06-26T11:00:00Z, 2026-06-26T11:10:00Z
- scope-hypothesis: universal
- candidate-status: pending

Markdown 等の長文を CLI オプションに直接渡さない。ファイルへ書き出し --body-file 等で渡す。シェルのクォート/ヒアドキュメント制約による破損を避けるため。
```

`captures.md` に `2026-06-26T11:00:00Z` と `2026-06-26T11:10:00Z` の2エントリ（ともに `unprocessed`）が存在する。

### 手順トレース

1〜4. 検証合格 → Route 注記 → 起票成功（`#402`）。
5. **status 反転**: provenance が**2つの timestamp** を持つため、`captures.md` の `2026-06-26T11:00:00Z` と `2026-06-26T11:10:00Z` の**両エントリ**を `promoted` へ反転する。両エントリの `- status: unprocessed` 行は同一テキストのため、procedure §6 ステップ2 に従い**各 timestamp の `## <timestamp>` 見出しブロックをアンカーに個別に Edit** する（status 行単独 Edit や `replace_all` は使わない＝誤反転防止）。

### 期待結果

- Issue `#402` が起票される。
- `captures.md` の2エントリ**ともに** `status: promoted` になる（畳んだ全由来観察を昇格済みに）。
- 次回 distill 実行時、両エントリは `promoted` のため再走査されず、同一候補は再生成されない（冪等性）。

完了報告: 検証1件 / 合格1件 / 起票1件（#402）/ status 反転 store エントリ2件。

---

## 関連

- [`promote-procedure.md`](promote-procedure.md) — 各例が検証する判定基準の本体
- `${CLAUDE_PLUGIN_ROOT}/references/personal-store-spec.md` — 候補ファイル・store のスキーマ、`status` 状態機械、provenance 規約
