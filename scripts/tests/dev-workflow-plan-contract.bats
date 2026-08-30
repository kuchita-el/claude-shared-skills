#!/usr/bin/env bats
root="$BATS_TEST_DIRNAME/../.."
@test "planは3入力とAC対応・衝突回避を持つ" {
  run grep -E 'Issueなし|固定入力|AC.*対応|連番|Codex|decision-request' "$root/plugins/dev-workflow/skills/plan-issue/SKILL.md"
  [ "$status" -eq 0 ]
}
@test "plan reviewerは独立性不足で停止する" {
  run grep -E '独立汎用sub-agent|独立文脈|定義完全注入|停止' "$root/plugins/dev-workflow/agents/plan-reviewer.md" "$root/plugins/dev-workflow/skills/plan-issue/SKILL.md"
  [ "$status" -eq 0 ]
}
@test "plan fixtures exist" {
  [ -d "$root/scripts/fixtures/dev-workflow/plan" ]
}

# ---------------------------------------------------------------------------
# Issue #814: プラン規範へ新設した規定の退行検出
#
# 新設規定ごとの検査要否と判定理由:
#
#  R1  レビュー経緯の行き先
#      要。条文が言い換え・削除で静かに消える型であり needle で固定できる。接頭辞の位置ごと
#      固定する——語幹後置形へ戻すと implementation が既存プランを特定する Glob
#      （`issue-{番号}-*.md`）に一致し、経緯付録がプラン本体として読まれる経路が生じるため。
#  R2  テンプレート未定義節を追加しない規定
#      不要。本 Issue の新設ではなく既存規定であり、その実効化は R3 の観点12 が担う。
#      同じ対象へ二重に検査を置かない。
#  R3  レビュー観点12
#      要。観点の実在に加え、射程の文言と正規化手順を照合する。射程をレベル列挙の形へ戻す
#      改変は観点の表行・詳細節を残したまま無検査の書き込み先を復活させるため、存在だけを
#      見る照合では捕らえられない。また列挙形にも `###` という語は残るので、レベル記号の
#      出現を見る needle も無効である。実在の照合は表行と詳細節見出しを別々の needle で
#      行う——観点名は両方に現れるため、1本の needle では片方の欠落がもう片方に吸収される。
#      あわせて観点数の宣言（3箇所）と観点表のデータ行数の一致も照合する。
#  R4  軸の区別の改訂
#      要。宣言した軸数と表のデータ行数の一致を照合する（今回是正した欠陥そのものの再発検出）。
#      検査は走査対象ファイルが同一の authoring-reference-relocation.bats 側へ置く。
#  R5  成果物の書き出し先と手段の併記   要。条文の実在を照合する。
#  R6  読み方区分                     要。値域（規範）と判定条件（生成手順）が別ファイルにあるため両方を照合する。
#  R7  完了条件の検証粒度             要。条文の実在を照合する。
#  R8  レビュアーへ出力テンプレートを渡す結線
#      要。渡し忘れると R3 の観点12 が判定不能のまま常に緑になる。起動側と受け手側の両方を
#      走査し、宣言（5点）と実体（列挙）の食い違いを検出する。
#  R9  経緯付録を書く主体と契機の結線
#      要。R1 の行き先が残っていても結線が消えれば付録は生まれず、分離の形が運用上は
#      「プランへ書かずメイン報告に留める」へ縮退する。行き先の存在検査では穴が残る。
#  R10 出力テンプレートの読み取り点の単一性
#      要。ステップ6 を元の全文再読の形へ戻しても渡す資産の点数と列挙は無傷のため R8 は
#      緑で通り、同一ファイルの二重読みの復活が無検査になる。
# ---------------------------------------------------------------------------

# ラベルで1行を取り出し、その行が期待語をすべて含むかを1本で判定する。
# ラベルと期待語を別々の全文 grep へ分けると、無関係な箇所の同語に吸収されて場所固定が崩れる。
plan_norm_line_has() {
  local file="$1" label="$2"
  shift 2
  local row word
  row="$(grep -F -e "$label" "$file" | head -1)"
  [ -n "$row" ] || return 1
  for word in "$@"; do
    case "$row" in
      *"$word"*) ;;
      *) return 1 ;;
    esac
  done
  return 0
}

@test "R1/R3/R5/R6/R7: プラン規範の新設条文が残っている" {
  local refs="$root/plugins/dev-workflow/skills/plan-issue/references"
  local -a pairs=(
    'plan-output-format.md::語幹の前に `review-log-` を付した形'
    'plan-output-format.md::review-log-issue-{番号}.md'
    'plan-output-format.md::裁定に至った論拠は経緯付録へ移して'
    'plan-output-format.md::ここに定義されていないセクションは追加しない'
    'plan-prompt.md::プラン本体の節として起こさない'
    'plan-contract.md::読み方区分の付与'
    'plan-contract.md::`全文読み` / `局所読み`'
    'plan-contract.md::置き換えるものではなく併記する'
    'plan-prompt.md::読み方区分の判定'
    'plan-contract.md::完了条件の検証粒度'
    'plan-contract.md::タスクごとの完了条件へ重ねて課さない'
    'plan-contract.md::成果物の書き出し先と手段の併記'
    'plan-contract.md::宛先だけを書いて手段を書かない記載は本必須記載を満たさない'
    'plan-prompt.md::成果物の書き出し先の選び方'
    'review-guide-default.md::| 12 | 出力テンプレート定義外の節の不在 |'
  )
  local -a absent=()
  local checked=0 pair file needle
  # 照合回数は配列の宣言ではなくループ内で数える。宣言の要素数を下限に用いると、
  # ループごと削除されても下限が満たされたまま緑になる。
  for pair in "${pairs[@]}"; do
    file="${pair%%::*}"
    needle="${pair#*::}"
    checked=$((checked + 1))
    grep -qF -e "$needle" "$refs/$file" || absent+=("$file: $needle")
  done
  if [ "${#absent[@]}" -ne 0 ]; then
    printf '条文が見つからない:\n'
    printf '  %s\n' "${absent[@]}"
    return 1
  fi
  [ "$checked" -ge 15 ] || {
    echo "照合件数が下限を下回った: checked=$checked (>=15)"
    return 1
  }
}

