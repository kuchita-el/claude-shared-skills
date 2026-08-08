#!/usr/bin/env bats
# doc-reviewer の fixture と、その確認記録の対応表が食い違っていないことを検査する。
#
# `doc-reviewer` の判定は決定的でないため、fixture を実際に読ませる確認は
# `scripts/run-tests.sh` の対象に含めていない（理由は fixtures/doc-reviewer/README.md）。
# その結果、fixture を足しても対応表の更新を忘れると、その欠陥の型は永久に確認されない
# まま残る。確認そのものは機械化できないが、**確認の台帳が対象を覆っているか**は機械で
# 検査できる。ここが覆うのはその一点である。
#
# `lint-ja.bats` の collect_fixture_coverage に相当する役割を、記録側に対して果たす。

load 'helpers/common'

FIXTURES="$REPO_ROOT/scripts/fixtures/doc-reviewer"
LEDGER="$FIXTURES/README.md"

CORPORA=()
PRECONDITION_PATHS=(
    "$FIXTURES/negative"
    "$FIXTURES/positive"
    "$LEDGER"
)

setup_file() {
    common_setup_file
}

# 「## 対応」節の表の行だけを取り出す。README 全体を照合の対象にすると、実施の記録や
# 限界の節に同じファイル名が現れるだけで緑になり、対応表の行を丸ごと削っても通ってしまう。
ledger_table() {
    awk '
        /^## 対応[[:space:]]*$/ { in_section = 1; next }
        /^## / { in_section = 0 }
        in_section && /^\|/ { print }
    ' "$LEDGER"
}

# 対応表に載っていない fixture を検出する。
collect_ledger_coverage() {
    local subdir="$1" table="$2"
    local prev_nullglob present f base label
    prev_nullglob="$(shopt -p nullglob || true)"
    shopt -s nullglob
    present=("$FIXTURES/$subdir"/*.md)
    eval "$prev_nullglob"

    if [ "${#present[@]}" -eq 0 ]; then
        collect_fail "$subdir に fixture が存在する" "1件も無い。対応表だけが残っている可能性がある"
        return 0
    fi

    for f in ${present[@]+"${present[@]}"}; do
        base="$(basename "$f")"
        label="$subdir fixture が対応表に載っている: $base"
        if printf '%s\n' "$table" | grep -qF "$subdir/$base"; then
            collect_ok "$label"
        else
            collect_fail "$label" "README.md の「## 対応」表に無いため、この型は一度も確認されない"
        fi
    done
    return 0
}

# 対応表に載っているのに実在しない fixture を検出する。名前の字種は問わない。
# 順方向が名前を問わずに照合する以上、逆方向を ASCII 名だけに限ると非対称になり、
# 非 ASCII 名の宙吊り参照が検出されない。
collect_ledger_dangling() {
    local subdir="$1" table="$2"
    local referenced base label
    referenced="$(printf '%s\n' "$table" | grep -oE "$subdir/[^ \`|]+\.md" | sort -u)"

    if [ -z "$referenced" ]; then
        collect_fail "$subdir が対応表から参照されている" "参照が1件も無い"
        return 0
    fi

    while IFS= read -r base; do
        [ -n "$base" ] || continue
        label="対応表の参照先が実在する: $base"
        if [ -f "$FIXTURES/$base" ]; then
            collect_ok "$label"
        else
            collect_fail "$label" "対応表が実在しないファイルを指している"
        fi
    done <<<"$referenced"
    return 0
}

@test "前提: fixture と確認記録が存在する" {
    assert_preconditions_met
}

@test "対応表が fixture を双方向に覆っている" {
    collect_init

    local table
    table="$(ledger_table)"
    if [ -z "$table" ]; then
        collect_fail "「## 対応」表が存在する" "節が見つからないか、表の行が1件も無い"
        collect_finish
        return
    fi
    collect_ok "「## 対応」表が存在する"

    collect_ledger_coverage negative "$table"
    collect_ledger_coverage positive "$table"
    collect_ledger_dangling negative "$table"
    collect_ledger_dangling positive "$table"

    collect_finish
}
