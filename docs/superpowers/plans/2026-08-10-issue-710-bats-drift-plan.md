# Issue #710 bats Drift Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** bats の異常系4サイトが `report` の差件数表示に依存せず、期待帰結ファイルの読込失敗を検出できるようにする。

**Architecture:** 本体スクリプトと fixture は変更せず、既存 bats テストの report 検査だけを変更する。正常経路の report 出力を各異常経路の baseline として比較し、差件数の表示文言は面⑪のみに閉じ込める。

**Tech Stack:** Bash、bats、mise、既存の `scripts/tests/helpers/common.bash` ヘルパー。

## Global Constraints

- `plugins/adr/scripts/adr-scoping-cases.sh` の振る舞いを変えない。
- `scripts/fixtures/adr-scoping-cases/` 配下を変更しない。
- 面⑪（18〜22c）の変更は行わない。
- 09b・40a・40b・40c は `差 N 件` の文字列一致を判定に用いない。

## Files and responsibilities

- Modify: `scripts/tests/adr-scoping-cases-basic.bats` — 09b の正常 report baseline 比較とラベル修正。
- Modify: `scripts/tests/adr-scoping-cases-edge.bats` — 40a／40b／40c の正常 report baseline 比較とラベル修正。
- Do not modify: `plugins/adr/scripts/adr-scoping-cases.sh`、`scripts/fixtures/adr-scoping-cases/`。

### Task 1: 09b の report 検査を baseline 比較へ変更

**Files:**
- Modify: `scripts/tests/adr-scoping-cases-basic.bats:241-257`

**Interfaces:**
- Consumes: `sc` helper、`$JUDGMENTS_DIR/valid-judgments.tsv`、`$CASES_DIR/valid`。
- Produces: 09b が正常経路と `a=b`／`j=1.tsv` 経路の report 出力一致を検証する。

- [ ] **Step 1: Write the failing test change**

  09b の `*"差 2 件"*` 一致を削除し、通常パスで `sc report "$JUDGMENTS_DIR/valid-judgments.tsv" "$CASES_DIR/valid"` を実行して `baseline` を保存する。`a=b`／`j=1.tsv` の `$output` と `baseline` の一致を検証し、ラベルから差件数表現を除く。

- [ ] **Step 2: Run the focused test to verify the intended assertion**

  Run: `mise exec -- bats scripts/tests/adr-scoping-cases-basic.bats`

  Expected: 09b の旧 assertion が残っていない状態で、basic suite が pass する。失敗する場合は report 出力取得方法または比較対象を修正する。

- [ ] **Step 3: Run the focused suite again after cleanup**

  Run: `mise exec -- bats scripts/tests/adr-scoping-cases-basic.bats`

  Expected: `not ok` なし。

- [ ] **Step 4: Commit**

  ```bash
  git add scripts/tests/adr-scoping-cases-basic.bats
  git commit -m "test: remove report count drift from case 09b"
  ```

### Task 2: 40a／40b／40c の report 検査を baseline 比較へ変更

**Files:**
- Modify: `scripts/tests/adr-scoping-cases-edge.bats:32,178,186,196-231`

**Interfaces:**
- Consumes: `check_weird_tmpdir`、`sc` helper、valid judgments/cases fixtures。
- Produces: 40a／40b／40c が正常経路と異常経路の report 出力一致を検証する。

- [ ] **Step 1: Write the failing test change**

  `check_weird_tmpdir` で通常の `report` 出力を baseline として取得し、異常な `$TMPDIR` の report 出力との一致を比較する。40c でも通常の題材集合パスの report 出力と特殊文字パスの出力を比較する。`差 2 件` の一致を削除し、ラベルを実際の性質（期待帰結読込を含む report 経路の同一性）に合わせる。

- [ ] **Step 2: Run the focused test to verify the intended assertion**

  Run: `mise exec -- bats scripts/tests/adr-scoping-cases-edge.bats`

  Expected: edge suite が pass し、40a／40b／40c に `not ok` がない。

- [ ] **Step 3: Run both affected suites**

  Run: `mise exec -- bats scripts/tests/adr-scoping-cases-basic.bats scripts/tests/adr-scoping-cases-edge.bats`

  Expected: 両 suite が pass する。

- [ ] **Step 4: Commit**

  ```bash
  git add scripts/tests/adr-scoping-cases-edge.bats
  git commit -m "test: remove report count drift from edge cases"
  ```

### Task 3: Issue AC と全体検証を確認

**Files:**
- Verify: `scripts/tests/adr-scoping-cases-basic.bats`
- Verify: `scripts/tests/adr-scoping-cases-edge.bats`

- [ ] **Step 1: Verify no affected site matches report count text**

  Run: `rg -n '09b|40a|40b|40c|差 [0-9]+ 件|差2件' scripts/tests/adr-scoping-cases-basic.bats scripts/tests/adr-scoping-cases-edge.bats`

  Expected: 09b／40a／40b／40c の assertion・ラベルに `差 N 件` 表現がない。面⑪など対象外の既存検査はこの確認から除外して判定する。

- [ ] **Step 2: Run the complete test runner**

  Run: `mise exec -- bash scripts/run-tests.sh`

  Expected: exit 0、全 suite が ok、`not ok` なし。

- [ ] **Step 3: Review the diff and AC checklist**

  `git diff origin/main...HEAD` で変更が2つの bats ファイルと設計・計画文書に限定され、本体スクリプト・fixture・面⑪を変更していないことを確認する。AC 1〜5 をそれぞれ resolved と記録する。

- [ ] **Step 4: Commit any final test-only cleanup**

  最終検証で必要な修正があれば対象ファイルだけを stage し、既存コミット規約に従ってコミットする。修正がなければ追加コミットは作らない。
