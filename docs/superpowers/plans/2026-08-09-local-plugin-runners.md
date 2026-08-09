# Local Plugin Runners Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Claude Code と Codex のローカルプラグイン検証を、対象が明確な実行スクリプトから任意のランタイム引数付きで起動できるようにする。

**Architecture:** ルート直下の2本の Bash ラッパーがランタイム別の準備と `exec` を担当する。Bats テストは PATH 上の偽コマンドへ呼び出しを記録し、外部状態を変更せずに引数と Codex の冪等な導入処理を検証する。

**Tech Stack:** Bash 4+、Bats 1.11.1、Codex CLI plugin commands

## Global Constraints

- `run-claude-local.sh` と `run-codex-local.sh` は受け取った全引数を順序と値を変えずにランタイムへ渡す。
- Codex 側は `dev-workflow`、`growth`、`adr`、`writing` と `superpowers@openai-curated` を必須で導入する。
- インストール済みプラグインは再インストールしない。
- 旧スクリプト名の互換ラッパーは残さない。
- 過去の判断を記録する ADR と監査文書内の旧名称は履歴として変更しない。

---

### Task 1: ランタイム別ローカル実行スクリプト

**Files:**
- Create: `scripts/tests/local-plugin-runners.bats`
- Modify: `scripts/run-tests.sh`
- Rename: `setup-local.sh` → `run-claude-local.sh`
- Rename: `setup-codex.sh` → `run-codex-local.sh`
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `docs/development/test-execution.md`

**Interfaces:**
- Consumes: `claude [OPTIONS]`、`codex plugin marketplace list/add`、`codex plugin list/add`、`codex [OPTIONS]`
- Produces: `run-claude-local.sh [claude arguments...]`、`run-codex-local.sh [codex arguments...]`

- [ ] **Step 1: 失敗する Bats テストを追加する**

`scripts/tests/local-plugin-runners.bats` に偽の `claude` / `codex` を作る setup と、次の4ケースを記述する。

```bash
@test "Claude runnerはローカルplugin-dirと全引数を渡す" {
  run env PATH="$FAKE_BIN:$PATH" "$REPO_ROOT/run-claude-local.sh" --model opus --resume "session name"
  [ "$status" -eq 0 ]
  grep -Fx -- 'claude|--plugin-dir|./plugins/dev-workflow|--plugin-dir|./plugins/adr|--plugin-dir|./plugins/writing|--model|opus|--resume|session name' "$CALLS"
}

@test "Codex runnerは未導入のmarketplaceと全pluginを導入して全引数を渡す" {
  run env PATH="$FAKE_BIN:$PATH" FAKE_CODEX_STATE=empty "$REPO_ROOT/run-codex-local.sh" --model gpt-5.6 --search
  [ "$status" -eq 0 ]
  grep -Fx -- 'codex|plugin|add|superpowers@openai-curated' "$CALLS"
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
```

偽コマンドは各引数を `|` 区切りで `$CALLS` へ記録し、`plugin marketplace list` と `plugin list --json` だけ `FAKE_CODEX_STATE` に応じた固定出力を返す。

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `mise exec -- bats scripts/tests/local-plugin-runners.bats`

Expected: FAIL。`run-claude-local.sh` / `run-codex-local.sh` が存在しない。

- [ ] **Step 3: スクリプトを改名し最小実装を行う**

`run-claude-local.sh` の末尾を次にする。

```bash
exec claude \
  --plugin-dir ./plugins/dev-workflow \
  --plugin-dir ./plugins/adr \
  --plugin-dir ./plugins/writing \
  "$@"
```

`run-codex-local.sh` はオプション引数の検査を撤去し、既存4プラグインに加えて次を無条件の導入対象へ加えた後、Codex を起動する。

```bash
if ! grep -Fq '"pluginId": "superpowers@openai-curated"' <<<"$installed_plugins"; then
  codex plugin add superpowers@openai-curated
fi

exec codex "$@"
```

- [ ] **Step 4: 新規 Bats を通す**

Run: `mise exec -- bats scripts/tests/local-plugin-runners.bats`

Expected: `1..4`、4 tests、0 failures。

- [ ] **Step 5: テストランナーと文書を更新する**

`scripts/run-tests.sh` の `EXPECTED_BATS` に `local-plugin-runners.bats` を追加する。`docs/development/test-execution.md` のファイル数・ケース総数を 9/76 から 10/80 へ更新し、新規4ケースを対応表へ追加する。

README と CLAUDE.md の現在の操作手順を次へ統一する。

```bash
./run-claude-local.sh --model opus
./run-codex-local.sh --model gpt-5.6
```

Codex の説明は Superpowers が必須導入されることを明記する。ADR と監査文書に残る `setup-local.sh` は過去時点の記録なので変更しない。

- [ ] **Step 6: 全検証を実行する**

Run: `bash -n run-claude-local.sh run-codex-local.sh`

Expected: exit 0。

Run: `bash scripts/run-tests.sh`

Expected: 80 tests、0 failures、`validate-skills` が `ok`。

Run: `git diff --check`

Expected: 出力なし、exit 0。

- [ ] **Step 7: コミットする**

```bash
git add run-claude-local.sh run-codex-local.sh scripts/tests/local-plugin-runners.bats scripts/run-tests.sh README.md CLAUDE.md docs/development/test-execution.md setup-local.sh setup-codex.sh
git commit -m "feat: run local plugins with Claude and Codex"
```
