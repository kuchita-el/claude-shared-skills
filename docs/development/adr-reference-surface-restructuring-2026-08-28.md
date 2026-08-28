# manage-adr 参照面の再構成（2026-08-28）

`manage-adr` スキルの参照面（`SKILL.md` ＋ `references/` の `.md`）を再構成し、ある規範を改訂するときに触る文書が一意に決まる状態にした作業の記録。Issue #722 の受入条件 AC1・AC3・AC4（検証結果側）・AC7・AC11 の証跡である。

配布物側へ置かないのは、これらがいずれも再構成という一回限りの作業の証跡であり、配布先の利用者が使う規約ではないためである（制約「配布物へ配布元リポジトリの Issue 番号を書き込まない」にも掛かる）。検査項目7件と正本の対応表だけは規約として機能するため、`plugins/adr/skills/manage-adr/references/adr-model.md` 側に置いた。

## 本再構成が従う前提

以降の各節はこの前提のもとで作られている。

- **references 間の参照の作法**: 直接ファイル名で正本を指す。射程は本再構成で新設・改稿する参照に限り、既存の間接名（`transitions.md` の「SKILL.md が指す状態モデルの規約」形ほか）は据え置く
- **参照の深さ**: 参照ファイル間の直接参照を許し、深さの上限を2段とする。すべてのポインタを `SKILL.md` へ集約すると `SKILL.md` が第二の列挙面に戻り、正本の一意性と衝突するため
- **検査項目↔正本の対応表の列構成**: 「検査項目 / 正本（パス＋節名）」の2列とする。是正手段の列を足すと、是正手段が対応表と各正本文書の2箇所に載り、対応表自身が正本の重複を作る
- **`template.md` の帰趨**: 現状の責務（front-matter 雛形＋見出し骨格＋HTML 注釈＋`## 変更履歴` の配置規約）を維持し、値の再掲の縮退のみを行う
- **配送単位**: 単一 PR。各コミット時点で全スイートが緑を保つようタスクを並べた

## 再構成前の参照面9件の帰趨と責務

帰趨の値域は 維持／分割／統合／削除 の4値。本表の対象は**再構成前に存在した9件**（`SKILL.md` ＋ references 8本）であり、新設3本は行を持たない（次節の11件の表に現れる）。

| ファイル | 帰趨 | 再構成後の責務 |
|---|---|---|
| `SKILL.md` | 維持 | 依頼をどの判断へルーティングするかを決め、各判断の正本文書を指す入口として機能する（レイヤの列挙面を持たない） |
| `references/adr-demotion.md` | 維持 | 既存 ADR を退役させるかの格下げ判定の正本（本再構成での変更0件） |
| `references/adr-model.md` | 維持 | ADR のドメインモデルの正本として、状態の型・配置・採番方式・発番スクリプトの契約・lint 検査項目7件と正本の対応表を持つ |
| `references/adr-scoping.md` | 分割 | 行き先と束ねと命名規約を `adr-destination.md` / `adr-splitting.md` へ出し、ADR 化要否の判定コア（格下げ判定との使い分け・必要条件・粒度判定基準・判定する入力の値域と定義・判定に添える申告・起票のタイミングと発見型）のみを持つ |
| `references/cross-references.md` | 維持 | `## 関連ADR` の関係語彙・`Related:` の書式規約・機械検査の範囲と是正手段の正本（相互参照の語彙の正本であることを冒頭で明示する） |
| `references/edit-decision.md` | 分割 | 記録の参照原則を `adr-reference-principle.md` へ出し、core／非core／些末 の分類と操作分岐のみを持つ |
| `references/io-examples.md` | 削除 | 4例すべてが他文書に規範として既述であり、例が正本の重複を作る経路になっていたため責務を持たない |
| `references/template.md` | 維持 | 新規 ADR の生成物の骨格（front-matter 雛形＋見出し骨格）と `## 変更履歴` 節の配置規約の正本（状態値・front-matter の値の再掲は落とす） |
| `references/transitions.md` | 維持 | 5遷移と分割の実行手順・双方向相互参照の書き込み・index の再生成の正本（入出力例と H1 形式の値の再掲は持たない） |

行数は9で、再構成前の参照面のファイル数と一致する。帰趨「統合」に当たるファイル単位の統合は0件である（`transitions.md`「共通: front-matter の書き方」が持つ H1 形式の記述を `adr-model.md` の正本へ縮退させる部分統合は生じるが、ファイルとしての帰趨は維持である）。

## 再構成後の参照面11件

