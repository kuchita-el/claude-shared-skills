# 相互参照の規約と drift-lint 実装の照合（2026-08-06）

`plugins/adr/skills/manage-adr/references/cross-references.md` に成文化した条項が、`plugins/adr/scripts/lint-adr.sh` のレイヤ4 実装および `scripts/fixtures/lint-adr/` の fixture と一致することを確認した記録。#561 AC6 の証跡である。

規約と実装が食い違う場合は規約を正とする（`cross-references.md` 冒頭）。本照合の時点では**不一致0件**であり、実装側の是正は生じていない。

**再照合（2026-08-07）**: レイヤ4 の参照先退役検査を `上書き済み` 限定へ狭めた改修に伴い、**レイヤ4 退役検査に関わる記述に限定して**再照合し、本文を改修後の実装へ追随させた。文書全体の再照合は行っておらず、射程外の記述は 2026-08-06 時点の照合結果のままである。

## 条項 → 実装 → fixture

| # | 条項（`cross-references.md`） | 実装根拠（`lint-adr.sh`） | fixture |
|---|---|---|---|
| 1 | 判定単位は `Related:` 以降で最初に現れる ADR stem | `extract_body_related()` が `Related:` 以降を切り出し、最初の `ADR-` 一致のみを採る | `valid/06-related-valid`（先頭 stem が有効なら通る行）、`invalid/23-related-dup-report` |
| 2 | 書式は不問（バレット有無・markdown リンク有無・リンクラベルが stem か説明文か） | 同上。リンク記法を剥がさず `ADR-` 一致で拾う | `invalid/18-related-retired-no-bullet`（バレット無し）、`invalid/19-related-retired-link`（リンク形式）、`invalid/22-related-link-label`（ラベルが説明文）、`valid/06-related-valid`（バレット有無×リンク有無の4書式） |
| 3 | 参照先は full slug 完全一致で解決する | レイヤ4 ループが `$ADR_DIR/$t_stem.md` の実在で判定 | `invalid/20-related-dangling` |
| 4 | 1行に複数列挙すると2件目以降は検査されない | 条項1 の帰結（先頭 stem のみ抽出） | 専用 fixture なし（条項1 の fixture が同じ実装経路を固定する） |
| 5 | 先頭 stem より後に現れる識別子は拾われない | 同じく先頭優先の抽出 | `valid/06-related-valid`（散文が**実在しない** slug を引用しても誤検出しない行。デコイに実在しない stem を使うのは、後続 stem を拾う退行が dangling 違反として現れ、退役判定の語彙の増減に影響されないため） |
| 6 | 同一ファイル内の同一 stem は違反報告1件へ集約 | `extract_body_related()` が `BODY_RELATED_TARGETS` へ積む前に重複を排除 | `invalid/23-related-dup-report`（plain 行とリンク行の2行から同一退役先を指しても報告1回） |

条項番号1〜6 は `cross-references.md`「`Related:` の書式規約」の番号に対応する。以下は同ファイル「機械検査の範囲」節の各小節に対応し、規約側に番号を持たないため小節名で参照する。

