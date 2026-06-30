---
description: distill は個人ローカル store（captures.md）の status:unprocessed の生観察をバッチ蒸留し、知識型で出力形を2分する（摩擦知→behavior-diff、判断知→decision-record）。出所で分類・重み付けし、各候補に scope/career 仮説タグと provenance を付与し candidates.md へ upsert する。既存ルール台帳と突合し既知ルール再発を知見化する（behavior-diff のみ）。検証・status 反転は行わない。Capture と非同期に明示起動する（Phase 1）。
allowed-tools:
  - Read
  - Write
  - Bash(git rev-parse *)
---

# distill

個人ローカル store の未処理の生観察を蒸留し、知識型に応じた候補（摩擦知→`behavior-diff` / 判断知→`decision-record`）へ変換する。各候補にスコープ仮説タグ・キャリア仮説タグ（Route 統合）と provenance を付与し候補ファイル（`candidates.md`）へ永続化する。学習ループ（`[Capture] → [Distill+Route] → [Promote] → [Distribute]`）の Distill 段（Route 統合）。

## 目的・原則

- **目的**: 蓄積した生観察を蒸留し、知識型に応じた**候補**にする（DESIGN.md §3 Distill・原理1）。実行不能な内省はここで捨て、肥大を下流へ送らない（原理5）。
- **出力形の2系統（ADR-20260701 D4）**: 候補の知識型で出力形（`type`）を分岐する。**摩擦知 → `behavior-diff`**（signal が摩擦群。規範差分＋理由。§3 棄却・§7 台帳突合 / N 再発を従来どおり適用、挙動不変）。**判断知 → `decision-record`**（signal が判断群＝選好/却下理由/目標表明/設計判断。`decision`/`rejected-alternatives`/`rationale`/`context` の4欄。原理1 の例外口として behavior-diff 要求と N 再発カウントを免除し、一回性の設計境界を決定の記録として残す）。知識型の導出規則・値域・スキーマ正準は personal-store-spec.md「シグナル種別」「type 別スキーマ」を単一出典とし二重定義しない。
- **Capture と非同期**: distill は capture（Capture）と別タイミングで明示起動するバッチ処理。store に溜まった `unprocessed` を一括で蒸留する（例: 1日分）。セッション終端には紐づかない。
- **Route 統合**: 各候補に**スコープ仮説タグ**（`scope-hypothesis`: `project-local` / `universal`）と**キャリア仮説タグ**（`career-hypothesis`: 昇格先キャリア＋宛先 repo 仮説）の直交2軸を付与する（蒸留観点で判定）。scope は2空間（learning-store-spec.md「2空間モデル」）のいずれへ、career は4分類（決定表は distill-procedure.md）のどの成果物・repo へ向かう候補かを示す。いずれも**仮説**であり確証しない。scope の最終裁定は人間 refine/review、career の確定（裁定）は集約点（取り込み Issue）が担う。promote はルーティング確定せず本文注記で運ぶのみ（ADR-20260628-2）。
- **分類・重み付け・台帳突合（#417）**: 各観察を出所（`origin`）を一次キーに環境摩擦（`tool-result`）と判断誤り（`user-utterance`）へ決定的に分類し、判断誤りを高優先・環境摩擦を低優先で出力順位に反映する（内容で origin ラベルを反転しない＝軽い判定。分類結果は candidates.md に永続化せず provenance から再導出する）。`behavior-diff` 候補を scope に対応する既存ルール台帳（**祖先を含む**）と突合し、既知ルールに一致する観察は「ルール追加候補」にせず「既存ルール X が N 回再発（機能していない）」知見へ変換する（N は provenance 件数から導出。`decision-record` は N 再発免除＝突合・カウント対象外）。再発知見も別ファイル・別ルートを作らず candidates.md 上で他候補と**同一形式・同一ライフサイクル**（promote→Issue）で扱う。突合は「既知/novel」までで、予測力・配布価値の検証（promote の責務）には踏み込まない（ADR-20260629）。
- **候補永続化まで（責務境界）**: 各候補にスコープ仮説タグ・キャリア仮説タグと provenance（クラスタを構成した観察の `## <timestamp>` 群）を付与し、候補ファイル（`candidates.md`）へ provenance キーで upsert 永続化するまでで責務を終える。検証・Promote（起票）・配布・`learnings.md` への書き込み・store の `status` 反転は**行わない**（二段ゲート。検証→起票→status 反転は promote の責務）。candidates.md（第3の個人ローカル成果物）へは書き込むが、store（`captures.md`）・`learnings.md`・台帳（参照源）には書き込まない。
- **入力契約（Phase 1 スコープ）**: 入力は**処理源**と**参照源**の2種（ADR-20260629）。処理源は正準パス `captures.md`（`unprocessed`）のみで、候補化の work queue。参照源は既存ルール台帳（`CLAUDE.md` 2層・`learnings.md`・`candidates.md` 自身）で、**読み取り専用**の突合用（候補は生成しない。台帳は書き換えない）。出力先は `candidates.md`。明示起動のみ。

