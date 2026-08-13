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

@test "emit-actions rejects an unconfirmed user" {
    ledger="$BATS_FILE_TMPDIR/pending-ledger.json"
    awk '/```migration-ledger-json/{inside=1; next} inside && /^```/{exit} inside{print}' "$FIXTURES_DIR/team-migration/valid/ledger.md" | sed 's/"status":"confirmed"/"status":"pending"/g' >"$ledger"
    run bash "$CHECKER" emit-actions "$ledger" "$FIXTURES_DIR/team-migration/valid/boundary-decision.json" "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"未確認利用者"* ]]
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

@test "core deletion is rejected even when new plugin ID is different" {
    ledger="$BATS_FILE_TMPDIR/core-bypass-ledger.json"
    awk '/```migration-ledger-json/{inside=1; next} inside && /^```/{exit} inside{print}' "$FIXTURES_DIR/team-migration/valid/ledger.md" >"$ledger"
    jq '.migrations += [{"oldPluginId":"dev-workflow","newPluginId":"growth","movedSkills":[],"oldEntryAction":"delete","installCommand":"delete","rollback":"restore"}]' "$ledger" >"$ledger.next" && mv "$ledger.next" "$ledger"
    run bash "$CHECKER" emit-actions "$ledger" "$FIXTURES_DIR/team-migration/valid/boundary-decision.json" "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"protected old plugin ID: dev-workflow"* ]]
}

@test "approved non-core deletion is emitted and applied consistently" {
    ledger="$BATS_FILE_TMPDIR/delete-ledger.json"
    awk '/```migration-ledger-json/{inside=1; next} inside && /^```/{exit} inside{print}' "$FIXTURES_DIR/team-migration/valid/ledger.md" >"$ledger"
    jq '.migrations += [{"oldPluginId":"growth","newPluginId":"growth","movedSkills":[],"oldEntryAction":"delete","installCommand":"remove","rollback":"restore"}]' "$ledger" >"$ledger.next" && mv "$ledger.next" "$ledger"
    run bash "$CHECKER" emit-actions "$ledger" "$FIXTURES_DIR/team-migration/valid/boundary-decision.json" "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 0 ]
    [ "$(jq -c '.deletePluginIds' "$BATS_FILE_TMPDIR/actions.json")" = '["growth"]' ]
    [ "$(jq -r '.runnerPluginIds | index("growth") // "missing"' "$BATS_FILE_TMPDIR/actions.json")" = "missing" ]
    repo="$BATS_FILE_TMPDIR/delete-repo"
    rm -rf "$repo"
    cp -R "$FIXTURES_DIR/team-migration/before-cutover" "$repo"
    mkdir -p "$repo/plugins/dependency-insight" "$repo/plugins/domain-design"
    run bash "$APPLIER" "$repo" "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 0 ]
    ! jq -e '.plugins[] | select(.name == "growth")' "$repo/.claude-plugin/marketplace.json" >/dev/null
    ! jq -e '.plugins[] | select(.name == "growth")' "$repo/.agents/plugins/marketplace.json" >/dev/null
}

@test "delete row without rollback is rejected during emit" {
    ledger="$BATS_FILE_TMPDIR/delete-missing-rollback.json"
    awk '/```migration-ledger-json/{inside=1; next} inside && /^```/{exit} inside{print}' "$FIXTURES_DIR/team-migration/valid/ledger.md" >"$ledger"
    jq '.migrations += [{"oldPluginId":"growth","newPluginId":"growth","movedSkills":[],"oldEntryAction":"delete","installCommand":"remove"}]' "$ledger" >"$ledger.next" && mv "$ledger.next" "$ledger"
    run bash "$CHECKER" emit-actions "$ledger" "$FIXTURES_DIR/team-migration/valid/boundary-decision.json" "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"削除行にrollbackがありません"* ]]
}

@test "retain and delete rows for one old plugin are rejected during emit" {
    ledger="$BATS_FILE_TMPDIR/delete-retain-conflict.json"
    awk '/```migration-ledger-json/{inside=1; next} inside && /^```/{exit} inside{print}' "$FIXTURES_DIR/team-migration/valid/ledger.md" >"$ledger"
    jq '.migrations += [{"oldPluginId":"growth","newPluginId":"growth","movedSkills":[],"oldEntryAction":"retain","installCommand":"keep","rollback":"restore"},{"oldPluginId":"growth","newPluginId":"growth","movedSkills":[],"oldEntryAction":"delete","installCommand":"remove","rollback":"restore"}]' "$ledger" >"$ledger.next" && mv "$ledger.next" "$ledger"
    run bash "$CHECKER" emit-actions "$ledger" "$FIXTURES_DIR/team-migration/valid/boundary-decision.json" "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"retain/delete"* ]]
}

@test "retain candidate added only to release set is rejected" {
    ledger="$BATS_FILE_TMPDIR/retain-release-ledger.json"
    awk '/```migration-ledger-json/{inside=1; next} inside && /^```/{exit} inside{print}' "$FIXTURES_DIR/team-migration/valid/ledger.md" >"$ledger"
    jq '.releasePlugins += [{"id":"retained-candidate","skills":[],"version":"0.1.0"}] | .releaseNotes += [{"pluginId":"retained-candidate","reason":"invalid","oldVersion":"none","newVersion":"0.1.0","compatibility":"new-plugin","breakingChanges":"none","rollback":"restore","evidence":"test"}]' "$ledger" >"$ledger.next" && mv "$ledger.next" "$ledger"
    boundary="$BATS_FILE_TMPDIR/retain-boundary.json"
    jq '.candidates += [{"id":"retained-candidate","skills":[],"decision":"retain","approval":{"id":"J9","status":"approved"}}]' "$FIXTURES_DIR/team-migration/valid/boundary-decision.json" >"$boundary"
    run bash "$CHECKER" emit-actions "$ledger" "$boundary" "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"retain候補"* ]]
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
    rm -rf "$repo"
    cp -R "$FIXTURES_DIR/team-migration/after-cutover" "$repo"
    cat >"$BATS_FILE_TMPDIR/actions.json" <<'EOF'
{"addPluginIds":[],"deletePluginIds":[],"retainPluginIds":["dev-workflow"],"runnerPluginIds":["dev-workflow","growth","adr","writing","domain-design","dependency-insight"]}
EOF
    run bash "$APPLIER" "$repo" "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 0 ]
    [ "$(jq -r '[.plugins[].name] | join(",")' "$repo/.claude-plugin/marketplace.json")" = "dev-workflow,growth,adr,writing" ]
}

@test "applier derives marketplace rows for approved additions" {
    repo="$BATS_FILE_TMPDIR/repo"
    rm -rf "$repo"
    cp -R "$FIXTURES_DIR/team-migration/before-cutover" "$repo"
    mkdir -p "$repo/plugins/domain-design" "$repo/plugins/dependency-insight"
    cat >"$BATS_FILE_TMPDIR/actions.json" <<'EOF'
{"addPluginIds":["domain-design","dependency-insight"],"deletePluginIds":[],"retainPluginIds":["dev-workflow"],"runnerPluginIds":["dev-workflow","growth","adr","writing","domain-design","dependency-insight"]}
EOF
    run bash "$APPLIER" "$repo" "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 0 ]
    [ "$(jq -r '[.plugins[].name] | sort | join(",")' "$repo/.claude-plugin/marketplace.json")" = "adr,dependency-insight,dev-workflow,domain-design,growth,writing" ]
    [ "$(jq -r '[.plugins[].name] | sort | join(",")' "$repo/.agents/plugins/marketplace.json")" = "adr,dependency-insight,dev-workflow,domain-design,growth,writing" ]
    [ "$(jq -r '.plugins[] | select(.name == "domain-design") | .source.path' "$repo/.agents/plugins/marketplace.json")" = "./plugins/domain-design" ]
}

@test "applier rejects a cutover that removes protected core" {
    repo="$BATS_FILE_TMPDIR/repo"
    rm -rf "$repo"
    cp -R "$FIXTURES_DIR/team-migration/after-cutover-core-missing" "$repo"
    cat >"$BATS_FILE_TMPDIR/actions.json" <<'EOF'
{"addPluginIds":[],"deletePluginIds":["dev-workflow"],"retainPluginIds":[],"runnerPluginIds":[]}
EOF
    run bash "$APPLIER" "$repo" "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"protected old plugin ID: dev-workflow"* ]]
}

@test "applier rejects delete and retain/runner overlap" {
    repo="$BATS_FILE_TMPDIR/repo"
    rm -rf "$repo"
    cp -R "$FIXTURES_DIR/team-migration/before-cutover" "$repo"
    cat >"$BATS_FILE_TMPDIR/actions.json" <<'EOF'
{"addPluginIds":[],"deletePluginIds":["growth"],"retainPluginIds":["growth"],"runnerPluginIds":["growth"]}
EOF
    run bash "$APPLIER" "$repo" "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"overlaps"* ]]
}

@test "applier validates additions before changing either marketplace" {
    repo="$BATS_FILE_TMPDIR/repo"
    rm -rf "$repo"
    cp -R "$FIXTURES_DIR/team-migration/before-cutover" "$repo"
    before_claude=$(sha256sum "$repo/.claude-plugin/marketplace.json")
    before_codex=$(sha256sum "$repo/.agents/plugins/marketplace.json")
    cat >"$BATS_FILE_TMPDIR/actions.json" <<'EOF'
{"addPluginIds":["ghost-plugin"],"deletePluginIds":["growth"],"retainPluginIds":[],"runnerPluginIds":[]}
EOF
    run bash "$APPLIER" "$repo" "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 1 ]
    [ "$(sha256sum "$repo/.claude-plugin/marketplace.json")" = "$before_claude" ]
    [ "$(sha256sum "$repo/.agents/plugins/marketplace.json")" = "$before_codex" ]
}

@test "applier checks protected core after an otherwise valid no-op" {
    repo="$BATS_FILE_TMPDIR/repo"
    rm -rf "$repo"
    cp -R "$FIXTURES_DIR/team-migration/after-cutover-core-missing" "$repo"
    cat >"$BATS_FILE_TMPDIR/actions.json" <<'EOF'
{"addPluginIds":[],"deletePluginIds":[],"retainPluginIds":[],"runnerPluginIds":[]}
EOF
    run bash "$APPLIER" "$repo" "$BATS_FILE_TMPDIR/actions.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"protected old plugin ID: dev-workflow"* ]]
}
