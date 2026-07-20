# Promote 手順（検証→Route 注記→自動起票→candidate-status 前進）

promote スキルの各段の判定基準の詳細。SKILL.md の手順 overview から参照される単一出典。worked example は [`promote-examples.md`](promote-examples.md) を参照する。

## 1. 目的・責務境界

- **目的**: distill が `candidates.md` へ永続化した仮説を検証し（原理2）、検証を通過したものだけを `gh` で Issue へ自動起票して既存ワークフローへ渡す。起票成功後に候補の `candidate-status` を前進させる。
- **責務境界**: promote が担うのは「検証 → Route 注記 → 自動起票 → candidate-status 前進」の4段。**promote はルーティング不可知である**——career（昇格先キャリア）も scope（適用範囲）も**確定（裁定）しない**。distill が `candidates.md` に出した `scope-hypothesis` / `career-hypothesis` の両仮説を、昇格 Issue 本文へ**注記として運ぶのみ**（ADR-20260628-2）。次は**行わない**:
  - 仮説の生成・クラスタ化（distill の責務）
  - career の Route 判定・決定表評価・キャリアラベル付与（決定表は distill 側＝distill-procedure.md へ移設済み。promote は決定表を持たない）
  - `learnings.md`（配布物）への物理書き込み（Distribute、Phase 2 の責務）。Route はタグの**注記**までで終端し、物理昇格はしない。
  - dev-workflow スキルの直接呼び出し（疎結合。起票は `gh` 直接のみ）
  - scope / career 仮説タグの確証・真化（仮説のまま終点。scope の最終裁定は人間 refine/review、career の確定は集約点＝取り込み Issue）
- **二段ゲートの位置**: promote の検証段（§3）が二段ゲートの「未検証を配布経路に乗せない」フィルタ。起票前に人間承認ゲートは置かない（§5）。L2 の規範的ゲート（承認/マルチエージェントレビュー）は起票後の既存ワークフロー（refine-issue / DoR / PR レビュー）が担う（DESIGN.md 二段ゲート）。

## 2. 仮説読取（入力選択）

1. **仮説ファイルパスの解決**: personal-store-spec.md「project-id とパスの解決手順」に従い `<project-id>` を解決し、仮説ファイルパス `~/.claude/projects/<project-id>/growth/candidates.md` を組み立てる。
2. **仮説ファイルの読取**: Read で読む。存在しない・読めない場合は §7 のエラー処理へ。
3. **エントリの抽出**: personal-store-spec.md「仮説ファイル（candidates.md）」のスキーマ（`## <見出し>` ＋ `- tags:` / `- provenance:` / `- scope-hypothesis:` / `- career-hypothesis:` / `- candidate-status:` メタ行 ＋ 本文）に従い行ベースで抽出する。旧スキーマの単値 `- type:` 行は後方互換規約（personal-store-spec.md「後方互換規約」）で `tags` へ写して読む。
4. **対象選択**: `candidate-status: pending` のエントリのみを処理対象に選ぶ。`rejected`（過去に検証で棄却）・`promoted`（昇格済み）は**無視**する。`pending` が0件なら §7 のエラー処理へ。

## 3. 検証（型適応）

各仮説を配布経路（Issue）へ乗せる価値があるかを評価する。検証は promote 自身が行う自己検証（Phase 1 の最小形。独立検証エージェント化は Phase 4）。

**検証軸は仮説の `tags` の各要素で分岐する**（ADR-20260701 D5）。摩擦知（`behavior-diff`）は予測誤差の反証（原理2）で、判断知（`decision-record`）は復元不能性で測る——フィルタは対象の価値軸と一致していなければ精度・再現のいずれかを失うため、1本のゲートで両型を測らない。仮説の `tags`（多値 set）の各タグに、対応する型適応検証をそれぞれ適用する。混在ゾーン（`tags: [behavior-diff, decision-record]`）仮説は behavior-diff 検証と decision-record 検証の両方を受ける。`tags` の値域・本文スキーマ正準は personal-store-spec.md「tags 別スキーマ」を参照する（promote 側で二重定義しない）。旧スキーマ（`type` 単値・`type`/`tags` とも欠落）は後方互換規約（personal-store-spec.md「後方互換規約」）で `tags` へ写して読む（単値 `type: <値>`＝`[<値>]`、欠落＝`[behavior-diff]`）。

### behavior-diff（摩擦知）: 予測・反証（原理2）

