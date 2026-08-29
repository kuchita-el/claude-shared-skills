#!/usr/bin/env bats
# ADR drift-lint のレイヤ4（plugins/adr/scripts/lint-adr.sh）のテスト。
#
# 非 Supersede 参照妥当性 lint（退役参照検査・判定単位の書式非依存化）。
# 有効 ADR の `## 関連ADR`（Related:）の先頭 ADR stem を、
# 行頭バレット有無・markdown リンク形式有無を問わず抽出し、参照先が上書き済み
# なら参照先退役違反、非存在なら dangling 参照違反として報告する。
# 後継を持たない退役（廃止済み）は差し替え先が存在せず建設的な是正が無いため対象外であり、
# 参照先が旧形式・validity 空の場合と同じく違反にならない（fail-open）。
#
# 【レイヤ4 の判定単位の正本はここにある】
# `Related:` 以降で最初に現れる ADR stem を、行頭バレットの有無・markdown リンクの有無・
# リンクラベルの書式を問わず取ること——この判定単位はどの ADR にも成文化されていない。
# 本テストと scripts/fixtures/lint-adr/ がその正であり、書式非依存性を境界事例として固定する。
#
# 【配置について】テストと fixture を配布物外へ置く境界は docs/distribution-boundary.md が定める。
#
# ADR 群は fixture ごとに異なり事前起動を共有できないため、共有 setup_file の CORPORA は
# 空にし、検査器の起動は各ケース内で bats 組み込みの `run` により行う。

load 'helpers/common'

SUT="$PLUGIN_ROOT/scripts/lint-adr.sh"
CORPUS_DIR="$FIXTURES_DIR/lint-adr"
CORPORA=()
PRECONDITION_PATHS=("$CORPUS_DIR/valid" "$CORPUS_DIR/invalid")

setup_file() {
    common_setup_file
}

# 出力中に needle が現れた回数が期待値と一致することを収集する（重複排除の検査用）。
collect_count() {
    local haystack="$1" needle="$2" expect="$3" label="$4"
    local count
    count=$(printf '%s\n' "$haystack" | grep -c -- "$needle" || true)
    if [ "$count" -eq "$expect" ]; then
        collect_ok "$label"
    else
        collect_fail "$label" "$expect 回報告を期待したが $count 回 / output: $haystack"
    fi
    return 0
}

@test "前提: 被テスト検査器と fixture の ADR 群が存在する" {
    assert_preconditions_met
}

# AC1/AC2(穴1): バレット無し＋plain の Related が上書き済みADRを指す → 参照先退役違反
# AC1/AC2(穴2): リンク形式の Related が上書き済みADRを指す → 参照先退役違反（相互参照違反は出ない）
@test "面①: 退役 ADR への参照の検出" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/18-related-retired-no-bullet"
    collect_rc 1 "(AC1/AC2-穴1): バレット無し Related が退役ADRを指すと参照先退役違反: exit 1"
    collect_contains "$output" "参照先退役違反" \
        '(AC1/AC2-穴1): バレット無し Related が退役ADRを指すと参照先退役違反: "参照先退役違反" を含む'
    collect_contains "$output" "ADR-202611021018-01-related-retired-nb-target" \
        '(AC1/AC2-穴1): バレット無し Related が退役ADRを指すと参照先退役違反: "ADR-202611021018-01-related-retired-nb-target" を含む'
    collect_not_contains "$output" "相互参照違反" \
        '(AC1/AC2-穴1): バレット無し Related が退役ADRを指すと参照先退役違反: "相互参照違反" を含まない'

    run_sut "$CORPUS_DIR/invalid/19-related-retired-link"
    collect_rc 1 "(AC1/AC2-穴2): リンク形式 Related が退役ADRを指すと参照先退役違反: exit 1"
    collect_contains "$output" "参照先退役違反" \
        '(AC1/AC2-穴2): リンク形式 Related が退役ADRを指すと参照先退役違反: "参照先退役違反" を含む'
    collect_contains "$output" "ADR-202611121019-01-related-retired-link-old" \
        '(AC1/AC2-穴2): リンク形式 Related が退役ADRを指すと参照先退役違反: "ADR-202611121019-01-related-retired-link-old" を含む'
    collect_not_contains "$output" "相互参照違反" \
        '(AC1/AC2-穴2): リンク形式 Related が退役ADRを指すと参照先退役違反: "相互参照違反" を含まない'

    collect_finish
}