| 小節（`cross-references.md`「機械検査の範囲」） | 条項 | 実装根拠（`lint-adr.sh`） | fixture |
|---|---|---|---|
| 検査される側（source） | source は `validity: 有効` な ADR のみ | レイヤ4 ループ冒頭で `FM_VALIDITY_BY_STEM[$src_stem] != "有効"` を `continue` | **専用 fixture なし**（下記「fixture の被覆の欠落」参照） |
| 違反となる状態 | 参照先退役（`上書き済み` に限る。後継なしの `廃止済み` は違反にしない）と dangling の2種 | ループ内の2分岐（`! -f` → dangling、`in_vocab RELATED_RETIRED_VALIDITY` → 参照先退役） | 退役: `invalid/18`・`invalid/19`・`invalid/22`・`invalid/23`（いずれも参照先 `上書き済み`）／dangling: `invalid/20`／非違反: `valid/06-related-valid`（先頭 stem が後継なしの `廃止済み`） |
| 検査されないこと | 双方向性は強制しない（一方向 `Related:` は合法） | `Related:` に reverse 方向の検査が無い（`Supersedes:` のみ forward/reverse 双方を持つ） | `valid/06-related-valid`（source→target の一方向のみで、target 側に逆参照が無くても exit 0） |
| 検査されないこと | 参照先が旧形式・`validity` 空なら違反にしない（fail-open） | `RELATED_RETIRED_VALIDITY`（`上書き済み` の1値）の完全一致のみを違反とみなすため、空値・旧形式は両分岐に掛からない | **専用 fixture なし**（下記参照） |
| 検査されないこと | Issue 番号参照は検査しない | 抽出対象が `ADR-` 接頭辞に限られる | 専用 fixture なし（抽出仕様の帰結） |
| （関係語彙節） | 生存語彙以外のラベルの行は抽出されない | 抽出条件が行頭 `Related:`（レイヤ4）と `Supersedes:`（レイヤ3）に限られる | `valid/02-xref-valid/ADR-202602030902-01-xref-unknown-label-example.md` |

## 逆方向の網羅（fixture → 条項）

レイヤ4 に該当する fixture のうち、対応する条項を持たないものが無いことを確認した。

| fixture | 対応条項 |
|---|---|
| `invalid/18-related-retired-no-bullet` | 2、および「違反となる状態」 |
| `invalid/19-related-retired-link` | 2、および「違反となる状態」 |
| `invalid/20-related-dangling` | 3、および「違反となる状態」 |
| `invalid/21-park-dangling` | 照合時点では**射程外**とした（`## 保留した決定` 欄の dangling 検査に対応するが、同節は廃止が決定していたため）。2026-08-07 に同節が廃止され、当該検査・fixture ともに撤去されたため、対応条項を持たない fixture は現存しない |
| `invalid/22-related-link-label` | 2、および「違反となる状態」 |
| `invalid/23-related-dup-report` | 1, 6、および「違反となる状態」 |
| `valid/06-related-valid` | 1, 2, 5（散文のデコイは実在しない stem）、および「検査されないこと」の双方向非強制、「違反となる状態」（後継なしの `廃止済み` を指す先頭 stem が違反にならない側） |
| `valid/02-xref-valid` の未知ラベル例 | 「関係語彙」節（生存語彙以外のラベルの行は抽出されない） |

## 不一致

**0件**（2026-08-06 の初回照合、2026-08-07 の再照合のいずれの時点でも）。規約の各条項はいずれも実装の振る舞いと一致しており、規約側・実装側とも是正を要さなかった。

2026-08-07 の再照合は、レイヤ4 の参照先退役検査を `上書き済み` 限定へ狭めた改修の射程に限る。実装（`lint-adr.sh` の `RELATED_RETIRED_VALIDITY` と仕様ヘッダ）・規約（`cross-references.md` の「違反となる状態」「是正手段」）・fixture（`invalid/18`・`invalid/22`・`invalid/23` の参照先を `上書き済み` へ転換、`valid/06` へ後継なし退役先を指す `Related:` を追加）を同一の変更で動かしたため、三者は改修後も一致している。表1 の条項2・条項6 は書式と重複排除を述べるもので参照先の `validity` に依存しないため、fixture の転換による記述のずれは生じていない。**この再照合はレイヤ4 退役検査に関わる行のみを対象としており、文書全体を再走査したものではない。**

**条項5 のデコイの是正（同日・レビュー指摘対応）**: 上記の語彙限定により、`valid/06` の条項5 用デコイ（先頭 stem の後ろに散文で引用される退役 slug）が検出力を失っていた。デコイが `廃止済み` であったため、抽出器が後続 stem を拾う退行を入れても違反が出ず、条項5 の回帰が空振りになる。`extract_body_related` の先頭 stem 抽出を最後尾 stem 抽出へ変える変異を当てて実測したところ、基底コミット `27c22f3` では面④ が FAIL するのに対し、語彙限定後は PASS へ変わっていた。**デコイを実在しない stem（`ADR-209901010101-01-nonexistent-quoted`）へ差し替え、dangling 検査で退行を捕まえる形へ改めた。** dangling は参照先の `validity` に依存しないため、退役判定の語彙が今後増減しても検出力を保つ。差し替え後は同じ変異で面④ が dangling 違反により FAIL する。