各仮説について以下を添えて評価する（現行どおり。変更なし）:

- **予測**: この規範が次にどんな状況で効くか（適用される具体場面）。予測が立てられない＝検証も反証もできない。
- **検証観点**: どの条件で反証されうるか（反例の形）。反証可能性が無い主張は仮説たりえない。

### decision-record（判断知）: 復元不能性

判断知（選好・却下理由・目標表明・設計判断）は一回性の設計境界＝予測誤差の形を持たないため、原理2 の予測的反証では測れない。代わりに「**復元不能で・まだ有効で・配布価値があるか**」を検査する。`decision-record` の本文4欄（`decision` / `rejected-alternatives` / `rationale` / `context`）を判断材料に、以下3条件をすべて満たせば合格、いずれかに該当すれば不合格とする:

- **復元不能か**: その決定知が既にリポ（コード・git 履歴・ADR・spec）に記録済みなら**復元可能**＝不合格（反証条件(a)。捕まえ直す価値がない）。
- **まだ有効か**: その決定が後に覆されているなら不合格（反証条件(b)。陳腐化）。
- **配布価値があるか**: carry-forward 価値のない一回性（その場限りで再利用されない判断）なら不合格（反証条件(c)）。

**合否境界**（タグ別）:

| タグ | 合格条件 | 不合格条件（→ `candidate-status: rejected`） |
|---|---|---|
| `behavior-diff` | 予測（効く場面）と反証条件の両方が立ち、規範として実行可能な振る舞い差分を述べている | 反証可能性を欠く（反例が原理的に作れない）／予測力を欠く（いつ効くか述べられない）／一回限りの事象で再現性が読めない |
| `decision-record` | 復元不能（リポ未記録）・まだ有効（覆されていない）・配布価値あり（carry-forward する）の3条件をすべて満たす | (a) 既にリポ（コード・git・ADR・spec）に記録済み＝復元可能／(b) 後に覆された／(c) carry-forward 価値のない一回性 |

- **混在ゾーン仮説（`tags: [behavior-diff, decision-record]`）の合否**: 各タグを対応する検証にかけ、**全タグが合格した仮説のみ起票段へ進める**。いずれかのタグが不合格なら仮説全体を `rejected` とする（保守的既定＝疑わしきは rejected。一部タグのみ合格した仮説を合格タグへ絞って起票する部分昇格は Phase 1 では扱わない）。
- いずれのタグも**不合格仮説は起票段へ進めない**。`candidate-status` を `rejected` へ更新する（§6 の冪等性）。`captures.md` は `status` フィールドを持たないため、`candidate-status: rejected` の更新のみで冪等性が完結する（captures.md への書き込みは発生しない）。

- 不合格仮説は `candidates.md` の当該エントリの `candidate-status: pending` を `rejected` へ Edit で更新する。これにより次回 distill / promote 実行で同一仮説が再提示・再評価されるループを断つ（personal-store-spec.md「冪等性」）。`- candidate-status: pending` 行は仮説間で同一テキストのため、対象仮説の**一意な `- provenance:` 行を含む見出しブロック**（`## <見出し>` ＋ `- tags: …` ＋ `- provenance: …` ＋ `- scope-hypothesis: …` ＋ `- career-hypothesis: …` ＋ `- candidate-status: pending`）を `old_string` アンカーにして Edit する（provenance は一意キー。§6 ステップ2 と同じハザード回避）。旧スキーマ仮説は実ファイルの記法に合わせ、`- tags:` の代わりに `- type: …` 行を（`type`/`tags` とも無ければ当該行を省いて）アンカーに用いる。複数仮説を更新する場合は仮説ごとに個別アンカーで行う。
- 検証は仮説を**棄却する方向に厳しく**倒す。未検証の幻覚を配布経路に漏らさないことが原理2／復元不能性ゲートの要請（疑わしきは rejected）。両型とも合格仮説の流路は不変（`candidates.md → promote → Issue → 既存ワークフロー`。decision-record を learnings.md へ直送しない）。

## 4. Route 注記（tags ＋ scope ＋ career）

合格仮説の `tags` ・`scope-hypothesis` ・`career-hypothesis` を読み、Issue 本文へ**注記**する。**promote はルーティング不可知であり、知識型も両仮説も確定（裁定）せず運ぶだけ**である（注記は記述であって確証ではない）。career の決定表は持たない（決定表は distill 側＝distill-procedure.md へ移設済み）。`learnings.md` へは書かない。

