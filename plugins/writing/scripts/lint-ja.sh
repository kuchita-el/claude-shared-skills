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
# 使い方:
#   bash lint-ja.sh [パス...]           変更のあった箇所だけを検査する（既定）
#   bash lint-ja.sh --all パス...        ファイル全体を検査する
#
# オプション:
#   --type <種別>       文書種別。プロファイルの行を選ぶ（既定: 汎用）
#   --profile <パス>    文書種別プロファイル（既定: プロジェクト固有 → 同梱の既定）
#   --base <ref>        差分の基点（既定: HEAD）
#   --all               ファイル全体を検査する。パスの指定が必須
#
# exit code:
#   0: 違反なし（候補だけが出た場合を含む）
#   1: 違反あり
#   2: 入力が不正（ファイル不在・パスの指定漏れ・プロファイルの解決失敗・git の解決失敗）

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

# 正規表現は変数へ入れてから [[ =~ ]] へ渡す。角括弧を退避した形を直接書くと、
# bash は退避を解いた文字列として扱わず、一致しないまま静かに素通りする。
LINK_RE='\[([^]]*)\]\([^)]*\)'
TABLE_SEP_RE='^\|[-:|[:space:]]*$'
HEADING_RE='^#{1,6}([[:space:]]|$)'
LIST_RE='^([-*+][[:space:]]+|[0-9]+\.[[:space:]]+)'
ID_RE='(ADR-[0-9]{8,12}-[0-9]+|#[0-9]+)'

usage() {
    cat <<'USAGE'
usage: bash lint-ja.sh [オプション] [パス...]

  引数なし    変更のあった箇所だけを検査する（既定）
  --all       ファイル全体を検査する。パスの指定が必須

オプション:
  --type <種別>       文書種別。プロファイルの行を選ぶ（既定: 汎用）
  --profile <パス>    文書種別プロファイル（既定: プロジェクト固有 → 同梱の既定）
  --base <ref>        差分の基点（既定: HEAD）

exit code:
  0 違反なし / 1 違反あり / 2 入力が不正
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
        chain+=("$PROFILE_PATH")
    else
        local project_profile="${CLAUDE_PROJECT_DIR:-.}/.claude/writing/type-profiles.md"
        [ -f "$project_profile" ] && chain+=("$project_profile")
    fi
    [ -f "$DEFAULT_PROFILE" ] && chain+=("$DEFAULT_PROFILE")

    local path want
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

# 表から種別の行を引き、「一文長の上限」の列の値を返す。列の位置はヘッダ行のセル名で
# 特定する。位置（最後の列）で拾うと、備考のような列を1つ足しただけで別の数値が上限
# として解決され、警告も出ないまま検査が無効化される。
PROFILE_VALUE=""
profile_lookup() {
    local path="$1" want="$2"
    PROFILE_VALUE=""

    local line col=-1 idx digits value pending=0
    local -a header=()
    while IFS= read -r line; do
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
        digits="${value//[^0-9]/}"
        [ -n "$digits" ] ||
            die "文書種別プロファイルの一文長の上限に数値がありません: $path（種別 $want、値「$value」）"
        # 先頭の 0 を落として10進として解釈する
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

# 表示に現れない記法の記号を落とす。字数はこの結果に対して数える。
DISPLAY=""
display_text() {
    local s="$1"
    # リンク記法は表示テキストだけを残す。置換のたびに角括弧と丸括弧の分だけ縮むため
    # 必ず停止する。
    while [[ "$s" =~ $LINK_RE ]]; do
        s="${s/"${BASH_REMATCH[0]}"/"${BASH_REMATCH[1]}"}"
    done
    s="${s//\`/}"
    s="${s//\*\*/}"
    s="${s//__/}"
    DISPLAY="$s"
}

# ---- 段落の抽出 ----
#
# 検査の単位は段落である。行の切れ目で文を切ると、1つの長い文が短い文の並びとして
# 通ってしまう。コードブロック・見出し・表・引用・文書冒頭のメタデータは対象から外す。

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

    local buf="" buf_first=0 buf_last=0 buf_offsets=""
    local in_fence=0 in_front=0 lineno=0 line s

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
    }

    while IFS= read -r line || [ -n "$line" ]; do
        lineno=$((lineno + 1))
        trim "$line"
        s="$TRIMMED"

        if [ "$lineno" -eq 1 ] && [ "$s" = "---" ]; then
            in_front=1
            continue
        fi
        if [ "$in_front" -eq 1 ]; then
            [ "$s" = "---" ] && in_front=0
            continue
        fi

        case "$s" in
            '```'* | '~~~'*)
                in_fence=$((1 - in_fence))
                flush
                continue
                ;;
        esac
        [ "$in_fence" -eq 0 ] || continue

        if [ -z "$s" ]; then
            flush
            continue
        fi

        # 4字下げのコードブロック。段落の途中の行は継続行であってコードではないため、
        # 直前が空行など段落の切れ目である場合に限る。
        if [ -z "$buf" ] && [[ "$line" == '    '* ]]; then
            continue
        fi

        # 見出しは記号の後に空白が続く場合に限る。記号だけで判定すると、行頭に置いた
        # 課題番号（#684 のような形）が行ごと検査対象から外れる。
        if [[ "$s" =~ $HEADING_RE ]]; then
            flush
            continue
        fi
        case "$s" in
            \|* | '>'*)
                flush
                continue
                ;;
        esac

        # 箇条書きと番号付きの項目は、先頭のマーカーを除いた残りを1つの段落として扱う。
        if [[ "$s" =~ $LIST_RE ]]; then
            flush
            s="${s#"${BASH_REMATCH[0]}"}"
            [ -n "$s" ] || continue
        fi

        if [ -z "$buf" ]; then
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
    done <"$file"

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
#
# 句点・疑問符・感嘆符で切る。ただし括弧の内側の区切りでは切らない。インラインコードの
# 内側の記号は区切りにも括弧の数え上げにも使わない。括弧の対応が段落の終わりまでに
# 閉じない場合は、段落の終わりで打ち切る。

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
CANDIDATES=0

