# ADR drift-lint のレイヤ分解とテスト再設計（2026-08-29）

Issue #800 の作業記録。設計 spec `docs/superpowers/specs/2026-08-27-adr-plugin-simplification-design.md` の節3（`lint-adr.sh` の実装整理）と節4（テスト再設計）を実装した工程の記録である。

実装プランは `docs/plans/issue-800.md`（git 未追跡）が持つ。プランはこの記録のファイル名を `lint-adr-layer-restructuring-2026-08-28.md` と書いているが、作業日は 2026-08-29 であり、`docs/development/` の日付接尾辞は作業日を指す慣行のため、実際の作業日に合わせた。

## 基準版

判定・照合の基準版は **`c126d72`**（`Merge pull request #799 from kuchita-el/feature/794-lint-adr-header-transition-table`）。本ブランチはこの commit から分岐している。

着手時点で取り直した実測値は次のとおり。プランが `c126d72` 時点として記載していた値と全件一致した。

| 項目 | 実測値 | 取得手段 |
|---|---|---|
| `plugins/adr/` の version（両マニフェスト） | `0.7.1` | `plugin.json` の `version` |
| `lint-adr.sh` の行数 | 714 | `wc -l` |
| bats ケース総数 | 150 | `bash scripts/run-tests.sh` の bats スイート |
| 正例 corpus 数 | 8 | `scripts/fixtures/lint-adr/valid/*/` |
| 負例 corpus 数 | 32（ディレクトリ名は `01`〜`33` で `21` が欠番） | `scripts/fixtures/lint-adr/invalid/*/` |
| 負例の終了コード1件数と出力行総数 | `rc1=32 output_lines=36` | 後述の負例実測手順 |
| 参照台帳 | `checked=84 missing=0 stale=0` | `bash scripts/validate-plugin-path-references.sh . docs/development/plugin-path-reference-ledger.md` |

## 検査分岐の被覆表

### 分岐の数え方

**違反を出力する `printf` 1つ＝1分岐**と定義する。`lint-adr.sh` の `printf` は基準版で25個あり、うち3個（`trim` の値返却、走査対象のソート入力、誤名走査対象のソート入力）は違反出力ではない。残る **22個**が検査分岐である。

分岐の列挙は既存テスト・既存 fixture を出発点にせず、`lint-adr.sh` のヘッダ仕様（レイヤ1違反種別の列挙、レイヤ2〜5 の仕様記述）と条文（`adr-model.md`「状態の型」「index の同期」「識別子の一意性」「H1 見出しの形式と識別子部の整合」「採番方式」、`transitions.md`「上書き」、`cross-references.md`「機械検査の範囲」）から独立に導出した。列挙し終えてから、各分岐へ正例 corpus・負例 corpus・アサーションの所在を事後に突き合わせている。

内訳はレイヤ1が8、レイヤ2が2、レイヤ3 forward が3、レイヤ3 reverse が2、レイヤ4が2、レイヤ5が5の計22。

### 被覆に数えないテスト資産

`lint-adr-` の名を冠する bats のうち、次の2本は `lint-adr.sh` の**検査内容**を検査していないため、本被覆表の被覆源に数えない。名前と検査対象の不一致そのものは Task 6 の改名で解消する。

| ファイル（基準版時点の名） | 実際の検査対象 | 改名後 |
|---|---|---|
| `scripts/tests/lint-adr-index.bats` | `plugins/adr/scripts/gen-adr-index.sh`（index 生成器） | `scripts/tests/gen-adr-index.bats` |
| `scripts/tests/lint-adr-surface.bats` | `manage-adr` スキル面（参照ファイルの存在網羅・旧節の除去・節名参照の解決）。ただし面⑥・面⑦は `lint-adr.sh` のヘッダを消費する | `scripts/tests/manage-adr-surface.bats` |

`manage-adr-surface.bats` の面⑥・面⑦、および `lint-adr-xref.bats` 面⑥・`lint-adr-stem.bats` 面①は、いずれも `lint-adr.sh` のヘッダ記述が条文の第二の正本にならないことを守る**条文と実装のあいだの正本対応の検査**であり、検査分岐の被覆源ではない。被覆表には現れない。

### 表

「正例」欄は当該分岐が発火しないことを固定する corpus、「負例」欄は当該分岐を発火させる corpus を指す。corpus 名は `scripts/fixtures/lint-adr/` からの相対。アサーション欄は基準版時点の所在。

