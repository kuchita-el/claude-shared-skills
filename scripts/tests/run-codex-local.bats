#!/usr/bin/env bats
# run-codex-local.sh のテスト。codex を、CODEX_HOME と引数を記録するだけの仮のものに差し替えて確かめる。

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    STUB_DIR="$BATS_TEST_TMPDIR/bin"
    CALLS_LOG="$BATS_TEST_TMPDIR/codex-calls"
    mkdir -p "$STUB_DIR"
    cat > "$STUB_DIR/codex" <<'STUB'
#!/bin/bash
{
    echo "CODEX_HOME=$CODEX_HOME"
    printf '%s\n' "$@"
    echo "---"
} >> "$CALLS_LOG"
if [ -n "${STUB_FAIL_SUPERPOWERS:-}" ] && [ "${!#}" = "superpowers@openai-curated" ]; then
    exit 1
fi
exit 0
STUB
    chmod +x "$STUB_DIR/codex"
    export CALLS_LOG
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME/.codex"
    unset CODEX_HOME CODEX_LOCAL_HOME
    DEV_HOME="$HOME/.codex-dev"
}

# n 番目（1始まり）の呼び出しの記録を出す
call() {
    awk -v n="$1" 'BEGIN { c = 1 } /^---$/ { c++; next } c == n' "$CALLS_LOG"
}

calls_count() {
    grep -c '^---$' "$CALLS_LOG"
}

@test "全ての呼び出しで、CODEX_HOME を開発用のホームにする" {
    PATH="$STUB_DIR:$PATH" run bash "$REPO_ROOT/run-codex-local.sh"
    [ "$status" -eq 0 ]
    [ "$(grep -c '^CODEX_HOME=' "$CALLS_LOG")" -eq "$(calls_count)" ]
    [ "$(grep '^CODEX_HOME=' "$CALLS_LOG" | sort -u)" = "CODEX_HOME=$DEV_HOME" ]
}

@test "CODEX_LOCAL_HOME で、開発用のホームを変えられる" {
    export CODEX_LOCAL_HOME="$BATS_TEST_TMPDIR/other-dev"
    PATH="$STUB_DIR:$PATH" run bash "$REPO_ROOT/run-codex-local.sh"
    [ "$status" -eq 0 ]
    [ "$(grep '^CODEX_HOME=' "$CALLS_LOG" | sort -u)" = "CODEX_HOME=$CODEX_LOCAL_HOME" ]
}

@test "Codex 用の定義にある全プラグインと superpowers を、作業ツリーへの上書きを付けて plugin add する" {
    PATH="$STUB_DIR:$PATH" run bash "$REPO_ROOT/run-codex-local.sh"
    [ "$status" -eq 0 ]
    mapfile -t plugins < <(jq -r '.plugins[].name' "$REPO_ROOT/.agents/plugins/marketplace.json")
    [ "$(calls_count)" -eq $(( ${#plugins[@]} + 2 )) ]
    i=1
    for id in "${plugins[@]/%/@claude-shared-skills}" superpowers@openai-curated; do
        call "$i" | grep -Fqx 'marketplaces.claude-shared-skills.source_type="local"'
        call "$i" | grep -Fqx "marketplaces.claude-shared-skills.source=\"$REPO_ROOT\""
        [ "$(call "$i" | tail -3 | head -2 | tr '\n' ' ')" = "plugin add " ]
        [ "$(call "$i" | tail -1)" = "$id" ]
        i=$(( i + 1 ))
    done
}

@test "最後に、上書きの後ろへ利用者の引数をそのまま付けて起動する" {
    PATH="$STUB_DIR:$PATH" run bash "$REPO_ROOT/run-codex-local.sh" --model gpt-test
    [ "$status" -eq 0 ]
    last="$(calls_count)"
    call "$last" | grep -Fqx "marketplaces.claude-shared-skills.source=\"$REPO_ROOT\""
    [ "$(call "$last" | tail -2 | head -1)" = "--model" ]
    [ "$(call "$last" | tail -1)" = "gpt-test" ]
    [ "$(call "$last" | grep -cFx 'plugin')" -eq 0 ]
}

@test "日常のホームの auth.json へのリンクを置き、日常のホームには何も足さない" {
    echo '{}' > "$HOME/.codex/auth.json"
    PATH="$STUB_DIR:$PATH" run bash "$REPO_ROOT/run-codex-local.sh"
    [ "$status" -eq 0 ]
    [ -L "$DEV_HOME/auth.json" ]
    [ "$(readlink "$DEV_HOME/auth.json")" = "$HOME/.codex/auth.json" ]
    [ "$(ls -A "$HOME/.codex")" = "auth.json" ]
}

@test "開発用のホームに auth.json があれば、置き換えない" {
    echo '{}' > "$HOME/.codex/auth.json"
    mkdir -p "$DEV_HOME"
    echo '{"dev":true}' > "$DEV_HOME/auth.json"
    PATH="$STUB_DIR:$PATH" run bash "$REPO_ROOT/run-codex-local.sh"
    [ "$status" -eq 0 ]
    [ ! -L "$DEV_HOME/auth.json" ]
    [ "$(cat "$DEV_HOME/auth.json")" = '{"dev":true}' ]
}

@test "日常のホームに auth.json が無ければ、リンクを置かずに起動する" {
    PATH="$STUB_DIR:$PATH" run bash "$REPO_ROOT/run-codex-local.sh"
    [ "$status" -eq 0 ]
    [ ! -e "$DEV_HOME/auth.json" ]
    [ ! -L "$DEV_HOME/auth.json" ]
}

@test "superpowers を導入できなくても、警告して起動を続ける" {
    export STUB_FAIL_SUPERPOWERS=1
    PATH="$STUB_DIR:$PATH" run bash "$REPO_ROOT/run-codex-local.sh" --model gpt-test
    [ "$status" -eq 0 ]
    [[ "$output" == *"superpowers@openai-curated"* ]]
    [ "$(call "$(calls_count)" | tail -1)" = "gpt-test" ]
}

@test "開発用のホームが日常のホームと同じなら、codex を呼ばずに失敗する" {
    export CODEX_LOCAL_HOME="$HOME/.codex"
    PATH="$STUB_DIR:$PATH" run bash "$REPO_ROOT/run-codex-local.sh"
    [ "$status" -ne 0 ]
    [ ! -e "$CALLS_LOG" ]
}

@test "CODEX_HOME が設定されていれば、それを日常のホームとして扱う" {
    export CODEX_HOME="$BATS_TEST_TMPDIR/daily"
    mkdir -p "$CODEX_HOME"
    echo '{}' > "$CODEX_HOME/auth.json"
    PATH="$STUB_DIR:$PATH" run bash "$REPO_ROOT/run-codex-local.sh"
    [ "$status" -eq 0 ]
    [ "$(readlink "$DEV_HOME/auth.json")" = "$BATS_TEST_TMPDIR/daily/auth.json" ]
    [ "$(grep '^CODEX_HOME=' "$CALLS_LOG" | sort -u)" = "CODEX_HOME=$DEV_HOME" ]
}
