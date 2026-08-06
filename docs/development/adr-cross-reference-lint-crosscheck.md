# 相互参照の規約と drift-lint 実装の照合（2026-08-06）

`plugins/adr/skills/manage-adr/references/cross-references.md` に成文化した条項が、`plugins/adr/scripts/lint-adr.sh` のレイヤ4 実装および `scripts/fixtures/lint-adr/` の fixture と一致することを確認した記録。#561 AC6 の証跡である。

規約と実装が食い違う場合は規約を正とする（`cross-references.md` 冒頭）。本照合の時点では**不一致0件**であり、実装側の是正は生じていない。

## 条項 → 実装 → fixture

| # | 条項（`cross-references.md`） | 実装根拠（`lint-adr.sh`） | fixture |
|---|---|---|---|
| 1 | 判定単位は `Related:` 以降で最初に現れる ADR stem | `extract_body_related()` が `Related:` 以降を切り出し、最初の `ADR-` 一致のみを採る | `valid/06-related-valid`（先頭 stem が有効なら通る行）、`invalid/23-related-dup-report` |
| 2 | 書式は不問（バレット有無・markdown リンク有無・リンクラベルが stem か説明文か） | 同上。リンク記法を剥がさず `ADR-` 一致で拾う | `invalid/18-related-retired-no-bullet`（バレット無し）、`invalid/19-related-retired-link`（リンク形式）、`invalid/22-related-link-label`（ラベルが説明文）、`valid/06-related-valid`（バレット有無×リンク有無の4書式） |
| 3 | 参照先は full slug 完全一致で解決する | レイヤ4 ループが `$ADR_DIR/$t_stem.md` の実在で判定 | `invalid/20-related-dangling` |
| 4 | 1行に複数列挙すると2件目以降は検査されない | 条項1 の帰結（先頭 stem のみ抽出） | 専用 fixture なし（条項1 の fixture が同じ実装経路を固定する） |
| 5 | 説明散文の中の識別子は参照先として拾われない | 同じく先頭優先の抽出 | `valid/06-related-valid`（散文が退役 slug を引用しても誤検出しない行） |
| 6 | 同一ファイル内の同一 stem は違反報告1件へ集約 | `extract_body_related()` が `BODY_RELATED_TARGETS` へ積む前に重複を排除 | `invalid/23-related-dup-report`（plain 行とリンク行の2行から同一退役先を指しても報告1回） |
| 7 | source は `validity: 有効` な ADR のみ | レイヤ4 ループ冒頭で `FM_VALIDITY_BY_STEM[$src_stem] != "有効"` を `continue` | **専用 fixture なし**（下記「fixture の被覆の欠落」参照） |
| 8 | 違反種別は参照先退役と dangling | ループ内の2分岐（`! -f` → dangling、`in_vocab RETIRED_VALIDITY` → 参照先退役） | 退役: `invalid/18`・`invalid/19`／dangling: `invalid/20` |
| 9 | 双方向性は強制しない（一方向 `Related:` は合法） | `Related:` に reverse 方向の検査が無い（`Supersedes:` のみ forward/reverse 双方を持つ） | `valid/06-related-valid`（source→target の一方向のみで、target 側に逆参照が無くても exit 0） |
| 10 | 参照先が旧形式・`validity` 空なら違反にしない（fail-open） | `RETIRED_VALIDITY` の完全一致のみを退役とみなすため、空値・旧形式は両分岐に掛からない | **専用 fixture なし**（下記参照） |
| 11 | Issue 番号参照は検査しない | 抽出対象が `ADR-` 接頭辞に限られる | 専用 fixture なし（抽出仕様の帰結） |

## 逆方向の網羅（fixture → 条項）

レイヤ4 に該当する fixture のうち、対応する条項を持たないものが無いことを確認した。

| fixture | 対応条項 |
|---|---|
| `invalid/18-related-retired-no-bullet` | 2, 8 |
| `invalid/19-related-retired-link` | 2, 8 |
| `invalid/20-related-dangling` | 3, 8 |
| `invalid/21-park-dangling` | **本 PR の射程外**。`## 保留した決定` 欄の dangling 検査に対応する。同節は廃止が決定しており、書式規約と検査範囲は後続 PR で扱う。`cross-references.md` は同節が現に検査対象である事実のみを1行で述べ、規約は定めていない |
| `invalid/22-related-link-label` | 2 |
| `invalid/23-related-dup-report` | 1, 6 |
| `valid/06-related-valid` | 1, 2, 5, 9 |

## 不一致

**0件**。規約の各条項はいずれも実装の振る舞いと一致しており、規約側・実装側とも是正を要さなかった。

## fixture の被覆の欠落（規約と実装の不一致ではない）

照合の過程で、条項に対応する回帰 fixture が存在しない箇所を2件検出した。いずれも規約と実装が食い違っているのではなく、**実装の振る舞いを固定する fixture が無い**という被覆の問題である。

- **条項7（source は有効 ADR のみ）**: 退役した source が `Related:` で退役先や不在先を指す corpus の fixture が無い。`valid/01-mixed-validity` は退役 ADR を含むが `Related:` 行を持たず、`valid/06-related-valid` の退役 ADR も `## 関連ADR` に `Related:` を持たない。したがって「退役 source の `Related:` は検査されない」ことを固定する回帰が存在しない
- **条項10（fail-open）**: 参照先が旧形式（front-matter 無し）または `validity` 空である `Related:` の fixture が無い。`valid/07-legacy-filename-skipped` は旧形式ファイル名の走査除外を扱うもので、レイヤ4 の fail-open は固定していない

いずれも本 PR のスコープ（#561 の成文化）外であり、fixture の追加は行っていない。実装が意図せず変わっても検出されない箇所として記録に残す。

## 備考

- 条項4（複数列挙の2件目以降が非検査）は既存 `docs/adr` に実例があり、真の複数列挙は7行（`ADR-202605312147-01`／`ADR-202606020010-01`／`ADR-202606270040-01`／`ADR-202607010734-01`／`ADR-202607121331-01`／`ADR-202605311500-01`／`ADR-202605131437-06` の各 `## 関連ADR`）。禁止則にすると既存 corpus が一斉に違反となるため、規約は検査が届かない事実の明示と人手担保の推奨にとどめた
- `lint-adr.sh` のレイヤ4 ヘッダコメントは規約と同内容の解説を保持している。二重出典ではあるが、実装単体の可読性を優先して残置した。裁定先は規約側である（同コメントにあった「本実装の振る舞いを正とする」旨の自認は本 PR で削除した）
