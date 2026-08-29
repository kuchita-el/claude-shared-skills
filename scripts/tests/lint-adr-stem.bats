#!/usr/bin/env bats
# ADR drift-lint のレイヤ5（plugins/adr/scripts/lint-adr.sh）のテスト。
#
# 仕様: レイヤ1〜4 はいずれもファイル本文（front-matter・本文節）と index を見るだけで、
# ファイル名そのものを検査しない。この欠落により同一識別子の ADR が2本 main へ到達した
# 実績がある。レイヤ5 はファイル名を第一級の検査対象に加える。
# 検査対象集合はレイヤ1 と同一（front-matter を持つ ADR のみ。旧形式はスキップ）。
#
# 【レイヤ5 が最後の関門である理由】
# レイヤ5 の識別子重複検査は、識別子の時刻部が分粒度であるために発番側（next-adr-id.sh）
# では構造的に消せない残余——同一分・別ブランチ・同一連番の重複——を受け止める最後の関門で
# ある。本テストはその検出を固定する（旧手順下では重複が1か月以上検出されないまま残った
# 実測がある）。
#
# 【識別子部の抽出を形式検査より緩くする判断と、それを守る ADR 群】
# lint-adr.sh は識別子部の抽出を形式検査より緩くしている。抽出を形式検査と同じ厳しさへ
# 変えると、旧規約ファイル名どうしの重複が報告されなくなる。面⑤が使う
# invalid/28-legacy-duplicate-id の ADR 群は、この判断を編集から守るために置かれている。
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

# 面②③の入力。`<stem>|<旧 [PASS] ラベル>`
# 暦妥当性の境界は fixture では月13 しか通っておらず、ADR_STEM_PATTERN の日・時・分の
# 選択肢を壊す編集が回帰に掛からない。パターンを直接叩いて MATCH/REJECT を突き合わせ、
# fixture を増やさずに境界を固定する。
STEM_ACCEPT=(
    'ADR-202601010000-01-a|(AC1-境界): 適合 stem を受理する: ADR-202601010000-01-a'
    'ADR-202612312359-99-boundary-max|(AC1-境界): 適合 stem を受理する: ADR-202612312359-99-boundary-max'
    'ADR-202601011030-10-seq-ten|(AC1-境界): 適合 stem を受理する: ADR-202601011030-10-seq-ten'
    'ADR-202607262019-01-adr-id-timestamp-numbering|(AC1-境界): 適合 stem を受理する: ADR-202607262019-01-adr-id-timestamp-numbering'
)

# 期待REJECT: AC1 が例示する暦不正（月13・日32・時24）＋分60・構造違反
STEM_REJECT=(
    'ADR-202613011030-01-bad-month|(AC1-境界): 不適合 stem を拒否する: ADR-202613011030-01-bad-month'
    'ADR-202601321030-01-bad-day|(AC1-境界): 不適合 stem を拒否する: ADR-202601321030-01-bad-day'
    'ADR-202601012430-01-bad-hour|(AC1-境界): 不適合 stem を拒否する: ADR-202601012430-01-bad-hour'
    'ADR-202601011060-01-bad-minute|(AC1-境界): 不適合 stem を拒否する: ADR-202601011060-01-bad-minute'
    'ADR-202601011030-1-short-seq|(AC1-境界): 不適合 stem を拒否する: ADR-202601011030-1-short-seq'
    'ADR-202601011030-00-zero-seq|(AC1-境界): 不適合 stem を拒否する: ADR-202601011030-00-zero-seq'
    'ADR-202601011030-01-Bad-Upper|(AC1-境界): 不適合 stem を拒否する: ADR-202601011030-01-Bad-Upper'
    'ADR-202601011030-01-double--hyphen|(AC1-境界): 不適合 stem を拒否する: ADR-202601011030-01-double--hyphen'
    'ADR-202601011030-01-trailing-|(AC1-境界): 不適合 stem を拒否する: ADR-202601011030-01-trailing-'
    'ADR-202601011030-01|(AC1-境界): 不適合 stem を拒否する: ADR-202601011030-01'
    'ADR-2026010110301-01-too-long|(AC1-境界): 不適合 stem を拒否する: ADR-2026010110301-01-too-long'
)

# 表が空になった（あるいは大きく削られた）まま緑になる経路を塞ぐ下限。面②③のループは
# 反復0回でも collect_finish が成功を返すため、照合の回数そのものを1検査項目として数える。
# 数える対象はループが実際に走らせた照合の回数であり、配列リテラルの要素数ではない
# （宣言を読むと、照合ループごと消えても配列さえ残っていれば下限が緑を返す）。
# 下限は名目値ではなく現在の実数を置く。lint-adr-layers.bats の LAYER1_INVALID_CASE_MIN と
# 同型であり、同型の穴が本ファイルにも残っていた。
# 由来: Issue #800 に対する PR #801 のレビュー指摘1（参考として挙げられた派生）。
STEM_ACCEPT_MIN=4
STEM_REJECT_MIN=11