| # | ファイル | 保持する判断 |
|---|---|---|
| 1 | `SKILL.md` | ルーティング |
| 2 | `references/adr-model.md` | 状態モデル・配置・採番・検査項目と正本の対応 |
| 3 | `references/adr-scoping.md` | ADR 化要否の判定コア |
| 4 | `references/adr-destination.md` | 判定結果の行き先・命名規約の ADR 化基準 |
| 5 | `references/adr-splitting.md` | 新規 ADR の束ねの制約 |
| 6 | `references/adr-demotion.md` | 格下げ（退役）判定 |
| 7 | `references/cross-references.md` | 相互参照の語彙・書式・機械検査 |
| 8 | `references/edit-decision.md` | 編集分類（core／非core／些末）と操作分岐 |
| 9 | `references/adr-reference-principle.md` | 記録の参照原則 |
| 10 | `references/template.md` | 生成物の骨格・`## 変更履歴` の配置規約 |
| 11 | `references/transitions.md` | 5遷移と分割の実行手順 |

## front-matter の型と旧表・レイヤ1違反種別の対応

### 構成子 ↔ 再構成前の「遷移ごとの必須ルール」表の行

`adr-model.md` の旧「遷移ごとの必須ルール」表（遷移で索引された5行）を、`## 状態の型` の直和型（5構成子）へ置き換えた。両者は1対1に対応し、対応の付かない行も構成子も0件である。`plugins/adr/scripts/lint-adr.sh`:23-29 が持つ遷移表の5行とも同じ対応で一致する。

| 旧表の行（遷移） | 旧表の値組（status / validity / superseded-by） | 構成子 |
|---|---|---|
| 起票 | 提案中 / （無し） / （無し） | `提案中` |
| 承認 | 承認済み / 有効 / （無し） | `有効` |
| 上書き | 承認済み（不変） / 上書き済み / 必須 | `上書き済み of NonEmptyList<FullSlug>` |
| 廃止 | 承認済み（不変） / 廃止済み / （無し） | `廃止済み` |
| 却下 | 却下 / （無し） / （無し） | `却下` |

行数5・構成子数5。型が新たに許す状態も新たに禁じる状態も生じていない（値組は逐語で保存され、旧表の3つの補足も型の制約・補足として保持した）。

### レイヤ1違反種別8件 ↔ 型の制約

対応表そのものは配布物側（`adr-model.md`「型の制約と機械検査の対応」）に置いた。ここに残すのは、その対応が `plugins/adr/scripts/lint-adr.sh`:31-39 の列挙と過不足なく一致することの照合結果と、既存 fixture による裏づけの有無である。

| # | `lint-adr.sh`:31-39 の違反種別 | 排除する制約 | 専用 fixture |
|---|---|---|---|
| 1 | status 欠落（空） | 制約1（すべての構成子が `status` を伴う） | `invalid/01-status-missing`、`invalid/06-multi-violation` |
| 2 | status=承認済み かつ validity 欠落（空） | 制約2（`承認済み` を伴う3構成子はいずれも `validity` を伴う） | `invalid/02-validity-missing` |
| 3 | validity=上書き済み かつ superseded-by 欠落（空） | 制約5（`上書き済み` の後継は非空リスト） | `invalid/03-superseded-by-missing`、`invalid/06-multi-violation` |
| 4 | status の値が語彙外 | 制約6（値は各軸の値域に限る） | `invalid/12-status-unknown-vocab` |
| 5 | validity の値が語彙外（空は合法） | 制約6（値は各軸の値域に限る） | `invalid/13-validity-unknown-vocab` |
| 6 | status=提案中 または 却下 かつ validity が非空 | 制約3（`validity` を伴わないのは `提案中` / `却下` だけ） | `invalid/14-proposed-with-validity`、`invalid/15-rejected-with-validity` |
| 7 | status=提案中 または 却下 かつ superseded-by が非空 | 制約4（`superseded-by` を伴えるのは `上書き済み` だけ） | **無し**（下記） |
| 8 | validity=有効 または 廃止済み かつ superseded-by が非空 | 制約4（`superseded-by` を伴えるのは `上書き済み` だけ） | `invalid/16-active-with-superseded-by`、`invalid/17-abandoned-with-superseded-by` |

行数8で `lint-adr.sh`:31-39 の列挙と1対1に対応し、対応欄が空の行は0件。制約1〜6 はいずれも少なくとも1件の違反種別へ対応づき、使われない制約も0件である。

**fixture の被覆の欠落（事実の記録。本再構成では埋めない）**: 種別7（`status=提案中` または `却下` かつ `superseded-by` が非空）には専用 fixture が存在しない。`invalid/14`・`invalid/15` は `提案中` / `却下` に `validity` を付けた側（種別6）を、`invalid/16`・`invalid/17` は `有効` / `廃止済み` に `superseded-by` を付けた側（種別8）をそれぞれ固定しており、`提案中` / `却下` に `superseded-by` を付けた組み合わせを固定する fixture はいずれのディレクトリにも無い（`invalid/06-multi-violation` は種別1 と種別3 を持つ）。fixture の追加は本再構成の対象外である（テストの追加は IN に含まれない）。

