#!/usr/bin/env bats
load 'helpers/common'

# 作者向け規約2本（context-budget / subagent-execution-parameters）を配布物外へ搬出し、
# 孤立ファイル workflow-patterns を削除した状態を固定する。
#
# 搬出に関する検査は「旧パス文字列がどこにも現れないこと」であり、行番号にも版にも依存しない。
# 本ファイルは搬出先 docs/references/context-budget.md を走査対象として共有するため、
# 同ファイル「軸の区別」節の宣言軸数と表のデータ行数の整合検査（Issue #814 の R4）も併せて持つ。
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

# 「軸の区別」節から、宣言された軸数・表に隣接する注記（直前と直後の非空行）・表のデータ行の
# 軸ラベルを取り出す。NOTE 行が2本、ROW 行がデータ行数ぶん出る。
axis_section_facts() {
    awk '
      /^## / { if (f) { exit } ; if ($0 ~ /^## 軸の区別/) { f = 1 } ; next }
      f && state == 0 {
        if ($0 ~ /^\| 軸 \| 出典 \| 縛る対象 \|/) { state = 1 ; next }
        if ($0 !~ /^[ \t]*$/) { before = $0 }
        if ($0 ~ /token に関わる規律は/) { decl = $0 }
        next
      }
      f && state == 1 {
        if ($0 ~ /^\|---/) { next }
        if ($0 ~ /^\| /) { n = n + 1 ; rows[n] = $0 ; next }
        state = 2
      }
      f && state == 2 {
        if ($0 !~ /^[ \t]*$/ && after == "") { after = $0 }
      }
      END {
        printf "DECL\t%s\n", decl
        printf "NOTE\t%s\n", before
        printf "NOTE\t%s\n", after
        for (i = 1; i <= n; i++) {
          line = rows[i]
          sub(/^\|[ \t]*/, "", line)
          sub(/[ \t]*\|.*$/, "", line)
          printf "ROW\t%s\n", line
        }
      }
    ' "$1"
}

@test "「軸の区別」の宣言軸数と表のデータ行数が一致する" {
  local doc="$REPO_ROOT/docs/references/context-budget.md"
  [ -f "$doc" ]

  local -a notes=() labels=()
  local kind val
  while IFS=$'\t' read -r kind val; do
    case "$kind" in
      DECL) local decl="$val" ;;
      NOTE) [ -n "$val" ] && notes+=("$val") ;;
      ROW) labels+=("$val") ;;
    esac
  done < <(axis_section_facts "$doc")

  local declared
  declared="$(printf '%s\n' "${decl-}" | sed -n 's/.*token に関わる規律は\([0-9][0-9]*\)軸ある.*/\1/p' | head -1)"
  [[ "$declared" =~ ^[0-9]+$ ]] || {
    echo "軸数の宣言が読み取れない（節・宣言文のいずれかが失われている）"
    return 1
  }
  # 走査面が死んだまま緑になる経路を塞ぐ。データ行0件は整合ではなく走査の失敗である。
  [ "${#labels[@]}" -gt 0 ] || {
    echo "軸の表のデータ行が0件（走査面が失われている）"
    return 1
  }

  # 除外規則は次の3条件の連言であり、1つでも欠ける注記では当該行を除外しない。
  #   (1) 位置      注記が表に隣接する（直前・直後のいずれか）
  #   (2) 逐語名指し 注記が当該行の軸ラベルを逐語で含む
  #   (3) 除外の明示 注記が「上記の N 軸には数えない」と述べる
  # 位置条件を直後だけに絞らないのは、同種の表を持つ docs/behavior-invariants.md では
  # 当該注記が表の直前に置かれているためである。逐語名指しを要求するのは、除外の意図だけを
  # 述べた曖昧な注記で任意の行が検査を逃れることを防ぐためである。
  local counted=0 label note excluded
  for label in "${labels[@]}"; do
    excluded=0
    for note in "${notes[@]}"; do
      case "$note" in
        *"$label"*) ;;
        *) continue ;;
      esac
      case "$note" in
        *"上記の${declared}軸には数えない"*) ;;
        *) continue ;;
      esac
      excluded=1
      break
    done
    [ "$excluded" -eq 1 ] || counted=$((counted + 1))
  done

  [ "$counted" -eq "$declared" ] || {
    echo "軸数の宣言と表のデータ行数が食い違う: declared=$declared counted=$counted"
    return 1
  }

  # 軸数の一致だけでは、作成時（静的）軸へ明記した所有と、原則4 の射程を限定する注記が
  # 消えても緑のまま通る。いずれも今回の改訂の実体であるため場所を固定して照合する。
  local owner_row
  owner_row="$(grep -F '| 作成時（静的） |' "$doc" | head -1)"
  case "$owner_row" in
    *'plan-output-format.md'*) ;;
    *)
      echo "作成時（静的）軸の出典にプラン出力テンプレートが現れない"
      return 1
      ;;
  esac
  case "$owner_row" in
    *'プラン成果物の静的分量'*) ;;
    *)
      echo "作成時（静的）軸の縛る対象にプラン成果物の静的分量が現れない"
      return 1
      ;;
  esac
  grep -qF -e '原則4 の射程との関係' "$doc" || {
    echo "原則4 の射程を限定する注記が失われている"
    return 1
  }
}
