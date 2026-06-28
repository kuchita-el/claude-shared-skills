# Distill 手順（蒸留・重複排除・候補化）

distill スキルの蒸留判定基準の詳細。SKILL.md の手順 overview から参照される単一出典。サンプル入力と期待結果は [`distill-examples.md`](distill-examples.md) を参照する。

## 1. 目的・責務境界

- **目的**: 個人ローカル store に溜まった未処理の生観察を、クラスタ化・重複排除し、実行可能な振る舞い差分（規範）の**候補**へ変換する（DESIGN.md §3 Distill・原理1）。
- **Route 統合（責務拡張）**: 各候補に2つの仮説タグを付与する。両者は**直交**する独立2軸であり（キャリア軸 ⊥ 空間軸。DESIGN.md「種別軸 ⊥ 共有境界軸」）、いずれも蒸留観点で判定する**仮説**として確証せず終点とする。
  - **スコープ仮説タグ**（`scope-hypothesis`: `project-local` / `universal`）: 蒸留時に「どの観点で蒸留したか」の視点で判定し、2空間（learning-store-spec.md「2空間モデル」）のいずれへ向かう候補かを示す。最終裁定（適用範囲の確定）は下流の人間 refine/review に委ねる（横断解析は Phase 3 の支援どまり）。
  - **キャリア仮説タグ**（`career-hypothesis`: 昇格先キャリア＋宛先 repo 仮説）: 候補がどのキャリア（成果物の種別）へ・どの repo へ向かうかを「§ career-hypothesis の判定（決定表）」で判定する。career の確定（裁定）は distill では行わず、最終裁定は集約点（取り込み Issue）が担う。promote はこの仮説をルーティング確定せず本文注記として運ぶのみ（ADR-20260628-2）。
- **責務境界（候補永続化まで）**: distill は候補を整形し、メタ欄（provenance・scope-hypothesis・career-hypothesis・candidate-status）を付けて候補ファイル（`candidates.md`）へ永続化するところまでで責務を終える。次のいずれも**行わない**:
  - 検証（候補が本物か／母集団に予測力を持つかの判定。promote の責務）
  - 昇格ゲート（Promote）・Issue 起票（`gh`）・配布物（`learnings.md`）への書き込み
  - store の `status` 反転（`unprocessed → promoted`。反転の実行主体は promote。personal-store-spec.md「状態管理」）
- distill が書き込むのは `candidates.md`（第3の個人ローカル成果物）のみ。`captures.md`（store）と `learnings.md`（配布物）のいずれにも書き込まない。候補は `candidates.md` へ永続化しつつチャットにも提示する。
- 原理5（足場を痩せさせる蒸留）に従い、実行不能な内省はここで捨てる。肥大を下流へ送らない。

> **冪等性（`status` 反転は promote が担う）**: `status` を `promoted` へ反転する主体は promote（#348 で確定。personal-store-spec.md「状態管理」）。distill は `status: unprocessed` のみを処理対象とし `promoted` は再走査しないため、promote が起票成功後に由来エントリを `promoted` へ反転すれば、次回 distill で同一観察は再走査されず同一候補は再生成されない（`status` 軸の冪等性が効く）。加えて候補ファイル側では、distill が provenance キーで upsert することで再実行時の候補重複を防ぎ、promote が棄却した候補は `candidate-status: rejected` で追跡され安易な再提示を避ける（§5）。

## 2. 入力選択（AC1）

1. **store パスの解決**: personal-store-spec.md「project-id とパスの解決手順」に従い `<project-id>` を解決し、store パス `~/.claude/projects/<project-id>/growth/captures.md` を組み立てる。
2. **store の読取**: Read ツールで store を読む。存在しない・読めない場合は §7 のエラー処理へ。
3. **エントリの抽出**: personal-store-spec.md「パース規約」に従い行ベースで抽出する。
   - エントリ境界: `## <timestamp>` 見出しから次の `##` 見出し（またはファイル末尾）まで。
   - メタ: `- signal: …` / `- session: …` / `- status: …`（`- key: value` 形式の単一行）。
   - observation 本文: メタ行と見出し直後の空行を除いた残りの行。
4. **未処理のみを対象**: `status: unprocessed` のエントリのみを処理対象に選ぶ。`status: promoted` は**無視**する（再走査しない）。`unprocessed` が0件なら §7 のエラー処理へ。

