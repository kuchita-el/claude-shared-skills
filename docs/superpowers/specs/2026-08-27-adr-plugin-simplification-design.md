# adrプラグイン簡素化 設計spec（2026-08-27）

## 目的

adrプラグインを「ADR corpus の不変条件を守る小さな機構（drift-lint・有効性index生成・識別子発番・commit前ゲート）＋判断単位に分解されたライフサイクル操作スキル」へ縮退させる。既存の実装・設計に囚われず、配布価値の本体でない検証装置を廃止し、テストを挙動ベースへ書き直す。

## 背景（現状の定量）

2026-08-27時点の棚卸し結果。

| 区分 | 行数 |
|---|---|
| スクリプト4本（`plugins/adr/scripts/`） | 1,956（うち `adr-scoping-cases.sh` 1,031、`lint-adr.sh` 722） |
| manage-adr スキル本文＋references 10ファイル | 1,106 |
| ADR関連 bats テスト（`scripts/tests/`） | 3,184（うち scoping-cases 系 2,084 = 65%） |
| fixtures（`scripts/fixtures/adr-scoping-cases/` 28ディレクトリ） | 1,562 |
| 開発専用台帳類（`docs/development/adr-scoping-cases/`、runs 131ファイル除く） | 約1,635 |

構造上の発見: 判定パイプライン一式（`adr-scoping-cases.sh` ＋ そのテスト ＋ fixtures ＋ 30フィールド判定契約 ＋ 台帳）が約6,400行あり、中核機構（lint・index・発番・ゲートとそれらのテスト、約1,840行）の約3.5倍を占める。この検査器は `plugins/adr/README.md` 自身が「manage-adr スキルからも commit ゲートからも呼ばれず、判定手続き文書を改訂する担い手が手で起動する」と明記する開発支援ツールであり、プラグインの配布価値の本体ではない。廃止の根拠はこの2点（配布価値の本体でないこと・規模比）であり、保守摩擦の解消は根拠に含めない（行番号固定台帳 `docs/development/plugin-path-reference-ledger.md` の commit ブロックは、126行中32行のみが削除対象由来で、廃止後も別系統の bats で同じブロックが起きる。台帳機構の是非は本簡素化の射程外＝follow-up 候補）。

## 決定事項（ユーザー承認済み、2026-08-27）

1. **判定パイプライン一式を廃止する**（退避・縮退ではなく削除。git履歴には残る）
2. **drift-lint は5レイヤ全て維持、commit前ゲートも維持**。簡素化は実装の整理に留め、検査内容は変えない（検査は全て実障害由来の不変条件であり、削ると再発する前提）
3. **manage-adr スキルはゼロベースで再設計**する。「1つのMarkdownに複数の判断が押し込まれテスタビリティが低い」問題への対処として、1判断=1参照ファイルへ分解する
4. **残るスクリプトのテストも再設計**する。検査すべき振る舞い（レイヤ単位の正例/負例・実障害由来の回帰）を洗い出して書き直す
5. **`docs/development/adr-scoping-cases/` 一式（runs 131ファイル含む）も削除**する

## 節1: 判定パイプラインの廃止

### 削除対象

- `plugins/adr/scripts/adr-scoping-cases.sh`（固定題材集合の実行支援。prompt/validate/report/derive/crosscheck/validate-returns の6サブコマンド）
- `scripts/tests/adr-scoping-cases-basic.bats`・`scripts/tests/adr-scoping-cases-edge.bats`
- `scripts/fixtures/adr-scoping-cases/` 一式
- `plugins/adr/skills/manage-adr/references/adr-judgment-contract.md`（判定器返却JSONの30フィールド直列化契約）
- `plugins/adr/skills/manage-adr/references/adr-scoring-thresholds.json`（点数閾値）
- `docs/development/adr-scoping-cases/` 一式（README・sources.md・defect-ledger.md・cases.md・expectations.tsv・runs/）
- `scripts/run-tests.sh` 内の該当テスト登録行
- `scripts/tests/helpers/adr-scoping-cases.bash`（削除対象2 bats からのみ参照される共有ヘルパー。2026-08-27 の実測で追加）
- `scripts/tests/return-schema-migration.bats`（判定器と fixture `returns/CASE-A1-1.json` に全面依存。同上）
- `scripts/migrate-return-schema.sh`（返却スキーマ移行スクリプト。参照元は削除対象の台帳・bats のみ。ファイル名に `adr-scoping-cases` を含まないため語彙走査では捕捉されず、削除対象はパス列挙で照合する。同上）

