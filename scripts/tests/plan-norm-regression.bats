#!/usr/bin/env bats
load 'helpers/common'
root="$REPO_ROOT"

# ---------------------------------------------------------------------------
# Issue #814: プラン規範へ新設した規定の退行検出
#
# 【本ファイルを contract 系と分けて置く理由】
# `dev-workflow-skill-contract.bats` は「文言ではなく構造として観測できる不変条件だけ」を
# 測ると宣言し、散文の逐語照合を意図して排除している（#813 / PR #816）。本ファイルが測る
# のは、その決定が対象とした「文言の推敲で赤くなる照合」ではなく、**新設した規定そのもの
# が言い換えや削除で静かに消えること**の検出である。目的が異なるため同居させず、規範条文
# の退行検出として独立させる。両者を混ぜると、構造検査の側が散文の推敲で赤くなる状態へ
# 戻り、#816 の決定が実質的に取り消される。
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
#      契機は2経路ある——修正周回ごとの追記（7c の FAIL 分岐）と、2周してもブロッカーが
#      残った場合の追記（ループ終了条件）。後者を欠くと、付録が保持すると宣言した
#      「未解消の指摘」だけが運用上一度も生成されない。両経路とも照合する。
#  R10 出力テンプレートの読み取り点の単一性
#      要。ステップ6 を元の全文再読の形へ戻しても渡す資産の点数と列挙は無傷のため R8 は
#      緑で通り、同一ファイルの二重読みの復活が無検査になる。
#  R11 読み方区分を書く位置のレイアウト規定
#      要。テンプレート側の1文であり、消えるとタスク構造の箇条書きが増える形へ戻りうる。
#      値域そのものは R6 が押さえるため、ここで見るのは書く位置の規定の実在に限る。
#
# 上記のうち R4 は authoring-reference-relocation.bats、それ以外は本ファイルが持つ。
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
    'plan-prompt.md::概ね5箇所以上'
    'plan-prompt.md::ファイル全体の構造に依存する編集を含むなら'
    'plan-prompt.md::局所読みの総量が全文を超えるなら'
    'plan-contract.md::完了条件の検証粒度'
    'plan-contract.md::タスクごとの完了条件へ重ねて課さない'
    'plan-contract.md::成果物の書き出し先と手段の併記'
    'plan-contract.md::宛先だけを書いて手段を書かない記載は本必須記載を満たさない'
    'plan-prompt.md::成果物の書き出し先の選び方'
    'plan-prompt.md::作業ディレクトリ配下を既定の宛先とする'
    'plan-prompt.md::手段を確認できない場合は、宛先を作業ディレクトリ配下へ倒す'
    'plan-output-format.md::読み方区分は該当するタスクの「内容」欄へ自然文として書き、箇条書き項目を増やさない'
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
  [ "$checked" -ge 21 ] || {
    echo "照合件数が下限を下回った: checked=$checked (>=21)"
    return 1
  }
}

@test "R3: 観点12 の射程がレベル列挙で閉じられておらず正規化手順が残っている" {
  local guide="$root/plugins/dev-workflow/skills/plan-issue/references/review-guide-default.md"
  local -a needles=(
    'テンプレートが定義する見出し集合に含まれない `##` 以下のすべての見出し'
    '対象の見出しレベルを列挙して射程を閉じない'
    '`（該当する場合）` を除去してから比較する'
    '除去はテンプレート側とプラン側の双方へ同じく施す'
    'より前の固定部分で比較する'
    '固定部分に連番が含まれる場合はその連番も可変部として扱う'
    '同じ固定部を持つ見出しが任意個現れてよい'
    '1件でもあればブロッカー（改善提案に留めない）'
    'レビュー経緯の記録がプラン本体の節として置かれている場合はブロッカー'
  )
  local -a absent=()
  local checked=0 needle

  # 詳細節の見出しは行頭アンカー付きで照合する。`grep -F` の部分一致だと `#### 12. …` へ
  # レベルを1段下げる改変にも一致してしまい、階層降格が検出できない。
  grep -qE '^### 12\. 出力テンプレート定義外の節の不在' "$guide" || absent+=('^### 12. 出力テンプレート定義外の節の不在（行頭）')
  checked=$((checked + 1))

  for needle in "${needles[@]}"; do
    checked=$((checked + 1))
    grep -qF -e "$needle" "$guide" || absent+=("$needle")
  done
  if [ "${#absent[@]}" -ne 0 ]; then
    printf '観点12 の条文が見つからない:\n'
    printf '  %s\n' "${absent[@]}"
    return 1
  fi
  [ "$checked" -ge 10 ] || {
    echo "照合件数が下限を下回った: checked=$checked (>=10)"
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
  local skill="$pd/skills/plan-issue/SKILL.md"
  # 期待語は指示そのものの語形（`経緯付録へ追記`）に取る。単に `経緯付録` を見ると、
  # 指示を消しても同じ行の補足や注記に残った同語へ吸収されて緑のまま通る。
  plan_norm_line_has "$skill" '編集モードで起動' '経緯付録へ追記' '修正周回ごと' || {
    echo "ステップ7c の FAIL 分岐が修正周回ごとの経緯付録への追記を指示していない"
    return 1
  }
  # 修正周回の経路だけを結線すると、付録が保持すると宣言した「未解消の指摘」を書く主体が
  # ループ終了経路に不在のままになる。終了条件の行も併せて場所固定で照合する。
  plan_norm_line_has "$skill" '2周してもブロッカーが残る' '経緯付録へ追記' || {
    echo "ループ終了条件が未解消ブロッカーの経緯付録への追記を指示していない"
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
