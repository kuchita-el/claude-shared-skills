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
    jq '.["推定で補った事実"]=["原文に記述なし"]' "$tmp/CASE-A1-1.json" > "$tmp/with-prose.json"
    run bash "$REPO_ROOT/scripts/migrate-return-schema.sh" "$tmp"
    [ "$status" -eq 0 ]
    jq -e '.["推定で補った事実"] == ["原文に記述なし"]' "$tmp/with-prose.json"
}