@test "R3: 観点12 の射程がレベル列挙で閉じられておらず正規化手順が残っている" {
  local guide="$root/plugins/dev-workflow/skills/plan-issue/references/review-guide-default.md"
  local -a needles=(
    '### 12. 出力テンプレート定義外の節の不在'
    'テンプレートが定義する見出し集合に含まれない `##` 以下のすべての見出し'
    '対象の見出しレベルを列挙して射程を閉じない'
    '`（該当する場合）` を除去してから比較する'
    'より前の固定部分で比較する'
    '同じ固定部を持つ見出しが任意個現れてよい'
    '1件でもあればブロッカー（改善提案に留めない）'
    'レビュー経緯の記録がプラン本体の節として置かれている場合はブロッカー'
  )
  local -a absent=()
  local checked=0 needle
  for needle in "${needles[@]}"; do
    checked=$((checked + 1))
    grep -qF -e "$needle" "$guide" || absent+=("$needle")
  done
  if [ "${#absent[@]}" -ne 0 ]; then
    printf '観点12 の条文が見つからない:\n'
    printf '  %s\n' "${absent[@]}"
    return 1
  fi
  [ "$checked" -ge 8 ] || {
    echo "照合件数が下限を下回った: checked=$checked (>=8)"
    return 1
  }

  # 観点数の宣言（冒頭・深刻度節・レビュー手順の3箇所）と観点表のデータ行数の整合。
  # 観点を足しながら宣言を旧数のまま残す型の食い違いを検出する。行数は実行時に数える。
  local rows num
  rows="$(awk '/^\| # \| 観点 \| チェック項目 \|/{f=1;next} f && /^\|---/{next} f && /^\| /{c++;next} f{exit} END{print c+0}' "$guide")"
  [ "$rows" -gt 0 ] || {
    echo "観点表のデータ行が0件（走査面が失われている）"
    return 1
  }
  local -a decls=()
  while IFS= read -r num; do decls+=("$num"); done < <(grep -oE '[0-9]+の?観点' "$guide" | grep -oE '[0-9]+')
  [ "${#decls[@]}" -ge 3 ] || {
    echo "観点数の宣言が3箇所に満たない: 検出=${#decls[@]}"
    return 1
  }
  for num in "${decls[@]}"; do
    [ "$num" -eq "$rows" ] || {
      echo "観点数の宣言と観点表の行数が食い違う: 宣言=$num 表=$rows"
      return 1
    }
  done
}

@test "R8: レビュアーへ出力テンプレートを渡す結線が起動側と受け手側で一致している" {
  local pd="$root/plugins/dev-workflow"
  local skill="$pd/skills/plan-issue/SKILL.md"
  local agent="$pd/agents/plan-reviewer.md"
  local checked=0

  plan_norm_line_has "$skill" '以下の順序でReadツールで読み込み、' '5点' || {
    echo "ステップ2 の導入行が 5点 を宣言していない"
    return 1
  }
  checked=$((checked + 1))
  plan_norm_line_has "$skill" '- **規範とレビュー基準**:' '5点' '出力テンプレート' || {
    echo "ステップ7a の資産列挙行が 5点／出力テンプレート を持たない"
    return 1
  }
  checked=$((checked + 1))
  plan_norm_line_has "$agent" '- **規範とレビュー基準**:' '5点' '出力テンプレート' || {
    echo "plan-reviewer の入力契約行が 5点／出力テンプレート を持たない"
    return 1
  }
  checked=$((checked + 1))

  # ステップ2 の番号付きリストの項目数を実行時に数える。走査範囲を `### 2. ` の次行から
  # 次の `### ` の直前までへ切り出すのは、SKILL.md に番号付きリストが他にもあり、範囲を
  # 切らずに数えると項目数がステップ2 の実体を表さないためである。列挙から出力テンプレートの
  # 項目だけを落として宣言を 5点 のまま残す改変は、この照合でのみ捕らえられる。
  local items
  items="$(awk '/^### 2\. /{f=1;next} f && /^### /{exit} f && /^[0-9]+\. /{c++} END{print c+0}' "$skill")"
  [ "$items" -eq 5 ] || {
    echo "ステップ2 の読み込み項目が5件でない: items=$items"
    return 1
  }
  checked=$((checked + 1))

  [ "$checked" -ge 4 ] || {
    echo "照合件数が下限を下回った: checked=$checked (>=4)"
    return 1
  }
}

@test "R9: 経緯付録を書く主体と契機がステップ7c へ結線されている" {
  local pd="$root/plugins/dev-workflow"
  plan_norm_line_has "$pd/skills/plan-issue/SKILL.md" '編集モードで起動' '経緯付録' || {
    echo "ステップ7c の FAIL 分岐が経緯付録への追記を指示していない"
    return 1
  }
}

@test "R10: 出力テンプレートの読み取り点がステップ2 の1点に保たれている" {
  local pd="$root/plugins/dev-workflow"
  plan_norm_line_has "$pd/skills/plan-issue/SKILL.md" '{OUTPUT_FORMAT}' 'ステップ2' || {
    echo "ステップ6 の3項がステップ2 の読み込み結果を用いる形になっていない"
    return 1
  }
}
