# Promote 手順（検証→Route 注記→自動起票→status 反転）

promote スキルの各段の判定基準の詳細。SKILL.md の手順 overview から参照される単一出典。worked example は [`promote-examples.md`](promote-examples.md) を参照する。

## 1. 目的・責務境界

- **目的**: distill が `candidates.md` へ永続化した候補を仮説として検証し（原理2）、検証を通過したものだけを `gh` で Issue へ自動起票して既存ワークフローへ渡す。起票成功後に store の `status` を反転する。
- **責務境界**: promote が担うのは「検証 → Route 注記 → 自動起票 → status 反転」の4段。次は**行わない**:
  - 候補の生成・クラスタ化（distill の責務）
  - `learnings.md`（配布物）への物理書き込み（Distribute、Phase 2 の責務）。Route はタグの**注記**までで終端し、物理昇格はしない。
  - dev-workflow スキルの直接呼び出し（疎結合。起票は `gh` 直接のみ）
  - スコープ仮説タグの確証・真化（仮説のまま終点。最終裁定は人間 refine/review）
- **二段ゲートの位置**: promote の検証段（§3）が二段ゲートの「未検証を配布経路に乗せない」フィルタ。起票前に人間承認ゲートは置かない（§5）。L2 の規範的ゲート（承認/マルチエージェントレビュー）は起票後の既存ワークフロー（refine-issue / DoR / PR レビュー）が担う（DESIGN.md 二段ゲート）。

## 2. 候補読取（入力選択）

1. **候補ファイルパスの解決**: personal-store-spec.md「project-id とパスの解決手順」に従い `<project-id>` を解決し、候補ファイルパス `~/.claude/projects/<project-id>/growth/candidates.md` を組み立てる。
2. **候補ファイルの読取**: Read で読む。存在しない・読めない場合は §7 のエラー処理へ。
3. **エントリの抽出**: personal-store-spec.md「候補ファイル（candidates.md）」のスキーマ（`## <見出し>` ＋ `- provenance:` / `- scope-hypothesis:` / `- candidate-status:` メタ行 ＋ 本文）に従い行ベースで抽出する。
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

- 不合格候補は `candidates.md` の当該エントリの `candidate-status: pending` を `rejected` へ Edit で更新する。これにより次回 distill / promote 実行で同一候補が再提示・再評価されるループを断つ（personal-store-spec.md「冪等性」）。
- 検証は候補を**棄却する方向に厳しく**倒す。未検証の幻覚を配布経路に漏らさないことが原理2 の要請（疑わしきは rejected）。

## 4. Route 注記

合格候補の `scope-hypothesis` タグを読み、Issue 本文へ**仮説として注記**する。注記は記述であって確証ではない。`learnings.md` へは書かない。

- `scope-hypothesis: universal` → パブリック/グローバル空間（全世界 × 全プロジェクト ＝ `learnings.md` 相当）へ向かう候補。
- `scope-hypothesis: project-local` → 閉じた空間（チーム/プロジェクト）へ向かう候補。

Issue 本文に含める Route 注記欄の書式:

```
## スコープ仮説
- 適用範囲（仮説・未確証）: universal（パブリック/グローバル空間 = learnings.md 相当へ向かう候補）
- 最終裁定は refine/review に委ねる。本タグは Distill の蒸留観点に基づく仮説。
```

`project-local` の場合は「適用範囲」を `project-local（閉じた空間 = チーム/プロジェクト）` と記す。

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
2. **反転**: provenance が指す `captures.md` の各エントリの `- status: unprocessed` 行を `- status: promoted` へ Edit で書き換える。**複数 timestamp を持つ候補は全エントリを反転**する（クラスタを畳んだ候補の全由来観察を昇格済みにする）。
3. **候補側の更新**: 起票成功した候補の `candidate-status` を `promoted` へ更新してもよい（再走査からの除外。任意だが推奨）。

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
