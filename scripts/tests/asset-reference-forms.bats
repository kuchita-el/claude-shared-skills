#!/usr/bin/env bats
# 配布物の本文が同梱資産を指す表記の形の機械検査。
#
# 【主題】同梱資産を指す表記が届くかどうかは、その表記が書かれた走査面で決まる。
# 面ごとにどの形を採り、どの形を採らないかの正本は
# docs/development/coding-agent-plugin-design-principles.md §6 であり、本ファイルは
# 条文を写さない。本ファイルが持つのは、同節が採らないとした形を全プラグインの配布物から
# 拾う語彙（REFERENCE_FORM_VOCABULARY）と、拾ったうえで通す行の表
# （REFERENCE_FORM_EXEMPTIONS）である。
#
# 【走査面】plugins/ 直下の全プラグインについて、次の3面を読む。プラグイン名で分岐しない。
#   skill      plugins/*/skills/*/SKILL.md
#   agent      plugins/*/agents/*.md
#   reference  plugins/*/references/ 配下と plugins/*/skills/*/references/ 配下の *.md
#              （下位ディレクトリを含む）
# 行はファイル全体から読み、front-matter を除かない。列挙は list_surface_files が単一の
# 出典である。
#
# 【語彙】面と語彙ラベルの対ごとに、行を拡張正規表現で照合する。
#   reference  plugin-root-var   ${CLAUDE_PLUGIN_ROOT}（波括弧なしの $CLAUDE_PLUGIN_ROOT を含む）
#   reference  skill-dir-var     ${CLAUDE_SKILL_DIR}（同上）
#   3面すべて  parent-relative   ../ を含むパス・Markdown 相対リンク
#                                （スキル本文の ${CLAUDE_SKILL_DIR}/../ の親相対もここで拾う）
#   agent      skill-dir-var     ${CLAUDE_SKILL_DIR}
#   3面すべて  placeholder       プラグインルートやスキルディレクトリを山括弧で書いた基点
#   3面すべて  factory-path      plugins/<name>/... の形の、配布元リポジトリからの相対パス
#
# 【語彙を絞った箇所と、絞ったことで届かない範囲】素直な正規表現は、同梱資産を指さない行を
# 拾う。次の3箇所は語彙の側を絞ってある。
#   - parent-relative は、直前が「.」の ../ を拾わない。URL やパスの途中を「...」で省いた
#     表記（`gh api .../branches/...`）が当たるためである。届かなくなるのは、省略記法の
#     直後に続くパス（`.../references/x.md`）である。
#   - placeholder は、山括弧の形すべてを拾わない。山括弧は利用者のホーム配下や導入先の
#     リポジトリを指す仮の名前（`~/.claude/projects/<project-id>/`・`<tables>/<id>.yaml`）
#     にも使われるためである。拾うのは、名前に plugin・skill・プラグイン・スキルを含む
#     山括弧と、パスの先頭に立ち直後に references/・scripts/・agents/・skills/ が続く
#     山括弧に限る。届かなくなるのは、そのどちらにも当たらない名前で基点を書いた形
#     （`<root>/learnings.md`）である。
#   - factory-path は、直前がパスを構成する文字（英数字・`_`・`.`・`/`・`~`・`-`）の
#     plugins/ を拾わない。利用者のホーム配下の導入先（`~/.claude/plugins/...`）が当たる
#     ためである。先頭の `./` だけは拾う。届かなくなるのは、別の基点の後ろに続く形
#     （`$REPO/plugins/x/...`）と、後ろに名前が続かない plugins/ 単独の言及である。
#
# 【届かない範囲】本検査が見るのは上の語彙に当たる行だけであり、次は見ない。
#   - references 本文が名指した資産へ、ハブ（当該スキルの本文）が到達形を
#     持っているか
#   - references 本文に在る、変数も ../ も伴わない素の `references/<name>`・`scripts/<name>` の
#     言及。相対パスで書いた実行形（`node scripts/x.mjs`）を含む
#   - 面で許された形（スキル本文の ${CLAUDE_PLUGIN_ROOT}/... 等）が指す先の実在
#   - 波括弧のパラメータ名（`{plugin_root}/...`・`{pluginRoot}/...`）と、同一ディレクトリ内を
#     指す相対リンク
#   - references 配下の .md 以外のファイル、README、hooks、同梱スクリプト
#   - 語彙に無い形で書かれた基点。語彙は上の一覧に固定である
#
# 【免除】到達を指示せず配置や変数名を説明するだけの言及は、同節が射程から除いている。
# この区別は行の字面からは判定できないため、通す行を REFERENCE_FORM_EXEMPTIONS へ1行ずつ
# 登録する。1件は「語彙ラベル・ファイル・その行に含まれる固定文字列」の3つ組であり、
# 行番号を持たない。行番号で固定すると、無関係な1行の挿入で検査が赤になるためである。
# 1件の免除は、ちょうど1行を免除する。当たる行が0行の免除（文言が変わった・行が消えた・
# 語彙に当たらなくなった）は死んだ免除として赤にし、2行以上に当たる免除も赤にする。
# 短い文字列を登録して、後から書かれた行までまとめて通すことを防ぐためである。
# 説明の言及を新たに書くときは、到達指示でないことを人が確かめたうえで表へ足す。
#
# 【判定形】一致1件を "<語彙ラベル><TAB><plugins/ からの相対パス>:<行番号>:<本文>" の
# 1行として出力する。死んだ免除と複数行に当たる免除は、行頭を dead-exemption・
# ambiguous-exemption とした行で出力する。末尾に、走査したファイル数・免除した行数・
# 違反の行数を1行で出力する。判定側は語彙ラベルを行頭に固定した1本の文字列として
# 照合する。ラベル・パス・本文を別々に照合すると、別の語彙の一致行で偶然通る。
#
# 【fail-closed の向き】走査根が無い場合と、3面のいずれかでファイルが0件の場合と、
# grep が読み取りに失敗した場合は、違反なしへ潰さず前提不成立（終了コード 2）へ倒す。
# 面の列挙が縮む変異は、面①が「走査件数 == 別の式で数えた件数」を等値で照合して捉える。
#
# 【置き場所と、採らなかった置き場所】本ファイル（bats）に走査関数とケースを同居させる。
#   - scripts/validate-plugin-portability.sh へ足す形は採らない。同検査器は fixture の
#     リポジトリ根に対しても起動される。実資産の行に紐づく免除の表を持たせると、
#     fixture では全件が死んだ免除になる。それを避けるために免除の検査を根ごとに
#     切り替えると、死んだ免除を見ない経路が生じる。
#   - 独立した scripts/*.sh へ切り出す形は採らない。runner の SUITES へ登録すれば
#     bats 経由と直接実行で走査が二重になり、登録しなければ runner から一度も起動されない
#     検査器が増える。`.bats` には EXPECTED_BATS による双方向照合があり、登録漏れが赤に
#     なるが、scripts/*.sh にはそれが無い。
# 実資産の写しへ表記を書き足す負例と、免除の表を差し替える変異を、同じファイルの中で
# 走査関数へ直接掛けられることも、この置き場所を採る理由である。
#
# 【ADR 化の判定】置き場所・語彙の保持形・免除の保持形の決定は、manage-adr スキルの
# ADR 化判定基準の必要条件（却下代替が在る）を満たす。粒度判定基準では、適用先が
# 本検査1本であり、理由の保持先がテスト資産である本ファイルに在るため、4項目のうち
# 2項目が非該当になる。残る2項目が該当しても境界の3点に届かないため、ADR 化しない。

