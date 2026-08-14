#!/usr/bin/env bats

load 'helpers/common'

setup_file() {
    common_setup_file
    FAKE_BIN="$BATS_FILE_TMPDIR/fake-bin"
    CALLS="$BATS_FILE_TMPDIR/calls"
    mkdir -p "$FAKE_BIN"
    : >"$CALLS"
    export FAKE_BIN CALLS

    cat >"$FAKE_BIN/claude" <<'EOF'
#!/usr/bin/env bash
{
    printf 'claude'
    printf '|%s' "$@"
    printf '\n'
} >>"$CALLS"
EOF

    cat >"$FAKE_BIN/codex" <<'EOF'
#!/usr/bin/env bash
{
    printf 'codex'
    printf '|%s' "$@"
    printf '\n'
} >>"$CALLS"
if [[ "$1 ${2:-} ${3:-}" == "plugin marketplace list" ]]; then
    [[ "${FAKE_CODEX_STATE:-empty}" == installed ]] && printf 'claude-shared-skills\n'
elif [[ "$1 ${2:-} ${3:-}" == "plugin list --json" ]]; then
    if [[ "${FAKE_CODEX_STATE:-empty}" == installed ]]; then
        printf '{"pluginId": "dev-workflow@claude-shared-skills"}\n'
        printf '{"pluginId": "growth@claude-shared-skills"}\n'
        printf '{"pluginId": "adr@claude-shared-skills"}\n'
        printf '{"pluginId": "writing@claude-shared-skills"}\n'
        printf '{"pluginId": "domain-design@claude-shared-skills"}\n'
        printf '{"pluginId": "dependency-insight@claude-shared-skills"}\n'
        printf '{"pluginId": "superpowers@openai-curated"}\n'
    fi
fi
EOF
    chmod +x "$FAKE_BIN/claude" "$FAKE_BIN/codex"
}

setup() {
    : >"$CALLS"
}

@test "Claude runnerはローカルplugin-dirと全引数を渡す" {
    run env PATH="$FAKE_BIN:$PATH" "$REPO_ROOT/run-claude-local.sh" --model opus --resume "session name"
    [ "$status" -eq 0 ]
    grep -Fx -- 'claude|--plugin-dir|./plugins/dev-workflow|--plugin-dir|./plugins/growth|--plugin-dir|./plugins/adr|--plugin-dir|./plugins/writing|--plugin-dir|./plugins/dependency-insight|--plugin-dir|./plugins/domain-design|--model|opus|--resume|session name' "$CALLS"
}

@test "Codex runnerは未導入のmarketplaceと全pluginを導入して全引数を渡す" {
    run env PATH="$FAKE_BIN:$PATH" FAKE_CODEX_STATE=empty "$REPO_ROOT/run-codex-local.sh" --model gpt-5.6 --search
    [ "$status" -eq 0 ]
    grep -Fx -- 'codex|plugin|add|superpowers@openai-curated' "$CALLS"
    grep -Fx -- 'codex|plugin|add|domain-design@claude-shared-skills' "$CALLS"
    grep -Fx -- 'codex|plugin|add|dependency-insight@claude-shared-skills' "$CALLS"
    ! grep -Fx -- 'codex|plugin|add|growth@claude-shared-skills' "$CALLS"
    grep -Fx -- 'codex|--model|gpt-5.6|--search' "$CALLS"
}

@test "Codex runnerは導入済みmarketplaceとpluginを再導入しない" {
    run env PATH="$FAKE_BIN:$PATH" FAKE_CODEX_STATE=installed "$REPO_ROOT/run-codex-local.sh"
    [ "$status" -eq 0 ]
    ! grep -Fq 'codex|plugin|add|' "$CALLS"
    ! grep -Fq 'codex|plugin|marketplace|add|' "$CALLS"
}

@test "runnerの旧ファイル名は残さない" {
    [ ! -e "$REPO_ROOT/setup-local.sh" ]
    [ ! -e "$REPO_ROOT/setup-codex.sh" ]
}
