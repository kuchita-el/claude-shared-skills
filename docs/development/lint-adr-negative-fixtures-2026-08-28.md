# ADR drift-lint の負例 fixture 追加（2026-08-28）

Issue #793 の作業記録。PR #792 のレビュー指摘5（負例 fixture の欠落3件）を引き取り、`plugins/adr/scripts/lint-adr.sh` が現に強制している不変条件のうち、退行しても赤にならなかった3件を退行検出網へ載せた。

対象は次の3件である。いずれも実装は検査しているが、その分岐を消しても全テストが緑のまま通る状態にあった。

| 検査 | 条文（`adr-model.md`） | 追加前の状態 |
|---|---|---|
| レイヤ2: `index.md` の不在を不一致として扱う | 「index の同期」 | fixture・アサーションとも無し |
| レイヤ5: H1 に識別子が現れない（見出しを持たない場合を含む） | 「H1 見出しの形式と識別子部の整合」 | 同上 |
| レイヤ1 違反種別7: `status=提案中` または `却下` かつ `superseded-by` が非空 | 「状態の型」制約4 | 専用 fixture 無し。既存 fixture による偶発的な被覆も無し |

## 追加した負例 fixture

4つの corpus を `scripts/fixtures/lint-adr/invalid/` へ追加した。種別7 は条件が `提案中` と `却下` の選言であり、既存の 14-proposed-with-validity / 15-rejected-with-validity（種別6）が両状態を別 corpus で押さえているのと対称に2本置いた。

| corpus | 対象検査 | 期待する違反メッセージ |
|---|---|---|
| `30-proposed-with-superseded-by` | レイヤ1 種別7（提案中側） | `status=提案中 だが superseded-by が空ではありません` |
| `31-rejected-with-superseded-by` | レイヤ1 種別7（却下側） | `status=却下 だが superseded-by が空ではありません` |
| `32-index-missing` | レイヤ2 不在 | `index 同期違反（index.md が存在しません）` |
| `33-h1-id-absent` | レイヤ5 H1 識別子不在 | `H1 整合違反（本文の最初の "# " 見出しに ADR 識別子が見つかりません…）` |

`33-h1-id-absent` は2ファイルを同梱する。`ADR-202612111033-01-h1-id-absent.md` は H1 を持つが識別子を欠き、`ADR-202612121033-01-h1-heading-absent.md` は H1 を1つも持たない。条文が「見出しを持たない場合を含む」と定めており、実装も抽出結果が空であることを一様の判定材料にしているため、`extract_h1_adr_id` の到達経路が異なる2つを同じ corpus で押さえた（前者は `# ` 行に当たって識別子抽出に失敗し、後者は `# ` 行に一度も当たらずループを抜ける）。

`32-index-missing` は index.md を持たないことが検査対象そのものである。誰かが index.md を足すと corpus は exit 0 へ落ちて負例が消えるため、fixture が index.md を持たないこと自体をアサーションの1項目として数えている。

### 各 corpus が単一原因で exit 1 になることの確認

追加時点の実測（`bash plugins/adr/scripts/lint-adr.sh <corpus>`）。いずれも報告される違反は対象検査のものだけであり、他レイヤは発火していない。

```
30-proposed-with-superseded-by
  ADR-202608091030-01-proposed-with-superseded-by-decision.md: status=提案中 だが superseded-by が空ではありません（値 "ADR-202608101030-01-proposed-superseded-by-successor"。提案中・却下 は superseded-by を伴いません）
  rc=1
31-rejected-with-superseded-by
  ADR-202608111031-01-rejected-with-superseded-by-decision.md: status=却下 だが superseded-by が空ではありません（値 "ADR-202608121031-01-rejected-superseded-by-successor"。提案中・却下 は superseded-by を伴いません）
  rc=1
32-index-missing
  index.md: index 同期違反（index.md が存在しません）
  rc=1
33-h1-id-absent
  ADR-202612111033-01-h1-id-absent.md: H1 整合違反（本文の最初の "# " 見出しに ADR 識別子が見つかりません。ファイル名の識別子部は ADR-202612111033-01）
  ADR-202612121033-01-h1-heading-absent.md: H1 整合違反（本文の最初の "# " 見出しに ADR 識別子が見つかりません。ファイル名の識別子部は ADR-202612121033-01）
  rc=1
```

## アサーションの追加先

新規ケースを起こさず、同じ検査意図を持つ既存の面へ足した。面番号は変えていない。