### 削除に伴う波及修正（削除ではなく編集。2026-08-27 の実測で追加）

- `scripts/tests/lint-adr-surface.bats`: `AC5_SURFACE_FILES` の固定列挙から `adr-judgment-contract.md` / `adr-scoring-thresholds.json` の2行を外す。本 bats は manage-adr スキル面の旧記述除去検査であり、判定パイプライン専用ではないため削除しない
- `scripts/run-tests.sh` の `EXPECTED_BATS`: 削除する3本（`adr-scoping-cases-basic` / `adr-scoping-cases-edge` / `return-schema-migration`）の登録行を外す。固定リストであり、glob の縮小では追随しない
- `docs/development/plugin-path-reference-ledger.md`: 削除対象ファイルを指す行番号固定の行を外す（対象行の特定は行数でなく削除対象のパスとの照合で行う。2026-08-27 実測で約32行）。`scripts/run-tests.sh:150` が本番台帳に対して `validate-plugin-path-references.sh` を走らせており、放置すると stale 判定で赤になる
- `docs/development/test-execution.md`: :185 の採点表（§6、過去時点の判定記録）と :199 の移行対応表（§7、移行完了時点の凍結記録）は**更新しない**（`scripts/run-tests.sh` の「§7 の移行対応表は移行完了時点の凍結記録であり、追随の対象ではない」規定に従う。ユーザー裁定 2026-08-27）。凍結記録・歴史記録は受入条件の参照残存検査から除外集合としてパスで固定する。§1 のスイート表には削除対象の記載が無いことを確認済み（2026-08-27）
- `docs/distribution-boundary.md` / `docs/adr/ADR-202607230648-01`: `adr-scoping-cases.sh` を配置判断の**例示**として引用している箇所。決定そのものは無効化されないため、例示の陳腐化を注記で処理する（ADR 本体の反転にはあたらない）
- `docs/development/` 配下の観測記録（`adr-destination-branch-measurability-2026-08-23.md` 等）は当時の観測を残す歴史記録であり、参照先の消滅を理由に書き換えない

### 存続対象

- `plugins/adr/skills/manage-adr/references/adr-scoping.md`（ADR化要否の判定基準の条文）。ADR化要否の判定は「条文をLLMが読んで判定する」形に戻し、機械検査・点数化・台帳との突き合わせは行わない。

  **判定の実体の内製化（2026-08-27 追記・ユーザー承認済み）**: 起案時の「得られた知見は条文へ反映済みとみなす」は現物と食い違っていた。`adr-scoping.md` は判定の実体を削除対象2ファイルへ外出ししており、そのまま削除すると条文が指示先を失う。

  - `adr-scoping.md` の判定表は全セルが「設定ファイルの項目1閾値以上」等の間接参照で書かれ、数値の実体は `adr-scoring-thresholds.json`（`item1_file_count: 3` / `item2_unit_count: 2` / `adr_score_boundary: 3`）にある
  - 同 :64 が「項目1・2の数え方、項目3の保持先と同居判定は `adr-judgment-contract.md` へ移設した」と明記しており、`adr-judgment-contract.md` は前半（「実測事実の値域と定義」＝条文の実体）と後半（30フィールドJSON直列化契約＝機械可読部分）の二重構造になっている

  したがって PR1 では、閾値の数値を `adr-scoping.md` へ直書きし、`adr-judgment-contract.md` 前半の値域定義（項目1・2の数え方、項目3の値域(A)(B)と条件1〜3、項目4の阻止状態）を条文へ吸収したうえで、機械可読部分だけを落とす。**4項目・閾値・合計点という判定の枠組み自体は現状維持**とし、点数化の撤去は行わない。`ADR-202608011651-01` 決定2 は項目名・スコア境界を保持対象から外しているため、この内製化は同 ADR の反転にあたらない。