# 照合件数の下限を1件の検査項目として収集する。面②③が同じ形で使う。
collect_stem_case_min() {
    local matched="$1" min="$2" label="$3"
    if [ "$matched" -ge "$min" ]; then
        collect_ok "$label（$matched 件 / 下限 $min 件）"
    else
        collect_fail "$label" \
            "照合件数 $matched 件が下限 $min 件を下回る（表の欠落・照合ループの退行。表を意図して減らした場合のみ本定数を下げる）"
    fi
    return 0
}

setup_file() {
    common_setup_file
}

# lint-adr.sh 本体を実行せずにパターン定義だけを取り出す。
# 検査器は直接実行されたときだけ検査本体を走らせるため、読み込みだけなら対象ディレクトリを
# 指定していなくても終了しない。取得は**部分シェル経由**で行う。ケース内で直接読み込むと
# 検査器の `set -euo pipefail` が bats 本体のシェルへ漏れ、nounset の下で共有ヘルパの
# 空配列参照が異常終了しうる。部分シェルなら出力と終了コードだけを観測できる。
load_stem_pattern() {
    local value
    value=$(bash -c 'source "$1"; printf "%s" "${ADR_STEM_PATTERN:-}"' _ "$SUT" 2>/dev/null) || return 1
    if [ -z "$value" ]; then
        return 1
    fi
    ADR_STEM_PATTERN="$value"
    return 0
}

@test "前提: 被テスト検査器と fixture の ADR 群が存在する" {
    assert_preconditions_met
}

# AC7: レイヤ5仕様のヘッダ成文化。削除で red 化する必須アサート。
# 検索対象は `cat` の全文ではなく `set -euo pipefail` までのヘッダブロックに限定する。
# レイヤ名・検査名は変数コメントや printf の違反メッセージにも現れるため、全文検索では
# ヘッダの記述ブロックを丸ごと削除してもグリーンのままとなり、AC7 の成果物を保護できない。
@test "面①: レイヤ5 仕様のヘッダ成文化" {
    collect_init

    local header
    header=$(sed -n '1,/^set -euo pipefail/p' "$SUT" 2>/dev/null || true)

    collect_contains "$header" "レイヤ5" "(AC7): ヘッダにレイヤ5の記述が存在する"
    collect_contains "$header" "ファイル名形式違反" \
        "(AC7): ヘッダにファイル名形式検査の違反条件が成文化されている"
    collect_contains "$header" "識別子重複違反" \
        "(AC7): ヘッダに識別子重複検査の違反条件が成文化されている"
    collect_contains "$header" "H1 整合違反" \
        "(AC7): ヘッダに H1 整合検査の違反条件が成文化されている"
    collect_contains "$header" "検査対象集合はレイヤ1 と同一" \
        "(AC7): ヘッダにレイヤ5の検査対象集合が成文化されている"

    collect_finish
}

@test "面②: stem パターンの受理" {
    collect_init

    if load_stem_pattern; then
        local entry stem label matched=0
        for entry in "${STEM_ACCEPT[@]}"; do
            stem="${entry%%|*}"
            label="${entry#*|}"
            if [[ "$stem" =~ $ADR_STEM_PATTERN ]]; then
                collect_ok "$label"
            else
                collect_fail "$label" "適合 stem を誤って拒否した"
            fi
            matched=$((matched + 1))
        done
        collect_stem_case_min "$matched" "$STEM_ACCEPT_MIN" \
            "(AC1-境界): 受理側の照合件数が下限を満たす"
    else
        collect_fail "(AC1-境界): ADR_STEM_PATTERN の定義" "定義が見つかりません: $SUT"
    fi

    collect_finish
}

@test "面③: stem パターンの拒否" {
    collect_init

    if load_stem_pattern; then
        local entry stem label matched=0
        for entry in "${STEM_REJECT[@]}"; do
            stem="${entry%%|*}"
            label="${entry#*|}"
            if [[ "$stem" =~ $ADR_STEM_PATTERN ]]; then
                collect_fail "$label" "不適合 stem を誤って受理した"
            else
                collect_ok "$label"
            fi
            matched=$((matched + 1))
        done
        collect_stem_case_min "$matched" "$STEM_REJECT_MIN" \
            "(AC1-境界): 拒否側の照合件数が下限を満たす"
    else
        collect_fail "(AC1-境界): ADR_STEM_PATTERN の定義" "定義が見つかりません: $SUT"
    fi

    collect_finish
}