- `scripts/tests/lint-adr-layers.bats` 面②（`LAYER1_INVALID_CASES` の表）に corpus 30・31 の2行を追加した。表の形式・ラベルの付け方は既存の9件と同じである
- 同ファイル面⑤を「index drift の検出」から「index 同期違反の検出（drift と不在）」へ広げ、corpus 32 を足した。drift と不在は実装上も別の分岐であり、同じ違反名へ合流する2経路である
- `scripts/tests/lint-adr-stem.bats` 面⑥（H1 整合違反の検出）に corpus 33 を足した。不一致（既存の 27-h1-id-mismatch）と不在が同じ検査の2分岐であるため束ねた

面⑤・面⑥は corpus ごとに `run_sut` を直接呼ぶ形であり、照合件数が構造的に0にならない。面②はループであり、表が空になると反復0回のまま `collect_finish` が成功を返す。この経路を塞ぐため、ループが実際に走らせた照合の回数をループ内で数え、ループ後に下限（`LAYER1_INVALID_CASE_MIN=11`）と突き合わせる項目を1件置いた。下限は名目値（1件）ではなく現在の実数を置いている。実行時に得た量を下限とループの双方が消費する点で、方式は `lint-adr-surface.bats` の AC5 下限と同じである。

数える対象を配列リテラルの要素数（`${#LAYER1_INVALID_CASES[@]}`）にしない。宣言だけを読む下限は、照合ループごと消えても配列さえ残っていれば緑を返し、退行しうる量を観測しない（レビュー指摘1。実測は下表の変異5）。

同じ根で、表の期待メッセージ欄が空になった行も塞いだ。`collect_contains` は空 needle に対して `[[ "$haystack" == *""* ]]` が常に真となり合格を返すため、空欄の行はメッセージ側の検出力を失う。ループ内で欄の非空を1項目として判定し、空なら行を名指しして落とし、下限にも数えない（実測は変異6）。

面⑤・面⑥は2分岐を1つの面へ束ねているため、両分岐の needle を分岐固有の文言へ寄せた。総称の違反名（`index 同期違反` / `H1 整合違反`）だけを照合していると、2分岐の出力が同じ文言へ合流しても緑のまま通る（レビュー指摘2。実測は変異7・8）。needle は違反名を先頭に含む形で分岐の文言へ延ばし、違反名が別の分岐へ移った場合も外れるようにしている。

## 変異検査

各検査について、実装側の分岐を削除する変異を当てて `bash scripts/run-tests.sh` が赤になることを実測した。変異1〜4 は実装（`lint-adr.sh`）または表を壊すもので、当てるたびに `git restore` で戻している。変異5〜8（レビュー指摘への対応の検証）は「修正後」と「修正前（`git show HEAD:` で取り出した版）」の双方へ同じ変異を当てて対で観測しており、対象ファイルは退避した複製から戻している。

| # | 変異 | 期待 | 実測 |
|---|---|---|---|
| 1 | レイヤ2 の `[ ! -f "$INDEX_FILE" ]` ガードを外し、`cat` の失敗を握り潰して差分比較だけを残す | RED | RED（面⑤の不在メッセージ項目のみ。違反名 `index 同期違反` は出るが `（index.md が存在しません）` が出ない） |
| 2 | レイヤ5 の `[ -z "$H1_ADR_ID" ]` 分岐を落とし、不一致検査へ `[ -n "$H1_ADR_ID" ]` を付けて識別子不在を違反にしない | RED | RED（面⑥の4項目。corpus 33 が exit 0 へ落ちる） |
| 3 | レイヤ1 種別7 の4行（`status=提案中/却下` かつ `superseded-by` 非空の報告）を削除 | RED | RED（面②の4項目。corpus 30・31 が exit 0 へ落ちる） |
| 4 | `LAYER1_INVALID_CASES` から1行（`01-status-missing`）を削除 | RED | RED（下限の項目のみ。10 件 < 下限 11 件） |
| 5 | 面②の照合ループ（`for entry in "${LAYER1_INVALID_CASES[@]}"` ブロック）を丸ごと削除し、配列宣言と下限判定だけを残す | RED | RED（下限の項目。0 件 < 下限 11 件）。修正前の版へ同じ変異を当てると `ok`（配列リテラルの要素数だけを読んでいたため） |
| 6 | `LAYER1_INVALID_CASES` の corpus 30 の行から期待メッセージ欄を空にする | RED | RED（空欄の名指しと下限の2項目）。修正前の版へ同じ変異を当てると `ok` |
| 7 | レイヤ2 drift 側の `printf` を不在側と同一の文言へ書き換える（2分岐を出力上で区別不能にする） | RED | RED（面⑤の drift 側メッセージ項目）。修正前の版へ同じ変異を当てると `ok` |
| 8 | レイヤ5 H1 不一致側の `printf` を不在側と同一の文言へ書き換える | RED | RED（面⑥の不一致側メッセージ項目）。修正前の版へ同じ変異を当てると `ok` |

