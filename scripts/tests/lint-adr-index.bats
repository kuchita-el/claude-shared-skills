#!/usr/bin/env bats
# ADR index 生成（plugins/adr/scripts/gen-adr-index.sh）のテスト。
#
# scripts/fixtures/lint-adr/valid/ の共有 corpus に対して gen-adr-index.sh を起動し、
# 列挙対象の絞り込みと validity 抽出の正規化を検査する。
#
# 【配置について】テストと fixture を配布物外へ置く境界は docs/distribution-boundary.md が定める。

load 'helpers/common'

SUT="$PLUGIN_ROOT/scripts/lint-adr.sh"
GEN_INDEX="$PLUGIN_ROOT/scripts/gen-adr-index.sh"

CORPORA=(
    "mixed-validity|$FIXTURES_DIR/lint-adr/valid/01-mixed-validity|$GEN_INDEX"
    "whitespace-gen|$FIXTURES_DIR/lint-adr/valid/03-whitespace-validity|$GEN_INDEX"
    "whitespace-lint|$FIXTURES_DIR/lint-adr/valid/03-whitespace-validity"
)

PRECONDITION_PATHS=("$GEN_INDEX")

setup_file() {
    common_setup_file
}

# 退避済みの exit code を、渡されたラベルで収集する。
# 緑経路でも必ず collect_ok を呼ぶ（失敗時にしか数えない形は、旧ランナーの欠陥として
# lint-adr-surface.bats が名指ししているものと同型であり、報告の分母を失敗の種類で
# 揺らがせる）。layers / xref / stem が持つ collect_rc と同じ形である。
collect_saved_rc() {
    local key="$1" expect="$2" label="$3" rc
    rc="$(sut_rc "$key")"
    if [ "$rc" = "$expect" ]; then
        collect_ok "$label"
    else
        collect_fail "$label" "exit $expect を期待したが $rc / output: $(sut_out "$key")"
    fi
    return 0
}

@test "前提: 被テスト検査器と fixture corpus が存在する" {
    assert_preconditions_met
}

# ==== AC4: gen-adr-index.sh が validity=有効 の ADR のみを列挙する ====
@test "面①: gen-adr-index が有効 ADR のみを列挙する" {
    collect_init

    local out
    out="$(sut_out mixed-validity)"

    # 旧ランナーはここで早期 return し、以降の7項目を1件も評価しなかった。
    # 打ち切らず、exit code を1項目として数えたうえで全項目を評価する。
    collect_saved_rc mixed-validity 0 "AC4: gen-adr-index.sh の exit code"

    collect_contains "$out" "ADR-202601010901-01-sample-decision" \
        "AC4: 有効ADR1件目(sample-decision)が含まれる"
    collect_contains "$out" "ADR-202601020901-01-second-decision" \
        "AC4: 有効ADR2件目(second-decision)が含まれる"
    collect_not_contains "$out" "ADR-202601030901-01-old-decision" \
        "AC4: 上書き済みADRが含まれない"
    collect_not_contains "$out" "ADR-202601040901-01-abandoned-decision" \
        "AC4: 廃止済みADRが含まれない"
    collect_not_contains "$out" "ADR-202601050901-01-rejected-decision" \
        "AC4: 却下ADRが含まれない"
    collect_not_contains "$out" "ADR-202601060901-01-proposed-decision" \
        "AC4: 提案中ADRが含まれない"
    collect_not_contains "$out" "ADR-202601070901-01-legacy-format-decision" \
        "AC4: 旧形式ADRが含まれない"

    collect_finish
}

# ==== 回帰: gen-adr-index.sh の validity 抽出は末尾空白をトリムする ====
# （lint-adr.sh の trim() と抽出・判定を一致させる。トリムしないと
#   validity: 有効<末尾空白> の ADR が gen 側からは「有効でない」扱いで
#   index から静かに除外される一方、lint レイヤ1はトリム済みで「有効」
#   判定するため、レイヤ2（gen 出力と index.md の diff）でも drift として
#   検出されず ADR が index から無言で消えるドリフトの回帰）
@test "面②: validity 抽出が末尾空白をトリムする（回帰）" {
    collect_init

    local gen_out
    gen_out="$(sut_out whitespace-gen)"

    collect_saved_rc whitespace-gen 0 "回帰(whitespace-validity): gen-adr-index.sh の exit code"

    collect_contains "$gen_out" "ADR-202602010903-01-trailing-space-decision" \
        "回帰(whitespace-validity): validity末尾空白ADRがindexに含まれる"

    collect_saved_rc whitespace-lint 0 \
        "回帰(whitespace-validity): lint-adr.sh は exit 0（レイヤ2 drift 誤検出なし）"

    collect_finish
}
