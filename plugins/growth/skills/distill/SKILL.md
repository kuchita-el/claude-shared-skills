---
description: distill は個人ローカル store（セグメント captures-*.md）からカーソルより新しい生観察を provenance 導出で選びバッチ仮説形成し、知識型で出力形を2分する（摩擦知→behavior-diff、判断知→decision-record）。知識型で分類・重み付けし（判断知→高優先、摩擦知→再発Nで重み付け）、各仮説に scope/career 仮説タグと provenance を付与し candidates.md へ upsert する。既存ルール台帳と突合し既知ルール再発を知見化する（behavior-diff のみ）。horizon 超の古いバケットを経年削除し store を有界化する。検証・配布は行わない。Capture と非同期に明示起動（Phase 1）。
allowed-tools:
  - Read
  - Write
  - Glob
  - Bash(git rev-parse *)
  - Bash(date *)
  - Bash(rm ~/.claude/projects/*/growth/captures-*.md)
---

# distill

個人ローカル store の未処理の生観察を仮説形成し、知識型に応じた仮説（摩擦知→`behavior-diff` / 判断知→`decision-record`）へ変換する。各仮説にスコープタグ・キャリアタグ（Route 統合）と provenance を付与し仮説ファイル（`candidates.md`）へ永続化する。学習ループ（`[Capture] → [Distill+Route] → [Promote] → [Distribute]`）の Distill 段（Route 統合）。

## 目的・原則

- **目的**: 蓄積した生観察を仮説形成し、知識型に応じた**仮説**にする（DESIGN.md §3 Distill・原理1）。実行不能な内省はここで捨て、肥大を下流へ送らない（原理5）。
- **出力形の2系統（ADR-20260701 D4）**: 仮説の知識型で出力形（`behavior-diff` / `decision-record`）を分岐する。**摩擦知 → `behavior-diff`**（signal が摩擦群。規範差分＋理由。§3 棄却・§7 台帳突合 / N 再発を従来どおり適用、挙動不変）。**判断知 → `decision-record`**（signal が判断群＝選好/却下理由/目標表明/設計判断。`decision`/`rejected-alternatives`/`rationale`/`context` の4欄。原理1 の例外口として behavior-diff 要求と N 再発カウントを免除し、一回性の設計境界を決定の記録として残す）。系統メンバーシップは `tags`（多値 set）で表し、混在ゾーンの第2タグは evidence-gated 分岐で陽性証拠時のみ付与する（既定 both 禁止。procedure §3.3）。知識型の導出規則・値域・スキーマ正準は personal-store-spec.md「シグナル種別」「tags 別スキーマ」を単一出典とし二重定義しない。
- **Capture と非同期**: distill は capture（Capture）と別タイミングで明示起動するバッチ処理。store に溜まったカーソルより新しい観察を一括で仮説形成する（例: 1日分）。セッション終端には紐づかない。
- **Route 統合**: 各仮説に**スコープタグ**（`scope-hypothesis`: `project-local` / `universal`）と**キャリアタグ**（`career-hypothesis`: 昇格先キャリア＋宛先 repo 仮説）の直交2軸を付与する（仮説形成観点で判定）。scope は2空間（learning-store-spec.md「2空間モデル」）のいずれへ、career は4分類（決定表は distill-procedure.md）のどの成果物・repo へ向かう仮説かを示す。いずれも**仮説**であり確証しない。scope の最終裁定は人間 refine/review、career の確定（裁定）は集約点（取り込み Issue）が担う。promote はルーティング確定せず本文注記で運ぶのみ（ADR-20260628-2）。
- **分類・重み付け・台帳突合（#417）**: 各観察を知識型で優先度付けする——判断知（`decision-record`）は高優先（復元不能性）、摩擦知（`behavior-diff`）は再発 N で重み付け（単発は低優先・再発で昇格）。痕跡種別（`origin`）は優先度に用いない（ADR-20260701 決定1）。分類結果は candidates.md に永続化せず知識型＋再発 N から再導出する（軽い判定）。`behavior-diff` 仮説を scope に対応する既存ルール台帳（**祖先を含む**）と突合し、既知ルールに一致する観察は「ルール追加候補」にせず「既存ルール X が N 回再発（機能していない）」知見へ変換する（N は provenance 件数から導出。`decision-record` は N 再発免除＝突合・カウント対象外）。再発知見も別ファイル・別ルートを作らず candidates.md 上で他仮説と**同一形式・同一ライフサイクル**（promote→Issue）で扱う。突合は「既知/novel」までで、予測力・配布価値の検証（promote の責務）には踏み込まない（ADR-20260629）。
- **経年削除（retention・distill のみ）**: distill は store を有界化する削除主体でもある。retention horizon（既定 M=60 日・可変）より古く、かつバケット内の全エントリがカーソル通過済みのバケットのみをバケット丸ごと `rm` する（保持/削除セマンティクスは personal-store-spec.md「retention」を単一出典）。**未 distill エントリを含むバケットは horizon 超でも削除しない**（guarantee-once 非退行＝未検証観測が齢で無音脱落しない）。capture は削除を行わない（削除主体は distill に限る）。
- **仮説永続化まで（責務境界）**: 各仮説にスコープタグ・キャリアタグと provenance（クラスタを構成した観察の `## <timestamp>` 群）を付与し、仮説ファイル（`candidates.md`）へ provenance キーで upsert 永続化するまでで責務を終える。検証・Promote（起票）・配布・`learnings.md` への書き込み・候補の `candidate-status` の promote/reject 前進は**行わない**（二段ゲート。検証→起票→`candidate-status` 前進は promote の責務）。candidates.md（第3の個人ローカル成果物）と distill-state.md（処理済みカーソル）へは書き込むが、store（`captures.md`）・`learnings.md`・台帳（参照源）には書き込まない。
- **入力契約（Phase 1 スコープ）**: 入力は**処理源**と**参照源**の2種（ADR-20260629）。処理源は正準パス（セグメント `captures-*.md`。カーソルより新しく provenance 除外後の観察）のみで、仮説化の work queue。参照源は既存ルール台帳（`CLAUDE.md` 2層・`learnings.md`・`candidates.md` 自身）で、**読み取り専用**の突合用（仮説は生成しない。台帳は書き換えない）。出力先は `candidates.md`。明示起動のみ。

## 手順

判定基準の詳細は `${CLAUDE_SKILL_DIR}/references/distill-procedure.md` を、サンプル入力と期待結果は `${CLAUDE_SKILL_DIR}/references/distill-examples.md` を参照する（手順本文を SKILL.md に二重化しない）。

1. **入力選択（処理源＝セグメント glob ＋カーソル＋provenance 導出／参照源）**: 処理源は personal-store-spec.md「project-id とパスの解決手順」で store ディレクトリ（`~/.claude/projects/<project-id>/growth/`）を解決し、**セグメント glob `captures-*.md` でバケットを列挙**する。distill-state.md のカーソル（`- distill-cursor:`）**日付以降**のバケットのみを Read 対象にする（**Read 有界化**。バケット日付 < カーソル日付の sealed バケットは走査対象から除外＝Read トークン天井回避）。読んだ各バケットを「パース規約」に従いエントリ抽出し（旧 `status` 行は読み飛ばす＝後方互換）、per-entry でカーソルより新しい観測を候補スライスにし（有界化。バケット粒度フィルタは超集合ゆえ同日バケットは全通過済みでも読み per-entry で除外しうる）、その中で `promoted`/`pending` 候補を provenance に持つ観測を除外して処理源を確定する（重複排除）。参照源として既存ルール台帳（`CLAUDE.md` 2層・`learnings.md`・`candidates.md` 自身）を読み取り専用で読む（突合用、仮説は生成しない）。store 未存在（バケット0件）・カーソルより新しい観測0件・カーソル欠損は手順 §9／§2.1 のエラー・欠損処理へ（procedure §2）。
2. **棄却（知識型で分岐）**: まず signal 群から知識型を導出し、型ごとに別の合否境界を適用する。**behavior-diff（摩擦知）**は「トリガー（どの状況で）」と「振る舞い差分（次回どう違う行動を取るか）」の両方が読める観察のみ合格（既存基準を緩めない。中間的で差分が一意に読めないものは棄却側）。**decision-record（判断知）**は behavior-diff 要求を免除し、`decision`（何を決めたか）が読めれば合格（一回性の設計境界を棄却で消さない＝原理1 の例外口）。空・決定核欠如は両型とも棄却（procedure §3・ADR-20260701 D4）。
3. **分類と重み付け（#417）**: §3 を通過した観察を知識型で優先度付けする（判断知→高優先、摩擦知→再発 N で重み付け。痕跡種別は用いない）。出力順位で実現・永続化しない（procedure §4・ADR-20260701 決定1）。
4. **クラスタ化・重複排除**: 合格観察から推論したトリガー×振る舞い差分が一致するものを1仮説へ集約する。表層の語彙差は無視し、`signal`・`origin` の一致だけでは畳まない（procedure §5）。
5. **仮説整形＋メタ付与（Route 統合）**: 各クラスタを `## <短い見出し>` ＋ 本文へ整形し、メタ欄として `tags`（`{behavior-diff, decision-record}` の非空部分集合。既定は単一タグ、混在ゾーンの第2タグは §3.3 の evidence-gated 分岐で陽性証拠時のみ）・`provenance`（畳んだ観察の `## <timestamp>` 群）・`scope-hypothesis`（`project-local` / `universal` の仮説タグ）・`career-hypothesis`（昇格先キャリア＋宛先 repo 仮説。`<career> / repo: <宛先>` 形式。4分類の決定表は procedure §6）・`candidate-status`（`pending`）を付与する。本文は `tags` の各要素で分岐し、`behavior-diff` は規範差分＋理由、`decision-record` は4欄（`decision` / `rejected-alternatives` / `rationale` / `context`）、混在ゾーンは両本文を併記。decision-record は大半 `scope-hypothesis: project-local`、`career-hypothesis` は `ADR 差分` / `learnings.md` を取りうる（procedure §6・personal-store-spec.md「仮説ファイル（candidates.md）」「tags 別スキーマ」）。
6. **台帳突合＋再発知見化（#417、behavior-diff を含む仮説のみ）**: `tags` に `behavior-diff` を含む仮説（および既存 pending 仮説）を scope に対応する台帳（**祖先を含む**）と突合し、既知ルールに一致するものを「既存ルール X が N 回再発」知見へ変換する（N は provenance 件数から導出。突合した台帳ルール参照を本文に明記）。再発知見も他仮説と同一スキーマ・同一ライフサイクルで扱う。`promoted`/`rejected` 仮説は不可侵。`decision-record` は N 再発免除のため本ステップを通さず §6 整形のまま次へ送る（復元可能性の検証は promote の責務。procedure §7・ADR-20260701 D4/D5）。
7. **永続化＋カーソル前進＋提示**: 整形・変換した仮説を `candidates.md`（パス解決は personal-store-spec.md 共通手順）へ provenance キーで **upsert** 永続化し、処理後 distill-state.md のカーソルを今回走査した観測の最新 timestamp へ前進させる（distill のみが前進。promote は触らない）。知識型で優先度付けした順（判断知〔`decision-record`〕高優先→摩擦知〔`behavior-diff`〕は再発 N 順）で仮説リストをチャットにも提示する。痕跡種別は順位に用いない。完了報告に型内訳（`behavior-diff` / `decision-record` を含む仮説数・混在ゾーン数）・優先度内訳・再発知見変換数・前進後カーソル・削除バケット件数を含める。`captures-*.md` の**既存エントリは書き換えない**（rewrite しない。バケット単位の経年削除 rm は手順8 で行う）。`learnings.md`・台帳は変更しない。検証・Promote（起票）・配布・候補の `candidate-status` 前進は行わない（promote の責務。procedure §8）。
8. **経年削除（retention・distill のみ）**: カーソル前進後、セグメント glob `captures-*.md` を列挙し、各バケットについて (バケット内の**最大見出しキー ≤ カーソル** ＝ 全エントリ通過済み) ∧ (**バケット日付 < `today − M` 日** ＝ horizon 超。既定 M=60 日・可変。horizon 境界計算に `date -u`) の両方が真のバケットを `rm` で丸ごと削除する（`allowed-tools` のパス限定パターン適合のため**1バケットにつき1回 `rm`**を呼ぶ。複数引数形にまとめない）。**未 distill エントリを含むバケットは horizon 超でも削除しない**（最大見出しキー > カーソルとなり全通過済み条件を満たさない＝guarantee-once 非退行）。ちょうど M 日前（`バケット日付 == today − M`）は厳密不等号 `<` により保持側。rm は best-effort（失敗は完了報告に注記し次回再試行で回収）。削除主体は distill のみ（procedure §2.1 経年削除節）。

## 完了報告

処理源件数（カーソルより新しく provenance 除外後）・棄却件数・型内訳（`behavior-diff` / `decision-record`）・優先度内訳（高優先／再発 N 順の件数）・採用仮説数（うち再発知見変換数）・前進後カーソル・削除バケット件数（retention 経年削除）・store パス・仮説ファイルパスを報告する。rm 失敗があればそのバケットも注記する。

```
処理源5件（カーソルより新しく provenance 除外後）を仮説形成しました。
- 棄却: 1件（純記述・実行不能）
- 型内訳: behavior-diff 2件 / decision-record 1件
- 優先度: 高優先 1件（decision-record）/ 再発 N 順 2件（behavior-diff。うち再発知見1件）
- 採用仮説: 3件（candidates.md へ upsert。うち再発知見へ変換1件）
- 前進後カーソル: 2026-07-11T09:30:00Z
- 経年削除: 1バケット（captures-2026-04-30.md／horizon 60日超・全通過済み）
store: ~/.claude/projects/-home-user-myproject/growth/captures-*.md
candidates: ~/.claude/projects/-home-user-myproject/growth/candidates.md
```

仮説は `candidates.md` へ永続化し、チャットにも提示する。検証・起票（`gh`）・候補の `candidate-status` 前進・`learnings.md` への追加は promote の責務であり、本スキルは行わない。

## 関連

- `${CLAUDE_SKILL_DIR}/references/distill-procedure.md` — 仮説形成判定基準の詳細（入力選択＝処理源/参照源・棄却・分類と重み付け・クラスタ化・仮説整形・台帳突合と再発知見化・責務境界・エラー処理）
- `${CLAUDE_SKILL_DIR}/references/distill-examples.md` — クラスタ化・棄却・再発知見化・分類順位のサンプル入力＋期待結果（手順トレース用）
- `${CLAUDE_PLUGIN_ROOT}/references/personal-store-spec.md` — 入力源 store の形式・パース規約・パス解決手順・distill 処理源選択（処理済みカーソル＋provenance 導出。`distill-state.md`・前進/巻き戻し/欠損規則。`origin`/`expected`/`actual` 欄を含む）、および**出力先 仮説ファイル（`candidates.md`）の形式・メタ欄スキーマ・provenance 規約・upsert 方式**
- `${CLAUDE_PLUGIN_ROOT}/references/learning-store-spec.md` — 仮説が将来昇格する先の1欄スキーマ・記法ルール・記法例（仮説見出し・本文が整合すべき規範形）・2空間モデル（scope-hypothesis の値域の裏付け）
- `${CLAUDE_PLUGIN_ROOT}/DESIGN.md` — 設計母艦（§3 Distill・§4 プラグイン構成・原理1・4・5・二段ゲート）
- `docs/adr/ADR-20260629-distill-input-contract-and-ledger-matching.md` — 入力契約の2分（処理源/参照源）・台帳突合・pending 再評価・責務境界の設計判断
- `docs/adr/ADR-20260701-learning-signal-recoverability-and-output-forms.md` — distill 出力形の2系統分離（`behavior-diff` / `decision-record`）・原理1 の例外口（判断知の behavior-diff 要求と N 再発免除）の設計判断（D4）
