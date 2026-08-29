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

レビュー対応で新設した `invalid/35-layer-order` は表の「負例 corpus」欄に載せていない。この corpus は L1-1・L2-1・L3F-3・L3R-2・L4-2・L5-1 の6分岐を同時に発火させるが、目的は違反の**出力順**の観測であり、いずれの分岐についても単一原因の負例が既に在る。被覆の出典を多重化すると、分岐を落とす変異がどの corpus で赤になるかが読めなくなる。発火の事実は次節の測定表に現れる。

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
| レビュー対応後（`invalid/35-layer-order` 追加） | 34 | 34 | 43 | 0 |

負例ディレクトリ名は `01`〜`35` の連番だが `21` が欠番のため、実数は最大番号より1小さい。件数は最大番号ではなく実数で数える。

最終行の出力行の総数が6行増えるのは、`invalid/35-layer-order` が6つの検査単位を1本ずつ同時に発火させるためである（他の負例はいずれも単一レイヤの違反しか出さない）。

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

レビュー対応で `invalid/35-layer-order` を足したあとの再実行は `base=c126d72 corpora=42 diffs=0` である。収集の印（後述）を実装へ足しても差分が出ないのは、印を欠いた起動が直接実行の経路には現れないためであり、基準版と同一であることの根拠はこの照合が引き続き担う。

## テストの再編と穴埋め

被覆表を根拠に、穴の埋め合わせとレイヤ単位の独立起動を検査する面を置いた。既存アサーションの判定内容は触っていない（設計 spec 節4 の「4ファイル914行を書き直し」を字義どおりに実行すると、直前の Issue #793 が投入した被覆と変異実測を作り直すことになるため、被覆表起点の再編と穴埋めへ縮退させている。数値の出所については後述「設計 spec の射程に対して実施しなかったこと」を参照）。

下表のうち面⑳・面㉑・面㉒と `lint-adr-stem.bats` の下限は、PR #801 のレビュー指摘への対応として足したものである。

| 面 | ファイル | 何を固定するか |
|---|---|---|
| 面⑰ | `scripts/tests/lint-adr-layers.bats` | L3R-1（逆方向で宣言の参照先そのものが不在）の検出。終了コード1と、逆方向・宣言の参照先・不在の参照先名を名指しする違反メッセージ。参照先が実在して front-matter だけが追随していない経路（L3R-2）のメッセージが出ないこと、および他レイヤの違反が混ざらないこと |
| 面⑱ | `scripts/tests/lint-adr-layers.bats` | レイヤ単位の独立起動（SCAN_TARGETS を読む側）。起動しなかったレイヤの違反が出ないこと（両方向）、起動したレイヤの違反は出ること、収集済みの事実を消費する側が偽陽性を出さないこと |
| 面⑲ | `scripts/tests/lint-adr-layers.bats` | 読み込みだけでは対象ディレクトリ不在の経路へ入らないこと。直接実行では従来どおり終了コード2であること |
| 面⑳ | `scripts/tests/lint-adr-layers.bats` | `FM_FILES` を読む3単位（レイヤ1・レイヤ3 forward・レイヤ5）それぞれの独立起動。起動した単位の違反は出ること、起動しなかった単位の違反は出ないこと |
| 面㉑ | `scripts/tests/lint-adr-layers.bats` | 違反の出力順が起動部の呼び出し順で決まること。6単位を1本ずつ同時に発火させる corpus で、隣接する5境界すべての相対順序と「1単位1件」の出力行数 |
| 面㉒ | `scripts/tests/lint-adr-layers.bats` | 収集を欠いたレイヤ起動が合格を返さないこと。事実を読む5単位が理由つきで非0に戻り違反件数を報告しないこと、印を要求しないレイヤ2 は従来どおり起動できること、収集を経た起動は検査を実行すること |
| 面⑧ | `scripts/tests/lint-adr-xref.bats` | レイヤ4 の単独起動。起動したレイヤの違反は出て、起動しなかったレイヤ（レイヤ5）の違反は出ないこと |
| 面②・面③の下限 | `scripts/tests/lint-adr-stem.bats` | 受理表・拒否表の照合が実際に走った回数。表を空にしても9件緑のまま通る経路（`lint-adr-layers.bats` の `LAYER1_INVALID_CASE_MIN` と同型の穴）を塞ぐ |

### 独立起動の観測の形

読み込みは**部分シェル経由**で行う（共有ヘルパの `run_sut_layer`）。ケース内で直接読み込むと検査器の `set -euo pipefail` が bats 本体のシェルへ漏れ、`nounset` の下で収集型ヘルパの空配列参照が異常終了しうる。部分シェルなら観測できるのは出力と終了コードだけになり、連想配列の中身などの内部状態は見られない。この代償は受け入れ、レイヤ間に検査の依存が無いことを外から確かめる形に留める。

面⑱・面⑧のいずれも、「起動しなかったレイヤの違反が出ない」だけでなく **「起動したレイヤの違反は出る」** を対で置いている。前者だけだと、レイヤ関数の中身を空にする変異でも緑のまま通り、独立性の検査が「何も検査しない」ことの確認へ退化する。

面⑱にはさらに、収集済みの事実を消費する側が偽陽性を出さないことの項を置いた。写像を作る単位が連想配列を関数ローカルで宣言してしまうと後続のレイヤから見えなくなり、双方向が揃った正例 corpus に対して「front-matter superseded-by がそれを指していません」の偽陽性が出る。この経路を負例側の項だけで検出することはできない。

