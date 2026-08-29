#!/usr/bin/env bats
load 'helpers/common'

# dev-workflow の4スキルが満たすべき契約を、スキル横断の不変条件として固定する。
#
# 【逐語照合を置かない理由】
# 旧 contract 系4本は description 本文や手順の散文を逐語で照合していた。文言を推敲する
# だけで赤くなる一方、起動契約の実体（name とディレクトリ名の一致・allowed-tools の
# 形式的妥当性）は何も測っていなかった。本ファイルが測るのは、文言ではなく構造として
# 観測できる不変条件だけである。
#
# 【走査対象のパスをここ1箇所に束ねる理由】
# scripts/validate-plugin-path-references.sh は scripts/ 配下の全ファイルから配布物パスの
# 出現を**行単位**で収集し、docs/development/plugin-path-reference-ledger.md と
# file:line:plugin の完全一致で双方向照合する。パスを本文中へ散らすと台帳へ乗る行が増え、
# 行番号のずれで unregistered と stale-ledger が同時に立つ。したがって配布物ルートは
# DW_ROOT へ1回だけ書き、以降の記述（コメントを含む）は変数名でのみ言及する。
#
# 【走査0件を緑にしない】
# 走査には find の出力を mapfile で受ける形を使う。`for f in <glob>` は非一致時に
# パターン文字列そのものを1回返すため、対象が消えてもループが1回回って緑になりうる。
# 加えて各ケースは走査回数を実行時カウンタで数え、下限を割ったら個別判定が全て緑でも
# ケースを赤にする。カウンタは配列の宣言ではなくループ本体で加算する
# （宣言を数えると、ループごと削除する変異に対して緑を返す）。

DW_ROOT="$REPO_ROOT/plugins/dev-workflow"

# 走査件数の下限。実測値との等値ではなく下限を置く。正当な追加（5本目のスキル）で
# 赤にせず、縮小（glob が0件へ落ちる・ディレクトリが空になる）だけを赤にするため。
SKILL_MIN=4

# description の上限字数。CLAUDE.md「スキル設計の token 規律」が定める
# 「200 字程度を目安、最長 300 字」の上限側を検査する。
DESC_MAX=300

# SKILL.md 本文の上限行数。規律の正本は CLAUDE.md「スキル設計の token 規律」の
# 「先頭 frontmatter を除いた本文の行数が 170 行を超えないことを目安とし」であり、
# 数値そのものはここに定数として持つ。条文から正規表現で数値を抽出する形は、
# 言い換え1回で静かに0件抽出へ落ちる（抽出失敗を赤にすれば今度は条文編集のたびに
# 赤くなる）。規律値の改訂は年単位で1回であり、両方を動かす手間と釣り合わない。
BODY_MAX=170

# 走査面（DW_ROOT 配下の md）の件数の下限。実測33本。
DW_MD_MIN=25

# 単一出典として検査する needle 群の件数の下限。
NEEDLE_GROUP_MIN=4

# 走査した reference ファイル件数の下限。実測20本。
REFERENCE_MIN=20

# 参照元（SKILL.md ・エージェント定義）の件数の下限。実測12本（skills 4 ＋ agents 8）。
# 参照到達性は「reference が誰かから引かれているか」を測るため、参照元が丸ごと消えると
# 判定が空振りする。参照元側にも下限を置き、エージェント定義の消失を赤にする。
SOURCE_MIN=12

# ---- 走査 ----

dw_skill_files() {
    find "$DW_ROOT/skills" -mindepth 2 -maxdepth 2 -name 'SKILL.md' -type f | sort
}

dw_md_files() {
    find "$DW_ROOT" -name '*.md' -type f | sort
}

# 参照到達性の被参照側（reference ファイル）。
dw_reference_files() {
    find "$DW_ROOT/skills" -mindepth 3 -maxdepth 3 -path '*/references/*' -name '*.md' -type f
    find "$DW_ROOT/references" -maxdepth 1 -name '*.md' -type f
}

# 参照到達性の参照元側（SKILL.md とエージェント定義）。
dw_reference_sources() {
    find "$DW_ROOT/skills" -mindepth 2 -maxdepth 2 -name 'SKILL.md' -type f
    find "$DW_ROOT/agents" -maxdepth 1 -name '*.md' -type f
}