| 分岐ID | レイヤ | 検査分岐（違反メッセージの識別部） | 正例 corpus | 負例 corpus | アサーションの所在 |
|---|---|---|---|---|---|
| L1-1 | 1 | `status が空です` | `valid/01-mixed-validity` | `invalid/01-status-missing` / `invalid/06-multi-violation` | `lint-adr-layers.bats` 面②（表行 `01-status-missing`）・面④ |
| L1-2 | 1 | `status=承認済み だが validity が空です` | `valid/01-mixed-validity` | `invalid/02-validity-missing` | `lint-adr-layers.bats` 面②（表行 `02-validity-missing`） |
| L1-3 | 1 | `validity=上書き済み だが superseded-by が空です` | `valid/01-mixed-validity` | `invalid/03-superseded-by-missing` / `invalid/06-multi-violation` | `lint-adr-layers.bats` 面②（表行 `03-superseded-by-missing`）・面④ |
| L1-4 | 1 | `status の値 "…" が語彙にありません` | `valid/01-mixed-validity` | `invalid/12-status-unknown-vocab` | `lint-adr-layers.bats` 面②（表行 `12-status-unknown-vocab`） |
| L1-5 | 1 | `validity の値 "…" が語彙にありません` | `valid/01-mixed-validity` | `invalid/13-validity-unknown-vocab` | `lint-adr-layers.bats` 面②（表行 `13-validity-unknown-vocab`） |
| L1-6 | 1 | `status=… だが validity が空ではありません` | `valid/01-mixed-validity` | `invalid/14-proposed-with-validity` / `invalid/15-rejected-with-validity` | `lint-adr-layers.bats` 面②（表行 `14-` / `15-`） |
| L1-7 | 1 | `status=… だが superseded-by が空ではありません` | `valid/01-mixed-validity` | `invalid/30-proposed-with-superseded-by` / `invalid/31-rejected-with-superseded-by` | `lint-adr-layers.bats` 面②（表行 `30-` / `31-`） |
| L1-8 | 1 | `validity=… だが superseded-by が空ではありません` | `valid/01-mixed-validity` | `invalid/16-active-with-superseded-by` / `invalid/17-abandoned-with-superseded-by` | `lint-adr-layers.bats` 面②（表行 `16-` / `17-`） |
| L2-1 | 2 | `index 同期違反（index.md が存在しません）` | `valid/01-mixed-validity` | `invalid/32-index-missing` | `lint-adr-layers.bats` 面⑤ |
| L2-2 | 2 | `index 同期違反（gen-adr-index.sh の出力と一致しません` | `valid/01-mixed-validity` | `invalid/04-index-drift` | `lint-adr-layers.bats` 面⑤ |
| L3F-1 | 3 forward | `superseded-by=… に有効な参照先 stem がありません` | `valid/05-xref-list-trailing-comma` | `invalid/11-xref-list-empty-superseded` | `lint-adr-layers.bats` 面⑯ |
| L3F-2 | 3 forward | `superseded-by=… だが参照先 … が見つかりません` | `valid/04-xref-list` | `invalid/10-xref-list-forward-file-missing` | `lint-adr-layers.bats` 面⑮ |
| L3F-3 | 3 forward | `… の本文 "## 関連ADR" に "Supersedes: …" が見つかりません` | `valid/02-xref-valid` / `valid/04-xref-list` | `invalid/05-xref-missing` / `invalid/08-xref-list-forward-missing` | `lint-adr-layers.bats` 面⑦・面⑬ |
| L3R-1 | 3 reverse | `逆方向: 本文 "## 関連ADR" の "Supersedes: …" 宣言の参照先 … が見つかりません` | `valid/02-xref-valid` | `invalid/34-xref-reverse-dangling`（本 PR で新設） | `lint-adr-layers.bats` 面⑰（本 PR で新設） |
| L3R-2 | 3 reverse | `逆方向: … の front-matter superseded-by がそれを指していません` | `valid/02-xref-valid` / `valid/04-xref-list` | `invalid/07-xref-reverse-missing` / `invalid/09-xref-list-reverse-missing` | `lint-adr-layers.bats` 面⑩・面⑭ |
| L4-1 | 4 | `dangling 参照違反（"## 関連ADR" の Related 参照先 … が見つかりません）` | `valid/06-related-valid` | `invalid/20-related-dangling` | `lint-adr-xref.bats` 面②（正例側は面④） |
| L4-2 | 4 | `参照先退役違反（"## 関連ADR" の Related 参照先 … は validity=… の退役ADRです）` | `valid/06-related-valid` | `invalid/18-related-retired-no-bullet` / `invalid/19-related-retired-link` / `invalid/22-related-link-label` / `invalid/23-related-dup-report` | `lint-adr-xref.bats` 面①・面③・面⑤（正例側は面④・面⑦） |
| L5-1 | 5 | `ファイル名形式違反（… 時刻部は暦として妥当な12桁 …）` | `valid/01-mixed-validity` / `valid/07-legacy-filename-skipped` | `invalid/24-filename-format-invalid` / `invalid/25-filename-calendar-invalid` / `invalid/28-legacy-duplicate-id` | `lint-adr-stem.bats` 面④（正例側は面⑦・面⑧） |
| L5-2 | 5 | `H1 整合違反（本文の最初の "# " 見出しに ADR 識別子が見つかりません` | `valid/08-frontmatter-yaml-comment` | `invalid/33-h1-id-absent` | `lint-adr-stem.bats` 面⑥（正例側は面⑦・面⑧） |
| L5-3 | 5 | `H1 整合違反（H1 見出しの識別子部 … と一致しません）` | `valid/01-mixed-validity` | `invalid/27-h1-id-mismatch` | `lint-adr-stem.bats` 面⑥（正例側は面⑧） |
| L5-4 | 5 | `識別子重複違反（識別子 … を持つ ADR が … 本あります）` | `valid/01-mixed-validity` | `invalid/26-duplicate-adr-id` / `invalid/28-legacy-duplicate-id` | `lint-adr-stem.bats` 面⑤（正例側は面⑧） |
| L5-5 | 5 | `ファイル名が "ADR-" 接頭辞を欠くため全レイヤの走査対象から外れます` | `valid/07-legacy-filename-skipped` | `invalid/29-missing-adr-prefix` | `lint-adr-stem.bats` 面④ |