あわせて、表3 の条項欄にあった条項番号 `8` を小節名参照へ是正した。条項は1〜6 しか存在せず `8` は指し先を持たない既存の不整合であったため、番号を発明せず「機械検査の範囲」節の小節名で指す形へ改めた。`invalid/20-related-dangling` の行は dangling 用でレイヤ4 退役検査に関わらないが、同じ表の同じ型の不整合であるため同じ編集に含めた**些末な訂正**であり、再照合の射程を広げるものではない。

## fixture の被覆の欠落（規約と実装の不一致ではない）

照合の過程で、条項に対応する回帰 fixture が存在しない箇所を2件検出した。いずれも規約と実装が食い違っているのではなく、**実装の振る舞いを固定する fixture が無い**という被覆の問題である。

- **検査範囲「検査される側」（source は有効 ADR のみ）**: 退役した source が `Related:` で退役先や不在先を指す corpus の fixture が無い。`valid/01-mixed-validity` は退役 ADR を含むが `Related:` 行を持たず、`valid/06-related-valid` の退役 ADR も `## 関連ADR` に `Related:` を持たない。したがって「退役 source の `Related:` は検査されない」ことを固定する回帰が存在しない
- **検査範囲「検査されないこと」（fail-open）**: 参照先が旧形式（front-matter 無し）または `validity` 空である `Related:` の fixture が無い。`valid/07-legacy-filename-skipped` は旧形式ファイル名の走査除外を扱うもので、レイヤ4 の fail-open は固定していない
- **`extract_body_related` の走査範囲（`## 関連ADR` 節限定）**: `Related:` の抽出を `## 関連ADR` 節の内側に限る実装だが、節限定を撤去する変異を当てても現行 fixture では無検出である（`origin/main` でも同じく生存する既存の穴であり、2026-08-07 改修が新たに開けた穴ではない）。節外（`## Context` / `## Consequences` 等）に置いた `Related:` 様の行が誤って拾われない、または正しく無視されることを固定する fixture が無い

いずれも本 PR のスコープ（#561 の成文化、および2026-08-07 の退役検査限定）外であり、fixture の追加は行っていない。実装が意図せず変わっても検出されない箇所として記録に残す。

**2026-08-07 の再照合時点でも3件とも現存する。** レイヤ4 の退役検査を `上書き済み` 限定へ狭めた改修は退役判定の語彙を絞るだけであり、fail-open の構造（空値・旧形式はどの語彙とも一致しない）と節スコープの実装は変わらない。欠落の性質も変わらないため、埋めることは当該改修のスコープを超えると判断し、fixture は追加していない。

なお「`## 関連ADR` 内の生存語彙以外のラベルを持つ行は、参照先が実在しなくても違反にならない」という fail-open は、`valid/02-xref-valid/ADR-202602030902-01-xref-unknown-label-example.md` が固定している。同 fixture は当初 `Amends:` ラベルで書かれていたが、廃止語彙の痕跡除去にあたって回帰を失わないよう、生存語彙でない別ラベル（`Refines:`）へ置き換えて維持した。

## 備考

- 条項4（複数列挙の2件目以降が非検査）は既存 `docs/adr` に実例があり、真の複数列挙は7行（`ADR-202605312147-01`／`ADR-202606020010-01`／`ADR-202606270040-01`／`ADR-202607010734-01`／`ADR-202607121331-01`／`ADR-202605311500-01`／`ADR-202605131437-06` の各 `## 関連ADR`）。禁止則にすると既存 corpus が一斉に違反となるため、規約は検査が届かない事実の明示と人手担保の推奨にとどめた
- `lint-adr.sh` のレイヤ4 ヘッダコメントは規約と同内容の解説を保持している。二重出典ではあるが、実装単体の可読性を優先して残置した。裁定先は規約側である（同コメントにあった「本実装の振る舞いを正とする」旨の自認は本 PR で削除した）