## 手順

判定基準の詳細は `${CLAUDE_SKILL_DIR}/references/distill-procedure.md` を、サンプル入力と期待結果は `${CLAUDE_SKILL_DIR}/references/distill-examples.md` を参照する（手順本文を SKILL.md に二重化しない）。

1. **入力選択（処理源＋参照源）**: 処理源は personal-store-spec.md「project-id とパスの解決手順」で store パス（`~/.claude/projects/<project-id>/growth/captures.md`）を組み立て Read で読み、「パース規約」に従いエントリを抽出して `status: unprocessed` のみを対象にする（`promoted` は無視）。参照源として既存ルール台帳（`CLAUDE.md` 2層・`learnings.md`・`candidates.md` 自身）を読み取り専用で読む（突合用、候補は生成しない）。store 未存在・0件は手順 §9 のエラー処理へ（procedure §2）。
2. **棄却（知識型で分岐）**: まず signal 群から知識型を導出し、型ごとに別の合否境界を適用する。**behavior-diff（摩擦知）**は「トリガー（どの状況で）」と「振る舞い差分（次回どう違う行動を取るか）」の両方が読める観察のみ合格（既存基準を緩めない。中間的で差分が一意に読めないものは棄却側）。**decision-record（判断知）**は behavior-diff 要求を免除し、`decision`（何を決めたか）が読めれば合格（一回性の設計境界を棄却で消さない＝原理1 の例外口）。空・決定核欠如は両型とも棄却（procedure §3・ADR-20260701 D4）。
3. **分類と重み付け（#417）**: §3 を通過した観察を出所（`origin`）を一次キーに環境摩擦（`tool-result`）／判断誤り（`user-utterance`）へ決定的に分類し、判断誤りを高優先・環境摩擦を低優先でランキングする（出力順位で実現。永続化しない。procedure §4）。
4. **クラスタ化・重複排除**: 合格観察から推論したトリガー×振る舞い差分が一致するものを1候補へ集約する。表層の語彙差は無視し、`signal`・`origin` の一致だけでは畳まない（procedure §5）。
5. **候補整形＋メタ付与（Route 統合）**: 各クラスタを `## <短い見出し>` ＋ 本文へ整形し、メタ欄として `type`（`behavior-diff` / `decision-record`）・`provenance`（畳んだ観察の `## <timestamp>` 群）・`scope-hypothesis`（`project-local` / `universal` の仮説タグ）・`career-hypothesis`（昇格先キャリア＋宛先 repo 仮説。`<career> / repo: <宛先>` 形式。4分類の決定表は procedure §6）・`candidate-status`（`pending`）を付与する。本文は型で分岐し、`behavior-diff` は規範差分＋理由、`decision-record` は4欄（`decision` / `rejected-alternatives` / `rationale` / `context`）。decision-record は大半 `scope-hypothesis: project-local`、`career-hypothesis` は `ADR 差分` / `learnings.md` を取りうる（procedure §6・personal-store-spec.md「候補ファイル（candidates.md）」「type 別スキーマ」）。
6. **台帳突合＋再発知見化（#417、behavior-diff のみ）**: `behavior-diff` 候補（および既存 pending 候補）を scope に対応する台帳（**祖先を含む**）と突合し、既知ルールに一致するものを「既存ルール X が N 回再発」知見へ変換する（N は provenance 件数から導出。突合した台帳ルール参照を本文に明記）。再発知見も他候補と同一スキーマ・同一ライフサイクルで扱う。`promoted`/`rejected` 候補は不可侵。`decision-record` は N 再発免除のため本ステップを通さず §6 整形のまま次へ送る（復元可能性の検証は promote の責務。procedure §7・ADR-20260701 D4/D5）。
7. **永続化＋提示**: 整形・変換した候補を `candidates.md`（パス解決は personal-store-spec.md 共通手順）へ provenance キーで **upsert** 永続化し、判断誤り（高優先）→環境摩擦（低優先）の順で候補リストをチャットにも提示して終了する。完了報告に分類内訳・型内訳（`behavior-diff` / `decision-record`）・再発知見変換数を含める。`captures.md`・`learnings.md`・台帳は変更しない。検証・Promote（起票）・配布・status 反転は行わない（promote の責務。procedure §8）。