# スキルごとの必須ツール。`<スキル名>|<ツール>|<ツール>…` の形を取る。
#
# これはハーネス側のツール語彙の網羅列挙ではない。各スキルの手順が実際に実行する操作の
# **最小集合**であり、部分集合として含まれることだけを要求する。ツールの追加は赤にならず、
# 必須のものを落としたときだけ赤になるため、ハーネスが新ツールを足しても陳腐化しない。
# 形式的妥当性（空でない・`Bash(` が閉じる・重複が無い）とは射程が異なり、そちらは
# 語彙を持たない検査、こちらはスキル固有の権限の欠落を見る検査である。
dw_required_tools() {
    printf '%s\n' \
        'create-issue|Read|AskUserQuestion|Write|Bash(gh issue create*)' \
        'refine-issue|Bash(gh issue view*)|Bash(bash *skills/refine-issue/scripts/prepare-issues.sh*)|Agent'
}

# 単一出典の needle 群。1行が1群で、`群名|needle|needle|…` の形を取る。
# 群の全構成要素が共起するファイルが DW_ROOT 配下でちょうど1件であることを検査する。
#
# 【走査面を DW_ROOT 配下へ限定する理由】
# 4群はいずれも現時点で dev-workflow 固有の値域であり、他プラグインを走査面へ加えても
# 測定値は変わらない。一方で走査面を全プラグインへ広げると、他プラグインが同じ語を
# 正当に独自定義した時点で赤くなる。後から広げる判断ができるよう、限定していることを
# ここに明記して残す。限定が効いていること（走査がそもそも届いていないだけではないこと）
# は、走査面の外へ同じ値域を置いても緑のままになる対の変異で確かめる。
#
# 【needle をバッククォート込みの固定文字列で持つ理由】
# 素の語は互いに部分文字列になる。`境界値` は同一ファイル内の採用技法 `境界値分析` の
# 部分文字列であり、`状態遷移` は `状態遷移テスト` の部分文字列である。素の語を needle に
# すると、値域から1項目を削る変異が上位語の残存に吸収されて緑で通る。バッククォートで
# 閉じた形は互いに部分文字列にならないため、削除変異が確実に赤になる。
# 射程の限界として、値域が本文中にバッククォートなしで複製された場合は検出できない。
#
# 【検査対象に含めない値域】
# 素のラベル `ブロッカー` は配布物内の多数のファイルに正当に現れるため needle にできず、
# 深刻度は定義句のほうを needle に取る。`決定論点` の振り分け2値（plan段階／実装段階）は
# 2ファイルに現れるが、一方が値域を、他方が振り分け基準を持つ意図的な分担であり
# 複製ではない。
dw_single_source_groups() {
    printf '%s\n' \
        '判断者ロール|`アーキテクト`|`プロダクトオーナー`|`ドメイン専門家`|`レビュアー（汎用）`' \
        'テストケース観点|`典型ケース`|`境界値`|`異常系`|`状態遷移`|`組み合わせ`' \
        '既定文言|該当なし。AC定義後に再生成すること' \
        '深刻度2段|マージすべきでない問題|マージを妨げないが改善が望ましい'
}

# front-matter の終端行番号（2本目の `---` の行番号）。閉じていなければ空を返す。
dw_frontmatter_end() {
    grep -n '^---$' "$1" | sed -n '2p' | cut -d: -f1
}