### ケース数の増減

| 時点 | bats ケース総数 | 内訳 |
|---|---|---|
| 基準版 `c126d72` | 150 | — |
| 構造整理・穴埋め後 | 154 | `lint-adr-layers.bats` に面⑰・面⑱・面⑲の3件、`lint-adr-xref.bats` に面⑧の1件 |
| レビュー対応後 | 157 | 上記に加え `lint-adr-layers.bats` へ面⑳・面㉑・面㉒の3件 |

改名（`lint-adr-index.bats` → `gen-adr-index.bats`、`lint-adr-surface.bats` → `manage-adr-surface.bats`）はケース数を動かさない。`lint-adr-stem.bats` へ足した照合件数の下限は既存の面②・面③の中の検査項目であり、ケース数を動かさない。

## 検出力の変異実測

新設・改訂した箇所について、実装側を1件ずつ壊して対応するテストが赤になることを実測した。変異は当てるたびに元へ戻している。これは**一回限りの実測**であり、変異検査を常設の検証層として持ち込むものではない（設計 spec 節4 の制約）。

構造整理そのものの妥当性は基準版との出力全文照合が担うため、既存アサーションを触っていない分岐については再実測していない。

測定は bats 一式（`mise exec -- bats scripts/tests/`）を走らせ、`not ok` の行を拾う形で行った。

| # | 当てた変異 | 期待 | 実測（赤になったケース） | 判定 |
|---|---|---|---|---|
| M1 | L3R-1（逆方向で宣言の参照先が不在）の `printf` と件数加算を落とす | 面⑰が赤 | `lint-adr-layers.bats` 面⑰・面⑱ | 期待どおり |
| M2 | `collect_facts` の `declare -gA FM_SB_BY_STEM` を `declare -A` にする（写像が関数ローカルに閉じる＝**正例が赤へ転じる側**） | 合法な組を違反として報告し、正例 corpus のケースが赤 | 正例側 `lint-adr-layers.bats` 面①・面⑥・面⑧・面⑨・面⑪・面⑫、`lint-adr-stem.bats` 面⑦・面⑧、`lint-adr-xref.bats` 面④・面⑦ を含む計30ケース。面⑱の偽陽性項も赤 | 期待どおり |
| M3 | `check_layer4_related_references` を即 `return 0` させる（単独起動が「何も検査しない」側へ退化） | `lint-adr-xref.bats` 面⑧が赤 | `lint-adr-xref.bats` 面①・面②・面③・面⑤・面⑧ | 期待どおり |
| M4 | 直接実行と読み込みを分ける判定を `if true` にする（読み込みでも検査本体が走る） | 面⑲が赤 | `lint-adr-layers.bats` 面⑱・面⑲、`lint-adr-stem.bats` 面②・面③、`lint-adr-xref.bats` 面⑧ | 期待どおり |
| M5 | `ADR_STEM_PATTERN` の定数名を変える（読み込みによる定数取得の検出力） | `lint-adr-stem.bats` 面②・面③が赤 | 上記2件を含む計19ケース | 期待どおり |
| M6 | `collect_facts` から `FM_FILES+=("$file")` を落とし、`check_layer1_frontmatter_schema` の先頭で `SCAN_TARGETS` から充填し直す（**本 PR が解いた結合の再導入**） | 面⑳が赤 | `lint-adr-layers.bats` 面⑳ のみ | 期待どおり |
| M7 | 起動部のレイヤ4／レイヤ5 の呼び出し2行を入れ替える（出力順の破壊） | 面㉑が赤 | `lint-adr-layers.bats` 面㉑ のみ | 期待どおり |
| M8 | `require_collected` の判定を常に真にする（収集の印を無効化し fail-open へ戻す） | 面㉒が赤 | `lint-adr-layers.bats` 面㉒ のみ | 期待どおり |
| M9 | 印を要求しないレイヤ2 へも `require_collected` を足す（**免除が消える側＝正例が赤へ転じる向き**） | 面㉒の「レイヤ2 は収集を欠いても起動できる」項が赤 | `lint-adr-layers.bats` 面㉒ のみ | 期待どおり |
| M10 | `STEM_ACCEPT` を空表にする | `lint-adr-stem.bats` 面②が赤 | `lint-adr-stem.bats` 面② のみ | 期待どおり |
| M11 | `STEM_REJECT` を空表にする | `lint-adr-stem.bats` 面③が赤 | `lint-adr-stem.bats` 面③ のみ | 期待どおり |

### 読み方

