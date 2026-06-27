---
description: distill は個人ローカル store（captures.md）に溜まった status:unprocessed の生観察をバッチで蒸留し、同一トリガー×振る舞い差分でクラスタ化・重複排除して学び置き場（learnings.md）の1欄形式の候補へ整形する。空・純記述・実行不能な観察は棄却する。検証・配布・status 反転は行わず候補化までに責務を限定する。蓄積した観察を蒸留して学び候補にしたいとき、Capture と非同期に明示起動する（Phase 1）。
allowed-tools:
  - Read
  - Bash(git rev-parse *)
---

# distill（Distill）

個人ローカル store の未処理の生観察をクラスタ化・重複排除し、実行可能な振る舞い差分（規範）の候補へ変換する。学習ループ（`[Capture] → [Distill] → [Route] → [Promote] → [Distribute]`）の2段目。

## 目的・原則

- **目的**: 蓄積した生観察を蒸留し、「次回どう違う行動を取るか」という実行可能な差分の**候補**にする（DESIGN.md §3 Distill・原理1）。実行不能な内省はここで捨て、肥大を下流へ送らない（原理5）。
- **Capture と非同期**: distill は capture（Capture）と別タイミングで明示起動するバッチ処理。store に溜まった `unprocessed` を一括で蒸留する（例: 1日分）。セッション終端には紐づかない。
- **候補化止まり（責務境界）**: 候補をチャット提示するまでで責務を終える。検証・Route・Promote・配布・`learnings.md` への書き込み・store の `status` 反転は行わない（二段ゲート。昇格は別 Issue・レビュー必須）。store と `learnings.md` のいずれにも書き込まない。
- **Phase 1 スコープ**: 入力源は正準パス `captures.md` のみ。明示起動のみ。

## 手順

判定基準の詳細は `${CLAUDE_SKILL_DIR}/references/distill-procedure.md` を、サンプル入力と期待結果は `${CLAUDE_SKILL_DIR}/references/distill-examples.md` を参照する（手順本文を SKILL.md に二重化しない）。

1. **入力選択（AC1）**: personal-store-spec.md「project-id とパスの解決手順」で store パス（`~/.claude/projects/<project-id>/growth/captures.md`）を組み立て、Read で読む。「パース規約」に従いエントリを抽出し、`status: unprocessed` のみを対象にする（`promoted` は無視）。store 未存在・0件は手順 §7 のエラー処理へ。
2. **棄却（AC4）**: 空・純記述的・実行不能な観察を候補化対象から外す。「トリガー（どの状況で）」と「振る舞い差分（次回どう違う行動を取るか）」の両方が読み取れる観察のみ合格。中間的で差分が一意に読めないものは棄却側に倒す（procedure §3・原理1・learning-store-spec.md「記法ルール」）。
3. **クラスタ化・重複排除（AC2）**: 合格観察から推論したトリガー×振る舞い差分が一致するものを1候補へ集約する。表層の語彙差は無視し、`signal` の一致だけでは畳まない（procedure §4）。
4. **候補整形（AC3）**: 各クラスタを `learnings.md` の1欄形式（`## <規範の短い見出し>` ＋ 規範差分の具体・理由の本文、メタ欄なし）へ整形する（procedure §5・learning-store-spec.md「記法例」）。
5. **提示（AC5）**: 候補リストをチャットに提示して終了する。store・`learnings.md` は変更しない。検証・Route・Promote・配布・status 反転は行わない。

## 完了報告

入力した `unprocessed` 件数・棄却件数・採用候補数・store パスを報告する。

```
未処理4件を蒸留しました。
- 棄却: 1件（純記述・実行不能）
- 採用候補: 2件
store: ~/.claude/projects/-home-user-myproject/growth/captures.md
```

候補は提示のみ。昇格（`learnings.md` への追加・`status` 反転）は別 Issue の責務であり、本スキルは行わない。

## 関連

- `${CLAUDE_SKILL_DIR}/references/distill-procedure.md` — 蒸留判定基準の詳細（入力選択・棄却・クラスタ化・候補整形・責務境界・エラー処理）
- `${CLAUDE_SKILL_DIR}/references/distill-examples.md` — AC2/AC4 のサンプル入力＋期待結果（手順トレース用）
- `${CLAUDE_PLUGIN_ROOT}/references/personal-store-spec.md` — 入力源 store の形式・パース規約・パス解決手順・`status` 状態管理
- `${CLAUDE_PLUGIN_ROOT}/references/learning-store-spec.md` — 候補の出力先 1欄スキーマ・記法ルール・記法例
- `${CLAUDE_PLUGIN_ROOT}/DESIGN.md` — 設計母艦（§3 Distill・§4 プラグイン構成・原理1・5・二段ゲート）