## 完了報告

入力した `unprocessed` 件数・棄却件数・分類内訳・型内訳（`behavior-diff` / `decision-record`）・採用候補数（うち再発知見変換数）・store パス・候補ファイルパスを報告する。

```
未処理5件を蒸留しました。
- 棄却: 1件（純記述・実行不能）
- 分類: 判断誤り2件 / 環境摩擦2件
- 型内訳: behavior-diff 2件 / decision-record 1件
- 採用候補: 3件（candidates.md へ upsert。うち再発知見へ変換1件）
store: ~/.claude/projects/-home-user-myproject/growth/captures.md
candidates: ~/.claude/projects/-home-user-myproject/growth/candidates.md
```

候補は `candidates.md` へ永続化し、チャットにも提示する。検証・起票（`gh`）・`status` 反転・`learnings.md` への追加は promote の責務であり、本スキルは行わない。

## 関連

- `${CLAUDE_SKILL_DIR}/references/distill-procedure.md` — 蒸留判定基準の詳細（入力選択＝処理源/参照源・棄却・分類と重み付け・クラスタ化・候補整形・台帳突合と再発知見化・責務境界・エラー処理）
- `${CLAUDE_SKILL_DIR}/references/distill-examples.md` — クラスタ化・棄却・再発知見化・分類順位のサンプル入力＋期待結果（手順トレース用）
- `${CLAUDE_PLUGIN_ROOT}/references/personal-store-spec.md` — 入力源 store の形式・パース規約・パス解決手順・`status` 状態管理（`origin`/`expected`/`actual` 欄を含む）、および**出力先 候補ファイル（`candidates.md`）の形式・メタ欄スキーマ・provenance 規約・upsert 方式**
- `${CLAUDE_PLUGIN_ROOT}/references/learning-store-spec.md` — 候補が将来昇格する先の1欄スキーマ・記法ルール・記法例（候補見出し・本文が整合すべき規範形）・2空間モデル（scope-hypothesis の値域の裏付け）
- `${CLAUDE_PLUGIN_ROOT}/DESIGN.md` — 設計母艦（§3 Distill・§4 プラグイン構成・原理1・4・5・二段ゲート）
- `docs/adr/ADR-20260629-distill-input-contract-and-ledger-matching.md` — 入力契約の2分（処理源/参照源）・台帳突合・pending 再評価・責務境界の設計判断
- `docs/adr/ADR-20260701-learning-signal-recoverability-and-output-forms.md` — distill 出力形の2系統分離（`behavior-diff` / `decision-record`）・原理1 の例外口（判断知の behavior-diff 要求と N 再発免除）の設計判断（D4）
