#!/usr/bin/env bats

load 'helpers/common'

setup() {
    common_setup_file
    tmp="$BATS_TEST_TMPDIR/returns"
    mkdir -p "$tmp"
    cp "$REPO_ROOT/scripts/fixtures/adr-scoping-cases/returns/CASE-A1-1.json" "$tmp/CASE-A1-1.json"
}

@test "順変換は欠測辞書を追加し、二度目も同じ結果になる" {
    run bash "$REPO_ROOT/scripts/migrate-return-schema.sh" "$tmp"
    [ "$status" -eq 0 ]
    cp "$tmp/CASE-A1-1.json" "$BATS_TEST_TMPDIR/first.json"
    run bash "$REPO_ROOT/scripts/migrate-return-schema.sh" "$tmp"
    [ "$status" -eq 0 ]
    cmp -s "$BATS_TEST_TMPDIR/first.json" "$tmp/CASE-A1-1.json"
    jq -e '.["欠測"] == {}' "$tmp/CASE-A1-1.json"
}

@test "欠測値の移送は順逆変換で値を保持する" {
    jq 'del(.["必要条件_成立"]) | .["必要条件_成立"] = "当時未施行"' "$tmp/CASE-A1-1.json" > "$tmp/legacy.json"
    run bash "$REPO_ROOT/scripts/migrate-return-schema.sh" "$tmp"
    [ "$status" -eq 0 ]
    jq -e '.["欠測"]["必要条件_成立"] == "当時未施行" and (has("必要条件_成立") | not)' "$tmp/legacy.json"
    run bash "$REPO_ROOT/scripts/migrate-return-schema.sh" --reverse "$tmp"
    [ "$status" -eq 0 ]
    jq -e '.["必要条件_成立"] == "当時未施行" and (has("欠測") | not)' "$tmp/legacy.json"
}

@test "順逆変換は旧スキーマへ無損失で戻る" {
    jq 'del(.["欠測"])' "$tmp/CASE-A1-1.json" > "$BATS_TEST_TMPDIR/original.json"
    cp "$BATS_TEST_TMPDIR/original.json" "$tmp/CASE-A1-1.json"
    run bash "$REPO_ROOT/scripts/migrate-return-schema.sh" "$tmp"
    [ "$status" -eq 0 ]
    run bash "$REPO_ROOT/scripts/migrate-return-schema.sh" --reverse "$tmp"
    [ "$status" -eq 0 ]
    jq -S . "$BATS_TEST_TMPDIR/original.json" > "$BATS_TEST_TMPDIR/original.sorted"
    jq -S . "$tmp/CASE-A1-1.json" > "$BATS_TEST_TMPDIR/result.sorted"
    cmp -s "$BATS_TEST_TMPDIR/original.sorted" "$BATS_TEST_TMPDIR/result.sorted"
}

@test "散文欄の欠測語は変換対象にしない" {
    jq '.["必要条件_補足"]="原文に記述なし"' "$tmp/CASE-A1-1.json" > "$tmp/with-prose.json"
    run bash "$REPO_ROOT/scripts/migrate-return-schema.sh" "$tmp"
    [ "$status" -eq 0 ]
    jq -e '.["必要条件_補足"] == "原文に記述なし" and .["欠測"] == {}' "$tmp/with-prose.json"
}

@test "移行スクリプトの対象キーが返却検査器の定義と一致する" {
    local validator migration
    validator="$(sed -n "s/^target_fields_json='\(.*\)'$/\1/p" \
        "$REPO_ROOT/plugins/adr/scripts/adr-scoping-cases.sh")"
    migration="$(sed -n "s/^[[:space:]]*targets='\(.*\)'$/\1/p" \
        "$REPO_ROOT/scripts/migrate-return-schema.sh")"
    [ -n "$validator" ]
    [ -n "$migration" ]
    [ "$(jq -S -c . <<<"$validator")" = "$(jq -S -c . <<<"$migration")" ]
}