load 'helpers/common'

PLUGINS_ROOT="$REPO_ROOT/plugins"
PRECONDITION_PATHS=("$PLUGINS_ROOT")

# ---- 語彙 ----
# 正規表現は grep -E の拡張正規表現であり、LC_ALL=C で照合する。日本語の語はバイト列
# として照合され、英数字のクラスは ASCII に限られる。
RE_PLUGIN_ROOT_VAR='\$\{?CLAUDE_PLUGIN_ROOT'
RE_SKILL_DIR_VAR='\$\{?CLAUDE_SKILL_DIR'
RE_PARENT_RELATIVE='(^|[^.])\.\./'
RE_PLACEHOLDER='<[^<>/]*([Pp]lugin|PLUGIN|[Ss]kill|SKILL|プラグイン|スキル)[^<>/]*>/'
RE_PLACEHOLDER="$RE_PLACEHOLDER"'|(^|[^[:alnum:]_./~-])<[^<>/]+>/(references|scripts|agents|skills)/'
RE_FACTORY_PATH='(^|[^[:alnum:]_./~-])(\./)?plugins/[[:alnum:]_{<$]'

# 走査語彙の単一の出典。1件は "<面>|<語彙ラベル>|<正規表現>"。正規表現は「|」を含むため、
# 先頭2つの「|」だけで区切る。
REFERENCE_FORM_VOCABULARY=(
    "reference|plugin-root-var|$RE_PLUGIN_ROOT_VAR"
    "reference|skill-dir-var|$RE_SKILL_DIR_VAR"
    "reference|parent-relative|$RE_PARENT_RELATIVE"
    "reference|placeholder|$RE_PLACEHOLDER"
    "reference|factory-path|$RE_FACTORY_PATH"
    "agent|skill-dir-var|$RE_SKILL_DIR_VAR"
    "agent|parent-relative|$RE_PARENT_RELATIVE"
    "agent|placeholder|$RE_PLACEHOLDER"
    "agent|factory-path|$RE_FACTORY_PATH"
    "skill|parent-relative|$RE_PARENT_RELATIVE"
    "skill|placeholder|$RE_PLACEHOLDER"
    "skill|factory-path|$RE_FACTORY_PATH"
)

# ---- 免除 ----
# 1件は "<語彙ラベル>|<plugins/ からの相対パス>|<その行に含まれる固定文字列>"。
# 固定文字列は「|」を含めない。いずれも到達を指示しない説明の言及である。
#   - learning-store-spec.md の2件: learnings.md の配置の説明
#   - personal-store-spec.md の6件と distill-procedure.md の1件: 配布元リポジトリで
#     growth 自身を開発するときの運用（追跡対象外の置き場とその確かめ方）の説明
REFERENCE_FORM_EXEMPTIONS=(
    'placeholder|growth/references/learning-store-spec.md|<プラグインルート>/learnings.md'
    'plugin-root-var|growth/references/learning-store-spec.md|配布先の `${CLAUDE_PLUGIN_ROOT}` 直下に'
    'factory-path|growth/references/personal-store-spec.md|既存 `.gitignore` の `plugins/growth/.local/` がディレクトリごと追跡対象外にする'
    'factory-path|growth/references/personal-store-spec.md|リポジトリルートの `.gitignore` で `plugins/growth/.local/` を追跡対象外にする'
    'factory-path|growth/references/personal-store-spec.md|in-repo の `plugins/growth/.local/` は手動 dogfooding 時に'
    'factory-path|growth/references/personal-store-spec.md|git check-ignore -v plugins/growth/.local/captures.md'
    'factory-path|growth/references/personal-store-spec.md|mkdir -p plugins/growth/.local && touch plugins/growth/.local/captures.md'
    'factory-path|growth/references/personal-store-spec.md|git status --porcelain plugins/growth/.local/'
    'factory-path|growth/skills/distill/references/distill-procedure.md|in-repo の `plugins/growth/.local/` は走査しない'
)