# AC6/AC8: Related が非存在 slug を指す → dangling 参照違反（解決不能＝fail-safe を統合）
@test "面②: dangling 参照の検出" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/20-related-dangling"
    collect_rc 1 "(AC6/AC8): Related が非存在slugを指すと dangling 参照違反: exit 1"
    collect_contains "$output" "dangling 参照違反" \
        '(AC6/AC8): Related が非存在slugを指すと dangling 参照違反: "dangling 参照違反" を含む'
    collect_contains "$output" "ADR-202612021020-01-does-not-exist" \
        '(AC6/AC8): Related が非存在slugを指すと dangling 参照違反: "ADR-202612021020-01-does-not-exist" を含む'

    collect_finish
}

# gap1(セルフレビュー反映): リンクラベルが説明文で stem がパス部のみの Related
# （`- Related: [詳細](./ADR-X.md)`）でも先頭 stem 抽出で退役を検出する（書式非依存の
# 適用範囲＝リンクラベル書式。旧実装は `Related:` 直後の stem 隣接を前提とし取り漏らした）
@test "面③: リンクラベル書式に依存しない判定" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/22-related-link-label"
    collect_rc 1 "(gap1-リンクラベル書式): リンクラベルが説明文でも先頭stem抽出で退役検出: exit 1"
    collect_contains "$output" "参照先退役違反" \
        '(gap1-リンクラベル書式): リンクラベルが説明文でも先頭stem抽出で退役検出: "参照先退役違反" を含む'
    collect_contains "$output" "ADR-202701021022-01-related-linklabel-target" \
        '(gap1-リンクラベル書式): リンクラベルが説明文でも先頭stem抽出で退役検出: "ADR-202701021022-01-related-linklabel-target" を含む'
    collect_not_contains "$output" "相互参照違反" \
        '(gap1-リンクラベル書式): リンクラベルが説明文でも先頭stem抽出で退役検出: "相互参照違反" を含まない'

    collect_finish
}

# AC2(誤検出回避): 全4書式の有効参照・散文が実在しない stem を引用する行・先頭 stem が
# 後継なし退役の行は、いずれも違反にならず exit 0（先頭stem抽出の要、および退役検査の対象語彙の限定）
#
# 散文のデコイに実在しない stem を置くのは、後続 stem を拾う退行が **dangling 違反**として
# 現れるようにするためである。デコイを退役 ADR にすると、退役検査の対象語彙が縮んだ時点で
# 退行が違反を生まなくなり、本ケースの検出力が黙って失われる（fixture 側の設計意図）。
@test "面④: 誤検出の回避" {
    collect_init

    local source_file="$CORPUS_DIR/valid/06-related-valid/ADR-202612310906-01-related-valid-source.md"
    collect_contains "$(cat "$source_file")" "ADR-209901010101-01-nonexistent-quoted" \
        "(AC2-誤検出回避): 実在しないstemを引用するデコイ行がfixtureに存在する（行が消えると本ケースの検出力が空回りする）"

    run_sut "$CORPUS_DIR/valid/06-related-valid"
    collect_rc 0 "(AC2-誤検出回避): 全書式の有効参照・散文の非実在stem引用は exit 0: exit 0"
    collect_not_contains "$output" "参照先退役違反" \
        '(AC2-誤検出回避): 全書式の有効参照・散文の非実在stem引用は exit 0: "参照先退役違反" を含まない'
    collect_not_contains "$output" "dangling 参照違反" \
        '(AC2-誤検出回避): 全書式の有効参照・散文の非実在stem引用は exit 0: "dangling 参照違反" を含まない'

    collect_finish
}

# 同一 source が複数の `Related:` 行から同じ退役 ADR を指しても参照先退役違反は1回のみ報告する
# （extract_body_related のファイル内 dedup。dedup を外すと二重報告に戻る）。
@test "面⑤: Related の重複排除" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/23-related-dup-report"
    collect_count "$output" "参照先退役違反.*ADR-202702021023-01-related-dup-target" 1 \
        "(related dup dedup): 複数Related行が同一退役ADRを指しても違反は1回のみ（count=1）"
    collect_not_contains "$output" "相互参照違反" \
        '(related dup dedup): 複数Related行が同一退役ADRを指しても違反は1回のみ: "相互参照違反" を含まない'

    collect_finish
}

