# Promote 手順（検証→Route 注記→自動起票→status 反転）

promote スキルの各段の判定基準の詳細。SKILL.md の手順 overview から参照される単一出典。worked example は [`promote-examples.md`](promote-examples.md) を参照する。

## 1. 目的・責務境界

- **目的**: distill が `candidates.md` へ永続化した候補を仮説として検証し（原理2）、検証を通過したものだけを `gh` で Issue へ自動起票して既存ワークフローへ渡す。起票成功後に store の `status` を反転する。
- **責務境界**: promote が担うのは「検証 → Route 注記 → 自動起票 → status 反転」の4段。**promote はルーティング不可知である**——career（昇格先キャリア）も scope（適用範囲）も**確定（裁定）しない**。distill が `candidates.md` に出した `scope-hypothesis` / `career-hypothesis` の両仮説を、昇格 Issue 本文へ**注記として運ぶのみ**（ADR-20260628-2）。次は**行わない**:
  - 候補の生成・クラスタ化（distill の責務）
  - career の Route 判定・決定表評価・キャリアラベル付与（決定表は distill 側＝distill-procedure.md へ移設済み。promote は決定表を持たない）
  - `learnings.md`（配布物）への物理書き込み（Distribute、Phase 2 の責務）。Route はタグの**注記**までで終端し、物理昇格はしない。
  - dev-workflow スキルの直接呼び出し（疎結合。起票は `gh` 直接のみ）
  - scope / career 仮説タグの確証・真化（仮説のまま終点。scope の最終裁定は人間 refine/review、career の確定は集約点＝取り込み Issue）
- **二段ゲートの位置**: promote の検証段（§3）が二段ゲートの「未検証を配布経路に乗せない」フィルタ。起票前に人間承認ゲートは置かない（§5）。L2 の規範的ゲート（承認/マルチエージェントレビュー）は起票後の既存ワークフロー（refine-issue / DoR / PR レビュー）が担う（DESIGN.md 二段ゲート）。

## 2. 候補読取（入力選択）

1. **候補ファイルパスの解決**: personal-store-spec.md「project-id とパスの解決手順」に従い `<project-id>` を解決し、候補ファイルパス `~/.claude/projects/<project-id>/growth/candidates.md` を組み立てる。
2. **候補ファイルの読取**: Read で読む。存在しない・読めない場合は §7 のエラー処理へ。
3. **エントリの抽出**: personal-store-spec.md「候補ファイル（candidates.md）」のスキーマ（`## <見出し>` ＋ `- provenance:` / `- scope-hypothesis:` / `- career-hypothesis:` / `- candidate-status:` メタ行 ＋ 本文）に従い行ベースで抽出する。
4. **対象選択**: `candidate-status: pending` のエントリのみを処理対象に選ぶ。`rejected`（過去に検証で棄却）・`promoted`（昇格済み）は**無視**する。`pending` が0件なら §7 のエラー処理へ。

## 3. 検証（原理2）

各候補を**仮説**とみなし、配布経路（Issue）へ乗せる価値があるかを評価する。検証は promote 自身が行う自己検証（Phase 1 の最小形。独立検証エージェント化は Phase 4）。

各候補について以下を添えて評価する:

- **予測**: この規範が次にどんな状況で効くか（適用される具体場面）。予測が立てられない＝検証も反証もできない。
- **検証観点**: どの条件で反証されうるか（反例の形）。反証可能性が無い主張は仮説たりえない。

**合否境界**:

| 判定 | 条件 | 後段の扱い |
|---|---|---|
| **合格** | 予測（効く場面）と反証条件の両方が立ち、規範として実行可能な振る舞い差分を述べている | 後段（Route 注記 → 起票）へ進める |
| **不合格** | 反証可能性を欠く（反例が原理的に作れない）／予測力を欠く（いつ効くか述べられない）／一回限りの事象で再現性が読めない | 起票段へ**進めない**。`candidate-status` を `rejected` へ更新（§6 の冪等性）。`status` 反転もしない |