### 穴の名指し

基準版時点で負例 corpus とアサーションのいずれも持たない分岐は **L3R-1 の1件のみ**である。この分岐は、本文 `## 関連ADR` の `Supersedes: T` 宣言に対して `T` のファイルそのものが存在しない場合を報告する。

L3R-1 が穴であることは、22分岐のメッセージ needle を全40 corpus の出力へ突き合わせて機械的に確認した（後述「分岐の発火の測定」）。発火0件の分岐は L3R-1 のみで、他21分岐はいずれも1件以上の corpus で発火する。

穴の埋め方は Task 2（corpus の新設）と Task 7（アサーションの追加）に分けている。corpus を先に置くのは、後から足すと当該分岐が基準版との出力照合を素通りし、構造整理での退行を検出できなくなるためである。

## 分岐の発火の測定

22分岐それぞれのメッセージ needle を、照合対象の全 corpus の出力へ突き合わせる。needle は分岐ごとに一意になるよう選ぶ。特に L1-7（`status=… だが superseded-by が空ではありません（値 "…"。提案中・却下 は superseded-by を伴いません）`）と L1-8（`validity=… だが superseded-by が空ではありません（値 "…"。superseded-by を伴えるのは 上書き済み だけです）`）は共通の前半を持つため、後半の説明句で分ける。前半だけを needle にすると、片方の分岐を落としても他方の発火で埋まって0件にならない。

基準版での測定結果は次のとおり。発火回数の合計は36で、負例実測の `output_lines=36` と一致する（すべての出力行がいずれか1つの分岐へ帰属し、取りこぼしが無い）。