### 知識型（tags）の注記

合格仮説の `tags`（`{behavior-diff, decision-record}` の非空部分集合）を Issue 本文へ注記する。promote は**ルーティング不可知のまま知識型を運搬する**——各タグに応じた下流の扱い（`behavior-diff` の強制化／`decision-record` の ADR・docs への翻訳）は確定せず、refine/review・集約点へ判断材料として渡す（ADR-20260701 D5）。いずれのタグも流路は同一（`candidates.md → promote → Issue → 既存ワークフロー`）であり、`decision-record` を learnings.md へ直送しない。

Issue 本文に含める知識型注記欄の書式:

```
## 知識型
- tags（distill 由来・未確証の扱い）: [behavior-diff, decision-record]（摩擦知＝実行可能な振る舞い差分／判断知＝選好・却下理由・目標表明・設計判断）
```

単一タグの場合は `[behavior-diff]（摩擦知＝実行可能な振る舞い差分）` または `[decision-record]（判断知＝選好・却下理由・目標表明・設計判断）` と記す。旧スキーマの単値 `type` / 欠落仮説は後方互換規約で `tags` へ写して（欠落は `[behavior-diff]` 既定）注記する。

### scope 仮説の注記

- `scope-hypothesis: universal` → パブリック/グローバル空間（全世界 × 全プロジェクト ＝ `learnings.md` 相当）へ向かう仮説。
- `scope-hypothesis: project-local` → 閉じた空間（チーム/プロジェクト）へ向かう仮説。

Issue 本文に含める scope 注記欄の書式:

```
## スコープ
- 適用範囲（仮説・未確証）: universal（パブリック/グローバル空間 = learnings.md 相当へ向かう仮説）
- 最終裁定は refine/review に委ねる。本タグは Distill の仮説形成観点に基づく仮説。
```

`project-local` の場合は「適用範囲」を `project-local（閉じた空間 = チーム/プロジェクト）` と記す。

### career 仮説の注記

`career-hypothesis`（`<career> / repo: <宛先 repo 仮説>` 形式）を、distill が出した値のまま**欠落・改変なく**注記する。promote は career を確定しない——昇格先キャリアと宛先 repo の裁定は集約点（取り込み Issue）が行う。

Issue 本文に含める career 注記欄の書式:

```
## キャリア
- 昇格先キャリア（仮説・未確証）: learnings.md
- 宛先 repo（仮説・未確証）: 配布元プラグイン repo（本リポジトリ）
- 最終裁定（career・宛先 repo の確定）は集約点（取り込み Issue）に委ねる。本タグは Distill の仮説形成観点に基づく仮説。
```

`career-hypothesis` の `<career>` 部を「昇格先キャリア」へ、`repo:` 部を「宛先 repo」へ転記する。`career-hypothesis` が欠落している仮説（旧スキーマで生成された古い仮説等）は、career 注記欄を省略し scope 注記のみ運ぶ（promote は仮説を生成しない＝ルーティング不可知のため、欠落を補完しない）。

## 5. 自動起票（疎結合・起票前ゲートなし）

検証通過仮説を Issue へ自動起票する。**起票前に人間承認ゲートを置かない**。

1. **本文の組み立て**: Issue 本文を組み立てる。最低限、仮説の見出し・本文（`behavior-diff` は規範差分、`decision-record` は4欄＝`decision`/`rejected-alternatives`/`rationale`/`context`、混在ゾーンは両本文を併記）と §4 の Route 注記欄（知識型 ＋ スコープ ＋ キャリア）を含める。検証段の所見（`behavior-diff` は「予測」「検証観点」、`decision-record` は「復元不能・有効・配布価値」の判定理由。混在ゾーンは両タグの所見）も本文へ記し、下流の refine/review が判断材料にできるようにする。
2. **本文の受け渡し**: 複数行本文を CLI 引数へ直接渡さず、Write で一時ファイル（例: `/tmp/promote-issue-<連番>.md`）へ書き出してから `--body-file` で渡す（CLAUDE.md 規約。シェルのクォート/ヒアドキュメント制約による破損を避ける）。
3. **起票コマンド**: `gh issue create --title "<見出し>" --body-file <一時ファイル>` で起票する。**dev-workflow スキル（create-issue 等）を呼び出さない**（疎結合。AC3）。ラベル付与等は任意。
4. **起票後**: 起票された Issue は既存ワークフロー（refine-issue / DoR / plan-issue / PR レビュー）= L2 ゲートに乗る。promote はここで承認を待たず次段（§6）へ進む。

