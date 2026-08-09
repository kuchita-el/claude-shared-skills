#!/usr/bin/env bash
# 日本語文書の機械検査。共通規約 references/japanese-writing.md の2項目を扱う。
#
#   一文の長さ超過   第5条の補則。閾値は文書種別プロファイルが優先する。違反として扱う
#   不透明な識別子   第2条。骨格位置にある識別子。候補として挙げるだけで違反にしない
#
# 第2条を候補に留めるのは、条文が説明の形式を問わないためである。括弧注・連体修飾・
# 述部で内容を述べる形のいずれも認められており、説明があるかどうかは意味の判定になる。
# 本スクリプトは形態素解析も意味解析も持たず、判定できるのは識別子の直後が助詞かどうか
# までである。確定は doc-reviewer が行う。候補は終了コード1に寄与しない。
#
# 第1条（語の接地）は機械検査の対象外である。初出の語が読み手に通じるかは、人手で保守
# する語の登録簿なしには判定できず、その保守コストに見合わないためである。第1条・第3条・
# 第4条は doc-reviewer が唯一の執行手段である。
#
# 字数の数え方と一文の切り方は references/japanese-writing.md の「一文の長さの計数規則」
# が単一の出典である。本スクリプトはその規則を実装するだけで、独自の規則を持たない。
#
# 検査していないことと違反が無いことを、同じ終了コードにしない。資源が読めない・基点が
# 解決できない・対象が Markdown でないといった事態は、いずれも終了コード2で止める。
#
# 使い方:
#   bash lint-ja.sh [パス...]           変更のあった箇所だけを検査する（既定）
#   bash lint-ja.sh --all パス...        ファイル全体を検査する
#
# オプション:
#   --type <種別>       文書種別。プロファイルの行を選ぶ（既定: 汎用）
#   --profile <パス>    文書種別プロファイル（既定: プロジェクト固有 → 同梱の既定）
#   --base <ref>        差分の基点（既定: HEAD）。指定した ref と HEAD の分岐点を採る
#   --two-dot           --base を分岐点ではなく2点間差分として解釈する
#   --all               ファイル全体を検査する。パスの指定が必須
#
# exit code:
#   0: 違反なし（候補だけが出た場合を含む）
#   1: 違反あり
#   2: 入力が不正、または検査に必要な資源を解決できない

set -uo pipefail

# 字数はコードポイントで数える。ロケールが UTF-8 でないとシェルは文字ではなくバイトを
# 数え、閾値が2倍以上に緩む。黙って緩めず、解決できなければ止める。
if [ -z "${LC_ALL:-}" ] || [ "${LC_ALL}" = "C" ] || [ "${LC_ALL}" = "POSIX" ]; then
    for _cand in C.UTF-8 C.utf8 en_US.UTF-8; do
        if LC_ALL="$_cand" bash -c '[ "${#1}" -eq 1 ]' _ あ 2>/dev/null; then
            export LC_ALL="$_cand"
            break
        fi
    done
    unset _cand
fi
_probe=あ
if [ "${#_probe}" -ne 1 ]; then
    echo "lint-ja: 文字単位で数えられるロケールが見つかりません（LC_ALL=${LC_ALL:-未設定}）" >&2
    echo "  UTF-8 ロケールを導入するか、LC_ALL へ UTF-8 のロケールを指定してください" >&2
    exit 2
fi
unset _probe

if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "lint-ja: bash 4 以降が必要です（連想配列を使うため）" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PROFILE="$SCRIPT_DIR/../references/document-type-profiles.md"

# 共通規約の第5条の補則が定める既定値。プロファイルを解決できない場合はこれで動く。
FALLBACK_MAX_LEN=100

# プロファイルから読んだ上限として受け付ける範囲。範囲を外れた値は解決の失敗として
# 扱い、既定へ黙って落とさない。表の列がずれていることに気づかないまま検査が
# 無効化されることを避けるためである。
MIN_ACCEPTED_LEN=10
MAX_ACCEPTED_LEN=10000

OPEN_BRACKETS=('（' '「' '『' '【' '［' '(' '[')
CLOSE_BRACKETS=('）' '」' '』' '】' '］' ')' ']')

# 文の区切り。半角の疑問符と感嘆符は含めない。ファイル名や識別子の中に文字として
# 現れるためである（共通規約「どこまでを一文と数えるか」）。
SENT_DELIMS=('。' '？' '！')

# 検査対象の行を絞らないことを表す番兵。空文字と区別する。空文字を「絞らない」の意味に
# 使うと、追加行がゼロの差分（純削除・改名・属性変更）が全行検査へ落ちる。
SCOPE_ALL='ALL'

# 正規表現は変数へ入れてから [[ =~ ]] へ渡す。角括弧を退避した形を直接書くと、
# bash は退避を解いた文字列として扱わず、一致しないまま静かに素通りする。
LINK_RE='\[([^]]*)\]\([^)]*\)'
REFLINK_RE='\[([^]]*)\]\[[^]]*\]'
TABLE_SEP_RE='^\|[-:|[:space:]]*$'
HEADING_RE='^#{1,6}([[:space:]]|$)'
LIST_RE='^([-*+][[:space:]]+|[0-9]+[.)][[:space:]]+)'
SETEXT_RE='^(=+|-+)$'
TABLE_ROW_RE='^\|'
QUOTE_ROW_RE='^>'
ID_RE='(ADR-[0-9]{8,12}-[0-9]+|#[0-9]+)'

# 文書冒頭のメタデータを挟む区切り線。
FRONT_MATTER_MARK='---'

# 読み手の画面に現れない強調の記号。囲みの内側の文字は数え、記号だけを落とす。
EMPHASIS_MARKS=('**' '__' '~~')

# 不透明な識別子を候補として挙げる骨格位置。主語と目的語を作る助詞に限る。
SKELETON_PARTICLES=('は' 'が' 'を')

