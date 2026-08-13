#!/usr/bin/env bats

load 'helpers/common'

setup_file() {
    common_setup_file
    export FIXTURES_DIR="$REPO_ROOT/scripts/fixtures"
    export CHECKER="$REPO_ROOT/scripts/check-team-migration.sh"
    export APPLIER="$REPO_ROOT/scripts/apply-team-migration.sh"
}

@test "valid ledger emits the approved release and retain sets" {
    run bash "$CHECKER" emit-actions \
        "$FIXTURES_DIR/team-migration/valid/ledger.md" \
        "$FIXTURES_DIR/team-migration/valid/boundary-decision.json" \
        "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 0 ]
    [ "$(jq -c '.addPluginIds' "$BATS_FILE_TMPDIR/actions.json")" = '["dependency-insight","domain-design"]' ]
    [ "$(jq -c '.deletePluginIds' "$BATS_FILE_TMPDIR/actions.json")" = '[]' ]
    [ "$(jq -c '.retainPluginIds' "$BATS_FILE_TMPDIR/actions.json")" = '["dev-workflow"]' ]
}

@test "unconfirmed user blocks migration validation" {
    run bash "$CHECKER" validate \
        "$FIXTURES_DIR/team-migration/one-pending/ledger.md" \
        "$FIXTURES_DIR/team-migration/valid/boundary-decision.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"未確認利用者"* ]]
}

@test "retain candidate added to ledger is rejected" {
    run bash "$CHECKER" validate \
        "$FIXTURES_DIR/team-migration/retain-added/ledger.md" \
        "$FIXTURES_DIR/team-migration/valid/boundary-decision.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"retain候補"* ]]
}

@test "core plugin deletion is rejected" {
    run bash "$CHECKER" validate \
        "$FIXTURES_DIR/team-migration/core-delete-forbidden/ledger.md" \
        "$FIXTURES_DIR/team-migration/valid/boundary-decision.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"protected old plugin ID: dev-workflow"* ]]
}

@test "zero users is rejected fail-closed" {
    run bash "$CHECKER" validate \
        "$FIXTURES_DIR/team-migration/zero-users/ledger.md" \
        "$FIXTURES_DIR/team-migration/valid/boundary-decision.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"利用者名簿が0件"* ]]
}

@test "applier preserves protected core and applies no-op actions" {
    repo="$BATS_FILE_TMPDIR/repo"
    cp -R "$FIXTURES_DIR/team-migration/before-cutover" "$repo"
    cat >"$BATS_FILE_TMPDIR/actions.json" <<'EOF'
{"addPluginIds":[],"deletePluginIds":[],"retainPluginIds":["dev-workflow"],"runnerPluginIds":["dev-workflow","growth","adr","writing","domain-design","dependency-insight"]}
EOF
    run bash "$APPLIER" "$repo" "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 0 ]
    [ "$(jq -r '[.plugins[].name] | join(",")' "$repo/.claude-plugin/marketplace.json")" = "dev-workflow,growth,adr,writing" ]
}

@test "applier derives marketplace rows for approved additions" {
    repo="$BATS_FILE_TMPDIR/repo"
    cp -R "$FIXTURES_DIR/team-migration/before-cutover" "$repo"
    mkdir -p "$repo/plugins/domain-design" "$repo/plugins/dependency-insight"
    cat >"$BATS_FILE_TMPDIR/actions.json" <<'EOF'
{"addPluginIds":["domain-design","dependency-insight"],"deletePluginIds":[],"retainPluginIds":["dev-workflow"],"runnerPluginIds":["dev-workflow","growth","adr","writing","domain-design","dependency-insight"]}
EOF
    run bash "$APPLIER" "$repo" "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 0 ]
    [ "$(jq -r '[.plugins[].name] | sort | join(",")' "$repo/.claude-plugin/marketplace.json")" = "adr,dependency-insight,dev-workflow,domain-design,growth,writing" ]
    [ "$(jq -r '[.plugins[].name] | sort | join(",")' "$repo/.agents/plugins/marketplace.json")" = "adr,dependency-insight,dev-workflow,domain-design,growth,writing" ]
}

@test "applier rejects a cutover that removes protected core" {
    repo="$BATS_FILE_TMPDIR/repo"
    cp -R "$FIXTURES_DIR/team-migration/after-cutover-core-missing" "$repo"
    cat >"$BATS_FILE_TMPDIR/actions.json" <<'EOF'
{"addPluginIds":[],"deletePluginIds":["dev-workflow"],"retainPluginIds":[],"runnerPluginIds":[]}
EOF
    run bash "$APPLIER" "$repo" "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"protected old plugin ID: dev-workflow"* ]]
}