- **M1 で面⑱も赤になるのは正しい。** 面⑱の「起動したレイヤの違反は出る」項が `invalid/34` へレイヤ3 reverse を単独起動して違反1件を期待しており、これも L3R-1 に対応する負例のケースである。M1 は L3R-1 の負例だけを赤にしており、他の分岐のケースは緑のまま残っている。
- **M3 は独立起動の面が退化を捕まえることの実測である。** 面⑧が「起動しなかったレイヤの違反が出ない」だけを見ていたら、レイヤ関数を空にする変異でも緑のまま通る。対で置いた「起動したレイヤの違反は出る」項がこの経路を塞いでいる。同時に赤になる面①〜⑤はいずれも全体起動でレイヤ4 の違反を期待するケースであり、変異の直接の帰結である。
- **M2 と M5 の赤の広さは変異の性質による。** どちらも1つの分岐ではなく、複数レイヤが共有する事実・定数を壊すため、影響が全レイヤへ及ぶ。M2 は正例が赤へ転じる側の対として置いており、落とす方向（M1・M3）だけでは無検査で残る「免除・除外が広がる」向きの退行を押さえる。
- **配布物配下を触る変異でも版据え置き検査は赤にならなかった。** マニフェストの版は Task 3 で `0.7.1` → `0.7.2` へ繰り上げ済みであり、`origin/main` に対して既に前進しているため、`plugins/adr/` へ差分が増えても `validate-plugin-versions` は発火しない。M3 を当てた状態で `bash scripts/run-tests.sh validate-plugin-versions` が `ok` であることを実測した。
- **M6〜M11 はいずれも赤が1ケースに収まっている。** M1〜M5 が複数レイヤの共有物（写像・定数・起動の判定）を壊すのに対し、M6〜M11 が壊すのは単位の境界・呼び出し順・印・表という1点であり、それを観測する面が1つずつ在る。裏を返せば、これらの面が無かった時点ではいずれの変異も**全ケース緑のまま通っていた**（レビュー指摘1〜3が示したのはこの状態である）。
- **M9 は免除の側を押さえる対である。** 収集の印を要求する5単位に対し、レイヤ2 だけは要求しない。落とす方向（M8）だけを置くと、要求を全単位へ一律に広げる変更が無検査で通り、レイヤ2 の免除が根拠なく消える。面㉒は要求する側と免除される側を同一ケース内で持つ。
- 変異を戻したあと `bash scripts/run-tests.sh` が全スイート緑（`157 tests, 0 failures`）へ戻ることを確認した。

## ADR 化要否の判定

判定に用いた条文は `plugins/adr/skills/manage-adr/references/adr-scoping.md` の **commit `c126d72` 時点の版**（138行）である。以降 main が動いても本判定はこの版に照らしたものとして読む。

本 PR が下した設計判断は6件ある（D1〜D4 が構造整理の段、D5・D6 がレビュー対応の段）。条文の手続きに従い、まず必要条件（採らなかった選択肢とその却下理由が対として特定できること）を確認し、成立する場合のみ粒度判定基準の4項目を判定した。発見型の短絡はいずれの決定にも適用していない（本件はいずれも未記録の規範の発見ではなく、意図的に下した設計判断であるため）。したがって6件とも4項目すべてを判定している。

`lint-adr-stem.bats` へ足した照合件数の下限は判定の対象に数えない。既に `lint-adr-layers.bats` が持つ規範（照合件数の下限は実行時の照合回数を数える）を同型の箇所へ適用しただけであり、新たな設計判断ではない。

件数を数えた項目については、数えた対象を列挙する。

### D1: レイヤ分解の実現形を関数抽出のみに留める

**必要条件: 成立。**

| 採らなかった選択肢 | 却下理由 |
|---|---|
| レイヤを選択する CLI オプションを足す | 配布物の公開インターフェースを広げるため反転コストが上がり、commit 前ゲートの呼び出し形にも掛かる |
| レイヤごとに別ファイルへ分割する | 配布物のファイル数が増えるうえ、既存の検査がヘッダブロックから `# レイヤN` 宣言を動的抽出して条文側の対応表と照合しているため、レイヤ仕様の記述をファイルへ散らすと当該照合が壊れる |

| 項目 | 点数 | 根拠 |
|---|---|---|
| 1. 後戻りコスト | **1** | 反転時に直す追跡下ファイルは4件で閾値3件に達する。列挙は `plugins/adr/scripts/lint-adr.sh`（関数定義と起動部）、`scripts/tests/helpers/common.bash`（`run_sut_layer` が関数名と読み込み口を前提にする）、`scripts/tests/lint-adr-layers.bats`（面⑱・面⑲）、`scripts/tests/lint-adr-xref.bats`（面⑧）。両マニフェストの version 繰り上げは配布物差分に伴う機械的追随として別に生じる。構造変更・スキーマ変更・配布済み成果物への利用者影響・蓄積済みデータ移行の4種はいずれも非該当（CLI・終了コード・違反メッセージは不変であり、利用者から見た提供物は変わらない） |
| 2. 適用先 | **0** | 本決定の規範（レイヤは同一ファイル内の関数として独立起動できる形にする）が適用される最小単位を、`lint-adr.sh` という実行可能単位1つと読むか、6つのレイヤ関数を入れ子の最小単位へ分解して6単位と読むかで結論が割れる。項目単位の同点処理に従い0点へ倒した |
| 3. 理由の揮発 | **0** | 値域(A)に当たる保持先が在る。本決定を体現する実装本体 `lint-adr.sh`（関数定義と起動部）と、独立起動を検査するテスト（`lint-adr-layers.bats` 面⑱・面⑲、`lint-adr-xref.bats` 面⑧、共有ヘルパ `run_sut_layer`）がそれである。(A) は理由の記載や強制の稼働を問わず0点とする |
| 4. 自動強制 | **0** | 阻止の状態は `現に阻止`。レイヤ単位の独立起動が壊れると面⑱・面⑲・`lint-adr-xref.bats` 面⑧ が赤になることを、変異 M3（レイヤ4 を即 return）と M4（起動判定を常に真）で実測している |

**合計1点。スコア境界3点未満のため ADR 化しない（非該当）。**

### D2: テスト再設計の射程を被覆表起点の再編と穴埋めへ縮退させる

**必要条件: 成立。**