### 付随工程

- **既存ADRとの決着**: 判定仕様・固定題材集合・退行検出網に関わる既存ADRを洗い出し、各件の判定結果（変更不要を含む）を記録する。2026-08-27 の実測（`docs/adr/` 全件走査）では遷移（上書き/廃止）を要するADRは無い: `ADR-202607230648-01` は例示引用のみで注記処理（「削除に伴う波及修正」参照）、`ADR-202608011651-01` 決定2 は閾値の内製化を反転と扱わないことを自ら明記している。本簡素化自体が設計判断であり、ADR化要否の判定を経る。
- **前提の消えた Issue の処理（ユーザー承認済み、2026-08-27）**: 判定器・判定契約・点数化・台帳・退行検出網そのものを直す OPEN Issue 14件のうち、10件（#604 / #606 / #607 / #608 / #719 / #724 / #727 / #747 / #750 / #766）は本廃止 Issue へリンクしたうえで not planned でクローズする。4件（#718 / #720 / #745 / #722）は指摘された条文欠陥自体が `adr-scoping.md` に残るため、受入条件から廃止対象の機構への依存（CASE 再導出・独立2試行・`defect-ledger.md` 更新・`cmd_derive` 同期）を外し、条文欠陥の是正だけを射程とする形へ本文を書き直す。#700 は本文に機構依存がなく、変更不要で存続する
- **参照掃き**: 削除対象への参照（`CLAUDE.md`、`docs/` 配下の規約文書、他スキル・エージェント定義、`README.md`）をリポジトリ全体で grep し、残参照を全て張り替えまたは削除する。廃止作業では「代替則と他規定の判定材料の衝突」「再混入ガードの不在」が既知の死角であり、隣接条文の全経路を列挙してから書き換える。

## 節2: manage-adr スキルのゼロベース再設計

### 設計原理

- スキルが下す**判断**を洗い出し、**1判断=1参照ファイル**へ分解し直す。既存の文書構成（transitions.md 211行、adr-model.md 108行等）は引き継ぎの前提としない
- `SKILL.md` は「利用者の依頼をどの判断へルーティングするか」だけを持つ骨格とする
- 既存のtoken規律に適合させる: SKILL.md 本文170行以内、description 200字程度

### 判断の候補（再設計時に洗い出しで確定する。以下は現機能からの見立て）

1. ADR化要否（`adr-scoping.md` を存続利用）
2. 遷移の選択と実行（起票・承認・上書き・廃止・却下）
3. 既存ADR編集の変更種別分類（core／非core／些末）と、分類に応じた経路（core=新規起票＋上書き、非core／些末=直接編集）
4. 多決定ADRの分割（1→N の部分上書き）
5. 格下げ（ADRから通常文書への降格）

### 統合方針

- io-examples.md・cross-references.md 等の小粒ファイルは、対応する判断ファイルへ吸収する
- template.md（ADR雛形）は成果物の形式定義として独立を維持してよい
- 目標規模: references 合計 約986行 → 500行前後（結果として減る。行数削減自体を目的にしない）。この数値は節1の内製化で `adr-scoping.md` が増える分を織り込む前のものであり、目安に留める
- PR1 で `adr-scoping.md` へ集約した判定の実体を、本再設計の分解で再配置することは織り込み済み（節1「判定の実体の内製化」の決定時に、PR2 まで参照除去を遅らせる代替案を棄却した帰結としての二段作業）

## 節3: スクリプトの整理

- `lint-adr.sh`: **検査内容（5レイヤ: front-matterスキーマ／index同期／相互参照の双方向性／参照先の生存性・実在性／ファイル名・識別子規約）は不変**。実装をレイヤ単位で独立に呼び出せる構造へ整理し、テスタビリティを上げる。物理的なファイル分割の要否は実装時に判断する
- `gen-adr-index.sh`・`next-adr-id.sh`・`hooks/`（commit前ゲート）: 既に小さく責務が明確なため現状維持

