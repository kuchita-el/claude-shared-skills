#!/usr/bin/env bats
# DDD ドキュメントリント（scripts/lint-domain-doc.sh）のテスト。
#
# scripts/fixtures/lint-domain-doc/{valid,invalid}/*.md を lint し、
# valid は exit 0、invalid は exit 1 と期待メッセージ部分一致を検査する。
#
# fixture 名は静的な配列として列挙する。ディレクトリを走査して動的に列挙すると
# 登録ケース数が入力で変動し、総数固定（AC5）に反する。

load 'helpers/common'

SUT="$REPO_ROOT/scripts/lint-domain-doc.sh"

CORPORA=(
    "valid-01|$FIXTURES_DIR/lint-domain-doc/valid/01-command-only.md"
    "valid-02|$FIXTURES_DIR/lint-domain-doc/valid/02-command-with-policy.md"
    "valid-03|$FIXTURES_DIR/lint-domain-doc/valid/03-multiple-commands.md"
    "valid-04|$FIXTURES_DIR/lint-domain-doc/valid/04-mermaid-and-symbols.md"
    "invalid-03|$FIXTURES_DIR/lint-domain-doc/invalid/03-failure-reason-as-type.md"
)

# <退避キー>|<旧ランナーの [PASS] ラベル>
VALID_LABELS=(
    "valid-01|valid/01-command-only.md (exit=0)"
    "valid-02|valid/02-command-with-policy.md (exit=0)"
    "valid-03|valid/03-multiple-commands.md (exit=0)"
    "valid-04|valid/04-mermaid-and-symbols.md (exit=0)"
)

# invalid 群の期待メッセージ（AND 検査）
INVALID_03_PATTERNS=("廃止記法" "失敗理由")

setup_file() {
    common_setup_file
}

@test "前提: 被テスト検査器と fixture が存在する" {
    assert_preconditions_met
}

@test "面①: valid fixture がいずれも exit 0" {
    collect_init

    local entry key label rc
    for entry in "${VALID_LABELS[@]}"; do
        key="${entry%%|*}"
        label="${entry#*|}"
        rc="$(sut_rc "$key")"
        if [ "$rc" = "0" ]; then
            collect_ok "$label"
        else
            # 1件目で打ち切らない。壊れた fixture が複数あれば1回の実行で全件出す。
            collect_fail "$label" "expected exit=0, got=$rc / output: $(sut_out "$key")"
        fi
    done

    collect_finish
}

@test "面②: invalid fixture が期待診断つきで非0" {
    collect_init

    local label="invalid/03-failure-reason-as-type.md (exit=1, msg matched)"
    local rc out ok missing p
    rc="$(sut_rc "invalid-03")"
    out="$(sut_out "invalid-03")"
    ok=1
    missing=""
    for p in "${INVALID_03_PATTERNS[@]}"; do
        if [[ "$out" != *"$p"* ]]; then
            ok=0
            missing="$p"
            break
        fi
    done

    if [ "$rc" = "1" ] && [ "$ok" -eq 1 ]; then
        collect_ok "$label"
    else
        collect_fail "$label" \
            "expected exit=1 with msg containing \"${INVALID_03_PATTERNS[*]}\", got exit=$rc (missing=\"$missing\")"
    fi

    collect_finish
}