| 採らなかった選択肢 | 却下理由 |
|---|---|
| lint 系 bats を全面書き直しする（設計 spec 節4 の字義） | そのまま実行すると直前の Issue #793 が投入した負例 fixture 4本と変異実測8件の被覆を作り直すことになる（spec の「4ファイル914行」の数値そのものは後述のとおり5ファイルの合計を4ファイルと書いたものだが、却下理由はこの数値に依存しない） |
| 構造整理への追随のみに留める | 節4 が求める「網羅の根拠を挙動の列挙に置く」が得られず、被覆の穴が残る |

| 項目 | 点数 | 根拠 |
|---|---|---|
| 1. 後戻りコスト | **0** | 反転（全面書き直しへ進む）時に手が入る追跡下ファイルは `lint-adr-layers.bats` / `lint-adr-stem.bats` / `lint-adr-xref.bats` の3本だが、これらは反転が命じる作業そのものであって、反転により既存の記述が矛盾するわけではない（現行のアサーションは反転後も真であり続ける）。除外規則が「追加だけで矛盾しないファイルは数えない」と矛盾を軸に置いていることに照らし、数えるか迷う。項目単位の同点処理に従い0点へ倒した |
| 2. 適用先 | **0** | 本決定の規範（テスト再設計は被覆表起点で行い、既存アサーションを事後照合する）が適用される最小単位を、本 PR のテスト再編1件と読むか、対象となる3本の bats と読むかで結論が割れる。同点処理に従い0点へ倒した |
| 3. 理由の揮発 | **1** | 値域に当たる保持先が無い。(A) 本決定を強制する実装・テスト資産・操作手順は存在しない。(B) 共有規約ファイル・プロジェクト指示ファイルにも書かれていない（被覆表と採用理由は `docs/development/` の作業記録に在るが、作業記録は(B)の値域外である）。したがって条件1〜3を評価し、条件1（却下理由が採用理由とは別に必要である）に該当した。採用理由（被覆の根拠を実装ヘッダと条文から独立に導出し、既存アサーションを事後照合する形が節4 の眼目を満たす）からは、なぜ全面書き直しを採らなかったか＝#793 が投入した被覆と変異実測を作り直すことになる、は導けない |
| 4. 自動強制 | **1** | 阻止の状態は `検査なし`。本決定への違反（テストを全面書き直しする／追随のみに留める）を検出・阻止する検査はリポジトリに無い |

**合計2点。スコア境界3点未満のため ADR 化しない（非該当）。**

### D3: テスト資産の帰属を整理する（改名と、lint を直接消費する2面の帰属の定義）

**必要条件: 成立。**

| 採らなかった選択肢 | 却下理由 |
|---|---|
| 改名を別 Issue へ出す | 名前と検査対象の不一致がレイヤ単位の被覆の根拠を読み違えさせる直接の原因であり、被覆表に「ファイル名が示す対象と実際の対象が違う」注記を残し続けることになる |
| 面⑥・面⑦を lint 側のテストへ切り出してから改名する | 面の移設が増え、Issue #794 が同一ファイルへガード面（面⑦）を足す予定と衝突しうる |
| 改名自体を見送り、被覆表の注記で済ませる | `lint-adr.sh` を直接消費する検査が manage-adr の名を冠する逆向きの不整合が残る |

| 項目 | 点数 | 根拠 |
|---|---|---|
| 1. 後戻りコスト | **1** | 反転時に直す追跡下ファイルは7件で閾値3件に達する。列挙は `scripts/tests/gen-adr-index.bats`（改名を戻す）、`scripts/tests/manage-adr-surface.bats`（改名を戻し冒頭の帰属定義を除く）、`scripts/run-tests.sh`（`EXPECTED_BATS` の2行とコメント。戻さないと双方向照合が赤になる）、`scripts/tests/lint-adr-layers.bats` と `scripts/tests/lint-domain-doc.bats`（コメント本文の旧名参照が偽になる）、`docs/development/plugin-path-reference-ledger.md`（登録行。戻さないと `missing` が出る）、`docs/superpowers/specs/2026-08-27-adr-plugin-simplification-design.md`（節5 の注記が偽になる）。加えて「ファイル群の構造変更」（テストファイルの改名）にも該当する |
| 2. 適用先 | **1** | 規範（bats の名は検査対象と一致させ、一致しない面は帰属を定義する）が適用される最小単位は2件。列挙は `scripts/tests/gen-adr-index.bats` と `scripts/tests/manage-adr-surface.bats` であり、条文の「同じプラグイン内の別スクリプトは別単位とする」に照らして別々の実行可能単位である。決定を記録する ADR と追跡用 Issue は含まない |
| 3. 理由の揮発 | **1** | 値域に当たる保持先が無い。(A) 名前と検査対象の一致を強制する実装・テストは存在しない（`EXPECTED_BATS` はファイル名の固定列挙であり、名前と検査対象の対応は検査しない）。帰属の定義は `manage-adr-surface.bats` の冒頭コメント＝散文であり、「散文だけの記述は(A)ではなく」に当たる。(B) 共有規約ファイル・プロジェクト指示ファイルにも本決定は書かれていない。したがって条件1〜3を評価し、条件1に該当した。採用理由（名前と検査対象の不一致が被覆の根拠を読み違えさせる）からは、なぜ面を移設しなかったか＝#794 のガード面追加と衝突しうる、は導けない |
| 4. 自動強制 | **1** | 阻止の状態は `検査なし`。名前と検査対象の一致を検査する機構は無い。改名を戻すと `EXPECTED_BATS` の双方向照合と参照台帳は赤になるが、これらが守るのは「列挙と実在が一致すること」であって本決定の規範ではない |

