#!/usr/bin/env bats

load 'helpers/common'

@test "ADR Wave 1 fixtureは成果契約とCodex縮退条件を列挙する" {
    fixture="$REPO_ROOT/scripts/fixtures/skill-portability/adr-wave1/README.md"

    [ -f "$fixture" ]
    grep -Fq 'explicit ADR validation' "$fixture"
    grep -Fq 'Claude Code hook' "$fixture"
    grep -Fq 'Codex: degraded' "$fixture"
    grep -Fq 'adapter migration trigger' "$fixture"
}

@test "ADR Wave 1の決定的スクリプトは両ホスト共通の成果を検査できる" {
    corpus="$REPO_ROOT/scripts/fixtures/lint-adr/valid/01-mixed-validity"

    run bash "$REPO_ROOT/plugins/adr/scripts/lint-adr.sh" "$corpus"
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    run bash "$REPO_ROOT/plugins/adr/scripts/gen-adr-index.sh" "$corpus"
    [ "$status" -eq 0 ]
    [[ "$output" == *'# 有効 ADR インデックス'* ]]
    [[ "$output" == *'ADR-202601010901-01-sample-decision'* ]]

    run bash "$REPO_ROOT/plugins/adr/scripts/next-adr-id.sh" "$corpus"
    [ "$status" -eq 0 ]
    [[ "$output" == ADR-* ]]
}
