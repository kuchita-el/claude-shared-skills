# Promote サンプル入力と期待結果（手順トレース用）

[`promote-procedure.md`](promote-procedure.md) の判定基準を検証するための worked example。本リポジトリは自動テスト基盤を持たないため、実装者は各例の入力を手順に通し（手順トレース）、期待結果と一致することを目視確認する。特に**負の振る舞い**（検証棄却時に起票しない／起票失敗時に status を反転しない）を重点的にトレースする。

各例が検証するケース:

| 検証するケース | 例 |
|---|---|
| `behavior-diff` の検証通過候補を自動起票し、起票成功後に provenance 経由で status を反転する | 例A |
| 反証可能性・予測力を欠く候補は起票せず、candidate-status を rejected にし status を反転しない | 例B |
| 起票が失敗したとき、由来 store エントリの status を反転しない（再実行可能を保つ） | 例C |
| 1候補が複数 observation を畳む（provenance 複数）とき、起票成功で全 store エントリを反転する | 例D |
| `decision-record` を復元不能性で検証して通過し、流路は behavior-diff と同一（learnings.md へ直送しない）で起票・反転する | 例E |
| `decision-record` が既にリポに記録済み＝復元可能のとき棄却し、candidate-status を rejected にし status を反転しない | 例F |

入力の `candidates.md` は distill が生成した状態（`candidate-status: pending`）を前提とする。`behavior-diff`（例A〜D）は予測・反証で、`decision-record`（例E〜F）は復元不能性で検証する（procedure §3 の型適応）。

---

## 例A: 検証通過 → 自動起票 → status 反転（単一 provenance）

### 入力（candidates.md の `pending` 候補1件）

```
## ファイル復元には git restore を使う
- tags: [behavior-diff]
- provenance: 2026-06-26T14:32:10Z
- scope-hypothesis: universal
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
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
3. **Route 注記（ルーティング不可知）**: `scope-hypothesis: universal` → Issue 本文に `## スコープ仮説`「適用範囲（仮説・未確証）: universal」を注記。`career-hypothesis: learnings.md / repo: …` → `## キャリア仮説`「昇格先キャリア（仮説・未確証）: learnings.md / 宛先 repo（仮説・未確証）: 配布元プラグイン repo」を注記。promote は両者を確定せず運ぶのみ（career の裁定は集約点）。
4. **自動起票**: 本文を一時ファイルへ Write → `gh issue create --title "ファイル復元には git restore を使う" --body-file <tmp>`。人間承認ゲートなし。成功し `#401` が払い出される。
5. **status 反転**: provenance `2026-06-26T14:32:10Z` が指す `captures.md` エントリの `- status: unprocessed` を `- status: promoted` へ反転。

### 期待結果

- Issue `#401` が起票される（本文に規範＋スコープ仮説注記＋キャリア仮説注記＋検証の予測/反証観点を含む）。
- `captures.md` の当該エントリが `status: promoted` になる。
- 候補の `candidate-status` を `promoted` へ更新（任意・推奨）。

完了報告: 検証1件 / 不合格0件 / 起票1件（#401）/ status 反転 store エントリ1件。

---

## 例B: 検証棄却（起票しない・status 反転しない）

### 入力（candidates.md の `pending` 候補1件）

```
## ログをちゃんと読む
- tags: [behavior-diff]
- provenance: 2026-06-26T15:00:00Z
- scope-hypothesis: universal
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
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
- tags: [behavior-diff]
- provenance: 2026-06-26T11:00:00Z, 2026-06-26T11:10:00Z
- scope-hypothesis: universal
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
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

## 例E: decision-record の検証通過（復元不能性）→ 自動起票 → status 反転

`behavior-diff` の予測・反証ではなく**復元不能性**で検証する型適応の正の例（procedure §3 decision-record 行）。流路は behavior-diff と**同一**（candidates → promote → Issue → 既存ワークフロー）であり、learnings.md へ直送しない。

### 入力（candidates.md の `pending` 候補1件・`tags: [decision-record]`）

```
## プランは追跡対象にしない
- tags: [decision-record]
- provenance: 2026-06-29T08:50:02Z
- scope-hypothesis: project-local
- career-hypothesis: ADR 差分 / repo: 当該プロジェクト repo
- candidate-status: pending

- decision: プランファイルは git 追跡対象（コミット）に変えない。追跡可否は利用者に委ねる。
- rejected-alternatives: プランを追跡対象（コミット）に変える第三案。
- rationale: 追跡するか否かは利用者側の運用判断であり、仕組みで固定すべきでない。
- context: プラン所在問題（#422 周辺）の解決案を巡る設計判断。
```

対応する `captures.md` のエントリ（抜粋）:

```
## 2026-06-29T08:50:02Z
- signal: 設計判断
- session: 7d3e1f02-9a4c-4b81-8e6f-1c2d3a4b5c6d
- status: unprocessed
- origin: user-utterance