# front-matter 内のスカラ値。値を囲む引用符は剥がす（YAML の値として実際に評価される
# 文字列を数えるため。引用の有無で字数判定が2字ぶん変わると、規律と無関係な回避が
# 境界近傍で成立する）。
#
# 値がブロックスカラ指示子（`>` / `|` と chomp・indent 修飾）または空で、後続に
# インデント継続行がある場合は、それらを連結して1つの値として返す。同一行しか読まない
# 実装だと、`description: >-` と書いて次行以降へ長文を置くだけで字数の規律を回避できる
# （引用符を剥がす決定が塞いだのと同型の穴が別の形で残る）。
dw_fm_value() {
    local file="$1" fm_end="$2" key="$3" v
    v="$(awk -v fmend="$fm_end" -v key="$key" '
        function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
        NR > fmend { exit }
        !inblock && index($0, key ":") == 1 {
            val = trim(substr($0, length(key) + 2))
            if (val == "" || val ~ /^[>|][0-9]*[-+]?$/) { inblock = 1; buf = ""; next }
            print val
            exit
        }
        inblock {
            if ($0 ~ /^[ \t]/) {
                line = trim($0)
                if (buf == "") { buf = line } else { buf = buf " " line }
                next
            }
            # exit は END を走らせる。先に inblock を落とさないと END でも同じ値が
            # 出力され、値が2倍に数えられる（400字が801字になる）。
            inblock = 0
            print buf
            exit
        }
        END { if (inblock) print buf }
    ' "$file")"
    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"
    if [ "${#v}" -ge 2 ]; then
        case "$v" in
            \"*\") v="${v#\"}"; v="${v%\"}" ;;
            \'*\') v="${v#\'}"; v="${v%\'}" ;;
        esac
    fi
    printf '%s' "$v"
}

# UTF-8 の文字数。`${#v}` はロケールに依存し、C ロケール下ではバイト数を返して
# 日本語の description を実際の3倍に数える。継続バイト（0x80-0xBF）を落とした
# 残りのバイト数を数えることで、ロケールに依存せず文字数を得る。
dw_char_count() {
    printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | LC_ALL=C wc -c | tr -d '[:space:]'
}

# front-matter の allowed-tools のリスト項目。`#` で始まるコメント行は除く。
#
# ブロック形（`allowed-tools:` の次行から `  - Read`）とフロー形（`allowed-tools: Read, Grep`
# および `[Read, Grep]`）の双方を受ける。ブロック形しか受けない実装だと、配布物が
# フロー形を正当に採った瞬間に「リスト項目が0件」で赤くなり、赤の原因が配布物の誤りか
# 検査の未対応かを判別できない。フロー形の分割は括弧の深さを見て行う。
# `Bash(gh api repos/*/pulls/*, x)` のような括弧内のカンマで項目が割れると、
# 閉じ括弧の欠落として誤検出されるためである。
dw_allowed_tools() {
    local file="$1" fm_end="$2"
    awk -v fmend="$fm_end" '
        function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
        function emit_flow(val,   i, ch, depth, item) {
            sub(/^\[/, "", val); sub(/\]$/, "", val)
            depth = 0; item = ""
            for (i = 1; i <= length(val); i++) {
                ch = substr(val, i, 1)
                if (ch == "(") { depth++ }
                else if (ch == ")") { depth-- }
                if (ch == "," && depth == 0) { print trim(item); item = ""; continue }
                item = item ch
            }
            print trim(item)
        }
        NR > fmend { exit }
        !inlist && index($0, "allowed-tools:") == 1 {
            val = trim(substr($0, 15))
            if (val == "") { inlist = 1; next }
            emit_flow(val)
            exit
        }
        inlist && /^[^ \t]/ { inlist = 0 }
        inlist && /^[ \t]*#/ { next }
        inlist && /^[ \t]*-/ {
            sub(/^[ \t]*-[ \t]*/, "")
            print trim($0)
            next
        }
    ' "$file"
}

# allowed-tools の形式的妥当性を収集する。既知ツール名の固定列挙は行わない
# （語彙の正本がリポジトリ内に無く、ハーネス側が新ツールを足した瞬間に赤くなって、
# 赤の原因が配布物の誤りかテストの陳腐化か判別できなくなるため）。
dw_collect_allowed_tools() {
    local file="$1" fm_end="$2" rel="$3" dir="$4"
    local -a items=()
    mapfile -t items < <(dw_allowed_tools "$file" "$fm_end")

    if [ "${#items[@]}" -eq 0 ]; then
        collect_fail "allowed-tools が1件以上ある: $rel" "リスト項目が0件"
        return 0
    fi
    collect_ok "allowed-tools が1件以上ある: $rel"

    local item seen="" bad_empty=0 bad_paren=0 bad_dup=0
    for item in "${items[@]}"; do
        if [ -z "$item" ]; then
            bad_empty=$((bad_empty + 1))
            continue
        fi
        case "$item" in
            Bash\(*\)) ;;
            Bash\(*) bad_paren=$((bad_paren + 1)) ;;
        esac
        case "$seen" in
            *"|$item|"*) bad_dup=$((bad_dup + 1)) ;;
            *) seen="$seen|$item|" ;;
        esac
    done

    if [ "$bad_empty" -eq 0 ]; then
        collect_ok "allowed-tools に空の項目が無い: $rel"
    else
        collect_fail "allowed-tools に空の項目が無い: $rel" "空の項目 $bad_empty 件"
    fi
    if [ "$bad_paren" -eq 0 ]; then
        collect_ok "allowed-tools の Bash(...) が閉じている: $rel"
    else
        collect_fail "allowed-tools の Bash(...) が閉じている: $rel" "閉じ括弧の無い項目 $bad_paren 件"
    fi
    if [ "$bad_dup" -eq 0 ]; then
        collect_ok "allowed-tools に重複が無い: $rel"
    else
        collect_fail "allowed-tools に重複が無い: $rel" "重複 $bad_dup 件"
    fi

    # スキル固有の必須ツールが宣言されているか（部分集合検査）。
    local line name tool
    local -a want=()
    while IFS= read -r line; do
        name="${line%%|*}"
        [ "$name" = "$dir" ] || continue
        IFS='|' read -r -a want <<<"$line"
        for tool in "${want[@]:1}"; do
            case "$seen" in
                *"|$tool|"*) collect_ok "必須ツールを宣言する: $rel -> $tool" ;;
                *) collect_fail "必須ツールを宣言する: $rel -> $tool" "allowed-tools に無い" ;;
            esac
        done
    done < <(dw_required_tools)
    return 0
}

