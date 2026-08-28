#!/usr/bin/env bats
load 'helpers/common'

# 作者向け規約2本（context-budget / subagent-execution-parameters）を配布物外へ搬出し、
# 孤立ファイル workflow-patterns を削除した状態を固定する。
#
# 検査は「旧パス文字列がどこにも現れないこと」であり、行番号にも版にも依存しない。
#
# 【走査面を git grep（追跡ファイルのみ）に置く理由】
# grep -R は git の追跡状態を見ず作業ツリーを走査するため、追跡外の下書きが docs/ に
# 1本置かれるだけでスイートが赤になり、その都度ファイル名を除外へ足すことになる。
# 除外集合は単調に伸び、そのぶん走査面が恒久的に削れる。本ガードが固定したいのは
# 「追跡下の現行文書に旧パスが再混入しないこと」だけなので、走査面を追跡ファイルへ寄せる。
#
# 【needle を完全形で持つ理由】
# 短形（`references/context-budget.md`）は搬出先の新パス `docs/references/context-budget.md`
# の部分文字列であり、needle にできない。したがって短形だけで書かれた記述は本ガードに
# 当たらず、除外も要らない（例: `docs/qa/plugin-bp-audit-20260722.md` は短形のみで書かれて
# いるため、除外を置いても空振りする）。
#
# 【除外集合】
# 凍結記録・観測記録のうち、完全形を実際に含むものに限る（needle との突き合わせ済み）:
#   docs/adr/                                                        旧ADR決定文（上書きADRで決着）
#   docs/development/adr-demotion-cases/                             当時の観測記録
#   docs/superpowers/specs/2026-07-25-subagent-exec-params-design.md 過去spec

# 走査範囲（リポジトリ全体 − 凍結記録）。旧パス側と新パス側で同一の値を使い、
# 片方だけが書き換わって走査面が食い違うことを防ぐ。
relocation_scan_scope() {
    printf '%s\n' \
        -- . \
        ':(exclude)docs/adr/' \
        ':(exclude)docs/development/adr-demotion-cases/' \
        ':(exclude)docs/superpowers/specs/2026-07-25-subagent-exec-params-design.md'
}

@test "搬出先が実在し新パスが CLAUDE.md から引かれている" {
  [ -f "$REPO_ROOT/docs/references/context-budget.md" ]
  [ -f "$REPO_ROOT/docs/references/subagent-execution-parameters.md" ]
  run grep -n -F \
    -e 'docs/references/context-budget.md' \
    -e 'docs/references/subagent-execution-parameters.md' \
    "$REPO_ROOT/CLAUDE.md"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -ge 2 ]
}

@test "旧パス3本の実体が配布物から消えている" {
  local plugin_root="$REPO_ROOT/plugins"
  [ ! -e "$plugin_root/dev-workflow/references/context-budget.md" ]
  [ ! -e "$plugin_root/dev-workflow/references/subagent-execution-parameters.md" ]
  [ ! -e "$plugin_root/dev-workflow/references/workflow-patterns.md" ]
}

@test "旧パス3本が追跡下の現行文書（凍結記録を除く）に残らない" {
  # 台帳（plugin-path-reference-ledger.md）の走査に拾われないよう、
  # behavior-invariants.bats と同じ形で literal を分割する。
  local refs='plugins/'"dev-workflow"'/references'
  local -a scope
  mapfile -t scope < <(relocation_scan_scope)

  run git -C "$REPO_ROOT" grep -n -F \
    -e "$refs/context-budget.md" \
    -e "$refs/subagent-execution-parameters.md" \
    -e "$refs/workflow-patterns.md" \
    "${scope[@]}"
  [ "$status" -eq 1 ]

  # 不在検査だけでは走査0件でも緑になる。同じ走査範囲・同じ起動形で新パス側を引き、
  # 走査面が生きていること（除外集合が走査を潰していないこと）を照合件数で確かめる。
  # scripts/tests/ を外すのは、本ファイル自身が新パスの literal を持つためである
  # （自己ヒットで満たされると、走査面が死んでもこの照合が緑のまま残る）。
  run git -C "$REPO_ROOT" grep -n -F \
    -e 'docs/references/context-budget.md' \
    -e 'docs/references/subagent-execution-parameters.md' \
    "${scope[@]}" ':(exclude)scripts/tests/'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -ge 2 ]
}
