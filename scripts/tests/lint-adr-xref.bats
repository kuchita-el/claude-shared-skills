#!/usr/bin/env bats
# ADR drift-lint のレイヤ4（plugins/adr/scripts/lint-adr.sh）のテスト。
#
# 非 Supersede 参照妥当性 lint（退役参照検査・判定単位の書式非依存化）。
# 有効 ADR の `## 関連ADR`（Related:）／`## 保留した決定`（park）の先頭 ADR stem を、
# 行頭バレット有無・markdown リンク形式有無を問わず抽出し、参照先が退役（上書き済み/廃止済み）
# なら参照先退役違反、非存在なら dangling 参照違反として報告する。park は dangling のみ
# （退役非適用）。
#
# 【レイヤ4 の判定単位の正本はここにある】
# `Related:` 以降で最初に現れる ADR stem を、行頭バレットの有無・markdown リンクの有無・
# リンクラベルの書式を問わず取ること——この判定単位はどの ADR にも成文化されていない。
# 本テストと scripts/fixtures/lint-adr/ がその正であり、書式非依存性を境界事例として固定する。
#
# 【配置について】テストと fixture を配布物外へ置く境界は docs/distribution-boundary.md が定める。
#
# corpus は fixture ごとに異なり事前起動を共有できないため、共有 setup_file の CORPORA は
# 空にし、検査器の起動は各ケース内で bats 組み込みの `run` により行う。

load 'helpers/common'

SUT="$PLUGIN_ROOT/scripts/lint-adr.sh"
CORPUS_DIR="$FIXTURES_DIR/lint-adr"
CORPORA=()
PRECONDITION_PATHS=("$CORPUS_DIR/valid" "$CORPUS_DIR/invalid")

setup_file() {
    common_setup_file
}

lint_corpus() {
    run bash "$SUT" "$1"
}