usage() {
    cat <<'USAGE'
usage: bash lint-ja.sh [オプション] [パス...]

  引数なし    変更のあった箇所だけを検査する（既定）
  --all       ファイル全体を検査する。パスの指定が必須

オプション:
  --type <種別>       文書種別。プロファイルの行を選ぶ（既定: 汎用）
  --profile <パス>    文書種別プロファイル（既定: プロジェクト固有 → 同梱の既定）
  --base <ref>        差分の基点（既定: HEAD）。指定した ref と HEAD の分岐点を採る
  --two-dot           --base を分岐点ではなく2点間差分として解釈する

exit code:
  0 違反なし / 1 違反あり / 2 入力が不正、または資源を解決できない
USAGE
}

die() {
    echo "lint-ja: $1" >&2
    exit "${2:-2}"
}

# ---- 引数解析 ----

DOC_TYPE="汎用"
PROFILE_PATH=""
DIFF_BASE="HEAD"
TWO_DOT=0
SCAN_ALL=0
PATHS=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        --type)
            [ "$#" -ge 2 ] || die "--type に値がありません"
            DOC_TYPE="$2"
            shift 2
            ;;
        --profile)
            [ "$#" -ge 2 ] || die "--profile に値がありません"
            PROFILE_PATH="$2"
            shift 2
            ;;
        --base)
            [ "$#" -ge 2 ] || die "--base に値がありません"
            DIFF_BASE="$2"
            shift 2
            ;;
        --two-dot)
            TWO_DOT=1
            shift
            ;;
        --all)
            SCAN_ALL=1
            shift
            ;;
        --)
            shift
            while [ "$#" -gt 0 ]; do
                PATHS+=("$1")
                shift
            done
            ;;
        -*)
            die "未知のオプションです: $1"
            ;;
        *)
            PATHS+=("$1")
            shift
            ;;
    esac
done

# ---- リポジトリの基点 ----
#
# 上限値の解決先を作業ディレクトリに従属させない。サブディレクトリから起動しただけで
# プロジェクト固有のプロファイルが見つからなくなると、同じファイルを同じオプションで
# 検査した結果が場所によって変わる。
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || REPO_ROOT=""
# 実体パスへ揃える。git が返すのは実体パスであり、作業ディレクトリが symlink 経由だと
# 論理パスと食い違って、リポジトリの中にいるのに外だと判定される。
[ -n "$REPO_ROOT" ] && REPO_ROOT="$(cd -P -- "$REPO_ROOT" 2>/dev/null && pwd -P)"

# 検査対象として指定されたパス（リポジトリのルート相対）。空なら全体を対象とする。
WANT_PATHS=()