| 分岐ID | 発火回数 | 発火した corpus |
|---|---|---|
| L1-1 | 2 | `invalid/01-status-missing`, `invalid/06-multi-violation` |
| L1-2 | 1 | `invalid/02-validity-missing` |
| L1-3 | 2 | `invalid/03-superseded-by-missing`, `invalid/06-multi-violation` |
| L1-4 | 1 | `invalid/12-status-unknown-vocab` |
| L1-5 | 1 | `invalid/13-validity-unknown-vocab` |
| L1-6 | 2 | `invalid/14-proposed-with-validity`, `invalid/15-rejected-with-validity` |
| L1-7 | 2 | `invalid/30-proposed-with-superseded-by`, `invalid/31-rejected-with-superseded-by` |
| L1-8 | 2 | `invalid/16-active-with-superseded-by`, `invalid/17-abandoned-with-superseded-by` |
| L2-1 | 1 | `invalid/32-index-missing` |
| L2-2 | 1 | `invalid/04-index-drift` |
| L3F-1 | 1 | `invalid/11-xref-list-empty-superseded` |
| L3F-2 | 1 | `invalid/10-xref-list-forward-file-missing` |
| L3F-3 | 2 | `invalid/05-xref-missing`, `invalid/08-xref-list-forward-missing` |
| L3R-1 | **0** | **なし（穴）** |
| L3R-2 | 2 | `invalid/07-xref-reverse-missing`, `invalid/09-xref-list-reverse-missing` |
| L4-1 | 1 | `invalid/20-related-dangling` |
| L4-2 | 4 | `invalid/18-related-retired-no-bullet`, `invalid/19-related-retired-link`, `invalid/22-related-link-label`, `invalid/23-related-dup-report` |
| L5-1 | 4 | `invalid/24-filename-format-invalid`, `invalid/25-filename-calendar-invalid`, `invalid/28-legacy-duplicate-id` |
| L5-2 | 2 | `invalid/33-h1-id-absent` |
| L5-3 | 1 | `invalid/27-h1-id-mismatch` |
| L5-4 | 2 | `invalid/26-duplicate-adr-id`, `invalid/28-legacy-duplicate-id` |
| L5-5 | 1 | `invalid/29-missing-adr-prefix` |

## 未被覆分岐の穴埋め（負例 corpus の新設）

L3R-1 の負例として `scripts/fixtures/lint-adr/invalid/34-xref-reverse-dangling/` を新設した。構造整理へ着手する**前**に置いている。後から足すと、当該分岐の退行が基準版との出力照合を素通りし、レイヤ分解で分岐を壊しても差分0のまま通ってしまう。

corpus は ADR 1本と `index.md` だけで構成する。ADR は本文 `## 関連ADR` で実在しない `ADR-202612101034-01-xref-reverse-dangling-absent-old` への `Supersedes:` を宣言する一方、front-matter は合法な組（`status: 承認済み` ＋ `validity: 有効`、`superseded-by` なし）とし、ファイル名・H1・index のいずれもレイヤ1・2・5 を発火させない。**単一原因で違反1件**になる形に保つのは、他レイヤが同時に発火すると L3R-1 を落とす変異が赤にならないためである。

実測した出力は1行・終了コード1で、`invalid/07-xref-reverse-missing`（参照先は実在するが front-matter が追随していない）とは別の分岐へ到達する。

新設後の負例実測は次のとおり。数える対象は「lint が標準出力へ出す行の総数」であり「違反」の語を含む行ではない（レイヤ1のメッセージは `status が空です（…）` 等で「違反」の語を持たないため、語で数えると値が食い違う）。

| 時点 | 負例 corpus 数 | 終了コード1の件数 | 出力行の総数 | 発火0件の分岐 |
|---|---|---|---|---|
| 基準版 `c126d72` | 32 | 32 | 36 | 1（L3R-1） |
| corpus 新設後 | 33 | 33 | 37 | 0 |

負例ディレクトリ名は `01`〜`34` の連番だが `21` が欠番のため、実数は最大番号より1小さい。件数は最大番号ではなく実数で数える。

## 基準版との同一性照合の手順

検査内容が変更前後で同一であることは、正常 corpus の緑同士では示さない（緑同士の一致は検査内容が同一であることの証拠にならない。設計 spec の反証レビュー C-5）。基準版と作業版の双方へ全 corpus を通し、**負例を含めて**標準出力・標準エラーを併合した全文と終了コードを corpus ごとに突き合わせる。

```
BASE=$(mktemp -d)
git show c126d72:plugins/adr/scripts/lint-adr.sh > "$BASE/lint-adr.sh"
git show c126d72:plugins/adr/scripts/gen-adr-index.sh > "$BASE/gen-adr-index.sh"
diffs=0; total=0
for c in scripts/fixtures/lint-adr/valid/*/ scripts/fixtures/lint-adr/invalid/*/; do
  total=$((total+1))
  o=$(bash "$BASE/lint-adr.sh" "$c" 2>&1; echo "rc=$?")
  n=$(bash plugins/adr/scripts/lint-adr.sh "$c" 2>&1; echo "rc=$?")
  [ "$o" = "$n" ] || { diffs=$((diffs+1)); echo "DIFF: $c"; }
done
echo "corpora=$total diffs=$diffs"
```