setup_file() {
    common_setup_file
}

# 走査面ごとのファイルの列挙（NUL 区切り・整列済み）。走査本体はこれだけを呼ぶ。
#   引数: $1 面（skill / agent / reference）/ $2 走査根
list_surface_files() {
    local surface="$1" root="$2" dir
    case "$surface" in
    skill)
        find "$root" -mindepth 4 -maxdepth 4 -type f -path "$root/*/skills/*/SKILL.md" -print0
        ;;
    agent)
        find "$root" -mindepth 3 -maxdepth 3 -type f -path "$root/*/agents/*.md" -print0
        ;;
    reference)
        for dir in "$root"/*/references "$root"/*/skills/*/references; do
            [ -d "$dir" ] || continue
            find "$dir" -type f -name '*.md' -print0
        done
        ;;
    esac | LC_ALL=C sort -z
}

# 走査関数（本ファイルの被テスト対象）。
#   引数: 走査根（省略時は配布物のルート plugins/）
#   出力: 違反1件ごとに "<語彙ラベル><TAB><相対パス>:<行番号>:<本文>" を1行
#         免除の不整合1件ごとに "dead-exemption<TAB><免除>" か "ambiguous-exemption<TAB><免除>"
#         末尾に "checked skill=<n> agent=<n> reference=<n> exempted=<n> violations=<n>"
#   終了コード: 0=違反なし / 1=違反あり、または免除の不整合あり
#               2=前提不成立（走査根が無い・面のファイルが0件・読み取り失敗・未知の面）
scan_reference_forms() {
    local root="${1:-$PLUGINS_ROOT}"
    root="${root%/}"

    if [ ! -d "$root" ]; then
        printf '走査根が存在しない、またはディレクトリでない: %s\n' "$root" >&2
        return 2
    fi

    local -a skill_files=() agent_files=() reference_files=()
    local f
    while IFS= read -r -d '' f; do skill_files+=("$f"); done < <(list_surface_files skill "$root")
    while IFS= read -r -d '' f; do agent_files+=("$f"); done < <(list_surface_files agent "$root")
    while IFS= read -r -d '' f; do reference_files+=("$f"); done < <(list_surface_files reference "$root")

    if [ "${#skill_files[@]}" -eq 0 ]; then
        printf '走査面 skill のファイルが1件も無い: %s\n' "$root" >&2
        return 2
    fi
    if [ "${#agent_files[@]}" -eq 0 ]; then
        printf '走査面 agent のファイルが1件も無い: %s\n' "$root" >&2
        return 2
    fi
    if [ "${#reference_files[@]}" -eq 0 ]; then
        printf '走査面 reference のファイルが1件も無い: %s\n' "$root" >&2
        return 2
    fi

    # 語彙ごとに面のファイル群へ grep を掛け、一致行を貯める
    local -a hit_labels=() hit_rels=() hit_rests=()
    local entry surface rest label regex matches rc line rel_line
    local -a files=()
    for entry in "${REFERENCE_FORM_VOCABULARY[@]}"; do
        surface="${entry%%|*}"
        rest="${entry#*|}"
        label="${rest%%|*}"
        regex="${rest#*|}"

        case "$surface" in
        skill) files=("${skill_files[@]}") ;;
        agent) files=("${agent_files[@]}") ;;
        reference) files=("${reference_files[@]}") ;;
        *)
            printf '語彙が未知の走査面を指している: %s\n' "$surface" >&2
            return 2
            ;;
        esac

        # 読み取り失敗（rc >= 2）は一致なしへ潰さず前提不成立へ倒す
        if matches="$(LC_ALL=C grep -HnaE -- "$regex" "${files[@]}")"; then
            rc=0
        else
            rc=$?
        fi
        if [ "$rc" -ge 2 ]; then
            printf '走査対象を読み取れない（面=%s 語彙=%s）\n' "$surface" "$label" >&2
            return 2
        fi
        [ "$rc" -ne 0 ] && continue

        while IFS= read -r line; do
            [ -z "$line" ] && continue
            rel_line="${line#"$root"/}"
            hit_labels+=("$label")
            hit_rels+=("${rel_line%%:*}")
            hit_rests+=("${rel_line#*:}")
        done <<<"$matches"
    done

    # 免除の照合。語彙ラベルとファイルが一致し、行の本文が固定文字列を含む一致行を通す
    local -a used=()
    local i j ex ex_rest ex_label ex_rel ex_key content exempt
    for i in "${!REFERENCE_FORM_EXEMPTIONS[@]}"; do
        used[i]=0
    done

    local violations=0 exempted=0
    for j in "${!hit_labels[@]}"; do
        content="${hit_rests[$j]#*:}"
        exempt=0
        for i in "${!REFERENCE_FORM_EXEMPTIONS[@]}"; do
            ex="${REFERENCE_FORM_EXEMPTIONS[$i]}"
            ex_label="${ex%%|*}"
            ex_rest="${ex#*|}"
            ex_rel="${ex_rest%%|*}"
            ex_key="${ex_rest#*|}"
            [ "$ex_label" = "${hit_labels[$j]}" ] || continue
            [ "$ex_rel" = "${hit_rels[$j]}" ] || continue
            case "$content" in
            *"$ex_key"*)
                used[i]=$((used[i] + 1))
                exempt=1
                ;;
            esac
        done
        if [ "$exempt" -eq 1 ]; then
            exempted=$((exempted + 1))
        else
            printf '%s\t%s:%s\n' "${hit_labels[$j]}" "${hit_rels[$j]}" "${hit_rests[$j]}"
            violations=$((violations + 1))
        fi
    done

    # 免除はちょうど1行に当たる。0行は死んだ免除、2行以上は範囲の定まらない免除である
    local exemption_problems=0
    for i in "${!REFERENCE_FORM_EXEMPTIONS[@]}"; do
        if [ "${used[$i]}" -eq 0 ]; then
            printf 'dead-exemption\t%s\n' "${REFERENCE_FORM_EXEMPTIONS[$i]}"
            exemption_problems=$((exemption_problems + 1))
        elif [ "${used[$i]}" -gt 1 ]; then
            printf 'ambiguous-exemption\t%s\n' "${REFERENCE_FORM_EXEMPTIONS[$i]}"
            exemption_problems=$((exemption_problems + 1))
        fi
    done

    printf 'checked skill=%s agent=%s reference=%s exempted=%s violations=%s\n' \
        "${#skill_files[@]}" "${#agent_files[@]}" "${#reference_files[@]}" "$exempted" "$violations"

    if [ "$violations" -gt 0 ] || [ "$exemption_problems" -gt 0 ]; then
        return 1
    fi
    return 0
}

# ---- ケース側のヘルパ ----

# 走査関数の列挙（list_surface_files）とは別の式で、面のファイルを数える・並べる。
# 走査関数は深さとディレクトリを固定して列挙するのに対し、こちらは名前とパスの
# 部分一致だけで拾う。両者が食い違えば、面の列挙が縮んだか、想定していない場所に
# 資産が置かれたかのどちらかである。
#   引数: $1 種別（skill / agent / reference / skill-reference / shared-reference）/ $2 走査根
independent_surface_files() {
    local kind="$1" root="$2"
    case "$kind" in
    skill) find "$root" -type f -name 'SKILL.md' ;;
    agent) find "$root" -type f -name '*.md' -path '*/agents/*' ;;
    reference) find "$root" -type f -name '*.md' -path '*/references/*' ;;
    skill-reference) find "$root" -type f -name '*.md' -path '*/skills/*/references/*' ;;
    shared-reference) find "$root" -type f -name '*.md' -path '*/references/*' ! -path '*/skills/*' ;;
    esac | LC_ALL=C sort
}

independent_surface_count() {
    independent_surface_files "$1" "$2" | wc -l | tr -d ' '
}

# 種別ごとに、書き足す先のファイルを1件選ぶ（走査根からの相対パス）。
# 実資産のファイル名を直書きしないのは、資産の改名・退役でケースが壊れないようにするためである。
first_surface_file() {
    local kind="$1" root="$2" path
    path="$(independent_surface_files "$kind" "$root" | head -1)"
    printf '%s\n' "${path#"$root"/}"
}

# 実資産の写しを作る。配布物本体（PLUGINS_ROOT）は一切書き換えない。
copy_plugins() {
    mkdir -p "$1"
    cp -r "$PLUGINS_ROOT"/. "$1"/
}

# 写しのファイルの末尾へ1行を書き足し、その行番号を出力する。
append_line() {
    local file="$1" content="$2"
    printf '\n%s\n' "$content" >>"$file"
    grep -nF -- "$content" "$file" | tail -1 | cut -d: -f1
}

# 直前の run の出力から、末尾の集計行を取り出す。
summary_line() {
    grep '^checked ' <<<"$output" | tail -1
}

# 直前の run の集計行から、違反の行数だけを取り出す。
summary_violations() {
    summary_line | sed -n 's/.* violations=\([0-9][0-9]*\)$/\1/p'
}

# 実資産に対する集計行の期待値。件数は走査関数とは別の式で数える。
expected_real_summary() {
    printf 'checked skill=%s agent=%s reference=%s exempted=%s violations=0\n' \
        "$(independent_surface_count skill "$PLUGINS_ROOT")" \
        "$(independent_surface_count agent "$PLUGINS_ROOT")" \
        "$(independent_surface_count reference "$PLUGINS_ROOT")" \
        "${#REFERENCE_FORM_EXEMPTIONS[@]}"
}

# 面ごとの「赤にすべき1行」。語彙ラベルごとに、その面で当該ラベルだけに当たる文を返す。
violating_line_for() {
    case "$1" in
    plugin-root-var) printf '%s\n' '詳細は `${CLAUDE_PLUGIN_ROOT}/references/x.md` を読む' ;;
    skill-dir-var) printf '%s\n' '詳細は `${CLAUDE_SKILL_DIR}/references/x.md` を読む' ;;
    parent-relative) printf '%s\n' '詳細は [x.md](../../../references/x.md) を読む' ;;
    placeholder) printf '%s\n' '詳細は `<plugin-root>/references/x.md` を読む' ;;
    factory-path) printf '%s\n' '詳細は `plugins/growth/references/x.md` を読む' ;;
    esac
}

@test "前提: 配布物のルート（plugins/）が存在する" {
    assert_preconditions_met
}

@test "面①: 実資産は違反なしで緑になり、走査件数が別の式で数えた件数と一致する" {
    collect_init

    run scan_reference_forms
    collect_rc 0 "引数省略時、実資産に対する走査が exit 0 で終わる"

    # 走査件数・免除した行数・違反の行数を、等値で照合する。下限「1件以上」だけでは、
    # 面の列挙が特定のプラグインや深さへ縮む変異を見逃す。
    collect_equals "$(summary_line)" "$(expected_real_summary)" "集計行が、別の式で数えた件数・免除の件数・違反0と一致する"

    local kind count
    for kind in skill agent reference skill-reference shared-reference; do
        count="$(independent_surface_count "$kind" "$PLUGINS_ROOT")"
        if [ "$count" -ge 1 ]; then
            collect_ok "実資産に $kind のファイルが1件以上ある"
        else
            collect_fail "実資産に $kind のファイルが1件以上ある" "実測: $count"
        fi
    done

    if [ "${#REFERENCE_FORM_EXEMPTIONS[@]}" -ge 1 ]; then
        collect_ok "免除の表が1件以上を持つ（免除の経路が実資産で通っている）"
    else
        collect_fail "免除の表が1件以上を持つ（免除の経路が実資産で通っている）" "0件"
    fi

    collect_finish
}

# 写しの全ファイルへ、3面すべてに掛かる語彙の1行を書き足す。走査がどのプラグインの
# どのファイルも読んでいることを、件数ではなく一致行の所在で確かめる。
@test "面②: 全プラグインの3面の全ファイルで、書き足した表記を検出する" {
    collect_init

    local dup="$BATS_TEST_TMPDIR/all-files"
    copy_plugins "$dup"

    local content
    content="$(violating_line_for placeholder)"

    local -a targets=()
    local path
    while IFS= read -r path; do
        [ -n "$path" ] && targets+=("${path#"$dup"/}")
    done < <(
        independent_surface_files skill "$dup"
        independent_surface_files agent "$dup"
        independent_surface_files reference "$dup"
    )

    local -a line_nos=()
    local i
    for i in "${!targets[@]}"; do
        line_nos[i]="$(append_line "$dup/${targets[$i]}" "$content")"
    done

    run scan_reference_forms "$dup"
    collect_rc 1 "全ファイルへ書き足した写しは非0で終わる"
    collect_equals "$(summary_violations)" "${#targets[@]}" "違反の行数が、書き足したファイル数と一致する"

    for i in "${!targets[@]}"; do
        collect_contains "$output" "placeholder"$'\t'"${targets[$i]}:${line_nos[$i]}:${content}" "${targets[$i]} の一致行が出力される"
    done

    # プラグインの単位でも確かめる。面を持つプラグインが1つでも走査から漏れれば赤になる
    local plugin_dir plugin
    for plugin_dir in "$dup"/*/; do
        plugin="$(basename "$plugin_dir")"
        [ -n "$(independent_surface_files reference "$plugin_dir")$(independent_surface_files skill "$plugin_dir")$(independent_surface_files agent "$plugin_dir")" ] || continue
        collect_contains "$output" "placeholder"$'\t'"$plugin/" "プラグイン $plugin の一致行が出力される"
    done

    collect_finish
}