# 走査件数の下限を収集型で判定する。
dw_collect_scanned() {
    local scanned="$1" min="$2" label="$3"
    if [ "$scanned" -ge "$min" ]; then
        collect_ok "$label（下限 $min 件）"
    else
        collect_fail "$label（下限 $min 件）" "実測 $scanned 件"
    fi
    return 0
}

@test "起動契約: name がディレクトリ名と一致し front-matter が閉じ description と allowed-tools の形式が成立する" {
    collect_init
    local -a files=()
    mapfile -t files < <(dw_skill_files)

    local scanned=0 f rel dir fm_end name desc len
    for f in ${files[@]+"${files[@]}"}; do
        scanned=$((scanned + 1))
        rel="${f#"$REPO_ROOT"/}"
        dir="$(basename "$(dirname "$f")")"

        fm_end="$(dw_frontmatter_end "$f")"
        if [ -z "$fm_end" ]; then
            collect_fail "front-matter が閉じている: $rel" "終端の '---' が無い"
            continue
        fi
        collect_ok "front-matter が閉じている: $rel"

        name="$(dw_fm_value "$f" "$fm_end" name)"
        collect_equals "$name" "$dir" "name がディレクトリ名と一致する: $rel"

        desc="$(dw_fm_value "$f" "$fm_end" description)"
        if [ -z "$desc" ]; then
            collect_fail "description が非空: $rel" "値が空"
        else
            collect_ok "description が非空: $rel"
            len="$(dw_char_count "$desc")"
            if [ "$len" -le "$DESC_MAX" ]; then
                collect_ok "description が ${DESC_MAX} 字以内: $rel"
            else
                collect_fail "description が ${DESC_MAX} 字以内: $rel" "実測 ${len} 字 / 上限 ${DESC_MAX} 字"
            fi
        fi

        dw_collect_allowed_tools "$f" "$fm_end" "$rel" "$dir"
    done

    dw_collect_scanned "$scanned" "$SKILL_MIN" "走査した SKILL.md の件数"
    collect_finish
}

@test "規模規律: SKILL.md 本文（front-matter を除く）が上限行数以下である" {
    collect_init
    local -a files=()
    mapfile -t files < <(dw_skill_files)

    local scanned=0 f rel fm_end total body
    for f in ${files[@]+"${files[@]}"}; do
        scanned=$((scanned + 1))
        rel="${f#"$REPO_ROOT"/}"

        fm_end="$(dw_frontmatter_end "$f")"
        if [ -z "$fm_end" ]; then
            # 閉じていない front-matter を本文0行とみなすと規律が最も緩い側へ倒れる。
            # 行数を数えずに違反として積む（fail-closed）。
            collect_fail "本文行数が ${BODY_MAX} 行以下: $rel" "front-matter が閉じておらず本文の始点を決められない"
            continue
        fi

        total="$(wc -l <"$f" | tr -d '[:space:]')"
        body=$((total - fm_end))
        if [ "$body" -le "$BODY_MAX" ]; then
            collect_ok "本文行数が ${BODY_MAX} 行以下: $rel（実測 ${body} 行）"
        else
            collect_fail "本文行数が ${BODY_MAX} 行以下: $rel" "実測 ${body} 行 / 上限 ${BODY_MAX} 行"
        fi
    done

    dw_collect_scanned "$scanned" "$SKILL_MIN" "走査した SKILL.md の件数"
    collect_finish
}