# AC1: 形式不適合（時刻部の桁数不足）／暦として妥当でない時刻部（月13）／`ADR-` 接頭辞欠落。
# 暦不正は桁数のみの照合では通過するため、next-adr-id.sh の発番側検証と同一の強度を
# lint 側にも置いていることの回帰。接頭辞を欠くファイルは `ADR-*.md` グロブに当たらず
# 全レイヤを素通りするため、レイヤ5 がこの経路も形式違反として塞ぐ。
@test "面④: ファイル名形式違反の検出" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/24-filename-format-invalid"
    collect_rc 1 "(AC1/レイヤ5): 時刻部の桁数不足を形式違反として検出: exit 1"
    collect_contains "$output" "ファイル名形式違反" \
        '(AC1/レイヤ5): 時刻部の桁数不足を形式違反として検出: "ファイル名形式違反" を含む'
    collect_contains "$output" "ADR-2026120-01-bad-digits.md" \
        '(AC1/レイヤ5): 時刻部の桁数不足を形式違反として検出: "ADR-2026120-01-bad-digits.md" を含む'

    run_sut "$CORPUS_DIR/invalid/25-filename-calendar-invalid"
    collect_rc 1 "(AC1/レイヤ5): 暦として不正な月を形式違反として検出: exit 1"
    collect_contains "$output" "ファイル名形式違反" \
        '(AC1/レイヤ5): 暦として不正な月を形式違反として検出: "ファイル名形式違反" を含む'
    collect_contains "$output" "ADR-202613011030-01-bad-month.md" \
        '(AC1/レイヤ5): 暦として不正な月を形式違反として検出: "ADR-202613011030-01-bad-month.md" を含む'

    run_sut "$CORPUS_DIR/invalid/29-missing-adr-prefix"
    collect_rc 1 "(AC1/レイヤ5): ADR- 接頭辞を欠く誤名ADRを形式違反として検出: exit 1"
    collect_contains "$output" "ファイル名形式違反" \
        '(AC1/レイヤ5): ADR- 接頭辞を欠く誤名ADRを形式違反として検出: "ファイル名形式違反" を含む'
    collect_contains "$output" "202612091009-01-missing-prefix.md" \
        '(AC1/レイヤ5): ADR- 接頭辞を欠く誤名ADRを形式違反として検出: "202612091009-01-missing-prefix.md" を含む'

    collect_finish
}

# AC2: 同一識別子を持つ ADR が2本 → 重複した識別子と該当する全ファイル名を出力に含む。
# 旧規約ファイル名どうしの重複（invalid/28）は「識別子部の抽出を形式検査より緩くする」判断を
# 守る ADR 群であり、形式違反も同時に報告されるため識別子重複違反を明示的にアサートする。
@test "面⑤: 識別子重複の検出" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/26-duplicate-adr-id"
    collect_rc 1 "(AC2/レイヤ5): 識別子重複を検出し全該当ファイルを列挙: exit 1"
    collect_contains "$output" "識別子重複違反" \
        '(AC2/レイヤ5): 識別子重複を検出し全該当ファイルを列挙: "識別子重複違反" を含む'
    collect_contains "$output" "ADR-202612051026-01" \
        '(AC2/レイヤ5): 識別子重複を検出し全該当ファイルを列挙: "ADR-202612051026-01" を含む'
    collect_contains "$output" "ADR-202612051026-01-dup-first.md" \
        '(AC2/レイヤ5): 識別子重複を検出し全該当ファイルを列挙: "ADR-202612051026-01-dup-first.md" を含む'
    collect_contains "$output" "ADR-202612051026-01-dup-second.md" \
        '(AC2/レイヤ5): 識別子重複を検出し全該当ファイルを列挙: "ADR-202612051026-01-dup-second.md" を含む'

    run_sut "$CORPUS_DIR/invalid/28-legacy-duplicate-id"
    collect_rc 1 "(AC2/レイヤ5): 旧規約ファイル名どうしの識別子重複も検出: exit 1"
    collect_contains "$output" "識別子重複違反" \
        '(AC2/レイヤ5): 旧規約ファイル名どうしの識別子重複も検出: "識別子重複違反" を含む'
    collect_contains "$output" "ADR-20260621-01" \
        '(AC2/レイヤ5): 旧規約ファイル名どうしの識別子重複も検出: "ADR-20260621-01" を含む'
    collect_contains "$output" "ADR-20260621-01-legacy-dup-a.md" \
        '(AC2/レイヤ5): 旧規約ファイル名どうしの識別子重複も検出: "ADR-20260621-01-legacy-dup-a.md" を含む'
    collect_contains "$output" "ADR-20260621-01-legacy-dup-b.md" \
        '(AC2/レイヤ5): 旧規約ファイル名どうしの識別子重複も検出: "ADR-20260621-01-legacy-dup-b.md" を含む'

    collect_finish
}