- 不合格候補は `candidates.md` の当該エントリの `candidate-status: pending` を `rejected` へ Edit で更新する。これにより次回 distill / promote 実行で同一候補が再提示・再評価されるループを断つ（personal-store-spec.md「冪等性」）。`- candidate-status: pending` 行は候補間で同一テキストのため、対象候補の**一意な `- provenance:` 行を含む見出しブロック**（`## <見出し>` ＋ `- provenance: …` ＋ `- scope-hypothesis: …` ＋ `- career-hypothesis: …` ＋ `- candidate-status: pending`）を `old_string` アンカーにして Edit する（provenance は一意キー。§6 ステップ2 と同じハザード回避）。複数候補を更新する場合は候補ごとに個別アンカーで行う。
- 検証は候補を**棄却する方向に厳しく**倒す。未検証の幻覚を配布経路に漏らさないことが原理2 の要請（疑わしきは rejected）。

## 4. Route 注記（scope ＋ career 両仮説）

合格候補の `scope-hypothesis` と `career-hypothesis` の両タグを読み、Issue 本文へ**仮説として注記**する。**promote はルーティング不可知であり、両仮説を確定（裁定）せず運ぶだけ**である（注記は記述であって確証ではない）。career の決定表は持たない（決定表は distill 側＝distill-procedure.md へ移設済み）。`learnings.md` へは書かない。

### scope 仮説の注記

- `scope-hypothesis: universal` → パブリック/グローバル空間（全世界 × 全プロジェクト ＝ `learnings.md` 相当）へ向かう候補。
- `scope-hypothesis: project-local` → 閉じた空間（チーム/プロジェクト）へ向かう候補。

Issue 本文に含める scope 注記欄の書式:

```
## スコープ仮説
- 適用範囲（仮説・未確証）: universal（パブリック/グローバル空間 = learnings.md 相当へ向かう候補）
- 最終裁定は refine/review に委ねる。本タグは Distill の蒸留観点に基づく仮説。
```

`project-local` の場合は「適用範囲」を `project-local（閉じた空間 = チーム/プロジェクト）` と記す。

### career 仮説の注記

`career-hypothesis`（`<career> / repo: <宛先 repo 仮説>` 形式）を、distill が出した値のまま**欠落・改変なく**注記する。promote は career を確定しない——昇格先キャリアと宛先 repo の裁定は集約点（取り込み Issue）が行う。

Issue 本文に含める career 注記欄の書式:

```
## キャリア仮説
- 昇格先キャリア（仮説・未確証）: learnings.md
- 宛先 repo（仮説・未確証）: 配布元プラグイン repo（本リポジトリ）
- 最終裁定（career・宛先 repo の確定）は集約点（取り込み Issue）に委ねる。本タグは Distill の蒸留観点に基づく仮説。
```

`career-hypothesis` の `<career>` 部を「昇格先キャリア」へ、`repo:` 部を「宛先 repo」へ転記する。`career-hypothesis` が欠落している候補（旧スキーマで生成された古い候補等）は、career 注記欄を省略し scope 注記のみ運ぶ（promote は仮説を生成しない＝ルーティング不可知のため、欠落を補完しない）。

## 5. 自動起票（疎結合・起票前ゲートなし）

検証通過候補を Issue へ自動起票する。**起票前に人間承認ゲートを置かない**。

1. **本文の組み立て**: Issue 本文を組み立てる。最低限、候補の規範（見出し・本文）と §4 の Route 注記欄を含める。検証段の「予測」「検証観点」も本文へ記し、下流の refine/review が判断材料にできるようにする。
2. **本文の受け渡し**: 複数行本文を CLI 引数へ直接渡さず、Write で一時ファイル（例: `/tmp/promote-issue-<連番>.md`）へ書き出してから `--body-file` で渡す（CLAUDE.md 規約。シェルのクォート/ヒアドキュメント制約による破損を避ける）。
3. **起票コマンド**: `gh issue create --title "<見出し>" --body-file <一時ファイル>` で起票する。**dev-workflow スキル（create-issue 等）を呼び出さない**（疎結合。AC3）。ラベル付与等は任意。
4. **起票後**: 起票された Issue は既存ワークフロー（refine-issue / DoR / plan-issue / PR レビュー）= L2 ゲートに乗る。promote はここで承認を待たず次段（§6）へ進む。

> **疎結合の静的保証**: 起票経路は `Bash(gh issue create*)` のみ。SKILL.md の `allowed-tools` に dev-workflow スキル呼び出し経路（Skill ツール等）を含めないことで、疎結合を許可ツールの面から保証する（AC3）。

## 6. status 反転（起票成功後のみ）