**合計4点。スコア境界3点以上のため ADR 化を推奨する。**

起票の時期は判定とは別の軸であり、条文「起票のタイミングとエスカレーション」が「最初から ADR にしようとせず、まず PR の説明に判断を書く。後から他の機能でも同じ問いが出てきた時点で ADR に昇格させる」と定める。本決定をこの規定に従って PR 説明へ留めるか、既に問いが2度（面⑥＝Issue #722 / PR #792、面⑦＝Issue #794 / PR #799）現れていることを「他でも同じ問いが出てきた」と読んで即時に昇格させるかは、条文の字義だけでは決まらないため、時期の判断をユーザーへ上げた。

**決着（2026-08-29 ユーザー裁定）: 本 PR では起票せず、PR 説明へ判断を書く。** 条文の起票タイミング規定の字義に従う。判定そのものは4点・ADR 化推奨として本記録に残るため、次に同じ問い（`lint-adr.sh` を直接消費する面が manage-adr 側に増える、あるいは他の bats で名前と検査対象の不一致が生じる）が現れた時点で、本節を根拠に昇格させる。PR 説明には決定の内容と、上表の却下代替3件を書く。

### D4: 検査内容の同一性を基準版との全 corpus 出力全文照合で示し、常設ゲート化しない

**必要条件: 成立。**

| 採らなかった選択肢 | 却下理由 |
|---|---|
| 正常 corpus の緑同士の一致で示す | 設計 spec の反証レビュー C-5 が「正常 corpus での緑同士の一致は検査内容が同一であることの証拠にならない」と明示的に否定している |
| 照合を常設の二重実行ゲートとしてテストスイートへ置く | 設計 spec 節4 の「変異検査・判定契約検査などの上位検証層は再導入しない」に反する。加えて基準版の保持先という新たな版据え置きの問題を生む |

| 項目 | 点数 | 根拠 |
|---|---|---|
| 1. 後戻りコスト | **0** | 反転（常設ゲート化）時に生じるのは新規 bats の追加、`run-tests.sh` の `EXPECTED_BATS` への1行追加、基準版の保持先の新設であり、いずれも追加が主で既存の記述が矛盾するものは無い。閾値3件に達するか迷うため、同点処理に従い0点へ倒した |
| 2. 適用先 | **0** | 本決定の規範（同一性の照合は一回限りで行い常設化しない）が適用される最小単位を、本 PR の照合1件と読むか、将来の同種の構造整理すべてと読むかで結論が割れる。同点処理に従い0点へ倒した |
| 3. 理由の揮発 | **1** | 値域に当たる保持先が無い。照合手順と実測は本作業記録に在るが、作業記録は(A)にも(B)にも当たらない。したがって条件1〜3を評価し、条件1に該当した。採用理由（負例を含む全文照合で示す）からは、なぜ常設化しなかったか＝上位検証層の再導入にあたり基準版の保持先という据え置き問題を生む、は導けない |
| 4. 自動強制 | **1** | 阻止の状態は `検査なし`。本決定への違反（照合を常設ゲートへ昇格させる）を検出・阻止する検査は無い |

**合計2点。スコア境界3点未満のため ADR 化しない（非該当）。**

### D5: レイヤ単位の起動の契約違反を、収集の完了印による fail-closed へ変える

**必要条件: 成立。**

| 採らなかった選択肢 | 却下理由 |
|---|---|
| レイヤ5 にだけ印を要求する（誤名走査だけが走って出力が出る最も誤読しやすい経路のみを塞ぐ） | 他4単位の無言の合格が残り、「未収集」と「対象0件」を畳む型そのものは温存される |
| 実装は変えず、ヘッダへ前提条件を明記するに留める | 契約違反が合格を返す事実は変わらず、テストからも観測できない（明記の有無は挙動を動かさない） |
| 印を持たず、各レイヤの冒頭で収集を毎回呼ぶ（冪等化） | 単独起動のたびに走査と front-matter 解析が走り、Issue #800 が分離した「収集」と「検査」の責務が再び1つの単位へ混ざる |

| 項目 | 点数 | 根拠 |
|---|---|---|
| 1. 後戻りコスト | **1** | 反転時に直す追跡下ファイルは3件で閾値3件に達する。列挙は `plugins/adr/scripts/lint-adr.sh`（印の宣言・`require_collected`・5単位のガード）、`scripts/tests/helpers/common.bash`（`invoke_sut_layer` / `run_sut_layer_uncollected`）、`scripts/tests/lint-adr-layers.bats`（面㉒）。両マニフェストの version 繰り上げは配布物差分に伴う機械的追随として別に生じる。構造変更・スキーマ変更・配布済み成果物への利用者影響・蓄積済みデータ移行の4種はいずれも非該当（直接実行の CLI・終了コード・違反メッセージ・出力順は不変であり、印が現れるのは読み込み経由の起動だけである） |
| 2. 適用先 | **0** | 本決定の規範（収集済みの事実を読む単位は起動時に印を要求する）が適用される最小単位を、`lint-adr.sh` という実行可能単位1つと読むか、要求する5単位と読むかで結論が割れる。項目単位の同点処理に従い0点へ倒した |
| 3. 理由の揮発 | **0** | 値域(A)に当たる保持先が在る。`require_collected` と5単位のガード、および面㉒が本決定を体現し、かつ強制する。(A) は理由の記載や強制の稼働を問わず0点とする |
| 4. 自動強制 | **0** | 阻止の状態は `現に阻止`。印を無効化する変異 M8 と、免除されるレイヤ2 へ要求を広げる変異 M9 のいずれでも面㉒が赤になることを実測している |

