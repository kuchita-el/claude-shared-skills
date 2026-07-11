---
description: promote は distill が candidates.md に永続化した仮説を type 適応で検証し（behavior-diff=予測・反証／decision-record=復元不能性）、通過仮説のみ gh で Issue へ自動起票し既存ワークフロー（refine/DoR/PR）へ疎結合に渡す。ルーティング不可知で scope/career 仮説は本文注記で運ぶのみ。起票前ゲートなし、起票成功後に store の status を unprocessed→promoted へ反転する。learnings.md へは書かない。共有経路へ昇格させたいとき明示起動する（Phase 1）。
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(gh issue create*)
  - Bash(git rev-parse *)
---

# promote

distill が仮説ファイル（`candidates.md`）へ永続化した仮説を検証し、検証を通過したものだけを `gh` で Issue へ自動起票して既存ワークフローへ渡す。起票成功後に store（`captures.md`）の `status` を反転する。学習ループ（`[Capture] → [Distill+Route] → [Promote] → [Distribute]`）の Promote 段。

## 目的・原則

- **目的**: 未検証の仮説を検証し（原理2＝気付きは仮説、検証されるまで配布しない）、共有に値するものだけを Issue という揉む場・配布経路へ投入する。検証段が未検証仮説を配布経路に乗せないフィルタになる。
- **疎結合**: 起票は `gh` での直接起票（`gh issue create --body-file`）で行い、**dev-workflow スキル（create-issue 等）を直接呼び出さない**。起票された Issue は既存の refine-issue / DoR / plan-issue / implementation / PR レビューへ自然に乗る（DESIGN.md §4）。
- **起票前ゲートなし（自動起票）**: 検証通過仮説は人間承認ゲートを挟まず自動起票する。起票前ゲートは自動化を阻害し、起票後の既存ワークフローの L2 承認（refine/DoR/PR レビュー）と二重になるため置かない。二段ゲートの L2 は起票後の既存ワークフローが担う。
- **ルーティング不可知（scope/career 仮説のまま終点）**: 仮説の `scope-hypothesis` ＋ `career-hypothesis` タグ（いずれも distill が付与）を Issue 本文へ**仮説として注記**するだけで、確証も `learnings.md` への物理書き込みもしない。promote は career（昇格先キャリア・宛先 repo）も scope（適用範囲）も確定しない。scope の最終裁定は人間 refine/review（横断解析は Phase 3 の支援どまり）、career の確定（裁定）は集約点（取り込み Issue）が担う（ADR-20260628-2）。career の決定表は持たない（distill 側へ移設済み）。
- **`status` 反転の主体**: 起票成功後にのみ provenance 経由で `captures.md` の `status` を `unprocessed → promoted` へ反転する（personal-store-spec.md「状態管理」で確定）。起票失敗・仮説棄却・ゲート拒否時は反転しない。
- **Phase 1 スコープ**: 検証は promote 自身の自己検証（最小）。独立検証エージェント化・マルチエージェントレビュー化は後続 Phase（Phase 4）。

## 手順

判定基準の詳細は `${CLAUDE_SKILL_DIR}/references/promote-procedure.md` を、worked example は `${CLAUDE_SKILL_DIR}/references/promote-examples.md` を参照する（手順本文を SKILL.md に二重化しない）。

1. **仮説読取（AC2 消費）**: personal-store-spec.md「project-id とパスの解決手順」で仮説ファイルパス（`~/.claude/projects/<project-id>/growth/candidates.md`）を組み立て、Read で読む。`candidate-status: pending` のエントリのみを対象にする（`rejected` / `promoted` は無視）。未存在・0件は procedure §7 のエラー処理へ。
2. **検証（AC1・原理2／型適応）**: 各仮説を評価する。仮説の `tags` の各要素で検証軸を分岐する（ADR-20260701 D5）——`behavior-diff`（摩擦知）は「予測（次にどんな状況で効くか）」と「検証観点（どの条件で反証されうるか）」（原理2、現行どおり）、`decision-record`（判断知）は「復元不能で・まだ有効で・配布価値があるか」（反証条件＝既にリポに記録済み＝復元可能／後に覆された／carry-forward 価値のない一回性）。混在ゾーン（両タグ）は両検証を受け、全タグ合格の仮説のみ後段へ。いずれかのタグが不合格なら仮説全体の `candidate-status` を `rejected` へ更新し後段（起票）へ進めない（procedure §3）。
3. **Route 注記（AC2 消費・ルーティング不可知）**: 合格仮説の `tags` ＋ `scope-hypothesis` ＋ `career-hypothesis` を読み、仮説の知識型・向かう空間（`universal`＝パブリック/グローバル空間＝`learnings.md` 相当 / `project-local`＝閉じた空間）・昇格先キャリア＋宛先 repo を Issue 本文へ**仮説として注記**する（`## 知識型` ＋ `## スコープ` ＋ `## キャリア` 欄）。promote はルーティング不可知のまま知識型を運搬する（知識型・scope・career のいずれも確定しない。career の裁定は集約点）。`learnings.md` には書かない（procedure §4）。
4. **自動起票（AC3・AC4）**: Issue 本文を Write で一時ファイルへ書き出し、`gh issue create --body-file` で起票する。起票前に人間承認ゲートを置かない。dev-workflow スキルを呼ばない（疎結合）。本文構造は procedure §5。
5. **`status` 反転（AC6）**: 起票が**成功した後にのみ**、仮説の `provenance` が指す `captures.md` の各エントリの `status` を `unprocessed → promoted` へ反転する。status 行はエントリ間で同一テキストのため、**一意な `## <timestamp>` 見出しブロックをアンカーに**個別 Edit する（`replace_all` 不可。誤反転防止）。複数 timestamp を持つ仮説は全エントリを反転する。起票失敗時は反転しない（procedure §6）。

## 完了報告

検証件数・合格/不合格件数・起票した Issue（番号/URL）・反転した store エントリ数・仮説ファイルパスを報告する。

```
仮説3件を検証しました。
- 不合格: 1件（反証可能性・予測力を欠く → candidate-status: rejected）
- 起票: 2件（#401, #402）
- status 反転: store エントリ3件（unprocessed → promoted）
candidates: ~/.claude/projects/-home-user-myproject/growth/candidates.md
```

検証で棄却した仮説・起票に失敗した仮説の由来 store エントリは `unprocessed` のまま残り、再実行可能な状態を保つ。

## 関連

- `${CLAUDE_SKILL_DIR}/references/promote-procedure.md` — 各段の判定基準（検証の合否境界・Route 注記書式・起票コマンド・status 反転手順・エラー処理）の単一出典
- `${CLAUDE_SKILL_DIR}/references/promote-examples.md` — worked example（behavior-diff の検証通過→起票→反転／検証棄却／起票失敗時の status 非反転／複数 provenance 反転／decision-record の復元不能性検証 通過・棄却）
- `${CLAUDE_PLUGIN_ROOT}/references/personal-store-spec.md` — 入力源 仮説ファイル（`candidates.md`）の形式・メタ欄スキーマ・provenance 規約、store（`captures.md`）の `status` 状態機械・パス解決手順
- `${CLAUDE_PLUGIN_ROOT}/references/learning-store-spec.md` — Route 注記が指す2空間モデル（universal/project-local＝パブリック/閉じた空間）
- `${CLAUDE_PLUGIN_ROOT}/DESIGN.md` — 設計母艦（§3 Promote・§4 プラグイン構成・原理2・二段ゲート）