起票が**成功した後にのみ**、候補の `provenance` が指す store エントリの `status` を反転する。

1. **対象の特定**: 合格・起票成功した候補の `provenance`（`captures.md` の `## <timestamp>` 群）を読む。
2. **反転（一意アンカーで Edit）**: `captures.md` の各エントリの `- status: unprocessed` 行は**エントリ間で同一テキスト**のため、status 行単独では Edit の `old_string` が一意マッチしない（未処理エントリが複数残るのは distill バッチ直後の常態）。status 行だけを Edit すると一意マッチ失敗で**失敗**するか、`replace_all` を使うと provenance に含まれない無関係エントリまで**誤反転**する。これを避けるため、対象エントリの**一意な `## <timestamp>` 見出し行から `- status: unprocessed` 行までの連続ブロック**（見出し＋`signal`/`session`/`status` メタ行。timestamp 見出しはエントリ一意）を `old_string` に含め、そのブロックの `status` 値のみ `promoted` に変えた `new_string` で Edit する。`replace_all` は使わない。**複数 timestamp を持つ候補は、各 timestamp について個別に（それぞれ固有の見出しブロックをアンカーに）反転する**。
   - 代替として、distill の upsert（§ distill-procedure §6）と対称に「Read で `captures.md` 全文取得 → 対象エントリの status のみ書き換え → Write で全文書き出し」で行ってもよい（他エントリを保持すればインライン性は保たれる）。状態反転のパターンを両スキルで揃えたい場合はこちらを採る。
3. **候補側の更新**: 起票成功した候補の `candidate-status` を `promoted` へ更新してもよい（再走査からの除外。任意だが推奨）。更新する場合も §3 と同様、候補の**一意な `- provenance:` 行を含む見出しブロック**をアンカーに Edit する（`- candidate-status:` 行も候補間で同一テキストのため、単独 Edit は一意マッチしない）。

**ディシジョンテーブル（status 反転）**:

| 検証通過 | 起票成功 | status 反転 |
|---|---|---|
| No | —（起票しない） | しない |
| Yes | No（失敗） | しない |
| Yes | Yes | する（provenance が指す全エントリ） |

- 誤反転は store の状態機械（監査履歴）を汚すため、起票成功を確認してから反転する順序を厳守する。
- provenance が指す store エントリが見つからない場合は、当該エントリの反転をスキップして警告報告する（起票済み Issue は維持する。§7）。

## 7. エラー・境界処理

| 状況 | promote の振る舞い |
|---|---|
| `git rev-parse` が失敗（git リポジトリ外等で project-id を解決できない） | 「project-id を解決できませんでした（確認: `git rev-parse --path-format=absolute --git-common-dir`）」と報告して終了。起票0・反転0 |
| `candidates.md` が存在しない／読めない | 「候補がありません（確認パス: `~/.claude/projects/<project-id>/growth/candidates.md`）」と報告し正常終了。起票0・反転0 |
| `candidate-status: pending` が0件（全 `rejected` / `promoted`） | 「処理対象の候補はありません」と報告して終了。起票0・反転0 |
| 全候補が検証で不合格 | 「配布可能な候補はありませんでした（不合格 N 件）」と報告して終了。全件 `candidate-status: rejected`。反転0 |
| `gh issue create` が失敗（認証・権限・ネットワーク等） | 一時ファイルを残しパスを示して再実行可能にする。`status` 反転は行わない（由来エントリは `unprocessed` のまま） |
| provenance が指す store エントリが見つからない | 当該エントリの反転をスキップし警告報告（起票済み Issue は維持） |

いずれも由来 store エントリの `status` を不用意に反転しないことを保証する（起票成功した候補の provenance のみ反転）。

## 関連

- [`promote-examples.md`](promote-examples.md) — 各段を検証する worked example（手順トレース用）
- `${CLAUDE_PLUGIN_ROOT}/references/personal-store-spec.md` — 入力源 候補ファイルの形式・メタ欄スキーマ・provenance 規約、store の `status` 状態機械・パス解決手順
- `${CLAUDE_PLUGIN_ROOT}/references/learning-store-spec.md` — Route 注記が指す2空間モデル
- `${CLAUDE_PLUGIN_ROOT}/DESIGN.md` — 設計母艦（§3 Promote・§4 プラグイン構成・原理2・二段ゲート）