# AC3: H1 整合検査は2つの分岐を持つ。
# 不一致: H1 見出しの識別子部がファイル名の識別子部と一致しない → 違反。
# 不在: H1 に識別子が現れない → 違反。条文はこれに「H1 見出しを持たない場合」を含めており、
# 実装も抽出結果が空であることを一様の判定材料にしている。invalid/33 は「H1 はあるが識別子を
# 欠く」ファイルと「H1 そのものが無い」ファイルを同梱し、両方の到達経路を1つの ADR 群で
# 押さえる（`extract_h1_adr_id` は前者では `# ` 行に当たって抽出に失敗し、後者では `# ` 行に
# 一度も当たらずループを抜ける）。
@test "面⑥: H1 整合違反の検出" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/27-h1-id-mismatch"
    collect_rc 1 "(AC3/レイヤ5): H1 の識別子部とファイル名の不整合を検出: exit 1"
    collect_contains "$output" "H1 整合違反（H1 見出しの識別子部 " \
        '(AC3/レイヤ5): H1 の識別子部とファイル名の不整合を検出: 不一致を名指しする違反メッセージを含む'
    collect_contains "$output" "ADR-202612061027-01-h1-mismatch.md" \
        '(AC3/レイヤ5): H1 の識別子部とファイル名の不整合を検出: "ADR-202612061027-01-h1-mismatch.md" を含む'

    run_sut "$CORPUS_DIR/invalid/33-h1-id-absent"
    collect_rc 1 "(AC3/レイヤ5): H1 に識別子が現れない場合を検出: exit 1"
    collect_contains "$output" 'H1 整合違反（本文の最初の "# " 見出しに ADR 識別子が見つかりません' \
        '(AC3/レイヤ5): H1 に識別子が現れない場合を検出: 識別子不在を名指しする違反メッセージを含む'
    collect_contains "$output" "ADR-202612111033-01-h1-id-absent.md" \
        '(AC3/レイヤ5): H1 に識別子が現れない場合を検出: "ADR-202612111033-01-h1-id-absent.md"（H1 はあるが識別子を欠く）を含む'
    collect_contains "$output" "ADR-202612121033-01-h1-heading-absent.md" \
        '(AC3/レイヤ5): H1 に識別子が現れない場合を検出: "ADR-202612121033-01-h1-heading-absent.md"（H1 を持たない）を含む'

    collect_finish
}

# 制約（旧形式の扱い）: front-matter を持たない旧形式 ADR は、ファイル名が新形式に
# 適合しなくてもレイヤ5 の検査対象外（レイヤ1 のスキップと同一の対象集合）。
# 同居する新形式 ADR は正しく通過する。
@test "面⑦: 検査対象集合の制約" {
    collect_init

    run_sut "$CORPUS_DIR/valid/07-legacy-filename-skipped"
    collect_rc 0 "(制約/レイヤ5): front-matter 無しの旧形式ファイル名はスキップされ exit 0: exit 0"
    collect_not_contains "$output" "ファイル名形式違反" \
        '(制約/レイヤ5): front-matter 無しの旧形式ファイル名はスキップされ exit 0: "ファイル名形式違反" を含まない'
    collect_not_contains "$output" "H1 整合違反" \
        '(制約/レイヤ5): front-matter 無しの旧形式ファイル名はスキップされ exit 0: "H1 整合違反" を含まない'

    collect_finish
}

# AC5(誤検出回避): front-matter 内の YAML コメント行は行頭 `# ` に当たるが H1 ではない。
# 読み飛ばさないと H1 と誤認して偽陽性を報告し、commit 前ゲートがコミットを止める。
# 既存の valid ADR 群にレイヤ5 が発火しないことも併せて固定する。
@test "面⑧: 誤検出の回避" {
    collect_init

    run_sut "$CORPUS_DIR/valid/08-frontmatter-yaml-comment"
    collect_rc 0 "(AC5/レイヤ5-誤検出回避): front-matter の YAML コメントを H1 と誤認しない: exit 0"
    collect_not_contains "$output" "H1 整合違反" \
        '(AC5/レイヤ5-誤検出回避): front-matter の YAML コメントを H1 と誤認しない: "H1 整合違反" を含まない'

    run_sut "$CORPUS_DIR/valid/01-mixed-validity"
    collect_rc 0 "(AC5/レイヤ5-誤検出回避): 適合の ADR 群では発火しない: exit 0"
    collect_not_contains "$output" "ファイル名形式違反" \
        '(AC5/レイヤ5-誤検出回避): 適合の ADR 群では発火しない: "ファイル名形式違反" を含まない'
    collect_not_contains "$output" "識別子重複違反" \
        '(AC5/レイヤ5-誤検出回避): 適合の ADR 群では発火しない: "識別子重複違反" を含まない'
    collect_not_contains "$output" "H1 整合違反" \
        '(AC5/レイヤ5-誤検出回避): 適合の ADR 群では発火しない: "H1 整合違反" を含まない'

    collect_finish
}