ユーザーが「プランを追跡対象に変えることは無い／追跡可否は利用者に委ねる」と設計境界を確定した。
```

### 手順トレース

1. **候補読取**: `candidate-status: pending` の1件が対象。`tags: [decision-record]`。
2. **検証（型適応＝復元不能性）**: `behavior-diff` の予測・反証ではなく復元不能性で測る（procedure §3 decision-record）。本文4欄を材料に:
   - 復元不能か: この設計境界（追跡可否を利用者に委ねる）は #422 周辺の会話でのみ交わされ、まだ ADR/spec に記録されていない → **復元不能**（反証条件(a)非該当）。
   - まだ有効か: 後に覆されていない → **有効**（(b)非該当）。
   - 配布価値があるか: プラン所在の設計指針として carry-forward する → **価値あり**（(c)非該当）。
   - 3条件すべて満たす → **合格**。
3. **Route 注記（tags 運搬）**: `## 知識型`「tags: [decision-record]（判断知）」＋ `## スコープ仮説`「project-local（閉じた空間）」＋ `## キャリア仮説`「昇格先キャリア: ADR 差分 / 宛先 repo: 当該プロジェクト repo」を注記。promote は知識型・scope・career のいずれも確定せず運ぶ。
4. **自動起票**: 本文（4欄＋復元不能性の判定理由＋ Route 注記欄）を一時ファイルへ Write → `gh issue create --title "プランは追跡対象にしない" --body-file <tmp>`。人間承認ゲートなし。dev-workflow 非呼び出し。成功し `#403` が払い出される。
5. **status 反転**: provenance `2026-06-29T08:50:02Z` が指す `captures.md` エントリの `- status: unprocessed` を `- status: promoted` へ反転（一意な `## <timestamp>` 見出しブロックをアンカーに Edit）。

### 期待結果

- Issue `#403` が起票される（本文に4欄＋知識型/スコープ/キャリア注記＋復元不能性の判定理由を含む）。
- `captures.md` の当該エントリが `status: promoted` になる。
- **流路は behavior-diff と同一**（candidates → promote → Issue → 既存ワークフロー＝L2 ゲート）。learnings.md へ直送しない（揉む場・Distribute 翻訳規約をスキップしない）。

完了報告: 検証1件 / 不合格0件 / 起票1件（#403）/ status 反転 store エントリ1件。

---

## 例F: decision-record の検証棄却（既にリポに記録済み＝復元可能）

復元不能性ゲートの反証条件(a)「既にリポに記録済み＝復元可能」に該当する負の例。棄却して起票せず status を反転しない（負の振る舞い）。

### 入力（candidates.md の `pending` 候補1件・`tags: [decision-record]`）

```
## ADR は docs/adr 配下に集約する
- tags: [decision-record]
- provenance: 2026-06-29T09:10:00Z
- scope-hypothesis: project-local
- career-hypothesis: ADR 差分 / repo: 当該プロジェクト repo
- candidate-status: pending

- decision: ADR は docs/adr/ 配下に集約して置く。
- rejected-alternatives: 各プラグインディレクトリ内へ分散配置する案。
- rationale: 一覧性のため集約する。
- context: ADR 配置を巡る整理。
```

### 手順トレース

1. **候補読取**: 1件が対象。`tags: [decision-record]`。
2. **検証（型適応＝復元不能性）**:
   - 復元不能か: この決定は既に `CLAUDE.md`「ADR」節・`docs/adr/README.md` に記録済み＝リポから決定的に復元可能 → 反証条件**(a)に該当**。
   - → **不合格**（復元可能なものは捕まえ直す価値がない。検証は棄却方向に厳しく倒す）。
3. 起票段へ進めない。候補の `candidate-status: pending` を `rejected` へ更新（一意な `- provenance:` 行を含む見出しブロックをアンカーに Edit）。
4. status 反転は行わない。

### 期待結果

- Issue は起票され**ない**。
- 候補の `candidate-status` が `rejected` になる（次回の再提示・再評価を抑止）。
- `captures.md` の由来エントリ（`2026-06-29T09:10:00Z`）は `status: unprocessed` の**まま**（反転しない）。

完了報告: 検証1件 / 不合格1件（candidate-status: rejected・既にリポに記録済み＝復元可能）/ 起票0件 / status 反転0件。

---

## 関連

- [`promote-procedure.md`](promote-procedure.md) — 各例が検証する判定基準の本体
- `${CLAUDE_PLUGIN_ROOT}/references/personal-store-spec.md` — 候補ファイル・store のスキーマ、`status` 状態機械、provenance 規約