## 節4: テスト再設計

- 検査すべき振る舞いを「レイヤ単位の正例/負例」＋「実障害由来の回帰」として洗い出してから書き直す。網羅の根拠を挙動の列挙に置き、既存テストのケース移植を出発点にしない
- **行番号固定・版据え置き型の常設ゲートは持ち込まない**。回帰ケースには由来（どの実障害か）をテスト内コメントで残す
- 対象: lint-adr 系 bats 4ファイル（計914行）は書き直し。`next-adr-id.bats`・`adr-portability.bats` は軽整理に留める
- 変異検査・判定契約検査などの上位検証層は再導入しない

## 節5: 工程分割（Issue単位PR・束ねない）

| 順 | 工程 | 内容 | 推奨effort |
|---|---|---|---|
| PR1 | 廃止 | 節1の削除一式＋既存ADRの遷移決着＋参照掃き（削除のみで機能追加なし） | medium |
| PR2 | スキル再設計 | 節2 | high |
| PR3 | lint整理＋テスト再設計 | 節3＋節4（lint実装とそのテストは同一PRが自然） | high |

- 順序依存: PR1 が先行（判定契約が消えた状態でスキルを再設計する）。PR2 と PR3 は相互に独立
- 各PRとも Issue を起票してから着手する（`create-issue` → `plan-issue` → `implementation` の既存ワークフローに乗せる）

## 受入条件（全体）

- 節1「削除対象」に列挙した各パス（`scripts/migrate-return-schema.sh` を含む）がリポジトリの追跡下に存在しない（worktree 複製を除く）。照合は「adr-scoping-cases 系」等の包含語ではなく、削除対象のパス列挙との突き合わせで行う
- 削除対象への参照が、リポジトリ内の規約文書・スキル定義・エージェント定義・テストランナーのいずれにも残っていない。凍結記録・歴史記録（`docs/development/test-execution.md` §6/§7、`docs/development/` 配下の観測記録）は除外集合としてパスで固定する
- `bash scripts/run-tests.sh` が全緑で、runner の既存ガード（`EXPECTED_BATS` と glob 結果の双方向照合、TAP のプラン行と結果件数の照合）がいずれも不発火である。PR1 実装時に残存スイートの skip 使用有無を grep で1回確認する（常設の skip 計数機構は追加しない。ユーザー裁定 2026-08-27）
- drift-lint の5レイヤの検査内容が変更前後で同一であることを、正例/負例テストで示せる
- manage-adr スキルの参照ファイルのうち判断を扱うものが、それぞれ単一の判断のみを扱う（形式定義の雛形ファイルは対象外）。SKILL.md 本文が170行以内である
- 本簡素化の設計判断が ADR 化要否の判定を経て決着している（起票または非該当の判定記録）。判定に使う条文は本簡素化による改訂前（着手時点の main）の版に固定し、判定記録に使用した版（commit）を明記する

## リスクと対策

- **廃止の巻き戻し**: 全て git 履歴から復元可能。削除は通常の PR レビューを経る
- **判定品質の低下**: 機械検査を失うため、ADR化要否判定のぶれは条文（`adr-scoping.md`）の質だけで支える。判定のぶれが実害として再観測されたら、その時点の実障害を根拠に必要最小の検証を再設計する（旧機構の復活は既定にしない）
- **lint 書き直しのリグレッション**: 検査内容不変が制約。5レイヤそれぞれの負例（違反を含む corpus）を新旧 lint に通し、同じ違反を同じレイヤで検出することを確認してから旧実装を落とす。正常 corpus での緑同士の一致は検査内容が同一であることの証拠にならないため、根拠にしない

## 射程外（follow-up 候補）

- 行番号固定台帳（`docs/development/plugin-path-reference-ledger.md`）と据え置き型検査の機構そのものの是非。削除対象由来は126行中32行のみで、廃止後も別系統の bats への1行挿入で同じ commit ブロックが起きる。本簡素化の根拠・受入条件には含めず、扱うなら別 Issue として起票する
