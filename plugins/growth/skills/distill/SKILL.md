---
description: distill は個人ローカル store（captures.md）の status:unprocessed の生観察をバッチで蒸留し、同一トリガー×振る舞い差分でクラスタ化・重複排除して候補へ整形する。各候補にスコープ仮説タグ・キャリア仮説タグ（昇格先＋宛先 repo。Route 統合）と provenance を付与し candidates.md へ upsert 永続化する。空・純記述・実行不能な観察は棄却する。検証・配布・status 反転・learnings.md への書き込みは行わない。蓄積した観察を蒸留したいとき、Capture と非同期に明示起動する（Phase 1）。
allowed-tools:
  - Read
  - Write
  - Bash(git rev-parse *)
---

# distill

個人ローカル store の未処理の生観察をクラスタ化・重複排除し、実行可能な振る舞い差分（規範）の候補へ変換する。各候補にスコープ仮説タグ・キャリア仮説タグ（Route 統合）と provenance を付与し候補ファイル（`candidates.md`）へ永続化する。学習ループ（`[Capture] → [Distill+Route] → [Promote] → [Distribute]`）の Distill 段（Route 統合）。

## 目的・原則

- **目的**: 蓄積した生観察を蒸留し、「次回どう違う行動を取るか」という実行可能な差分の**候補**にする（DESIGN.md §3 Distill・原理1）。実行不能な内省はここで捨て、肥大を下流へ送らない（原理5）。
- **Capture と非同期**: distill は capture（Capture）と別タイミングで明示起動するバッチ処理。store に溜まった `unprocessed` を一括で蒸留する（例: 1日分）。セッション終端には紐づかない。
- **Route 統合**: 各候補に**スコープ仮説タグ**（`scope-hypothesis`: `project-local` / `universal`）と**キャリア仮説タグ**（`career-hypothesis`: 昇格先キャリア＋宛先 repo 仮説）の直交2軸を付与する（蒸留観点で判定）。scope は2空間（learning-store-spec.md「2空間モデル」）のいずれへ、career は4分類（決定表は distill-procedure.md）のどの成果物・repo へ向かう候補かを示す。いずれも**仮説**であり確証しない。scope の最終裁定は人間 refine/review、career の確定（裁定）は集約点（取り込み Issue）が担う。promote はルーティング確定せず本文注記で運ぶのみ（ADR-20260628-2）。
- **候補永続化まで（責務境界）**: 各候補にスコープ仮説タグ・キャリア仮説タグと provenance（クラスタを構成した観察の `## <timestamp>` 群）を付与し、候補ファイル（`candidates.md`）へ provenance キーで upsert 永続化するまでで責務を終える。検証・Promote（起票）・配布・`learnings.md` への書き込み・store の `status` 反転は**行わない**（二段ゲート。検証→起票→status 反転は promote の責務）。candidates.md（第3の個人ローカル成果物）へは書き込むが、store（`captures.md`）と `learnings.md` には書き込まない。
- **Phase 1 スコープ**: 入力源は正準パス `captures.md` のみ。出力先は `candidates.md`。明示起動のみ。

## 手順

判定基準の詳細は `${CLAUDE_SKILL_DIR}/references/distill-procedure.md` を、サンプル入力と期待結果は `${CLAUDE_SKILL_DIR}/references/distill-examples.md` を参照する（手順本文を SKILL.md に二重化しない）。

1. **入力選択（AC1）**: personal-store-spec.md「project-id とパスの解決手順」で store パス（`~/.claude/projects/<project-id>/growth/captures.md`）を組み立て、Read で読む。「パース規約」に従いエントリを抽出し、`status: unprocessed` のみを対象にする（`promoted` は無視）。store 未存在・0件は手順 §7 のエラー処理へ。
2. **棄却（AC4）**: 空・純記述的・実行不能な観察を候補化対象から外す。「トリガー（どの状況で）」と「振る舞い差分（次回どう違う行動を取るか）」の両方が読み取れる観察のみ合格。中間的で差分が一意に読めないものは棄却側に倒す（procedure §3・原理1・learning-store-spec.md「記法ルール」）。
3. **クラスタ化・重複排除（AC2）**: 合格観察から推論したトリガー×振る舞い差分が一致するものを1候補へ集約する。表層の語彙差は無視し、`signal` の一致だけでは畳まない（procedure §4）。
4. **候補整形＋メタ付与（AC3・Route 統合）**: 各クラスタを `## <規範の短い見出し>` ＋ 規範差分の具体・理由の本文へ整形し、メタ欄として `provenance`（畳んだ観察の `## <timestamp>` 群）・`scope-hypothesis`（`project-local` / `universal` の仮説タグ）・`career-hypothesis`（昇格先キャリア＋宛先 repo 仮説。`<career> / repo: <宛先>` 形式。4分類の決定表は procedure §5「career-hypothesis の判定（決定表）」）・`candidate-status`（`pending`）を付与する（procedure §5・personal-store-spec.md「候補ファイル（candidates.md）」）。
5. **永続化＋提示**: 整形した候補を `candidates.md`（パス解決は personal-store-spec.md 共通手順）へ provenance キーで **upsert** 永続化し、候補リストをチャットにも提示して終了する。`captures.md`・`learnings.md` は変更しない。検証・Promote（起票）・配布・status 反転は行わない（promote の責務）。

## 完了報告

入力した `unprocessed` 件数・棄却件数・採用候補数・store パス・候補ファイルパスを報告する。

```
未処理4件を蒸留しました。
- 棄却: 1件（純記述・実行不能）
- 採用候補: 2件（candidates.md へ upsert）
store: ~/.claude/projects/-home-user-myproject/growth/captures.md
candidates: ~/.claude/projects/-home-user-myproject/growth/candidates.md
```

候補は `candidates.md` へ永続化し、チャットにも提示する。検証・起票（`gh`）・`status` 反転・`learnings.md` への追加は promote の責務であり、本スキルは行わない。

## 関連

- `${CLAUDE_SKILL_DIR}/references/distill-procedure.md` — 蒸留判定基準の詳細（入力選択・棄却・クラスタ化・候補整形・責務境界・エラー処理）
- `${CLAUDE_SKILL_DIR}/references/distill-examples.md` — AC2/AC4 のサンプル入力＋期待結果（手順トレース用）
- `${CLAUDE_PLUGIN_ROOT}/references/personal-store-spec.md` — 入力源 store の形式・パース規約・パス解決手順・`status` 状態管理、および**出力先 候補ファイル（`candidates.md`）の形式・メタ欄スキーマ・provenance 規約・upsert 方式**
- `${CLAUDE_PLUGIN_ROOT}/references/learning-store-spec.md` — 候補が将来昇格する先の1欄スキーマ・記法ルール・記法例（候補見出し・本文が整合すべき規範形）・2空間モデル（scope-hypothesis の値域の裏付け）
- `${CLAUDE_PLUGIN_ROOT}/DESIGN.md` — 設計母艦（§3 Distill・§4 プラグイン構成・原理1・5・二段ゲート）