# 面と語彙ラベルの対ごとに、写しへ1行だけ書き足して赤になることを確かめる。
# 書き足しは対ごとに写しを作り直して1件だけに保つ。
@test "面③: 面と語彙の対ごとに、正規形から外れた1行を検出する" {
    collect_init

    # 対照: 何も書き足していない写しは exit 0（負例が空振りでも赤に見える事態を防ぐ）
    local control="$BATS_TEST_TMPDIR/control"
    copy_plugins "$control"
    run scan_reference_forms "$control"
    collect_rc 0 "対照: 何も書き足していない写しは exit 0"

    # 負例が覆う対の一覧。語彙を足したときに対応する負例が無ければここが赤になる
    local -a pairs=(
        'reference|plugin-root-var'
        'reference|skill-dir-var'
        'reference|parent-relative'
        'reference|placeholder'
        'reference|factory-path'
        'agent|skill-dir-var'
        'agent|parent-relative'
        'agent|placeholder'
        'agent|factory-path'
        'skill|parent-relative'
        'skill|placeholder'
        'skill|factory-path'
    )
    local -a vocabulary_pairs=()
    local entry
    for entry in "${REFERENCE_FORM_VOCABULARY[@]}"; do
        vocabulary_pairs+=("${entry%%|*}|$(cut -d'|' -f2 <<<"$entry")")
    done
    collect_equals "${pairs[*]}" "${vocabulary_pairs[*]}" "負例の対の一覧が走査語彙を過不足なく覆う"

    # reference はスキル配下と共有の2種の置き場を別々に確かめる
    local pair surface label content kind target dup line_no n=0
    local -a kinds=()
    for pair in "${pairs[@]}"; do
        surface="${pair%%|*}"
        label="${pair#*|}"
        content="$(violating_line_for "$label")"
        case "$surface" in
        reference) kinds=(skill-reference shared-reference) ;;
        *) kinds=("$surface") ;;
        esac

        for kind in "${kinds[@]}"; do
            n=$((n + 1))
            dup="$BATS_TEST_TMPDIR/pair-$n"
            copy_plugins "$dup"
            target="$(first_surface_file "$kind" "$dup")"
            line_no="$(append_line "$dup/$target" "$content")"

            run scan_reference_forms "$dup"
            collect_rc 1 "$kind への $label の書き足しは非0で終わる"
            collect_equals "$(summary_violations)" "1" "$kind への $label の書き足しは違反が1行になる"
            collect_contains "$output" "${label}"$'\t'"${target}:${line_no}:${content}" "$kind への $label の一致行がラベル・所在・本文の組で出力される"
        done
    done

    collect_finish
}