生成器（`gen-adr-index.sh`）も同じ作業ディレクトリへ取り出す。基準版の `lint-adr.sh` は同梱の生成器を `dirname "$0"` で解決するため、取り出さないとレイヤ2 が生成器不在で落ち、差分が「実装の違い」ではなく「取り出し漏れ」に化ける。

照合は両ストリームを併合して行う。実装が標準エラーへ書くのは対象ディレクトリ不在の1経路のみで、照合対象の corpus はいずれもその経路へ入らない。ストリームの分離は `lint-adr-layers.bats` の存在しないディレクトリを渡すケースが別途担保する。

この照合は構造整理の各段で手で走らせる**一回限りの検証**であり、テストスイートへ常設しない（設計 spec 節4 が上位検証層の再導入を禁じており、常設すると基準版の保持先と版据え置きの問題が新たに生じるため）。

**手順が空振りしないことの確認**: 実装を一切変えていない状態（新設 corpus のみを足した状態）で1回走らせ、`base=c126d72 corpora=41 diffs=0` を得た。以降の各段でこの照合を再実行する。

## テストの再編と穴埋め

被覆表を根拠に、穴の埋め合わせとレイヤ単位の独立起動を検査する面を置いた。既存アサーションは触っていない（設計 spec 節4 の「4ファイル914行を書き直し」は策定時点の現況に基づく指示であり、そのまま実行すると直前の Issue #793 が投入した被覆と変異実測を作り直すことになるため、被覆表起点の再編と穴埋めへ縮退させている）。

| 面 | ファイル | 何を固定するか |
|---|---|---|
| 面⑰ | `scripts/tests/lint-adr-layers.bats` | L3R-1（逆方向で宣言の参照先そのものが不在）の検出。終了コード1と、逆方向・宣言の参照先・不在の参照先名を名指しする違反メッセージ。参照先が実在して front-matter だけが追随していない経路（L3R-2）のメッセージが出ないこと、および他レイヤの違反が混ざらないこと |
| 面⑱ | `scripts/tests/lint-adr-layers.bats` | レイヤ単位の独立起動。起動しなかったレイヤの違反が出ないこと（両方向）、起動したレイヤの違反は出ること、収集済みの事実を消費する側が偽陽性を出さないこと |
| 面⑲ | `scripts/tests/lint-adr-layers.bats` | 読み込みだけでは対象ディレクトリ不在の経路へ入らないこと。直接実行では従来どおり終了コード2であること |
| 面⑧ | `scripts/tests/lint-adr-xref.bats` | レイヤ4 の単独起動。起動したレイヤの違反は出て、起動しなかったレイヤ（レイヤ5）の違反は出ないこと |

### 独立起動の観測の形

読み込みは**部分シェル経由**で行う（共有ヘルパの `run_sut_layer`）。ケース内で直接読み込むと検査器の `set -euo pipefail` が bats 本体のシェルへ漏れ、`nounset` の下で収集型ヘルパの空配列参照が異常終了しうる。部分シェルなら観測できるのは出力と終了コードだけになり、連想配列の中身などの内部状態は見られない。この代償は受け入れ、レイヤ間に検査の依存が無いことを外から確かめる形に留める。

面⑱・面⑧のいずれも、「起動しなかったレイヤの違反が出ない」だけでなく **「起動したレイヤの違反は出る」** を対で置いている。前者だけだと、レイヤ関数の中身を空にする変異でも緑のまま通り、独立性の検査が「何も検査しない」ことの確認へ退化する。

面⑱にはさらに、収集済みの事実を消費する側が偽陽性を出さないことの項を置いた。写像を作る単位が連想配列を関数ローカルで宣言してしまうと後続のレイヤから見えなくなり、双方向が揃った正例 corpus に対して「front-matter superseded-by がそれを指していません」の偽陽性が出る。この経路を負例側の項だけで検出することはできない。

### ケース数の増減

| 時点 | bats ケース総数 | 内訳 |
|---|---|---|
| 基準版 `c126d72` | 150 | — |
| 本 PR 後 | 154 | `lint-adr-layers.bats` に面⑰・面⑱・面⑲の3件、`lint-adr-xref.bats` に面⑧の1件 |

改名（`lint-adr-index.bats` → `gen-adr-index.bats`、`lint-adr-surface.bats` → `manage-adr-surface.bats`）はケース数を動かさない。