report() {
    printf '%s:%s: [%s] %s\n' "$1" "$2" "$3" "$4"
    VIOLATIONS=$((VIOLATIONS + 1))
}

# 候補は終了コード1に寄与しない。確定判断を doc-reviewer が担う項目を、違反と同じ
# 終了コードへ落とすと、書き手はレビューの確定を待たずに書き換える側へ倒れる。
note() {
    printf '%s:%s: [候補: %s] %s\n' "$1" "$2" "$3" "$4"
    CANDIDATES=$((CANDIDATES + 1))
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
        case "$after" in
            'は'* | 'が'* | 'を'*)
                note "$file" "$line" "不透明な識別子" \
                    "$id が骨格位置にある。参照先を開かずに読めるかを確認: $(excerpt "$sentence")"
                ;;
        esac
    done
    return 0
}

# ---- ファイル単位の検査 ----

# 行の範囲が検査対象と交差するかを見る。
range_in_scope() {
    local from="$1" to="$2" scope="$3" ln
    for ((ln = from; ln <= to; ln++)); do
        case " $scope " in
            *" $ln "*) return 0 ;;
        esac
    done
    return 1
}

check_file() {
    # file は報告に用いる名前、source は実際に読むパス、scope は検査対象の
    # 行番号の集合（空なら全行）。差分モードでは報告名がリポジトリ相対、
    # 読み取りパスが絶対になるため、両者を分けて受け取る。
    local file="$1" source="$2" scope="$3"
    local i n_para

    collect_paragraphs "$source"
    n_para="${#PARA_TEXT[@]}"
    [ "$n_para" -gt 0 ] || return 0

    for ((i = 0; i < n_para; i++)); do
        # 段落が検査範囲とまったく交差しなければ、文へ分ける手前で飛ばす。
        if [ -n "$scope" ] && ! range_in_scope "${PARA_FIRST[i]}" "${PARA_LAST[i]}" "$scope"; then
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
            if [ -n "$scope" ] && ! range_in_scope "$start_line" "$end_line" "$scope"; then
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
REPO_ROOT=""

# ファイルの列挙とハンクの取得を分ける。差分本文の `+++` 行からファイル名を読むと、
# diff.noprefix ・ diff.mnemonicPrefix の設定下で接頭辞が変わり、非 ASCII のファイル名は
# core.quotePath により引用されるため、いずれの場合も対象を見失ったまま成功を返す。
collect_changed_lines() {
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" ||
        die "git リポジトリの中ではありません（ファイル全体を検査するには --all を指定してください）"
    git rev-parse --verify --quiet "$DIFF_BASE" >/dev/null ||
        die "差分の基点を解決できません: $DIFF_BASE"

    local f
    local -a tracked=() untracked=()

    while IFS= read -r -d '' f; do
        [ -n "$f" ] && tracked+=("$f")
    done < <(git -c core.quotePath=false diff --name-only -z --diff-filter=d \
        "$DIFF_BASE" -- ${PATHS[@]+"${PATHS[@]}"} 2>/dev/null)

    # 未追跡のファイルも対象に含める。規約の適用範囲の筆頭は新しく起草する文書であり、
    # 追跡される前が最も検査したい時点である。
    while IFS= read -r -d '' f; do
        [ -n "$f" ] && untracked+=("$f")
    done < <(git -c core.quotePath=false ls-files --others --exclude-standard --full-name -z \
        -- ${PATHS[@]+"${PATHS[@]}"} 2>/dev/null)

    for f in ${tracked[@]+"${tracked[@]}"}; do
        case "$f" in *.md) ;; *) continue ;; esac
        CHANGED_LINES["$f"]="$(hunk_lines "$f")"
    done
    # 未追跡のファイルは全体が新しいため、行を絞らず全体を検査する。
    for f in ${untracked[@]+"${untracked[@]}"}; do
        case "$f" in *.md) ;; *) continue ;; esac
        CHANGED_LINES["$f"]=""
    done
    return 0
}

# 1ファイル分のハンクから、変更後の行番号を取り出す。
hunk_lines() {
    local f="$1" line spec start count k acc=""
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
    done < <(git -C "$REPO_ROOT" diff --unified=0 --no-color "$DIFF_BASE" \
        -- ":(top,literal)$f" 2>/dev/null)
    printf '%s' "$acc"
}

# ---- 主処理 ----

resolve_max_len

if [ "$SCAN_ALL" -eq 1 ]; then
    [ "${#PATHS[@]}" -gt 0 ] ||
        die "--all にはパスの指定が必要です。既存文書の一括是正は規約の範囲外であり、対象を明示させます"
    for p in "${PATHS[@]}"; do
        [ -f "$p" ] || die "ファイルが見つかりません: $p"
        # 対象は Markdown に限る。差分モードと同じ境界を保つ。黙って飛ばすと、
        # 明示的に渡したファイルが検査されないまま成功を返す。
        case "$p" in
            *.md) ;;
            *) die "Markdown ではありません: $p" ;;
        esac
        check_file "$p" "$p" ""
    done
else
    # 一致するものが無いパスは、検査していないことを違反なしと区別できないため弾く。
    for p in ${PATHS[@]+"${PATHS[@]}"}; do
        [ -e "$p" ] || die "パスが見つかりません: $p"
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