# 正規表現の選択肢ごとの負例。面③は語彙ラベルごとに1文しか置かないため、同じラベルの
# 別の書き方を落とす変異（選択肢を1つ削る・波括弧を必須にする等）はここが捉える。
@test "面④: 同じ語彙の別の書き方も検出する" {
    collect_init

    local -a cases=(
        'plugin-root-var|実行は `node $CLAUDE_PLUGIN_ROOT/scripts/x.mjs` で行う'
        'skill-dir-var|実行は `node $CLAUDE_SKILL_DIR/scripts/x.mjs` で行う'
        'parent-relative|../skills/x/references/y.md を読む'
        'parent-relative|詳細は `references/../y.md` を読む'
        'placeholder|配置は <プラグインルート>/x.md である'
        'placeholder|配置は <スキルディレクトリ>/references/x.md である'
        'placeholder|詳細は `<skill-dir>/references/x.md` を読む'
        'placeholder|詳細は `<PLUGIN_ROOT>/x.md` を読む'
        'placeholder|詳細は `<PluginRoot>/x.md` を読む'
        'placeholder|詳細は `<SkillDir>/x.md` を読む'
        'placeholder|詳細は `<SKILL_DIR>/x.md` を読む'
        'placeholder|詳細は `<root>/references/x.md` を読む'
        'placeholder|実行は `node <base>/scripts/x.mjs` で行う'
        'placeholder|定義は `<base>/agents/x.md` に在る'
        'placeholder|定義は `<base>/skills/x/SKILL.md` に在る'
        'factory-path|詳細は `./plugins/growth/references/x.md` を読む'
        'factory-path|plugins/{plugin}/references/x.md を読む'
        'factory-path|詳細は `plugins/<name>/references/x.md` を読む'
    )

    local dup="$BATS_TEST_TMPDIR/variants"
    copy_plugins "$dup"
    local target
    target="$(first_surface_file skill-reference "$dup")"

    local -a labels=() contents=() line_nos=()
    local i item
    for i in "${!cases[@]}"; do
        item="${cases[$i]}"
        labels[i]="${item%%|*}"
        contents[i]="${item#*|}"
        line_nos[i]="$(append_line "$dup/$target" "${contents[$i]}")"
    done

    run scan_reference_forms "$dup"
    collect_rc 1 "別の書き方を書き足した写しは非0で終わる"
    collect_equals "$(summary_violations)" "${#cases[@]}" "違反の行数が、書き足した行数と一致する"
    for i in "${!cases[@]}"; do
        collect_contains "$output" "${labels[$i]}"$'\t'"${target}:${line_nos[$i]}:${contents[$i]}" "${labels[$i]} の別の書き方が検出される: ${contents[$i]}"
    done

    # 新設の置き場: 既存のどのプラグインでもないディレクトリの、共有 references の下位
    # ディレクトリに置いたファイルも読む（プラグイン名・深さで絞らない設計であることの確認）
    local newdir_dup="$BATS_TEST_TMPDIR/new-plugin"
    copy_plugins "$newdir_dup"
    mkdir -p "$newdir_dup/zz-new-plugin/references/sub"
    local new_content
    new_content="$(violating_line_for plugin-root-var)"
    printf '%s\n' "$new_content" >"$newdir_dup/zz-new-plugin/references/sub/new.md"
    run scan_reference_forms "$newdir_dup"
    collect_rc 1 "新設のプラグインの共有 references への書き足しは非0で終わる"
    collect_contains "$output" "plugin-root-var"$'\t'"zz-new-plugin/references/sub/new.md:1:${new_content}" "新設のプラグインの下位ディレクトリの一致行が出力される"

    # スキル本文の変数つきの親相対（${CLAUDE_SKILL_DIR}/../）も parent-relative として拾う
    local parent_dup="$BATS_TEST_TMPDIR/skill-dir-parent"
    copy_plugins "$parent_dup"
    local skill_target parent_content parent_line
    skill_target="$(first_surface_file skill "$parent_dup")"
    parent_content='詳細は `${CLAUDE_SKILL_DIR}/../../references/x.md` を読む'
    parent_line="$(append_line "$parent_dup/$skill_target" "$parent_content")"
    run scan_reference_forms "$parent_dup"
    collect_rc 1 "スキル本文への変数つきの親相対の書き足しは非0で終わる"
    collect_equals "$(summary_violations)" "1" "スキル本文への変数つきの親相対の書き足しは違反が1行になる"
    collect_contains "$output" "parent-relative"$'\t'"${skill_target}:${parent_line}:${parent_content}" "スキル本文の変数つきの親相対が parent-relative として出力される"

    collect_finish
}