変異1 は「ガードを消したら `set -e` でスクリプトが落ちる」形ではなく、`cat` の失敗を握り潰して静かに差分比較へ倒す形を選んだ。落ちる形なら exit code だけでも赤にできるため、検査の弱さを暴けない。握り潰す形は exit 1 も違反名 `index 同期違反` も維持したまま不在の名指しだけを失うため、メッセージの粒度が実際に効いているかを問える。

変異4 は下限アサート自体が空回りしていないことの確認である。下限が無ければ表を削っても、削られた行のアサーションが走らなくなるだけで緑のまま通る。

変異5〜8 はレビュー指摘への対応を検証したものであり、当てる先が実装（`lint-adr.sh`）とテスト資産の両方にまたがる。変異5・6 はテスト側の表と照合ループを壊し、変異7・8 は実装側の `printf` を壊す。いずれも「修正後は RED / 修正前は緑」を対で実測しており、修正が検出網に実際の差を生んでいることを示す。変異7・8 は検出そのもの（exit 1・違反名）を壊さず、2分岐の文言の区別だけを消す形であり、変異1 と同じ「メッセージの粒度が効いているか」を問う方向にある。

実装側を触る変異（1〜3・7・8）では `validate-plugin-versions` も同時に赤になる。これは変異が `plugins/adr/` 配下を触ったことによる版据え置き検出であり、変異の副作用である。本 Issue の成果物は `plugins/` 配下を一切変更していないため、この検査には掛からない。

### 種別7 の変異がレイヤ3 に空振りしていないこと（AC3）

種別7 の corpus は `superseded-by` が非空であるため、後継ファイルが無いとレイヤ3 forward の「参照先が見つかりません」が代わりに発火し、種別7 の分岐を消しても corpus は exit 1 のままになる。これを避けるため、corpus 30・31 には後継 ADR を同梱し、後継の本文 `## 関連ADR` に `Supersedes:` 逆参照を置いてレイヤ3 forward・reverse の双方を充足させた。

変異3 を当てた状態で両 corpus を直接起動し、**exit 0**（違反0件）になることを確認した。レイヤ3 が代わりに発火していれば exit 1 のままになるため、赤になる原因が種別7 の分岐削除に一意に絞られている。

```
$ bash plugins/adr/scripts/lint-adr.sh scripts/fixtures/lint-adr/invalid/30-proposed-with-superseded-by
rc30=0
$ bash plugins/adr/scripts/lint-adr.sh scripts/fixtures/lint-adr/invalid/31-rejected-with-superseded-by
rc31=0
```

## 受入条件の照合

| AC | 内容 | 結果 |
|---|---|---|
| 1 | 3件それぞれに負例 fixture が存在し、違反メッセージと exit 1 をアサートしている | 充足。corpus 30/31（種別7）・32（レイヤ2 不在）・33（レイヤ5 H1 不在）。各面で `collect_rc 1` とメッセージの部分一致を対で置いた |
| 2 | 各件について変異で対応するテストが赤になることを実測し記録している | 充足。上表の変異1〜3 |
| 3 | 種別7 の fixture は後継と `Supersedes:` 逆参照を同梱しレイヤ3 を満たし、変異で赤になる原因が種別7 であることを確認している | 充足。変異3 下で両 corpus が exit 0 |
| 4 | 既存 fixture（valid 8・invalid 28）を変更していない | 充足。`git diff origin/main...HEAD --diff-filter=MDR --name-status -- scripts/fixtures/` が空（改変・削除・改名が0件）。`--name-status` 全体でも `scripts/fixtures/` 配下は `A`（追加）のみ |
| 5 | 照合件数が0件のまま緑になる経路が無い | 充足。面⑤・面⑥は直接起動で構造的に0にならず、面②のループには実行時の照合回数に対する下限を置いた（変異4・5 で下限が効くことを、変異6 で空 needle 経路が塞がれていることを確認） |
| 6 | `bash scripts/run-tests.sh` が exit 0 | 充足。`all suites passed (6 suites)` / 149 tests, 0 failures |

### 制約の充足

「行番号固定・版据え置き型の検査にしない（#787）」— 追加したアサーションはいずれも corpus を起動して違反メッセージを部分一致で照合する形であり、行番号にも版番号にも依存しない。面②へ足した下限が数えるのは実行時の照合回数であり、行番号ではない。

## 対象外（引き継がない）

- `lint-adr.sh` の検査ロジックそのものの変更。本 Issue は検査の被覆のみを扱う
- front-matter を持たない ADR が全レイヤをすり抜ける検知漏れ（#551）
- `lint-adr.sh` 冒頭の遷移表の処遇（#794）