**合計1点。スコア境界3点未満のため ADR 化しない（非該当）。**

### D6: 出力順の固定を、6単位を同時に発火させる負例 corpus 1本で行う

**必要条件: 成立。**

| 採らなかった選択肢 | 却下理由 |
|---|---|
| 2レイヤだけを発火させる corpus を1本足す（レビュー指摘が示した最小形） | 隣接する5境界のうち1つしか観測されず、宣言の大部分が無検査で残る |
| 出力順の宣言をヘッダから削り、検査を足さない | 出力順は Issue #800 が振る舞い不変の一部として挙げており、宣言を削ると基準版照合が守っている対象が実装の記述から消える |
| 既存の複数違反 corpus（`06` / `28` / `33`）へ別レイヤの違反を足す | これらは単一原因の負例として分岐の被覆に使われており、違反を足すと当該分岐を落とす変異でどの corpus が赤になるかが読めなくなる |

| 項目 | 点数 | 根拠 |
|---|---|---|
| 1. 後戻りコスト | **1** | 反転時に直す追跡下ファイルは8件で閾値3件に達する。列挙は `scripts/fixtures/lint-adr/invalid/35-layer-order/` の ADR 7本と `scripts/tests/lint-adr-layers.bats`（面㉑と needle 表）。構造変更・スキーマ変更・配布済み成果物への利用者影響・蓄積済みデータ移行の4種はいずれも非該当（配布物へは差分が入らない） |
| 2. 適用先 | **0** | 本決定の規範（出力順は常設のテストで固定する）が適用される先は `lint-adr.sh` の起動部1つであり、複数単位へ展開されない |
| 3. 理由の揮発 | **0** | 値域(A)に当たる保持先が在る。`invalid/35-layer-order` と面㉑が本決定を体現し、かつ強制する |
| 4. 自動強制 | **0** | 阻止の状態は `現に阻止`。起動部のレイヤ4／レイヤ5 の呼び出しを入れ替える変異 M7 で面㉑が赤になることを実測している |

**合計1点。スコア境界3点未満のため ADR 化しない（非該当）。**

### 確かめられなかった事実

無し。4件の判定に用いた事実（反転時に直すファイルの列挙、規範の適用先の列挙、保持先の値域の成否、判定時点の阻止の状態）はいずれも作業ディレクトリ上で確認している。

## レビュー指摘への対応（PR #801）

指摘は4件。いずれも一次情報で再現・確認したうえで対応した。

### 1. レイヤ単位の独立起動を守る検査が `FM_FILES` を読む3レイヤを1つも覆っていない

**確認**: `run_sut_layer` の呼び出しは全 bats で6箇所あり、対象は `check_layer2_index_sync` / `check_layer3_reverse` / `check_layer4_related_references` の3単位に限られていた。実装で `FM_FILES` を読むのはレイヤ1・レイヤ3 forward・レイヤ5 の3単位であり、そのいずれも独立起動されていなかった。`helpers/common.bash` のレイヤ1 分岐（引数を取らない単位の起動口）はどのテストからも到達していなかった。

**対応**: 面⑳を新設し、3単位それぞれの独立起動と、起動しなかった単位の違反が出ないことを対で置いた。これで AC1 の「任意の1レイヤ」が6単位すべてで観測される。検出力は M6 で実測した（本 PR が解いた結合を `FM_FILES` について再導入する変異が、対応前は全ケース緑のまま通っていた）。

### 2. 「違反の出力順は呼び出し順で決まる」宣言を守る検査が無い

**確認**: 負例33本のうち違反が2件以上出るのは3本（`06-multi-violation` 2行・`28-legacy-duplicate-id` 3行・`33-h1-id-absent` 2行）で、いずれも同一レイヤ内の違反であった。レイヤ間の相対順序はどのアサーションにも観測されておらず、起動部の2行を入れ替えても全ケースが緑のまま通った。

**対応**: 6単位を1本ずつ同時に発火させる負例 corpus `invalid/35-layer-order` を新設し、面㉑で隣接する5境界すべての相対順序と出力行数（1単位1件）を固定した。needle は単位を一意に決める断片を選び、レイヤ3 の2単位が共有する `相互参照違反` は採らない（どちらの行にも一致して順序を観測できなくなる）。検出力は M7 で実測した。

### 3. 収集を欠いたレイヤ起動が「違反0件・exit 0」を返す

**確認**: 収集を呼ばずにレイヤ関数を起動すると、空配列参照の退避形と連想配列の既定値が「未収集」と「対象0件」を同じ値へ畳み、5単位すべてが無言で違反0件・exit 0 を返した。レイヤ5 は誤名走査だけが走るため、corpus によっては出力まで出る（`invalid/29` で違反1行・rc=0）。

**対応**: 収集単位が完了印（`SCAN_TARGETS_COLLECTED` / `FACTS_COLLECTED`）を立て、収集済みの事実を読む5単位が `require_collected` で印を要求する形にした。印が立っていなければ標準エラーへ理由を出し非0で戻る。`collect_facts` 自身も走査対象を消費する単位であるため同じ印を要求する（要求しないと穴が下流へ移る）。`collect_scan_targets` は下流の印を倒し、走査対象を入れ替えたのに事実を収集し直していない状態を未収集と同じ扱いにする。

レイヤ2 だけは印を要求しない。収集済みの事実を1つも読まず対象ディレクトリのみを消費するため、要求しても常に真になる無内容な検査になる。この免除が根拠なく消える向きは M9（レイヤ2 へも要求を広げる変異）で押さえた。