# 語彙から外してある形と、面で許された形が、緑のまま通ることを固定する。
# 語彙を広げる変異（「.」の除外を外す・山括弧をすべて拾う・plugins/ の直前を見ない・
# スキル本文で変数を禁じる等）はここが捉える。
@test "面⑤: 語彙から外した形と、面で許された形は緑のまま通る" {
    collect_init

    local -a common=(
        'DoR は `{plugin_root}/references/dor-default.md` を読む'
        '定義は `{pluginRoot}/agents/x.md` に在る'
        '詳細は [x.md](x.md) を読む'
        '確定判定は `gh api .../branches/{branch}/protection` で行える'
        'store は `~/.claude/projects/<project-id>/growth/captures.md` に在る'
        '各表は `<tables>/<id>.yaml` に置く'
        '置き場は `<X>/docs/rdra` である'
        '導入先は `~/.claude/plugins/cache/x/references/y.md` に在る'
        '変数名 CLAUDE_PLUGIN_ROOT と CLAUDE_SKILL_DIR は host が定める'
        '配布先に plugins/ は存在しない'
    )
    local -a skill_only=(
        '詳細は `${CLAUDE_PLUGIN_ROOT}/references/x.md` を読む'
        '詳細は `${CLAUDE_SKILL_DIR}/references/x.md` を読む'
    )
    local -a agent_only=(
        '詳細は `${CLAUDE_PLUGIN_ROOT}/references/x.md` を読む'
    )

    local dup="$BATS_TEST_TMPDIR/positives"
    copy_plugins "$dup"

    local kind target content
    for kind in skill agent skill-reference shared-reference; do
        target="$(first_surface_file "$kind" "$dup")"
        for content in "${common[@]}"; do
            append_line "$dup/$target" "$content" >/dev/null
        done
    done
    target="$(first_surface_file skill "$dup")"
    for content in "${skill_only[@]}"; do
        append_line "$dup/$target" "$content" >/dev/null
    done
    target="$(first_surface_file agent "$dup")"
    for content in "${agent_only[@]}"; do
        append_line "$dup/$target" "$content" >/dev/null
    done

    run scan_reference_forms "$dup"
    collect_rc 0 "語彙から外した形と面で許された形を書き足した写しは exit 0"
    collect_equals "$output" "$(expected_real_summary)" "出力が集計行だけであり、実資産の集計と一致する"

    collect_finish
}