> distill の入力源は正準パス（`captures.md`）のみ。in-repo の `plugins/growth/.local/` は走査しない（personal-store-spec.md「構成上の保証」）。

## 3. 棄却の合否境界（AC4）

クラスタ化の前に、各観察が**規範化可能か**を判定し、不可能なものを候補化対象から外す。判定は learning-store-spec.md「記法ルール」＋原理1（保存対象は記述ではなく振る舞い差分）に依拠する。

**合否境界（次のいずれかに該当する観察は棄却し、候補に出さない）**:

| 棄却理由 | 判定の手掛かり |
|---|---|
| 空 | observation 本文が実質的に空（事実が読み取れない） |
| 純記述的 | 事実の記述に留まり、行動を命じない。「何が起きたか」だけで「次回どう違う行動を取るか」が読み取れない（例: 「ビルドが想定より遅かった」「ログが冗長だった」） |
| 実行不能 | 規範として書こうとしても、次回再現できる具体的な行動差分に落ちない（感想・分類・一回限りの事象） |

**合格（候補化する）の条件**:

- 観察から「**トリガー**（どの状況で）」と「**振る舞い差分**（次回どう違う行動を取るか）」の両方が読み取れること。両者が揃って初めて規範（実行可能な差分）になる。
- 中間的な観察（行動が暗示されるが明示されない）は、振る舞い差分が**一意に読み取れる**場合のみ合格。読み取れない場合は棄却側に倒す（純記述を候補へ漏らさない。下流 Promote の負荷を上げない）。

> 棄却は store からの削除ではない。distill は store を変更しない（§1）。棄却された観察は `unprocessed` のまま store に残る。

## 4. クラスタ化・重複排除（AC2）

合格した観察を、同種ごとに1候補へ畳む。

1. **トリガーと振る舞い差分の推論**: 各観察から「トリガー（状況）」と「振る舞い差分（次回の行動）」を推論する。store のスキーマにこれらの明示欄はない（observation と signal のみ）ため、observation 本文から導出する。
2. **同種判定の基準**: **推論したトリガー × 推論した振る舞い差分**が一致する観察を同種とみなし、1候補へ集約する。
   - **表層の語彙・言い回しの差は無視**する。同じトリガー×振る舞い差分に畳めるなら、文言が違っても1候補にまとめる。
   - **`signal` の一致だけでは畳まない**。同一 signal（例: `訂正` ×2）でも、振る舞い差分が異なれば別候補として分離する。signal は畳み込みの基準ではない。
3. **集約結果**: §3 を通過した合格観察を N 件とすると、同種が1件以上重複する場合、集約後の候補数は N 未満へ減る（AC2 の「集約後候補数 < N」の N は合格観察数を指す。棄却された観察は N に含めない）。

## 5. 候補整形＋メタ付与（AC3・Route 統合）

各クラスタを、候補ファイル（`candidates.md`）のスキーマ（personal-store-spec.md「候補ファイル（candidates.md）」）に整合する候補へ整形する。候補は**見出し＋メタ欄＋本文**を持つ。

- **見出し** `## <規範の短い見出し>`: その候補が命じる振る舞い差分の一文要約（規範）。昇格時にそのまま `learnings.md` の見出しになる形（learning-store-spec.md「記法例」と整合）。
- **メタ欄**（`- key: value` 形式の単一行で見出し直後に置く）:
  - `provenance`: このクラスタを構成した観察の `## <timestamp>` 群（複数畳んだ場合はカンマ区切り等で全て列挙）。promote の `status` 反転対象を特定する粒度。
  - `scope-hypothesis`: スコープ仮説タグ（`project-local` / `universal` の2値のいずれか）。§1 の Route 統合に従い蒸留観点で判定。2値以外を出さない。
  - `career-hypothesis`: キャリア仮説タグ。`<career> / repo: <宛先 repo 仮説>` の1行形式。`<career>` は次節「career-hypothesis の判定（決定表）」が一意に出力した4分類（`強キャリア` / `改善還元` / `ADR 差分` / `learnings.md`）のいずれか。`<宛先 repo 仮説>` は当該キャリアの成果物を向ける repo の仮説（distill 時点では仮説であり、最終宛先は集約点が確定する）。scope-hypothesis と直交に判定する。
  - `candidate-status`: 新規生成時は `pending`。