この変更は直接実行の経路には現れないため、基準版との出力全文照合は `corpora=42 diffs=0` のまま変わらない。

### 4. PR 説明の根拠づけ2点

- **(a) 節4 を実行しなかった根拠の第一が事実と合わない**: 指摘のとおりであることを実測で確認した（`d14179a` 時点の5ファイル合計がちょうど914）。本記録の該当箇所3つと PR 説明を訂正した。詳細は「設計 spec の射程に対して実施しなかったこと」。
- **(b) D3 の起票見送りが条文適用の自明な帰結であるかのように読める**: 本記録の D3 節は「問いが既に2度現れている」ことと、条文の字義だけでは決まらないため時期の判断をユーザーへ上げて裁定を得た経緯を保持しているが、PR 説明側にはその係争が現れていなかった。PR 説明の D3 節へ、昇格条件のカウンタが既に2であることと、それが裁定に付されたことを書き足した。

## 受入条件の照合

Issue #800 の AC1〜AC9 を1件ずつ、充足の根拠と対にして照合する。

| AC | 内容 | 充足 | 根拠 |
|---|---|---|---|
| AC1 | 5レイヤがレイヤ単位で個別に起動できる単位へ分離され、各レイヤが消費する事実の収集が検査本体と別の単位に分かれている | 充足 | `lint-adr.sh` に `collect_scan_targets` / `collect_facts` の2つの収集単位と、`check_layer1_frontmatter_schema` / `check_layer2_index_sync` / `check_layer3_forward` / `check_layer3_reverse` / `check_layer4_related_references` / `check_layer5_filename_and_identifier` の6つの検査単位が在る。収集単位は違反を1件も出力しない。トップレベルの起動部は「走査対象の収集 → 事実の収集 → 各レイヤの呼び出し → 終了コードの決定」の並びのみ。任意の1レイヤを他レイヤの検査を実行せずに起動できることは、6単位すべてについて `lint-adr-layers.bats` 面⑱（レイヤ2・レイヤ3 reverse）・面⑳（レイヤ1・レイヤ3 forward・レイヤ5）と `lint-adr-xref.bats` 面⑧（レイヤ4）が検査する。起動の前提（事実の収集）を欠いた場合に検査を実行せず非0で戻ることは面㉒が検査する |
| AC2 | 検査内容が変更前後で同一。基準版と改訂後へ全 corpus を通し全文と終了コードが一致し、負例はいずれも終了コード1と1行以上の出力を返し、全22分岐が照合の中で発火する | 充足 | 基準版 `c126d72` との出力全文照合が `base=c126d72 corpora=42 diffs=0`。負例実測が `invalid_dirs=34 rc1=34 output_lines=43`（34件すべてが終了コード1、出力行の総数43）。22分岐の発火測定が `zero_fire_branches=0`。走査対象0件・対象ディレクトリ不在の境界も基準版と一致することを別途実測 |
| AC3 | 全検査分岐について正例 corpus・負例 corpus・アサーションの所在を対応付けた被覆表が存在し、負例を持たない分岐が0件 | 充足 | 本記録「検査分岐の被覆表」。分岐の数え方は「違反を出力する `printf` 1つ＝1分岐」で、レイヤ1が8・レイヤ2が2・レイヤ3 forward が3・reverse が2・レイヤ4が2・レイヤ5が5の計22。基準版時点で唯一の穴だった L3R-1 は `invalid/34-xref-reverse-dangling` と `lint-adr-layers.bats` 面⑰で埋め、22行すべてに負例とアサーションの所在が入っている |
| AC4 | `lint-adr.sh` の検査内容を検査する bats が `lint-adr-` 接頭辞を持ち、それ以外が同接頭辞を持たない。改名後のファイルに `lint-adr.sh` を直接消費する検査が残る場合、その帰属を定義する記述が冒頭コメントに存在し対象の面を名指しする | 充足 | `lint-adr-` を冠するのは `lint-adr-layers.bats` / `lint-adr-stem.bats` / `lint-adr-xref.bats` の3本のみで、いずれも `lint-adr.sh` の検査内容を検査する。`lint-adr-index.bats` は `gen-adr-index.bats` へ、`lint-adr-surface.bats` は `manage-adr-surface.bats` へ改名した。後者の冒頭コメントは面⑥と面⑦を名指しし、帰属を「条文と実装のあいだの正本対応の検査」と定義している |
| AC5 | 追加・改訂したテストに行番号固定・版据え置き型の常設ゲートが含まれない。回帰ケースに由来がテスト内コメントとして書かれている。新設・改訂した検査分岐について、当該分岐を落とす変異で対応する負例のケースだけが赤になることが実測・記録されている | 充足 | 追加した面⑰・面⑱・面⑲・面⑳・面㉑・面㉒（layers）と面⑧（xref）、および `lint-adr-stem.bats` の照合件数の下限は、いずれも corpus・関数名・実行時の照合回数だけを消費し、行番号にも版番号にも依存しない。各面のコメントに由来（Issue #800、参照先の #722 / #794、レビュー対応分は PR #801 のレビュー指摘番号）を書いた。検出力は変異11件で実測し、本記録「検出力の変異実測」に当てた変異・期待・実測・赤になったケース名を表として残した |
| AC6 | `bash scripts/run-tests.sh` が終了コード0で終わり、runner の既存ガードがいずれも不発火 | 充足 | `all suites passed (6 suites)` / bats は `157 tests, 0 failures`。`EXPECTED_BATS` と glob 結果の双方向照合は「期待するテストファイルが無い」「期待リストに未登録のテストファイル」のいずれも報告していない。TAP のプラン行と結果件数の照合も不発火 |
| AC7 | `bash scripts/run-tests.sh validate-plugin-path-references` が `missing=0 stale=0` を出力する | 充足 | `checked=84 missing=0 stale=0`。改名した1本の登録行と、行構成が変わった `helpers/common.bash` の登録行（32 → 34）を追随させた。件数が基準版と同じ84のままなのは、改名が登録の付け替えであり参照記述を増減させないため |
| AC8 | 本 PR の設計判断について、着手時点の main に固定した `adr-scoping.md` の版（commit を明記）に照らした ADR 化要否の判定結果が記録されている | 充足 | 本記録「ADR 化要否の判定」。条文の版は commit `c126d72` と明記。設計判断6件（構造整理の段の D1〜D4、レビュー対応の段の D5・D6）について必要条件の成否・4項目それぞれの点数と根拠・合計点・境界（3点）との関係・結論を記録した。D3 のみ4点で境界を越え、起票の時期はユーザー裁定により PR 説明へ留める。他5件はいずれも境界未満で非該当 |
| AC9 | `gen-adr-index.sh` / `next-adr-id.sh` / `hooks/` の挙動が変わっていない | 充足 | (a) `git diff c126d72 -- plugins/adr/scripts/gen-adr-index.sh plugins/adr/scripts/next-adr-id.sh plugins/adr/hooks/` の出力が空（差分0行）。(b) index 生成器・発番器・可搬性の各スイート（`gen-adr-index.bats` / `next-adr-id.bats` / `adr-portability.bats`）が緑。`lint-adr.sh` から index 生成器を呼ぶ経路の変更は AC2 の全 corpus 出力照合が覆う |

