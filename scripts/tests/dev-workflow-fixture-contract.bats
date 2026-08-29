#!/usr/bin/env bats
load 'helpers/common'

# dev-workflow の fixture が固定している境界を、期待値ファイルの構造として検査する。
#
# 【ディレクトリの存在確認を置かない理由】
# 旧 contract 系は fixture を `[ -d ... ]` で見るだけのケースを持っており、その配下の
# expected.json は一度も読まれていなかった。中身が壊れても緑で通るため、境界は何も
# 固定されていない。本ファイルのケースはすべて期待値ファイルの中身を読む。
#
# 【停止系と非停止系を対で置く理由】
# 停止側（decision=stop）だけを検査すると、停止しない側の契約が失われても検出できない。
# create は停止2件と非停止1件、refine は host adapter の注入とフォールバックを対で読む。
#
# 【走査0件を緑にしない】
# 走査は find の出力を mapfile で受け、走査回数を実行時カウンタで数えて下限をアサートする。
# 下限は実測値との等値ではない。fixture の正当な追加で赤にせず、縮小（ディレクトリが空に
# なる・glob が0件へ落ちる）だけを赤にするためである。

FIXTURE_ROOT="$FIXTURES_DIR/dev-workflow"

# 走査件数の下限（実測13件）。
FIXTURE_MIN=13

# implementation 系の下限。5件それぞれが完了を拒否することに意味がある集合であり、
# 下限と各件の内容検査の対で担保する。
IMPL_FIXTURE_MIN=5

dw_fixture_dirs() {
    find "$FIXTURE_ROOT" -mindepth 2 -maxdepth 2 -type d | sort
}

# jq のフィルタが真を返すことを収集型で判定する。
collect_jq() {
    local file="$1" filter="$2" label="$3"
    if [ ! -f "$file" ]; then
        collect_fail "$label" "期待値ファイルが無い: ${file#"$REPO_ROOT"/}"
        return 0
    fi
    if jq -e "$filter" "$file" >/dev/null 2>&1; then
        collect_ok "$label"
    else
        collect_fail "$label" "フィルタが偽: $filter / 実体: $(tr -d '\n' <"$file")"
    fi
    return 0
}

# 走査件数の下限を収集型で判定する。
collect_scanned_min() {
    local scanned="$1" min="$2" label="$3"
    if [ "$scanned" -ge "$min" ]; then
        collect_ok "$label（下限 $min 件）"
    else
        collect_fail "$label（下限 $min 件）" "実測 $scanned 件"
    fi
    return 0
}

@test "fixture 走査: 全ディレクトリが非空の期待値ファイルを持ち JSON は構文として妥当である" {
    collect_init
    local -a dirs=()
    mapfile -t dirs < <(dw_fixture_dirs)

    local scanned=0 d rel n f
    for d in ${dirs[@]+"${dirs[@]}"}; do
        scanned=$((scanned + 1))
        rel="${d#"$REPO_ROOT"/}"

        local -a expected=()
        mapfile -t expected < <(find "$d" -maxdepth 1 -name 'expected.*' -type f | sort)
        n="${#expected[@]}"
        if [ "$n" -eq 0 ]; then
            collect_fail "期待値ファイルを1つ以上持つ: $rel" "expected.* が無い"
            continue
        fi
        collect_ok "期待値ファイルを1つ以上持つ: $rel"

        for f in "${expected[@]}"; do
            if [ -s "$f" ]; then
                collect_ok "期待値ファイルが非空: ${f#"$REPO_ROOT"/}"
            else
                collect_fail "期待値ファイルが非空: ${f#"$REPO_ROOT"/}" "0バイト"
            fi
            case "$f" in
                *.json)
                    if jq -e . "$f" >/dev/null 2>&1; then
                        collect_ok "JSON として妥当: ${f#"$REPO_ROOT"/}"
                    else
                        collect_fail "JSON として妥当: ${f#"$REPO_ROOT"/}" "jq が解釈できない"
                    fi
                    ;;
            esac
        done
    done

    collect_scanned_min "$scanned" "$FIXTURE_MIN" "走査した fixture ディレクトリの件数"
    collect_finish
}