@test "面⑥: 免除を外すと実資産の行が赤へ転じ、死んだ免除と複数行に当たる免除も赤になる" {
    collect_init

    local -a original=("${REFERENCE_FORM_EXEMPTIONS[@]}")
    local i j ex ex_label ex_rest ex_rel ex_key

    # (1) 免除を1件ずつ外す。外した免除が通していた行だけが違反として現れる
    for i in "${!original[@]}"; do
        ex="${original[$i]}"
        ex_label="${ex%%|*}"
        ex_rest="${ex#*|}"
        ex_rel="${ex_rest%%|*}"
        ex_key="${ex_rest#*|}"

        REFERENCE_FORM_EXEMPTIONS=()
        for j in "${!original[@]}"; do
            [ "$j" -eq "$i" ] || REFERENCE_FORM_EXEMPTIONS+=("${original[$j]}")
        done

        run scan_reference_forms
        collect_rc 1 "免除 $((i + 1)) 件目を外すと実資産が非0で終わる"
        collect_equals "$(summary_violations)" "1" "免除 $((i + 1)) 件目を外すと違反が1行になる"
        if grep -F -- "${ex_label}"$'\t'"${ex_rel}:" <<<"$output" | grep -qF -- "$ex_key"; then
            collect_ok "免除 $((i + 1)) 件目が通していた行が違反として出力される"
        else
            collect_fail "免除 $((i + 1)) 件目が通していた行が違反として出力される" "output: $output"
        fi
    done
    REFERENCE_FORM_EXEMPTIONS=("${original[@]}")

    # (2) 免除が指す行を写しから消す。免除は1件ずつ、死んだ免除として赤になる
    local dup file
    for i in "${!original[@]}"; do
        ex="${original[$i]}"
        ex_rest="${ex#*|}"
        ex_rel="${ex_rest%%|*}"
        ex_key="${ex_rest#*|}"

        dup="$BATS_TEST_TMPDIR/dead-$i"
        copy_plugins "$dup"
        file="$dup/$ex_rel"
        grep -vF -- "$ex_key" "$file" >"$file.tmp" || true
        mv "$file.tmp" "$file"

        run scan_reference_forms "$dup"
        collect_rc 1 "免除 $((i + 1)) 件目が指す行を消すと非0で終わる"
        collect_contains "$output" "dead-exemption"$'\t'"$ex" "免除 $((i + 1)) 件目が死んだ免除として出力される"
        collect_equals "$(summary_violations)" "0" "行を消しただけでは違反の行は増えない"
    done

    # (3) 免除の文言が行と合わなくなる。行は違反として現れ、免除は死んだ免除になる
    ex="${original[0]}"
    ex_label="${ex%%|*}"
    ex_rest="${ex#*|}"
    ex_rel="${ex_rest%%|*}"
    REFERENCE_FORM_EXEMPTIONS=("${original[@]}")
    REFERENCE_FORM_EXEMPTIONS[0]="${ex_label}|${ex_rel}|現物のどの行にも無い文言"
    run scan_reference_forms
    collect_rc 1 "免除の文言が行と合わなくなると非0で終わる"
    collect_contains "$output" "dead-exemption"$'\t'"${ex_label}|${ex_rel}|現物のどの行にも無い文言" "文言の合わない免除が死んだ免除として出力される"
    collect_equals "$(summary_violations)" "1" "文言の合わない免除が通していた行が違反になる"

    # (4) 免除は語彙ラベルを見る。別の語彙ラベルの免除は、同じ行を通さない
    REFERENCE_FORM_EXEMPTIONS=("${original[@]}")
    REFERENCE_FORM_EXEMPTIONS[0]="no-such-label|${ex_rest}"
    run scan_reference_forms
    collect_rc 1 "語彙ラベルの違う免除は行を通さず非0で終わる"
    collect_contains "$output" "dead-exemption"$'\t'"no-such-label|${ex_rest}" "語彙ラベルの違う免除が死んだ免除として出力される"
    collect_equals "$(summary_violations)" "1" "語彙ラベルの違う免除が通さなかった行が違反になる"
    REFERENCE_FORM_EXEMPTIONS=("${original[@]}")

    # (5) 免除はファイルを見る。免除された行と同じ文を別のファイルへ書いても通らない
    ex_key="${ex_rest#*|}"
    local other_dup="$BATS_TEST_TMPDIR/other-file"
    copy_plugins "$other_dup"
    local other_target other_line_no
    other_target="$(first_surface_file skill-reference "$other_dup")"
    if [ "$other_target" = "$ex_rel" ]; then
        collect_fail "前提: 免除1件目のファイルと書き足し先が別のファイルである" "どちらも $ex_rel"
    else
        collect_ok "前提: 免除1件目のファイルと書き足し先が別のファイルである"
    fi
    other_line_no="$(append_line "$other_dup/$other_target" "$ex_key")"
    run scan_reference_forms "$other_dup"
    collect_rc 1 "免除された行と同じ文を別のファイルへ書くと非0で終わる"
    collect_contains "$output" "${ex_label}"$'\t'"${other_target}:${other_line_no}:${ex_key}" "別のファイルへ書いた同じ文が違反として出力される"

    # (6) 免除はちょうど1行に当たる。同じ文をもう1行書くと、免除の範囲が定まらず赤になる
    local twice_dup="$BATS_TEST_TMPDIR/twice"
    copy_plugins "$twice_dup"
    append_line "$twice_dup/$ex_rel" "$ex_key" >/dev/null
    run scan_reference_forms "$twice_dup"
    collect_rc 1 "免除の文言に当たる行が2行になると非0で終わる"
    collect_contains "$output" "ambiguous-exemption"$'\t'"$ex" "2行に当たる免除が出力される"

    collect_finish
}