**型化が合法集合を動かしていないことの担保**: 既存 fixture（`valid` 8種・`invalid` 28種）は本再構成で1件も変更しておらず、`lint-adr.sh` も変更していないため、判定結果は文書編集の前後で必然的に同一である。したがって fixture は「lint の挙動を意図せず動かしていないこと」までを担保し、型化の正しさは上の2表（構成子↔旧表5行、違反種別8件↔制約）の突き合わせが担保する。

## 3語彙群の出現箇所一覧

<!-- Task 10 で埋める -->

## `io-examples.md` の4例の規範側の所在

削除した4例はいずれも他文書に規範として既述であり、例が規範の複製を作る経路になっていた。削除に伴って行き先を失った規範は0件である。

| 削除した例 | 同じ内容を規範として持つ箇所 |
|---|---|
| 例1 起票（front-matter・骨格） | `references/transitions.md`「起票（提案中）」 |
| 例1 採番衝突 | `references/adr-model.md`「同一時刻部の採番例」表、同「採番衝突時の解消手順」 |
| 例2 承認 | `references/transitions.md`「承認（承認済み・有効）」 |
| 例3 上書き（双方向相互参照） | `references/transitions.md`「上書き（上書き済み・双方向相互参照）」 |
| 例4 廃止・却下 | `references/transitions.md`「廃止（廃止済み）」「却下（却下）」 |

`transitions.md`「入出力例（上書き遷移）」節と目次行も同時に削除した。同節は例3 と同じ内容を二重に掲載していたものであり、規範側は上記のとおり同ファイルの「上書き（上書き済み・双方向相互参照）」節が持つ。

before→after の並置形式も固有の価値を持たない。before 側は `transitions.md`「遷移前の状態確認（実行ガード）」が期待遷移元を規定し、after 側は各遷移節と `adr-model.md`「状態の型」が規定している。

**保全した契約**: `adr-model.md`「採番衝突時の解消手順」末尾にあった入出力例のうち、`next-adr-id.sh` の終了コードは散文としてリポジトリ内でこの1箇所にしかなかったため、例の本体（入力・手順・期待結果）だけを削除し、終了コードは「発番スクリプトの契約」節として残した。あわせて終了コード `1` の意味を実装準拠（件数ではなく最大連番）へ是正した。

## 移動元→移動先の対応表

各条文について、移動先に1件のみ存在し移動元に残っていないことを照合した。「文言の差分」欄は、移動に伴う参照表現の書き換えのみを許し、判定条件・語順・語彙の変更を許さない。

### `edit-decision.md` → `adr-reference-principle.md`

| 移動した条文 | 移動元 | 移動先 | 文言の差分 |
|---|---|---|---|
| 原則本文（記録は可変文書を現在の参照先として指さない） | `edit-decision.md`「記録の参照原則（参照を書く／直す編集の判定）」 | `adr-reference-principle.md`「原則」 | 「前記の凍結原則」→「`edit-decision.md` の凍結原則」。凍結原則は移動元に残るため、相対語では指せなくなったことによる書き換え |
| 判定テスト（参照先を空にして読み直す） | 同上 | 同上 | なし（逐語） |
| 適用対象の例・対象外の例 | 同上 | 同上 | なし（逐語） |
| 判定テストの位置づけの但し書き | 同上 | 同上 | なし（逐語） |

**参照元の張り替え（3箇所）**

| 参照元 | 変更前の指し先 | 変更後の指し先 |
|---|---|---|
| `SKILL.md`「5遷移」節の本文 | `references/edit-decision.md` の「記録の参照原則」 | `references/adr-reference-principle.md` |
| `SKILL.md`「手順の参照」の一覧 | `edit-decision.md` の行が2責務を併記 | `edit-decision.md`（編集分類と操作分岐）と `adr-reference-principle.md`（記録の参照原則）の2行へ分離 |
| `transitions.md` 廃止手順2 | `edit-decision.md`「記録の参照原則」 | `adr-reference-principle.md` |

**冒頭リードの整合**: `edit-decision.md` の冒頭リードが持っていた「参照は1段階まで＝本ファイルから他の reference ファイルへ委譲・相互参照しない」という自ファイルの参照方針の括弧書きを、本再構成で採る作法（正本を直接ファイル名で指す・深さの上限2段）に合わせた記述へ改めた。あわせて記録の参照原則が本ファイルの責務でなくなったことを明記した。書き換えは同ファイルの参照方針とその責務の記述に限り、ADR 運用条文の判定条件・語彙には触れていない。

## 判定手続きの分岐の前後突き合わせ

<!-- Task 11 で埋める -->

## 節名を照合キーにしている開発記録の追随

<!-- Task 9 で埋める -->

## 受入条件の照合

<!-- Task 12 で埋める -->