### 設計 spec の射程に対して実施しなかったこと

- **節4 の「lint-adr 系 bats 4ファイル（計914行）は書き直し」を実行していない。** そのまま実行すると直前の Issue #793 が投入した負例 fixture 4本と変異実測8件の被覆を作り直すことになる。節4 の眼目は「網羅の根拠を挙動の列挙に置き、既存テストのケース移植を出発点にしない」ことであり、被覆の根拠を実装ヘッダと条文から独立に導出したうえで既存アサーションを事後照合する形はこれを満たす（判断 D2）。

  なお **914 という数値は「4ファイル」の合計ではない**。spec を追跡下へ入れた commit `d14179a`（2026-08-28 09:06）時点の lint-adr 系 bats は5ファイルで、`lint-adr-index.bats` 95 ＋ `lint-adr-layers.bats` 264 ＋ `lint-adr-stem.bats` 256 ＋ `lint-adr-surface.bats` 115 ＋ `lint-adr-xref.bats` 184 ＝ 914 である。どのファイルも0行ではないため、4ファイルのどの部分集合も914にはならない。つまり「4ファイル」は spec 側の数え違いであり、時間経過による乖離ではない。

  着手時点 `c126d72` の現況は5ファイル1579行である。914 からの増分665行のうち600行は `lint-adr-surface.bats`（115 → 715）単独であり、これは本 PR が「lint の検査内容を検査していない」と分類して射程から外し、`manage-adr-surface.bats` へ改名したファイルである。射程内の3本は 704 → 769 の +65行（+9%）に留まる。したがって「spec の数値が現況と乖離したから実行しない」という説明は成り立たず、実行しない根拠は上段の1点（#793 の被覆を作り直すことになる）だけが立つ。（PR #801 のレビュー指摘4(a) を受けて訂正。訂正前は「策定時点の現況に基づく数値であり現況と食い違う」と書いていた）
- **上位検証層を常設していない。** 基準版との出力全文照合と検出力の変異は、いずれも実行コマンドと実測結果を本記録へ残す一回限りの検証に留めた（判断 D4・J6）。

### 射程外として扱った Issue

いずれも本 PR で扱っておらず、扱わなかったことで各 Issue の前提が崩れていないことを確認した。

| Issue | 内容 | 本 PR での扱い | 前提の状態 |
|---|---|---|---|
| #551 | front-matter を持たない ADR の検知漏れ | 扱わない（検査内容の変更にあたり、本 PR の振る舞い不変の宣言に反する） | 崩れていない。レイヤ1・レイヤ5 の検査対象集合は `collect_facts` が選別する `FM_FILES` へ移ったが、選別の条件（front-matter を持つこと）は変えていない。穴はそのまま残っており、塞ぐ先が収集単位1箇所へ集約された分だけ着手しやすくなっている |
| #786 | 配布物への配布元 Issue 番号の混入検出 | 扱わない（テスト側の欠落だが本 PR の射程外） | 崩れていない。本 PR は配布物（`plugins/adr/`）へ Issue 番号を書き込んでいない。テスト側のコメントには由来として Issue 番号を書いたが、これは配布物外（`scripts/tests/`）であり #786 が問題にする混入には当たらない |
| #787 | 行番号固定台帳の機構の是非 | 台帳への追随のみ行い、機構そのものは扱わない | 崩れていない。むしろ本 PR で追随が2回必要になった（改名による登録の付け替え1件と、`helpers/common.bash` への2行挿入による行番号のずれ1件）。後者は「テストへ行を足すだけで台帳が赤になる」という #787 の問題そのものの再現であり、Issue の前提を補強する実測になっている |