collect_rc() {
    local expect="$1" label="$2"
    if [ "$status" -eq "$expect" ]; then
        collect_ok "$label"
    else
        collect_fail "$label" "exit $expect を期待したが $status / output: $output"
    fi
    return 0
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

@test "前提: 被テスト検査器と fixture corpus が存在する" {
    assert_preconditions_met
}

# AC1/AC2(穴1): バレット無し＋plain の Related が廃止済みADRを指す → 参照先退役違反
# AC1/AC2(穴2): リンク形式の Related が上書き済みADRを指す → 参照先退役違反（相互参照違反は出ない）
@test "面①: 退役 ADR への参照の検出" {
    collect_init

    lint_corpus "$CORPUS_DIR/invalid/18-related-retired-no-bullet"
    collect_rc 1 "(AC1/AC2-穴1): バレット無し Related が退役ADRを指すと参照先退役違反: exit 1"
    collect_contains "$output" "参照先退役違反" \
        '(AC1/AC2-穴1): バレット無し Related が退役ADRを指すと参照先退役違反: "参照先退役違反" を含む'
    collect_contains "$output" "ADR-202611021018-01-related-retired-nb-target" \
        '(AC1/AC2-穴1): バレット無し Related が退役ADRを指すと参照先退役違反: "ADR-202611021018-01-related-retired-nb-target" を含む'

    lint_corpus "$CORPUS_DIR/invalid/19-related-retired-link"
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
# AC6/AC7: park 欄が非存在 slug を指す → dangling 参照違反（park も dangling 検査の対象）
@test "面②: dangling 参照の検出" {
    collect_init

    lint_corpus "$CORPUS_DIR/invalid/20-related-dangling"
    collect_rc 1 "(AC6/AC8): Related が非存在slugを指すと dangling 参照違反: exit 1"
    collect_contains "$output" "dangling 参照違反" \
        '(AC6/AC8): Related が非存在slugを指すと dangling 参照違反: "dangling 参照違反" を含む'
    collect_contains "$output" "ADR-202612021020-01-does-not-exist" \
        '(AC6/AC8): Related が非存在slugを指すと dangling 参照違反: "ADR-202612021020-01-does-not-exist" を含む'

    lint_corpus "$CORPUS_DIR/invalid/21-park-dangling"
    collect_rc 1 "(AC6/AC7): 保留した決定が非存在slugを指すと dangling 参照違反: exit 1"
    collect_contains "$output" "dangling 参照違反" \
        '(AC6/AC7): 保留した決定が非存在slugを指すと dangling 参照違反: "dangling 参照違反" を含む'
    collect_contains "$output" "ADR-202612121021-01-park-missing" \
        '(AC6/AC7): 保留した決定が非存在slugを指すと dangling 参照違反: "ADR-202612121021-01-park-missing" を含む'

    collect_finish
}

# gap1(セルフレビュー反映): リンクラベルが説明文で stem がパス部のみの Related
# （`- Related: [詳細](./ADR-X.md)`）でも先頭 stem 抽出で退役を検出する（書式非依存の
# 適用範囲＝リンクラベル書式。旧実装は `Related:` 直後の stem 隣接を前提とし取り漏らした）
@test "面③: リンクラベル書式に依存しない判定" {
    collect_init

    lint_corpus "$CORPUS_DIR/invalid/22-related-link-label"
    collect_rc 1 "(gap1-リンクラベル書式): リンクラベルが説明文でも先頭stem抽出で退役検出: exit 1"
    collect_contains "$output" "参照先退役違反" \
        '(gap1-リンクラベル書式): リンクラベルが説明文でも先頭stem抽出で退役検出: "参照先退役違反" を含む'
    collect_contains "$output" "ADR-202701021022-01-related-linklabel-target" \
        '(gap1-リンクラベル書式): リンクラベルが説明文でも先頭stem抽出で退役検出: "ADR-202701021022-01-related-linklabel-target" を含む'

    collect_finish
}

# AC2/AC7(誤検出回避): 全4書式の有効参照・散文の退役引用・park→有効/退役(存在)は
# いずれも違反にならず exit 0（先頭stem抽出の要、park は dangling のみ＝J4 の正方向固定）
@test "面④: 誤検出の回避" {
    collect_init

    lint_corpus "$CORPUS_DIR/valid/06-related-valid"
    collect_rc 0 "(AC2/AC7-誤検出回避): 全書式の有効参照・散文退役引用・park退役(存在)は exit 0: exit 0"
    collect_not_contains "$output" "参照先退役違反" \
        '(AC2/AC7-誤検出回避): 全書式の有効参照・散文退役引用・park退役(存在)は exit 0: "参照先退役違反" を含まない'
    collect_not_contains "$output" "dangling 参照違反" \
        '(AC2/AC7-誤検出回避): 全書式の有効参照・散文退役引用・park退役(存在)は exit 0: "dangling 参照違反" を含まない'

    collect_finish
}

# park 参照が markdown リンク形式（`[stem](./stem.md)`）でも dangling 違反は1回のみ報告する
# （ラベル部とパス部で同一 stem を二重報告しない回帰。invalid/21 の park 参照はリンク形式）。
@test "面⑤: park リンクの重複排除" {
    collect_init

    lint_corpus "$CORPUS_DIR/invalid/21-park-dangling"
    collect_count "$output" "ADR-202612121021-01-park-missing" 1 \
        "(park link dedup): リンク形式 park dangling は1回のみ報告（count=1）"

    collect_finish
}

# 同一 source が複数の `Related:` 行から同じ退役 ADR を指しても参照先退役違反は1回のみ報告する
# （extract_body_related のファイル内 dedup。park 側と対称の保護。dedup を外すと二重報告に戻る）。
@test "面⑥: Related の重複排除" {
    collect_init

    lint_corpus "$CORPUS_DIR/invalid/23-related-dup-report"
    collect_count "$output" "ADR-202702021023-01-related-dup-target" 1 \
        "(related dup dedup): 複数Related行が同一退役ADRを指しても違反は1回のみ（count=1）"

    collect_finish
}

# AC5: レイヤ4仕様のヘッダ成文化。判定単位の書式非依存化・退役/dangling 検査の仕様を
# lint-adr.sh ヘッダに既存レイヤ1〜3 と同形式で成文化する。削除で red 化する必須アサート。
@test "面⑦: レイヤ4 仕様のヘッダ成文化" {
    collect_init

    local content
    content=$(cat "$SUT")
    collect_contains "$content" "レイヤ4" "(AC5): ヘッダにレイヤ4の記述が存在する"
    collect_contains "$content" "生存性・実在性" \
        "(AC5): ヘッダにレイヤ4（Related/park 参照の生存性・実在性）仕様が成文化されている"

    collect_finish
}