# 列挙結果が、指定されたパスのいずれかに含まれるかを見る。
path_wanted() {
    local f="$1" w
    [ "${#WANT_PATHS[@]}" -eq 0 ] && return 0
    for w in "${WANT_PATHS[@]}"; do
        [ "$w" = "." ] && return 0
        [ "$f" = "$w" ] && return 0
        case "$f" in "$w"/*) return 0 ;; esac
    done
    return 1
}

# 作業ディレクトリ相対のパスを、リポジトリのルート相対へ直す。
REPO_RELATIVE=""
to_repo_relative() {
    local p="$1" dir base abs
    if [ -d "$p" ]; then
        abs="$(cd -P -- "$p" 2>/dev/null && pwd -P)" || die "パスを解決できません: $p"
    else
        dir="$(dirname -- "$p")"
        base="$(basename -- "$p")"
        abs="$(cd -P -- "$dir" 2>/dev/null && pwd -P)" || die "パスを解決できません: $p"
        abs="$abs/$base"
    fi
    case "$abs" in
        "$REPO_ROOT") REPO_RELATIVE="." ;;
        "$REPO_ROOT"/*) REPO_RELATIVE="${abs#"$REPO_ROOT"/}" ;;
        *) die "リポジトリの外を指しています: $p" ;;
    esac
}

project_base() {
    if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
        printf '%s' "$CLAUDE_PROJECT_DIR"
        return 0
    fi
    if [ -n "$REPO_ROOT" ]; then
        printf '%s' "$REPO_ROOT"
        return 0
    fi
    # git リポジトリの外では、作業ディレクトリから親をたどって設定の置き場所を探す。
    # 作業ディレクトリをそのまま基点にすると、同じファイルを同じ指定で検査した結果が
    # 起動した場所の深さで変わる。
    local d
    d="$(pwd)"
    while [ -n "$d" ] && [ "$d" != "/" ]; do
        if [ -d "$d/.claude" ]; then
            printf '%s' "$d"
            return 0
        fi
        d="$(dirname -- "$d")"
    done
    printf '%s' "."
}

# ---- 文字列の操作 ----
#
# 前後の空白を落とす操作と文字の数え上げは1行あたり十数回呼ばれる。コマンド置換で
# 呼ぶとその回数だけプロセスが生まれるため、結果はグローバルへ書いて返す。

TRIMMED=""
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    TRIMMED="${s%"${s##*[![:space:]]}"}"
}

# ---- 文書種別プロファイル ----

# 一文長の上限を解決する。プロファイルは種別を行、値を列に取る表である。
# 解決は「指定の種別を優先順位の順に探し、どこにも無ければ汎用を同じ順で探す」形を
# 取る。優先順位はプロジェクト固有、プラグイン同梱の既定の順である。
resolve_max_len() {
    local -a chain=()

    if [ -n "$PROFILE_PATH" ]; then
        [ -f "$PROFILE_PATH" ] || die "文書種別プロファイルが見つかりません: $PROFILE_PATH"
        [ -r "$PROFILE_PATH" ] || die "文書種別プロファイルを読めません: $PROFILE_PATH"
        chain+=("$PROFILE_PATH")
    else
        local project_profile
        project_profile="$(project_base)/.claude/writing/type-profiles.md"
        if [ -f "$project_profile" ]; then
            [ -r "$project_profile" ] || die "文書種別プロファイルを読めません: $project_profile"
            chain+=("$project_profile")
        fi
    fi
    if [ -f "$DEFAULT_PROFILE" ]; then
        [ -r "$DEFAULT_PROFILE" ] || die "同梱の文書種別プロファイルを読めません: $DEFAULT_PROFILE"
        chain+=("$DEFAULT_PROFILE")
    fi

    # 上限の列を持たないプロファイルは、指定が黙って捨てられる。列名の表記ゆれや
    # 区切り行の欠落で明示した指定が効かないまま既定へ緩むのを避け、止める。
    local path
    for path in ${chain[@]+"${chain[@]}"}; do
        profile_validate "$path"
    done

    local want
    for want in "$DOC_TYPE" "汎用"; do
        for path in ${chain[@]+"${chain[@]}"}; do
            profile_lookup "$path" "$want"
            if [ -n "$PROFILE_VALUE" ]; then
                MAX_LEN="$PROFILE_VALUE"
                return 0
            fi
        done
    done

    MAX_LEN="$FALLBACK_MAX_LEN"
    return 0
}

# 表の1行をセルの配列へ分ける。両端の縦棒は落とし、各セルの前後の空白も落とす。
ROW_CELLS=()
split_row() {
    local line="$1" rest cell
    ROW_CELLS=()
    line="${line#|}"
    line="${line%|}"
    rest="$line"
    while :; do
        if [[ "$rest" == *"|"* ]]; then
            cell="${rest%%|*}"
            rest="${rest#*|}"
        else
            cell="$rest"
            rest=""
            trim "$cell"
            ROW_CELLS+=("$TRIMMED")
            break
        fi
        trim "$cell"
        ROW_CELLS+=("$TRIMMED")
    done
}

# 種別を左端の列に取る表が、「一文長の上限」の列を持つことを表ごとに確かめる。
# ファイル単位で1つでもあれば通す形にすると、表を複数持つプロファイルで、列名が
# ずれた表に置かれた種別の登録が黙って捨てられる。
profile_validate() {
    local path="$1" line idx pending=0 found=0 seen=0
    local -a header=()
    [ -r "$path" ] || die "文書種別プロファイルを読めません: $path"
    while IFS= read -r line || [ -n "$line" ]; do
        trim "$line"
        line="$TRIMMED"
        case "$line" in
            \|*) ;;
            *)
                pending=0
                continue
                ;;
        esac
        if [[ "$line" =~ $TABLE_SEP_RE ]]; then
            if [ "$pending" -eq 1 ] && [ "${#header[@]}" -gt 0 ] && [ "${header[0]}" = "種別" ]; then
                found=0
                for idx in "${!header[@]}"; do
                    [ "${header[idx]}" = "一文長の上限" ] && found=1 && break
                done
                [ "$found" -eq 1 ] ||
                    die "文書種別プロファイルの表に「一文長の上限」の列がありません: $path"
                seen=1
            fi
            pending=0
            continue
        fi
        split_row "$line"
        header=(${ROW_CELLS[@]+"${ROW_CELLS[@]}"})
        pending=1
    done <"$path"
    [ "$seen" -eq 1 ] ||
        die "文書種別プロファイルに種別の表がありません: $path"
    return 0
}

# 表から種別の行を引き、「一文長の上限」の列の値を返す。列の位置はヘッダ行のセル名で
# 特定する。位置（最後の列）で拾うと、備考のような列を1つ足しただけで別の数値が上限
# として解決され、警告も出ないまま検査が無効化される。
PROFILE_VALUE=""
profile_lookup() {
    local path="$1" want="$2"
    PROFILE_VALUE=""

    [ -r "$path" ] || die "文書種別プロファイルを読めません: $path"

    local line col=-1 idx digits value pending=0
    local -a header=()
    while IFS= read -r line || [ -n "$line" ]; do
        trim "$line"
        line="$TRIMMED"

        case "$line" in
            \|*) ;;
            *)
                # 表の外へ出た。次の表は別の列構成を持ちうる。
                col=-1
                pending=0
                continue
                ;;
        esac

        if [[ "$line" =~ $TABLE_SEP_RE ]]; then
            # 区切り行の直前の行が見出し行である。見出しの内容だけで表を特定すると、
            # 「一文長の上限」を左端のセルに持つ別の表のデータ行を見出しと取り違える。
            if [ "$pending" -eq 1 ]; then
                col=-1
                for idx in "${!header[@]}"; do
                    if [ "${header[idx]}" = "一文長の上限" ]; then
                        col="$idx"
                        break
                    fi
                done
            fi
            pending=0
            continue
        fi

        split_row "$line"

        if [ "$col" -lt 0 ]; then
            header=(${ROW_CELLS[@]+"${ROW_CELLS[@]}"})
            pending=1
            continue
        fi

        [ "${#ROW_CELLS[@]}" -gt 0 ] || continue
        [ "${ROW_CELLS[0]}" = "$want" ] || continue
        [ "$col" -lt "${#ROW_CELLS[@]}" ] ||
            die "文書種別プロファイルの行に「一文長の上限」の列がありません: $path（種別 $want）"

        value="${ROW_CELLS[col]}"
        # 先頭の連続する数字だけを採る。非数字を落として連結すると、脚注のような記号が
        # 付いた値で桁が変わり（100[^1] が 1001 になる）、検査が黙って10倍に緩む。
        digits="${value%%[!0-9]*}"
        [ -n "$digits" ] ||
            die "文書種別プロファイルの一文長の上限に数値がありません: $path（種別 $want、値「$value」）"
        case "${value#"$digits"}" in
            *[0-9]*)
                die "文書種別プロファイルの一文長の上限に数値が2つ以上あります: $path（種別 $want、値「$value」）"
                ;;
        esac
        digits="$((10#$digits))"
        if [ "$digits" -lt "$MIN_ACCEPTED_LEN" ] || [ "$digits" -gt "$MAX_ACCEPTED_LEN" ]; then
            die "文書種別プロファイルの一文長の上限が想定の範囲を外れています: $path（種別 $want、値 $digits）"
        fi
        PROFILE_VALUE="$digits"
        return 0
    done <"$path"
    return 0
}

# インラインコードを、同じ長さの記号を含まない文字列へ置き換える。文の区切りと括弧の
# 対応はこの結果に対して数える。長さを保つのは、元の文字列との位置の対応を崩さない
# ためである。囲みを外してから数えると、句点を含むコードスパンで囲みの片側だけが
# 断片に入り、除去が働かない。
MASKED=""
mask_codespans() {
    local t="$1" out="" pre rest body filler n
    while [[ "$t" == *'`'*'`'* ]]; do
        pre="${t%%\`*}"
        rest="${t#*\`}"
        body="${rest%%\`*}"
        t="${rest#*\`}"
        n=$((${#body} + 2))
        printf -v filler '%*s' "$n" ''
        out="$out$pre${filler// /x}"
    done
    MASKED="$out$t"
}

# 表示に現れない記法の記号を落とす。インラインコードの内側は対象にしない。コードと
# して書かれた記号は読み手の画面に現れるためである。
STRIPPED=""
strip_markup() {
    local s="$1"
    # 置換のたびに角括弧と丸括弧の分だけ縮むため、いずれの繰り返しも必ず停止する。
    while [[ "$s" =~ $LINK_RE ]]; do
        s="${s/"${BASH_REMATCH[0]}"/"${BASH_REMATCH[1]}"}"
    done
    while [[ "$s" =~ $REFLINK_RE ]]; do
        s="${s/"${BASH_REMATCH[0]}"/"${BASH_REMATCH[1]}"}"
    done
    local m
    for m in "${EMPHASIS_MARKS[@]}"; do
        s="${s//"$m"/}"
    done
    # 対を成さないバッククォートはコードスパンを作らないが、記法の記号として数えない。
    s="${s//\`/}"
    STRIPPED="$s"
}

# コードスパンを畳むための記号。記法のいずれの記号とも重ならない1字を使う。
CODESPAN_TOKEN=$'\x01'

DISPLAY=""
display_text() {
    local s="$1" folded="" pre rest body
    local -a bodies=()

    # まずコードスパンを1字の記号へ畳む。畳んでから記法を解釈しないと、リンクの表示
    # テキストがインラインコードである形（角括弧の内側にコードスパンがある形）で、
    # リンク記法が断片へ割れて一致せず、アドレス全体が字数へ入る。
    while [[ "$s" == *'`'*'`'* ]]; do
        pre="${s%%\`*}"
        rest="${s#*\`}"
        body="${rest%%\`*}"
        s="${rest#*\`}"
        bodies+=("$body")
        folded="$folded$pre$CODESPAN_TOKEN"
    done
    folded="$folded$s"

    strip_markup "$folded"
    folded="$STRIPPED"

    # 畳んだ順に中身を戻す。囲みの2字だけを除き、中身はそのまま数える。
    local i result="" head
    for ((i = 0; i < ${#bodies[@]}; i++)); do
        case "$folded" in
            *"$CODESPAN_TOKEN"*) ;;
            # 残りの記号が尽きた場合、以降のコードスパンは記法の内側にあって表示へ
            # 現れない。中身も数えない。
            *) break ;;
        esac
        head="${folded%%"$CODESPAN_TOKEN"*}"
        result="$result$head${bodies[i]}"
        folded="${folded#*"$CODESPAN_TOKEN"}"
    done
    DISPLAY="$result$folded"
}

# ---- 段落の抽出 ----
#
# 検査の単位は段落である。行の切れ目で文を切ると、1つの長い文が短い文の並びとして
# 通ってしまう。コードブロック・見出し・表・引用・冒頭のメタデータ・注釈は対象から外す。
#
# 囲みの範囲は先に全行を走査して決める。開いた記号を見た時点でトグルすると、閉じない
# 記号1つで以降がファイル末尾まで黙って未検査になる。条文は「囲まれた範囲」「挟まれた
# 範囲」と定めており、閉じない開き記号は範囲を成さない。

PARA_TEXT=()
PARA_FIRST=()
PARA_LAST=()
PARA_OFFSETS=() # "<開始オフセット>:<行番号>" を空白区切りで持つ

collect_paragraphs() {
    local file="$1"
    PARA_TEXT=()
    PARA_FIRST=()
    PARA_LAST=()
    PARA_OFFSETS=()

    [ -r "$file" ] || die "検査対象を読めません: $file"

    local -a lines=()
    local line
    while IFS= read -r line || [ -n "$line" ]; do
        lines+=("$line")
    done <"$file"

    local n="${#lines[@]}"
    [ "$n" -gt 0 ] || return 0

    local -a skip=()
    local i j k
    for ((i = 0; i < n; i++)); do skip[i]=0; done

    # 冒頭のメタデータ。閉じる区切り線があるときだけ範囲を成す。
    trim "${lines[0]}"
    if [ "$TRIMMED" = "$FRONT_MATTER_MARK" ]; then
        for ((j = 1; j < n; j++)); do
            trim "${lines[j]}"
            if [ "$TRIMMED" = "$FRONT_MATTER_MARK" ]; then
                for ((k = 0; k <= j; k++)); do skip[k]=1; done
                break
            fi
        done
    fi

    # フェンスで囲まれたコードブロック。開いた記号と同じ種類で閉じたときだけ範囲を成す。
    local marker close
    i=0
    while [ "$i" -lt "$n" ]; do
        if [ "${skip[i]}" -eq 1 ]; then
            i=$((i + 1))
            continue
        fi
        trim "${lines[i]}"
        marker=""
        case "$TRIMMED" in
            '```'*) marker='```' ;;
            '~~~'*) marker='~~~' ;;
        esac
        if [ -n "$marker" ]; then
            close=-1
            for ((j = i + 1; j < n; j++)); do
                trim "${lines[j]}"
                case "$TRIMMED" in
                    "$marker"*)
                        close="$j"
                        break
                        ;;
                esac
            done
            if [ "$close" -ge 0 ]; then
                for ((k = i; k <= close; k++)); do skip[k]=1; done
                i=$((close + 1))
                continue
            fi
        fi
        i=$((i + 1))
    done

    # 縦棒で始まらない表も対象から外す。区切り行を見つけ、その直前の見出し行と、直後の
    # 連続する行のうち縦棒を含むものを表の行として扱う。縦棒で始まる表は行ごとの判定
    # （TABLE_ROW_RE）が拾うため、ここでは扱わない。
    local gfm_sep='^[[:space:]]*:?-{2,}:?[[:space:]]*(\|[[:space:]]*:?-{2,}:?[[:space:]]*)+$'
    for ((i = 0; i < n; i++)); do
        [ "${skip[i]}" -eq 1 ] && continue
        trim "${lines[i]}"
        [[ "$TRIMMED" == '|'* ]] && continue
        [[ "$TRIMMED" =~ $gfm_sep ]] || continue
        skip[i]=1
        if [ "$i" -gt 0 ] && [ "${skip[i - 1]}" -eq 0 ]; then
            trim "${lines[i - 1]}"
            [[ "$TRIMMED" == *"|"* ]] && skip[$((i - 1))]=1
        fi
        for ((j = i + 1; j < n; j++)); do
            [ "${skip[j]}" -eq 1 ] && break
            trim "${lines[j]}"
            [[ "$TRIMMED" == *"|"* ]] || break
            skip[j]=1
        done
    done

    # 除外の決まった行を空行へ落とし、以降は1つの文字列として扱う。段落の切れ目は
    # 空行が作るため、除外した行は切れ目として働く。
    local blob=""
    for ((i = 0; i < n; i++)); do
        if [ "${skip[i]}" -eq 1 ]; then
            blob="$blob"$'\n'
        else
            blob="$blob${lines[i]}"$'\n'
        fi
    done

    # 読み手の画面に現れない注釈を、行ではなく文字の範囲で落とす。行単位で落とすと、
    # 注釈と同じ行に置いた地の文が黙って未検査になり、行の途中で閉じた注釈より後ろが
    # 過大に数えられる。閉じない注釈は範囲を成さないため、そのまま残す。
    # 範囲は、行ごとにコードスパンを伏せた写しの上で決める。生の文字列で探すと、
    # インラインコードで注釈の記号に言及しただけで範囲が開き、次の `-->` までの地の文が
    # 丸ごと落ちる。伏せ字は長さを保つため、写しの位置はそのまま元の位置に対応する。
    local masked_blob="" ml
    while IFS= read -r ml; do
        mask_codespans "$ml"
        masked_blob="$masked_blob$MASKED"$'\n'
    done <<<"${blob%$'\n'}"

    local out="" rest="$blob" mrest="$masked_blob" pre body nl pre_m body_m i j
    while [[ "$mrest" == *'<!--'*'-->'* ]]; do
        pre_m="${mrest%%<!--*}"
        i="${#pre_m}"
        mrest="${mrest:i+4}"
        body_m="${mrest%%-->*}"
        j="${#body_m}"
        mrest="${mrest:j+3}"

        pre="${rest:0:i}"
        body="${rest:i+4:j}"
        rest="${rest:i+4+j+3}"
        # 落とした範囲に含まれる改行だけを残し、行番号を保つ。
        nl="${body//[!$'\n']/}"
        out="$out$pre$nl"
    done
    blob="$out$rest"

    lines=()
    while IFS= read -r line; do
        lines+=("$line")
    done <<<"${blob%$'\n'}"

    local buf="" buf_first=0 buf_last=0 buf_offsets="" buf_is_list=0 s lineno
    flush() {
        if [ -n "$buf" ]; then
            PARA_TEXT+=("$buf")
            PARA_FIRST+=("$buf_first")
            PARA_LAST+=("$buf_last")
            PARA_OFFSETS+=("$buf_offsets")
        fi
        buf=""
        buf_first=0
        buf_last=0
        buf_offsets=""
        buf_is_list=0
    }

    for ((i = 0; i < n; i++)); do
        lineno=$((i + 1))
        line="${lines[i]}"
        trim "$line"
        s="$TRIMMED"

        if [ -z "$s" ]; then
            flush
            continue
        fi

        # 字下げのコードブロック。段落の途中の行は継続行であってコードではないため、
        # 直前が段落の切れ目である場合に限る。字下げは半角4字またはタブ1字とする。
        if [ -z "$buf" ] && { [[ "$line" == '    '* ]] || [[ "$line" == $'\t'* ]]; }; then
            continue
        fi

        # 見出しは記号の後に空白が続く場合に限る。記号だけで判定すると、行頭に置いた
        # 課題番号（#684 のような形）が行ごと検査対象から外れる。
        if [[ "$s" =~ $HEADING_RE ]]; then
            flush
            continue
        fi
        # 下線形式の見出し。直前の段落の全体が見出しの内容になるため、溜めた分を捨てる。
        # 直前が箇条書きの項目である場合は適用しない。その位置の区切り線は箇条書きを
        # 閉じるものであって、項目の内容を見出しへ変えない。
        if [ -n "$buf" ] && [ "$buf_is_list" -eq 0 ] && [[ "$s" =~ $SETEXT_RE ]]; then
            buf=""
            buf_first=0
            buf_last=0
            buf_offsets=""
            continue
        fi

        if [[ "$s" =~ $TABLE_ROW_RE ]] || [[ "$s" =~ $QUOTE_ROW_RE ]]; then
            flush
            continue
        fi

        # 箇条書きと番号付きの項目は、先頭のマーカーを除いた残りを1つの段落として扱う。
        local is_list=0
        if [[ "$s" =~ $LIST_RE ]]; then
            flush
            s="${s#"${BASH_REMATCH[0]}"}"
            [ -n "$s" ] || continue
            is_list=1
        fi

        if [ -z "$buf" ]; then
            buf_is_list="$is_list"
            buf_first="$lineno"
            buf_offsets="0:$lineno"
            buf="$s"
        else
            # 英数字どうしが行の切れ目で隣り合う場合だけ空白を挟む。挟まないと別々の語が
            # 1語につながり、字数が実際より短く数えられる。
            local tail="${buf: -1}" head="${s:0:1}" sep=""
            if [[ "$tail" == [A-Za-z0-9] ]] && [[ "$head" == [A-Za-z0-9] ]]; then
                sep=" "
            fi
            buf="$buf$sep"
            buf_offsets="$buf_offsets ${#buf}:$lineno"
            buf="$buf$s"
        fi
        buf_last="$lineno"
    done

    flush
    unset -f flush
    return 0
}

# 段落内のオフセットから元の行番号を引く。
LINE_NO=0
line_for_offset() {
    local offsets="$1" off="$2"
    local pair result=""
    for pair in $offsets; do
        if [ "${pair%%:*}" -le "$off" ]; then
            result="${pair##*:}"
        else
            break
        fi
    done
    LINE_NO="${result:-0}"
}

# ---- 文への分割 ----

SENTS=()
SENT_OFF=()

split_sentences() {
    local text="$1"
    SENTS=()
    SENT_OFF=()

    mask_codespans "$text"
    local masked="$MASKED"

    local total="${#text}"
    local pos=0 acc_start=0 depth=0
    local tail best d p pre cut naked b tmp opens closes seg

    while [ "$pos" -lt "$total" ]; do
        tail="${masked:pos}"
        best=-1
        for d in "${SENT_DELIMS[@]}"; do
            case "$tail" in
                *"$d"*)
                    pre="${tail%%"$d"*}"
                    p="${#pre}"
                    ;;
                *) continue ;;
            esac
            if [ "$best" -lt 0 ] || [ "$p" -lt "$best" ]; then
                best="$p"
            fi
        done

        if [ "$best" -lt 0 ]; then
            cut="$total"
        else
            cut=$((pos + best + 1))
        fi

        naked="${masked:pos:$((cut - pos))}"
        opens=0
        closes=0
        for b in "${OPEN_BRACKETS[@]}"; do
            tmp="${naked//"$b"/}"
            opens=$((opens + ${#naked} - ${#tmp}))
        done
        for b in "${CLOSE_BRACKETS[@]}"; do
            tmp="${naked//"$b"/}"
            closes=$((closes + ${#naked} - ${#tmp}))
        done
        depth=$((depth + opens - closes))
        [ "$depth" -ge 0 ] || depth=0

        # 括弧が閉じていて、かつ区切りの記号で終わっているときだけ文を切る。
        if [ "$depth" -eq 0 ] && [ "$best" -ge 0 ]; then
            SENTS+=("${text:acc_start:$((cut - acc_start))}")
            SENT_OFF+=("$acc_start")
            acc_start="$cut"
        fi
        pos="$cut"
    done

    if [ "$acc_start" -lt "$total" ]; then
        seg="${text:acc_start}"
        trim "$seg"
        if [ -n "$TRIMMED" ]; then
            SENTS+=("$seg")
            SENT_OFF+=("$acc_start")
        fi
    fi
    return 0
}

# ---- 検出 ----

VIOLATIONS=0

report() {
    printf '%s:%s: [%s] %s\n' "$1" "$2" "$3" "$4"
    VIOLATIONS=$((VIOLATIONS + 1))
}

# 候補は終了コード1に寄与しない。確定判断を doc-reviewer が担う項目を、違反と同じ
# 終了コードへ落とすと、書き手はレビューの確定を待たずに書き換える側へ倒れる。
note() {
    printf '%s:%s: [候補: %s] %s\n' "$1" "$2" "$3" "$4"
}

excerpt() {
    local s="$1"
    if [ "${#s}" -gt 40 ]; then
        printf '%s…' "${s:0:40}"
    else
        printf '%s' "$s"
    fi
}

check_length() {
    local file="$1" line="$2" sentence="$3"
    local n
    display_text "$sentence"
    n="${#DISPLAY}"
    if [ "$n" -gt "$MAX_LEN" ]; then
        report "$file" "$line" "一文の長さ" \
            "${n}字（上限 ${MAX_LEN}字）: $(excerpt "$DISPLAY")"
    fi
    return 0
}

# 第2条。インラインコードで囲まれた識別子も対象に含める。囲みを外してから骨格位置を
# 見ることで、識別子と後続の助詞の間にバッククォートが挟まる形でも取り逃さない。
# 同じ識別子が1文に2度現れる形に備え、走査した分を消費しながら左から順に進める。
check_identifiers() {
    local file="$1" line="$2" sentence="$3"
    local naked rest id after
    naked="${sentence//\`/}"
    rest="$naked"
    while [[ "$rest" =~ $ID_RE ]]; do
        id="${BASH_REMATCH[1]}"
        rest="${rest#*"$id"}"
        after="$rest"
        after="${after#"${after%%[![:space:]]*}"}"
        # 骨格位置（主語・目的語）にあるものだけを挙げる。
        local particle
        for particle in "${SKELETON_PARTICLES[@]}"; do
            case "$after" in
                "$particle"*)
                    note "$file" "$line" "不透明な識別子" \
                        "$id が骨格位置にある。参照先を開かずに読めるかを確認: $(excerpt "$sentence")"
                    break
                    ;;
            esac
        done
    done
    return 0
}

# ---- ファイル単位の検査 ----

# 行の範囲が検査対象と交差するかを見る。
range_in_scope() {
    local from="$1" to="$2" scope="$3" ln
    [ "$scope" = "$SCOPE_ALL" ] && return 0
    for ((ln = from; ln <= to; ln++)); do
        case " $scope " in
            *" $ln "*) return 0 ;;
        esac
    done
    return 1
}

check_file() {
    # file は報告に用いる名前、source は実際に読むパス、scope は検査対象の
    # 行番号の集合（SCOPE_ALL なら全行）。差分モードでは報告名がリポジトリ相対、
    # 読み取りパスが絶対になるため、両者を分けて受け取る。
    local file="$1" source="$2" scope="$3"
    local i n_para

    collect_paragraphs "$source"
    n_para="${#PARA_TEXT[@]}"
    [ "$n_para" -gt 0 ] || return 0

    for ((i = 0; i < n_para; i++)); do
        # 段落が検査範囲とまったく交差しなければ、文へ分ける手前で飛ばす。
        if ! range_in_scope "${PARA_FIRST[i]}" "${PARA_LAST[i]}" "$scope"; then
            continue
        fi

        split_sentences "${PARA_TEXT[i]}"
        local j n_sent="${#SENTS[@]}"
        for ((j = 0; j < n_sent; j++)); do
            local sentence="${SENTS[j]}" start_line end_line end_off

            line_for_offset "${PARA_OFFSETS[i]}" "${SENT_OFF[j]}"
            start_line="$LINE_NO"
            end_off=$((SENT_OFF[j] + ${#sentence}))
            [ "$end_off" -le "${SENT_OFF[j]}" ] && end_off=$((SENT_OFF[j] + 1))
            line_for_offset "${PARA_OFFSETS[i]}" "$((end_off - 1))"
            end_line="$LINE_NO"

            # 判定の単位は文である。段落を単位にすると、同じ段落にある触れていない文の
            # 既存の違反まで赤くなり、既定を差分にした理由（既存文書を1行直しただけで
            # 既存の違反が赤になることを避ける）が段落の内側で崩れる。
            if ! range_in_scope "$start_line" "$end_line" "$scope"; then
                continue
            fi

            check_length "$file" "$start_line" "$sentence"
            check_identifiers "$file" "$start_line" "$sentence"
        done
    done
    return 0
}

# ---- 差分の解決 ----

# 既定の入力単位が差分なのは、規約の適用範囲が新規起草物と編集で触れた箇所に限られる
# ためである。ファイル全体を既定にすると、既存文書を1行直しただけで既存の違反が赤になる。
declare -A CHANGED_LINES=()
declare -A RENAME_SRC=()
BASE_COMMIT=""

# ファイルの列挙とハンクの取得を分ける。差分本文の `+++` 行からファイル名を読むと、
# diff.noprefix ・ diff.mnemonicPrefix の設定下で接頭辞が変わり、非 ASCII のファイル名は
# core.quotePath により引用されるため、いずれの場合も対象を見失ったまま成功を返す。
collect_changed_lines() {
    [ -n "$REPO_ROOT" ] ||
        die "git リポジトリの中ではありません（ファイル全体を検査するには --all を指定してください）"

    # commit を指しているかまで確かめる。実在の確認だけでは、blob や tree を渡された
    # ときに後段の git diff が使い方の誤りで落ち、その失敗が握り潰されて全件0になる。
    local resolved
    resolved="$(git rev-parse --verify --quiet "${DIFF_BASE}^{commit}" 2>/dev/null)" ||
        die "差分の基点を commit として解決できません: $DIFF_BASE"

    if [ "$TWO_DOT" -eq 1 ]; then
        BASE_COMMIT="$resolved"
    else
        # 分岐点を採る。2点間差分にすると、基点のブランチが進んだ時点で、このブランチが
        # 触れていないファイルまで報告される。規約の適用範囲は編集で触れた箇所である。
        # 分岐点が求まらない場合（履歴を共有しない基点・浅いクローン）は黙って2点間へ
        # 落とさず止める。落とすと、触れていないファイルが警告なしに報告される。
        BASE_COMMIT="$(git merge-base "$resolved" HEAD 2>/dev/null)" ||
            die "分岐点を解決できません: $DIFF_BASE（履歴を共有しないか、浅いクローンです。2点間差分を採るなら --two-dot を指定してください）"
        [ -n "$BASE_COMMIT" ] ||
            die "分岐点を解決できません: $DIFF_BASE（履歴を共有しないか、浅いクローンです。2点間差分を採るなら --two-dot を指定してください）"
    fi

    local f st old_path
    local -a tracked=() untracked=()

    # 改名は、変更前後の両方をパススペックへ渡さないと git が改名の対として扱えず、
    # 全行が追加行に見える。名前の対をここで captured しておき、ハンクの取得へ渡す。
    while IFS= read -r -d '' st; do
        case "$st" in
            R* | C*)
                IFS= read -r -d '' old_path || break
                IFS= read -r -d '' f || break
                RENAME_SRC["$f"]="$old_path"
                ;;
            D*)
                IFS= read -r -d '' f || break
                continue
                ;;
            *)
                IFS= read -r -d '' f || break
                ;;
        esac
        [ -n "$f" ] && tracked+=("$f")
    # 列挙はパススペックで絞らない。git はパススペックで差分を絞ってから改名を検出する
    # ため、新しい名前だけを渡すと改名の対を作れず、全行が追加行に見える。絞り込みは
    # 列挙した結果に対して行う。
    done < <(git -C "$REPO_ROOT" -c core.quotePath=false diff --name-status -z -M \
        "$BASE_COMMIT" 2>/dev/null)

    # 未追跡のファイルも対象に含める。規約の適用範囲の筆頭は新しく起草する文書であり、
    # 追跡される前が最も検査したい時点である。列挙はリポジトリのルートから行う。
    # 作業ディレクトリから行うと、その配下だけが対象になり追跡分と射程が揃わない。
    while IFS= read -r -d '' f; do
        [ -n "$f" ] && untracked+=("$f")
    done < <(git -C "$REPO_ROOT" -c core.quotePath=false ls-files --others --exclude-standard \
        --full-name -z 2>/dev/null)

    for f in ${tracked[@]+"${tracked[@]}"}; do
        case "$f" in *.md) ;; *) continue ;; esac
        path_wanted "$f" || continue
        hunk_lines "$f"
        case "$?" in
            0) ;;
            1) die "差分を取得できません: $f" ;;
            2) die "差分をテキストとして取得できません: $f（-diff 属性が設定されている可能性があります）" ;;
        esac
        # 追加行がゼロの差分（純削除・改名・属性変更）は、触れた文が無いことを意味する。
        # ここで全行検査へ落とすと、触れていない文の既存の違反が赤くなる。取得の失敗と
        # 区別するため、失敗は上の分岐で止めてある。
        [ -n "$HUNK_ACC" ] || continue
        CHANGED_LINES["$f"]="$HUNK_ACC"
    done
    for f in ${untracked[@]+"${untracked[@]}"}; do
        case "$f" in *.md) ;; *) continue ;; esac
        path_wanted "$f" || continue
        CHANGED_LINES["$f"]="$SCOPE_ALL"
    done
    return 0
}

# 1ファイル分のハンクから、変更後の行番号を取り出す。結果は HUNK_ACC へ書く。
# 戻り値は 0（取得できた）／1（git が失敗した）／2（テキストとして取得できない）。
# 取得の失敗を「追加行がゼロ」と同じ扱いにすると、検査していないことが違反なしと
# 区別できなくなる。
HUNK_ACC=""
hunk_lines() {
    local f="$1" out rc line spec start count k acc=""
    local -a pathspec=(":(top,literal)$f")
    # 改名は変更前後の両方を渡さないと対として扱われず、全行が追加行に見える。
    [ -n "${RENAME_SRC[$f]:-}" ] && pathspec+=(":(top,literal)${RENAME_SRC[$f]}")

    HUNK_ACC=""
    # テキストとして差分を取れるかは numstat で見る。差分の本文に「Binary files 」と
    # いう語が現れるだけで止めると、その語を含む文書が偽の原因で弾かれる。
    local ns
    ns="$(git -C "$REPO_ROOT" diff --numstat -M "$BASE_COMMIT" -- "${pathspec[@]}" 2>/dev/null)" ||
        return 1
    case "$ns" in
        "-"$'\t'"-"*) return 2 ;;
    esac

    out="$(git -C "$REPO_ROOT" diff --unified=0 --no-color -M "$BASE_COMMIT" \
        -- "${pathspec[@]}" 2>/dev/null)"
    rc="$?"
    [ "$rc" -eq 0 ] || return 1

    while IFS= read -r line; do
        case "$line" in
            '@@'*)
                # @@ -a,b +c,d @@ の +c,d を取る
                spec="${line#*+}"
                spec="${spec%% *}"
                start="${spec%%,*}"
                if [ "$spec" = "$start" ]; then
                    count=1
                else
                    count="${spec#*,}"
                fi
                [ "$count" -gt 0 ] || continue
                for ((k = 0; k < count; k++)); do
                    acc="$acc $((start + k))"
                done
                ;;
        esac
    done <<<"$out"
    HUNK_ACC="$acc"
    return 0
}

# ---- 主処理 ----

# 対象は Markdown に限る。明示的に渡されたファイルが Markdown でなければ、黙って
# 飛ばさずに止める。飛ばすと、検査していないことが違反なしと区別できない。
assert_markdown() {
    case "$1" in
        *.md) ;;
        *) die "Markdown ではありません: $1" ;;
    esac
}

resolve_max_len

if [ "$SCAN_ALL" -eq 1 ]; then
    [ "${#PATHS[@]}" -gt 0 ] ||
        die "--all にはパスの指定が必要です。既存文書の一括是正は規約の範囲外であり、対象を明示させます"
    for p in "${PATHS[@]}"; do
        [ -f "$p" ] || die "ファイルが見つかりません: $p"
        assert_markdown "$p"
        check_file "$p" "$p" "$SCOPE_ALL"
    done
else
    # 一致するものが無いパスは、検査していないことを違反なしと区別できないため弾く。
    # あわせて、git へ渡すパススペックをリポジトリのルート相対へ揃える。存在確認だけを
    # 作業ディレクトリ相対で行うと、同じ相対パスが2つの意味を持ち、サブディレクトリから
    # 名指ししたファイルが黙って未検査になったり、同名の別ファイルが検査されたりする。
    WANT_PATHS=()
    for p in ${PATHS[@]+"${PATHS[@]}"}; do
        [ -e "$p" ] || die "パスが見つかりません: $p"
        # ディレクトリは配下の全体を指す。ファイルを名指ししたときだけ拡張子を見る。
        [ -f "$p" ] && assert_markdown "$p"
        to_repo_relative "$p"
        WANT_PATHS+=("$REPO_RELATIVE")
    done
    collect_changed_lines
    if [ "${#CHANGED_LINES[@]}" -gt 0 ]; then
        for f in "${!CHANGED_LINES[@]}"; do
            target="$REPO_ROOT/$f"
            [ -f "$target" ] || continue
            check_file "$f" "$target" "${CHANGED_LINES[$f]}"
        done
    fi
fi

[ "$VIOLATIONS" -eq 0 ] || exit 1
exit 0