@test "create 系: 停止2件が書き込みを伴わず停止し 非停止1件が生成物を持つ" {
    collect_init
    local root="$FIXTURE_ROOT/create"
    local scanned=0 name

    # 停止系。decision が stop で、未解決項目を持ち、書き込みが1件も無いことを
    # 3条件の共起として要求する（どれか1つでも欠ければ赤になる）。
    for name in missing-ac rejected; do
        scanned=$((scanned + 1))
        collect_jq "$root/$name/expected.json" \
            '.decision == "stop" and (.unresolved | length > 0) and (.writes | length == 0)' \
            "停止契約が成立する: create/$name"
    done

    # 非停止系。停止しない側の正例であり、生成物が空でなく受入条件の節を持つ。
    scanned=$((scanned + 1))
    local complete="$root/complete/expected.md"
    if [ -s "$complete" ]; then
        collect_ok "生成物が非空: create/complete"
        collect_contains "$(cat "$complete")" '## 受入条件' "生成物が受入条件の節を持つ: create/complete"
    else
        collect_fail "生成物が非空: create/complete" "expected.md が無いか0バイト"
    fi

    collect_scanned_min "$scanned" 3 "走査した create fixture の件数"
    collect_finish
}

@test "refine 系: status が Ready 境界の2値を取り host adapter の注入とフォールバックが対で固定される" {
    collect_init
    local root="$FIXTURE_ROOT/refine"
    local scanned=0 name

    # status の値域。Ready / Not Ready のいずれかであることを4件すべてに要求する。
    for name in single-ready single-not-ready single-codex-injected single-codex-main-fallback; do
        scanned=$((scanned + 1))
        collect_jq "$root/$name/expected.json" \
            '.status == "Ready" or .status == "Not Ready"' \
            "status が Ready 境界の2値を取る: refine/$name"
    done

    # Ready 側は充足した検査項目を、Not Ready 側は未解決項目を持つ。
    # 件数への固定は置かない（未解決項目が2件へ増える正当な更新で赤にしないため）。
    collect_jq "$root/single-ready/expected.json" \
        '.status == "Ready" and (.checks | length > 0)' \
        "Ready 側が充足項目を持つ: refine/single-ready"
    collect_jq "$root/single-not-ready/expected.json" \
        '.status == "Not Ready" and (.unresolved | length > 0)' \
        "Not Ready 側が未解決項目を持つ: refine/single-not-ready"

    # host adapter witness。注入とフォールバックを対で読む。
    collect_jq "$root/single-codex-injected/expected.json" \
        '.execution == "injected"' \
        "注入側の execution が固定される: refine/single-codex-injected"
    collect_jq "$root/single-codex-main-fallback/expected.json" \
        '.execution == "main-fallback"' \
        "フォールバック側の execution が固定される: refine/single-codex-main-fallback"

    collect_scanned_min "$scanned" 4 "走査した refine fixture の件数"
    collect_finish
}

@test "implementation 系: 未解決を含む全 fixture が Ready を拒否する" {
    collect_init
    local -a files=()
    mapfile -t files < <(find "$FIXTURE_ROOT/implementation" -mindepth 2 -maxdepth 2 -name 'expected.json' -type f | sort)

    local scanned=0 f rel
    for f in ${files[@]+"${files[@]}"}; do
        scanned=$((scanned + 1))
        rel="${f#"$FIXTURE_ROOT"/}"
        collect_jq "$f" '.status != "Ready"' "完了を拒否する: $rel"
        collect_jq "$f" '.status | type == "string" and length > 0' "status が非空の文字列である: $rel"
    done

    collect_scanned_min "$scanned" "$IMPL_FIXTURE_MIN" "走査した implementation fixture の件数"
    collect_finish
}

@test "plan 系: レビュー往復の上限で判断依頼へ抜ける境界が固定される" {
    collect_init
    local f="$FIXTURE_ROOT/plan/reviewer-fail-twice/expected.json"

    collect_jq "$f" '.status == "decision-request"' "上限到達で判断依頼へ抜ける: plan/reviewer-fail-twice"
    collect_jq "$f" '(.reviewRounds | type) == "number" and .reviewRounds <= 2' \
        "レビュー往復が上限2以下に収まる: plan/reviewer-fail-twice"

    collect_finish
}