# AC2(後継なし退役): 先頭 stem が後継を持たずに退役した（廃止済み）ADR である `Related:` 行は
# 違反にならない。参照先が上書き済みなら「その決定を引き継いだ後継へ差し替える」という一意の是正先が
# あるが、後継なしの退役には差し替え先が一意に定まらず、検査が具体的な直し方を指示できない。
# レイヤ4 の参照先退役検査は参照先 validity=上書き済み のみを対象とする。
# lint-adr.sh は違反を出力するたび violations を加算し violations > 0 なら exit 1 で終わるため、
# 「出力に当該 stem が現れる」⟹「rc=1」⟹ 面④ の exit 0 チェックも落ちる構造上、本ケース単独の
# 検出力は無い。面④ と同じ内容を当該 stem 名指しで固定し、何を守っているかの可読性のために残す。
@test "面⑦: 後継なし退役先への参照は違反にならない" {
    collect_init

    local source_file="$CORPUS_DIR/valid/06-related-valid/ADR-202612310906-01-related-valid-source.md"
    collect_contains "$(cat "$source_file")" "ADR-202701030906-01-related-valid-retired-mentioned" \
        "(AC2-後継なし退役): 後継なし退役ADRを先頭stemに指すRelated行がfixtureに存在する（行が消えると本ケースが自明に成立する）"

    run_sut "$CORPUS_DIR/valid/06-related-valid"
    collect_rc 0 "(AC2-後継なし退役): 先頭stemが後継なし退役ADRのRelatedは違反にならない: exit 0"
    collect_not_contains "$output" "ADR-202701030906-01-related-valid-retired-mentioned" \
        '(AC2-後継なし退役): 先頭stemが後継なし退役ADRのRelatedは違反にならない: 当該 stem が出力に現れない'

    collect_finish
}

# AC5: レイヤ4仕様のヘッダ成文化。判定単位の書式非依存化・退役/dangling 検査の仕様を
# lint-adr.sh ヘッダに既存レイヤ1〜3 と同形式で成文化する。削除で red 化する必須アサート。
#
# 検索対象は全文ではなく `set -euo pipefail` までのヘッダブロックに限定する。レイヤ名・
# 検査名は節見出しや変数コメントにも現れるため、全文検索ではヘッダの記述ブロックを丸ごと
# 削除してもグリーンのままとなり、保護対象を守れない（レイヤ5 側と同じ限定である）。
# 加えて検査語はブロック固有の見出しでアンカーする。「生存性・実在性」はファイル冒頭の
# 要約行（レイヤ横断の性質列挙）にも現れるため、ヘッダへ限定するだけでは不足する。
@test "面⑥: レイヤ4 仕様のヘッダ成文化" {
    collect_init

    local header
    header=$(sed -n '1,/^set -euo pipefail/p' "$SUT" 2>/dev/null || true)
    collect_contains "$header" "レイヤ4" "(AC5): ヘッダにレイヤ4の記述が存在する"
    collect_contains "$header" "レイヤ4（Related 参照の生存性・実在性）" \
        "(AC5): ヘッダにレイヤ4（Related 参照の生存性・実在性）仕様が成文化されている"

    collect_finish
}

# ---- レイヤ単位の独立起動 ----
#
# Issue #800 の構造整理まで、レイヤ4 が消費する事実（stem から validity への写像）は
# レイヤ1 のループ内で副次的に充填されており、レイヤ1 を実行せずにレイヤ4 を起動できなかった。
# 事実の収集だけを済ませた状態でレイヤ4 だけを起動し、起動したレイヤの違反だけが出ることを
# 外から確かめる。読み込みは run_sut_layer が部分シェル経由で行う。
@test "面⑧: レイヤ4 を単独で起動できる" {
    collect_init

    # 起動したレイヤの違反は出ること。この項が無いと、レイヤ関数の中身を空にする変異でも
    # 下の「他レイヤの違反が出ない」項が緑のまま通る。
    run_sut_layer check_layer4_related_references "$CORPUS_DIR/invalid/20-related-dangling"
    collect_rc 0 "#800: dangling の ADR 群へレイヤ4 だけを起動できる"
    collect_contains "$output" "dangling 参照違反" \
        "#800: 起動したレイヤの違反は出力する"
    collect_contains "$output" "[violations=1]" \
        "#800: 起動したレイヤの違反は数える"

    # 起動しなかったレイヤの違反は出ないこと。invalid/24 はレイヤ5 だけが発火する ADR 群。
    run_sut_layer check_layer4_related_references "$CORPUS_DIR/invalid/24-filename-format-invalid"
    collect_rc 0 "#800: ファイル名形式違反の ADR 群へレイヤ4 だけを起動できる"
    collect_contains "$output" "[violations=0]" \
        "#800: レイヤ4 の単独起動でレイヤ5 の違反を数えない"
    collect_not_contains "$output" "ファイル名形式違反" \
        "#800: レイヤ4 の単独起動でレイヤ5 の違反は出ない"

    collect_finish
}