@test "面⑦: 走査の前提が崩れたとき、0件照合を緑にせず fail-closed で終わる" {
    collect_init

    run scan_reference_forms "$BATS_TEST_TMPDIR/does-not-exist"
    collect_rc 2 "走査根が存在しない場合、前提不成立として exit 2 で終わる"

    local empty_dir="$BATS_TEST_TMPDIR/empty-root"
    mkdir -p "$empty_dir"
    run scan_reference_forms "$empty_dir"
    collect_rc 2 "走査根の配下にファイルが1件も無い場合、前提不成立として exit 2 で終わる"

    # 面ごとの0件。他の2面にファイルが在っても、1面が空なら緑にしない
    local no_skill="$BATS_TEST_TMPDIR/no-skill"
    copy_plugins "$no_skill"
    find "$no_skill" -type f -name 'SKILL.md' -delete
    run scan_reference_forms "$no_skill"
    collect_rc 2 "SKILL.md が1件も無い場合、前提不成立として exit 2 で終わる"
    collect_contains "$output" "走査面 skill のファイルが1件も無い" "0件の走査面 skill が名指しされる"

    local no_agent="$BATS_TEST_TMPDIR/no-agent"
    copy_plugins "$no_agent"
    find "$no_agent" -type f -path '*/agents/*' -delete
    run scan_reference_forms "$no_agent"
    collect_rc 2 "agents 定義が1件も無い場合、前提不成立として exit 2 で終わる"
    collect_contains "$output" "走査面 agent のファイルが1件も無い" "0件の走査面 agent が名指しされる"

    local no_reference="$BATS_TEST_TMPDIR/no-reference"
    copy_plugins "$no_reference"
    find "$no_reference" -type f -path '*/references/*' -delete
    run scan_reference_forms "$no_reference"
    collect_rc 2 "references のファイルが1件も無い場合、前提不成立として exit 2 で終わる"
    collect_contains "$output" "走査面 reference のファイルが1件も無い" "0件の走査面 reference が名指しされる"

    # grep が読み取り失敗（終了コード 2）を返す状況を、grep を差し替えて作る。
    # 実行する利用者によらず成り立つので、root でも読み取り失敗の扱いを検査できる。
    # 差し替えは走査面のファイル群への grep（-HnaE）だけに効かせる。
    grep() {
        if [ "$1" = "-HnaE" ]; then
            printf 'grep: Permission denied\n' >&2
            return 2
        fi
        command grep "$@"
    }
    run scan_reference_forms
    unset -f grep
    collect_rc 2 "grep が読み取り失敗を返す場合、前提不成立として exit 2 で終わる"
    collect_contains "$output" "走査対象を読み取れない" "読み取り失敗が理由つきで出力される"

    # 未知の走査面を指す語彙は、黙って読み飛ばさない
    local -a saved_vocabulary=("${REFERENCE_FORM_VOCABULARY[@]}")
    REFERENCE_FORM_VOCABULARY+=("readme|plugin-root-var|$RE_PLUGIN_ROOT_VAR")
    run scan_reference_forms
    REFERENCE_FORM_VOCABULARY=("${saved_vocabulary[@]}")
    collect_rc 2 "語彙が未知の走査面を指す場合、前提不成立として exit 2 で終わる"

    collect_finish
}