> **疎結合の静的保証**: 起票経路は `Bash(gh issue create*)` のみ。SKILL.md の `allowed-tools` に dev-workflow スキル呼び出し経路（Skill ツール等）を含めないことで、疎結合を許可ツールの面から保証する（AC3）。

## 6. candidate-status 前進（起票成功後のみ）

起票が**成功した後にのみ**、起票した候補自身の `candidate-status` を `pending` から `promoted` へ更新する。`captures.md` は無状態の store であり、promote はこれを書き換えない（対象は `candidates.md` の当該エントリのみ）。

1. **対象の特定**: 起票が成功した候補（`candidates.md` の当該見出しブロック）を特定する。§1〜§5 で既に読み取り・検証済みの候補であり、追加の store 参照は不要。
2. **前進（一意アンカーで Edit）**: `- candidate-status: pending` 行は候補間で同一テキストのため、単独 Edit では `old_string` が一意マッチしない。対象候補の**一意な `- provenance:` 行を含む見出しブロック**（`## <見出し>` ＋ `- tags: …` ＋ `- provenance: …` ＋ `- scope-hypothesis: …` ＋ `- career-hypothesis: …` ＋ `- candidate-status: pending`）を `old_string` アンカーにして、`candidate-status` 値のみ `promoted` に変えた `new_string` で Edit する（`replace_all` は使わない。誤前進防止）。旧スキーマ仮説は §3 と同様、`- tags:` の代わりに `- type: …` 行をアンカーに用いる。複数候補を更新する場合は候補ごとに個別アンカーで行う。

**ディシジョンテーブル（candidate-status 前進）**:

| 検証通過 | 起票成功 | candidate-status 前進 |
|---|---|---|
| No | —（起票しない） | しない（`rejected` のまま） |
| Yes | No（失敗） | しない（`pending` のまま） |
| Yes | Yes | する（`pending → promoted`） |

- `candidate-status` は `pending` から `rejected` / `promoted` への一方向遷移であり、`rejected` / `promoted` はいずれも不可侵の終端（再走査対象から除外。ADR-20260720-2 決定1）。誤って `promoted` を先に付与すると起票失敗時の再実行判定を壊すため、起票成功を確認してから前進する順序を厳守する。

## 7. エラー・境界処理

| 状況 | promote の振る舞い |
|---|---|
| `git rev-parse` が失敗（git リポジトリ外等で project-id を解決できない） | 「project-id を解決できませんでした（確認: `git rev-parse --path-format=absolute --git-common-dir`）」と報告して終了。起票0・前進0 |
| `candidates.md` が存在しない／読めない | 「仮説がありません（確認パス: `~/.claude/projects/<project-id>/growth/candidates.md`）」と報告し正常終了。起票0・前進0 |
| `candidate-status: pending` が0件（全 `rejected` / `promoted`） | 「処理対象の仮説はありません」と報告して終了。起票0・前進0 |
| 全仮説が検証で不合格 | 「配布可能な仮説はありませんでした（不合格 N 件）」と報告して終了。全件 `candidate-status: rejected`。前進0 |
| `gh issue create` が失敗（認証・権限・ネットワーク等） | 一時ファイルを残しパスを示して再実行可能にする。`candidate-status` の前進は行わない（`pending` のまま） |
| 起票成功後、対象候補の一意アンカー（`- provenance:` 行を含む見出しブロック）が `candidates.md` で Edit マッチしない | 当該候補の `candidate-status` 前進をスキップし警告報告（起票済み Issue は維持） |

いずれも候補の `candidate-status` を不用意に前進させないことを保証する（起票成功した候補のみ `pending → promoted` へ前進する）。

## 関連

- [`promote-examples.md`](promote-examples.md) — 各段を検証する worked example（手順トレース用）
- `${CLAUDE_PLUGIN_ROOT}/references/personal-store-spec.md` — 入力源 仮説ファイルの形式・メタ欄スキーマ・provenance 規約、`candidate-status` 状態機械・パス解決手順
- `${CLAUDE_PLUGIN_ROOT}/references/learning-store-spec.md` — Route 注記が指す2空間モデル
- `${CLAUDE_PLUGIN_ROOT}/DESIGN.md` — 設計母艦（§3 Promote・§4 プラグイン構成・原理2・二段ゲート）