- **本文**: 規範差分の具体（次回どう違う行動を取るか）＋理由（なぜその振る舞いを取るか）。複数行可。メタ欄の後に置く。
- 昇格時にメタ欄は落ち、見出しと本文（規範）だけが `learnings.md` の1欄スキーマ（メタ欄なし）として残る形であること。

### career-hypothesis の判定（決定表）

`career-hypothesis` の昇格先キャリアは、候補の性質を入力に**一意に**出力する決定表で判定する（#349 D1 の4分類。本決定表は #382 `promotion-issue-spec.md` から distill へ移設した単一出典）。一意性は入力条件の相互排他ではなく、**上から順に評価して最初に合致した行を採る順序評価**と、**行4を「上記いずれにも該当しない」残余枝（既定枝）として定義する**ことで保証する。行1〜3の条件は重なりうる（例: 強キャリア化可能な候補は同時に汎用ルールでもある）が、順序評価＋強キャリア最優先により一意に決まる。distill が出すのは**仮説**であり、確証しない（最終裁定は集約点＝取り込み Issue）。

| # | 入力条件（候補性質の判別基準。上から評価し最初に合致した行を採る） | 出力キャリア | 宛先 repo 仮説の手掛かり |
|---|---|---|---|
| 1 | 候補が **skill / hook / lint / test へ構造変換可能**な強キャリアである（決定論的ガードレールへ畳み込める。「二度と起こせない構造」へ変換できる） | `強キャリア` | 当該ガードレールを実装する repo（多くは配布元プラグイン repo）。テキスト規範ではなく構造へ変換する |
| 2 | 候補が **任意のプラグイン／コミュニティの改善還元**を命じる（既存の配布物・ツール・プロセスの改善。dev-workflow に限らない） | `改善還元` | 当該プラグイン／コミュニティの repo（宛先 repo は可変）。`gh` 経由で Issue/PR を立てる先。distill 時点では仮説で、最終宛先は集約点（所属コミュニティ境界を知る側）が確定する |
| 3 | 候補が **後戻りコストが高く横断再発する構造的な設計判断**である（複数モジュール波及・採用理由揮発・却下選択肢ありの設計決定） | `ADR 差分` | 設計判断が属する repo の `docs/adr/`。ADR 運用ルールの粒度判定（README の4項目チェックリスト）に乗せる |
| 4 | 上記いずれにも該当しない、**テキスト規範として置くしかない汎用の振る舞いルール**（次回どう違う行動を取るかを一文で命じられる） | `learnings.md` | 配布元プラグイン repo（`learnings.md` を配布する側）。強キャリアへ変換可能になれば畳み込みで除去される |

**一意性と曖昧時のフォールバック**:

- 入力条件は**上から順に評価し、最初に合致した行のキャリアを採る**。強キャリア（行1）への変換可能性を最優先に判定するのは、強制可能な制約 > 書かれたルール（原理4）に従い、可能な限り強いキャリアへ寄せるため。
- 行1〜3のいずれにも明確に該当しない候補は**既定枝として行4（learnings.md）にフォールバック**する。テキスト規範は最弱だが最も導入コストが低く、後から畳み込み（強キャリア化）で上へ移送できるため、迷う候補の既定の受け皿に適する。
- 強キャリア化の可否やキャリア妥当性・宛先 repo に確信が持てない候補も、仮説として付与したうえで**最終裁定を集約点（取り込み Issue）に委ねる**。distill は確証しない。

**宛先 repo の仮説**: 宛先 repo は distill 時点では仮説である。特に行2（改善還元）は知識の集約単位が global / 組織 / チームと様々ありうるため宛先 repo を固定しない。最終宛先は集約点（所属コミュニティ境界を知る側）が確定する（ADR-20260628-2）。

**判定例**:

| 候補（振る舞い差分） | 判別 | career-hypothesis（例） |
|---|---|---|
| 「ファイル復元には `git checkout` ではなく `git restore` を使え」型の汎用規範 | 行1〜3に該当せず、テキスト規範として置く汎用ルール → 行4 | `learnings.md / repo: 配布元プラグイン repo` |
| 「内省機能を dev-workflow に混ぜず独立プラグインへ分離する」型の構造判断 | 後戻りコスト高・横断・却下選択肢ありの設計決定 → 行3 | `ADR 差分 / repo: 当該設計が属する repo` |
| 「create-issue の AC 生成を検証可能性チェックで厳格化する」型 | 既存プラグインの手順改善 → 行2 | `改善還元 / repo: dev-workflow プラグイン repo（仮説）` |
| 「長文 CLI 引数の破損を lint で機械的に禁止する」型 | skill/hook/lint へ構造変換可能な強キャリア → 行1 | `強キャリア / repo: 配布元プラグイン repo` |

**キャリア軸 ⊥ 空間軸（直交）**: この4キャリア軸（昇格先＝何の成果物へ配るか）は、scope の2空間軸（`universal` / `project-local`）と**直交する**（DESIGN.md「種別軸 ⊥ 共有境界軸」）。同じ learnings.md 行きの候補でも universal / project-local に分かれうるため、`career-hypothesis` と `scope-hypothesis` は独立した2メタ欄として持つ。

## 6. 出力・完了報告

- **候補ファイルへの永続化（upsert）**: §5 で整形した候補を `candidates.md`（パス解決は personal-store-spec.md「project-id とパスの解決手順」を共通参照。store と同階層 `~/.claude/projects/<project-id>/growth/candidates.md`）へ書き込む。書き込みは **provenance キーで upsert**（同一 provenance キーの既存候補があれば置換、なければ追加）する。単純追記は再実行で重複し、全置換は既存候補（promote が `rejected` を記録したもの等）を失うため。既存の `candidate-status: rejected` 候補は尊重し、同一 provenance の候補を安易に `pending` で再生成しない。
  - **upsert の実装手順**: distill の `allowed-tools` は `Write` のみで `Edit`（部分置換）を持たない。したがって upsert は「(1) 既存 `candidates.md` を Read で全文取得（未存在なら空集合）→ (2) provenance キーで突き合わせ、新規候補を追加・既存候補を置換し、`rejected`/`promoted` の既存エントリは保持して、メモリ上で候補集合全体を再構成 → (3) 再構成した全文を Write で書き出す」で行う。Read を伴わない単純追記 Write・naive な全置換 Write は行わない（前者は重複、後者は既存候補喪失を招く）。
- 候補リストはチャットにも提示する（永続化と提示の両方を行う）。
- 完了報告に以下を含める:
  - 入力した `unprocessed` 件数
  - 棄却件数（§3 で候補化対象から外した数）
  - 採用候補数（§5 の出力数。集約後の件数）
  - store パス・候補ファイルパス

## 7. エラー・境界処理

| 状況 | 振る舞い |
|---|---|
| `git rev-parse` が失敗（git リポジトリ外・git 未インストール等で project-id を解決できない） | 「project-id を解決できませんでした（確認: `git rev-parse --path-format=absolute --git-common-dir`）」と報告して終了。候補0 |
| store ファイルが存在しない／読めない | 「store が見つかりません（確認パス: `~/.claude/projects/<project-id>/growth/captures.md`）」と報告して終了。候補0 |
| `status: unprocessed` が0件（全 `promoted` または空） | 「未処理の観察はありません」と報告して終了。候補0 |
| 全観察が §3 で棄却された | 「候補化できる規範はありませんでした（棄却 N 件）」と報告して終了。候補0 |

いずれもエラーではなく正常終了として報告する。候補が0件のためいずれの場合も `candidates.md` への書き込みは行わず、`captures.md`（store）・`learnings.md` も変更しない。

## 関連

- [`distill-examples.md`](distill-examples.md) — AC2/AC4 のサンプル入力＋期待結果（手順トレース用）
- `${CLAUDE_PLUGIN_ROOT}/references/personal-store-spec.md` — 入力源 store の形式・パース規約・パス解決手順・`status` 状態管理、および出力先 候補ファイル（`candidates.md`）の形式・メタ欄スキーマ・provenance 規約・upsert 方式
- `${CLAUDE_PLUGIN_ROOT}/references/learning-store-spec.md` — 候補が将来昇格する先の1欄スキーマ・記法ルール・記法例（昇格時に残る見出し・本文の規範形）・2空間モデル（scope-hypothesis の値域の裏付け）
- `${CLAUDE_PLUGIN_ROOT}/DESIGN.md` — 設計母艦（§3 Distill・原理1・5・二段ゲート）