@test "単一出典: 正本4群の値域が走査面でちょうど1ファイルにのみ共起する" {
    collect_init
    local -a md=()
    mapfile -t md < <(dw_md_files)

    # 走査面の件数は群ごとの照合ループの中で数えると群数ぶん重複する。ここで1回だけ数える。
    local scanned=0 f
    for f in ${md[@]+"${md[@]}"}; do
        scanned=$((scanned + 1))
    done
    dw_collect_scanned "$scanned" "$DW_MD_MIN" "走査した md ファイルの件数"

    local groups=0 line label hits hitlist all n
    local -a parts=() needles=()
    while IFS= read -r line; do
        groups=$((groups + 1))
        IFS='|' read -r -a parts <<<"$line"
        label="${parts[0]}"
        needles=("${parts[@]:1}")

        hits=0
        hitlist=""
        for f in ${md[@]+"${md[@]}"}; do
            all=1
            for n in "${needles[@]}"; do
                # 交替（grep -E 'A|B'）は使わない。1語の一致で合格になると、
                # 値域から他の語が消えても検査が緑で通る。
                grep -qF -e "$n" "$f" || { all=0; break; }
            done
            if [ "$all" -eq 1 ]; then
                hits=$((hits + 1))
                hitlist="${hitlist}${hitlist:+, }${f#"$REPO_ROOT"/}"
            fi
        done

        if [ "$hits" -eq 1 ]; then
            collect_ok "値域の共起がちょうど1ファイル: $label"
        else
            collect_fail "値域の共起がちょうど1ファイル: $label" \
                "期待 1 件 / 実測 ${hits} 件${hitlist:+（$hitlist）}"
        fi
    done < <(dw_single_source_groups)

    dw_collect_scanned "$groups" "$NEEDLE_GROUP_MIN" "検査した needle 群の件数"
    collect_finish
}

# 【既存検査との射程差】
# scripts/validate-plugin-portability.sh は「SKILL.md が指す参照先が実在するか（壊れた参照）」
# と「2段参照になっていないか」を既に検査している。本ケースが測るのはその逆方向、
# すなわち reference 側から見た到達性（どこからも引かれない孤立ファイルの検出）である。
# 射程が重ならないため、壊れた参照と2段参照はここで再実装しない。
#
# 【判定形を件数ではなく到達の有無に置く理由】
# 参照元の件数を固定すると、同じファイルを2箇所から引く正当な記述の増減で赤くなり、
# 赤の意味が「孤立が生じた」から「数え直しが要る」へ濁る。判定は「到達元が1件以上あるか」
# に置き、参照が2件以上あるファイルの参照を1件削っても緑のままであることを対の変異で
# 確かめる。
@test "参照到達性: reference ファイルがいずれも SKILL.md またはエージェント定義から引かれている" {
    collect_init
    local -a refs=() srcs=()
    mapfile -t refs < <(dw_reference_files)
    mapfile -t srcs < <(dw_reference_sources)

    if [ "${#srcs[@]}" -eq 0 ]; then
        collect_fail "参照元が1件以上ある" "SKILL.md とエージェント定義がいずれも見つからない"
        collect_finish
        return
    fi

    # 参照元側にも下限を置く。参照元が丸ごと消えると判定が空振りするため、被参照側の
    # 走査件数だけでは「到達できている」ことの根拠にならない。
    local sources=0 s
    for s in "${srcs[@]}"; do
        sources=$((sources + 1))
    done
    dw_collect_scanned "$sources" "$SOURCE_MIN" "走査した参照元（SKILL.md ・エージェント定義）の件数"

    local scanned=0 r rel base
    for r in ${refs[@]+"${refs[@]}"}; do
        scanned=$((scanned + 1))
        rel="${r#"$REPO_ROOT"/}"
        base="$(basename "$r")"
        if grep -qlF -e "$base" "${srcs[@]}" 2>/dev/null; then
            collect_ok "到達元が1件以上ある: $rel"
        else
            collect_fail "到達元が1件以上ある: $rel" "SKILL.md ・エージェント定義のいずれからも引かれていない"
        fi
    done

    dw_collect_scanned "$scanned" "$REFERENCE_MIN" "走査した reference ファイルの件数"
    collect_finish
}
