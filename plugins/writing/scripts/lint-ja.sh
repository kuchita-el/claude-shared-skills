#!/usr/bin/env bash
# 日本語文書の機械検査。共通規約 references/japanese-writing.md の3項目を検出する。
#
#   一文の長さ超過          第5条の補則。閾値は文書種別プロファイルが優先する
#   未接地語                第1条。対象の字種は英語トークンとカタカナ語に限る
#   説明を伴わない不透明な識別子  第2条。骨格位置にある識別子で説明句が無いもの
#
# 本検査は候補を出すところまでを担う。参照の解決可能性の確定判断は doc-reviewer が行う。
# 連体修飾で意味が通っている文は括弧注を探す検査では拾えず、誤検出になるためである。
#
# 漢字の複合語は対象にしない。本スクリプトは形態素解析を持たず、漢字の連なりを素朴に
# 切ると1文書あたり数百件の候補が出て、確定を担う doc-reviewer の負荷に乗るためである。
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
#   --allowlist <パス>  許可リストのディレクトリ（既定: 同梱の allowlist/）
#   --base <ref>        差分の基点（既定: HEAD）
#   --all               ファイル全体を検査する。パスの指定が必須
#
# exit code:
#   0: 検出なし
#   1: 検出あり
#   2: 入力が不正（ファイル不在・パスの指定漏れ・git の解決失敗など）

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
DEFAULT_ALLOWLIST="$SCRIPT_DIR/allowlist"

# 共通規約の第5条の補則が定める既定値。プロファイルを解決できない場合はこれで動く。
FALLBACK_MAX_LEN=100

# カタカナの字種。範囲指定（ァ-ヴ）はロケールの照合順序に依存し C.UTF-8 では
# 「Invalid collation character」で落ちるため、文字を明示して列挙する。
# 中黒を含めないことで、中黒で区切られた並列は区切りごとに切り出される。
KATAKANA='ァアィイゥウェエォオカガキギクグケゲコゴサザシジスズセゼソゾタダチヂッツヅテデトドナニヌネノハバパヒビピフブプヘベペホボポマミムメモャヤュユョヨラリルレロヮワヰヱヲンヴーヷヸヹヺヽヾ'

OPEN_BRACKETS=('（' '「' '『' '【' '［' '(' '[')
CLOSE_BRACKETS=('）' '」' '』' '】' '］' ')' ']')

usage() {
    cat <<'USAGE'
usage: bash lint-ja.sh [オプション] [パス...]

  引数なし    変更のあった箇所だけを検査する（既定）
  --all       ファイル全体を検査する。パスの指定が必須

オプション:
  --type <種別>       文書種別。プロファイルの行を選ぶ（既定: 汎用）
  --profile <パス>    文書種別プロファイル（既定: プロジェクト固有 → 同梱の既定）
  --allowlist <パス>  許可リストのディレクトリ（既定: 同梱の allowlist/）
  --base <ref>        差分の基点（既定: HEAD）

exit code:
  0 検出なし / 1 検出あり / 2 入力が不正
USAGE
}

die() {
    echo "lint-ja: $1" >&2
    exit "${2:-2}"
}

# ---- 引数解析 ----

DOC_TYPE="汎用"
PROFILE_PATH=""
ALLOWLIST_DIR=""
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
        --allowlist)
            [ "$#" -ge 2 ] || die "--allowlist に値がありません"
            ALLOWLIST_DIR="$2"
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

# ---- 文書種別プロファイル ----

# 一文長の上限を解決する。プロファイルは種別を行、値を列に取る表であり、
# 一文長の上限は最後の列に置かれる。該当する種別の行が無ければ汎用の行へ、
# 汎用の行も無ければ共通規約の補則が定める既定値へ落とす。
resolve_max_len() {
    local path="$PROFILE_PATH"

    if [ -z "$path" ]; then
        local project_root="${CLAUDE_PROJECT_DIR:-.}"
        local project_profile="$project_root/.claude/writing/type-profiles.md"
        if [ -f "$project_profile" ]; then
            path="$project_profile"
        elif [ -f "$DEFAULT_PROFILE" ]; then
            path="$DEFAULT_PROFILE"
        fi
    fi

    if [ -z "$path" ] || [ ! -f "$path" ]; then
        MAX_LEN="$FALLBACK_MAX_LEN"
        return 0
    fi

    local value
    value="$(profile_lookup "$path" "$DOC_TYPE")"
    if [ -z "$value" ] && [ "$DOC_TYPE" != "汎用" ]; then
        value="$(profile_lookup "$path" "汎用")"
    fi

    if [ -n "$value" ]; then
        MAX_LEN="$value"
    else
        MAX_LEN="$FALLBACK_MAX_LEN"
    fi
    return 0
}

# 表から種別の行を引き、最後の列に含まれる数値を返す。
profile_lookup() {
    local path="$1" want="$2"
    local line first last digits
    while IFS= read -r line; do
        case "$line" in
            \|*) ;;
            *) continue ;;
        esac
        # 区切り行（|---|---|）は読み飛ばす
        case "$line" in
            *---*) continue ;;
        esac
        line="${line#|}"
        line="${line%|}"
        first="${line%%|*}"
        first="$(trim "$first")"
        [ "$first" = "$want" ] || continue
        last="${line##*|}"
        digits="$(printf '%s' "$last" | tr -cd '0-9')"
        if [ -n "$digits" ]; then
            printf '%s' "$digits"
            return 0
        fi
    done <"$path"
    return 0
}

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# ---- 許可リスト ----

declare -A ALLOW_EN=()
declare -A ALLOW_KA=()

load_allowlist() {
    local dir="${ALLOWLIST_DIR:-$DEFAULT_ALLOWLIST}"
    [ -d "$dir" ] || return 0

    local f line
    local prev_nullglob
    prev_nullglob="$(shopt -p nullglob || true)"
    shopt -s nullglob
    local files=("$dir"/*.txt)
    eval "$prev_nullglob"

    for f in ${files[@]+"${files[@]}"}; do
        while IFS= read -r line || [ -n "$line" ]; do
            line="$(trim "$line")"
            [ -n "$line" ] || continue
            case "$line" in \#*) continue ;; esac
            # 英語トークンは大文字小文字を区別せず照合する。
            if [[ "$line" =~ ^[A-Za-z0-9._-]+$ ]]; then
                ALLOW_EN["${line,,}"]=1
            else
                ALLOW_KA["$line"]=1
            fi
        done <"$f"
    done
    return 0
}

# ---- 文字列の操作 ----

# インラインコードを囲みごと取り除く。第1条の検査と括弧の数え上げで使う。
strip_codespans() {
    local t="$1" pre rest post
    while [[ "$t" == *'`'*'`'* ]]; do
        pre="${t%%\`*}"
        rest="${t#*\`}"
        post="${rest#*\`}"
        t="$pre$post"
    done
    printf '%s' "$t"
}

# 表示に現れない記法の記号を落とす。字数はこの結果に対して数える。
display_text() {
    local s="$1"
    # リンク記法は表示テキストだけを残す
    while [[ "$s" =~ \[([^]]*)\]\([^\)]*\) ]]; do
        s="${s/"${BASH_REMATCH[0]}"/"${BASH_REMATCH[1]}"}"
    done
    s="${s//\`/}"
    s="${s//\*\*/}"
    s="${s//__/}"
    printf '%s' "$s"
}

count_char() {
    local t="$1" c="$2" stripped
    stripped="${t//"$c"/}"
    printf '%s' "$(((${#t} - ${#stripped})))"
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
        s="$(trim "$line")"

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
        case "$s" in
            \#* | \|* | '>'*)
                flush
                continue
                ;;
        esac

        # 箇条書きと番号付きの項目は、先頭のマーカーを除いた残りを1つの段落として扱う。
        if [[ "$s" =~ ^([-*+][[:space:]]+|[0-9]+\.[[:space:]]+) ]]; then
            flush
            s="${s#"${BASH_REMATCH[0]}"}"
            [ -n "$s" ] || continue
        fi

        if [ -z "$buf" ]; then
            buf_first="$lineno"
            buf_offsets="0:$lineno"
            buf="$s"
        else
            # 両端が ASCII なら空白を1つ挟む。日本語同士は直結する。
            # 英数字どうしが行の切れ目で隣り合う場合だけ空白を挟む。挟まないと
            # 別々の語が1語につながり、第1条の検査が実在しない語を拾う。
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
    printf '%s' "${result:-0}"
}

# ---- 文への分割 ----
#
# 句点で切る。ただし括弧の内側の句点では切らない。インラインコードの中身は括弧の
# 数え上げから外す。括弧の対応が段落の終わりまでに閉じない場合は、段落の終わりで打ち切る。

SENTS=()
SENT_OFF=()

split_sentences() {
    local text="$1"
    SENTS=()
    SENT_OFF=()

    local rest="$text" acc="" acc_off=0 consumed=0
    local seg depth=0 opens closes b

    while [ -n "$rest" ]; do
        if [[ "$rest" == *"。"* ]]; then
            seg="${rest%%。*}。"
            rest="${rest#"$seg"}"
        else
            seg="$rest"
            rest=""
        fi

        local naked
        naked="$(strip_codespans "$seg")"
        opens=0
        closes=0
        for b in "${OPEN_BRACKETS[@]}"; do
            opens=$((opens + $(count_char "$naked" "$b")))
        done
        for b in "${CLOSE_BRACKETS[@]}"; do
            closes=$((closes + $(count_char "$naked" "$b")))
        done
        depth=$((depth + opens - closes))
        [ "$depth" -ge 0 ] || depth=0

        [ -n "$acc" ] || acc_off="$consumed"
        acc="$acc$seg"
        consumed=$((consumed + ${#seg}))

        # 括弧が閉じていて、かつ句点で終わっているときだけ文を切る。
        if [ "$depth" -eq 0 ] && [ "${seg: -1}" = "。" ]; then
            SENTS+=("$acc")
            SENT_OFF+=("$acc_off")
            acc=""
        fi
    done

    if [ -n "$(trim "$acc")" ]; then
        SENTS+=("$acc")
        SENT_OFF+=("$acc_off")
    fi
    return 0
}

# ---- 検出 ----

VIOLATIONS=0

report() {
    printf '%s:%s: [%s] %s\n' "$1" "$2" "$3" "$4"
    VIOLATIONS=$((VIOLATIONS + 1))
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
    local shown n
    shown="$(display_text "$sentence")"
    n="${#shown}"
    if [ "$n" -gt "$MAX_LEN" ]; then
        report "$file" "$line" "一文の長さ" \
            "${n}字（上限 ${MAX_LEN}字）: $(excerpt "$shown")"
    fi
    return 0
}

# 第1条。インラインコードは識別子として扱い、この検査の対象から外す。
scan_ungrounded_tokens() {
    local sentence="$1"
    local naked
    naked="$(strip_codespans "$sentence")"
    printf '%s\n' "$naked" | grep -oE "[A-Za-z][A-Za-z]+" 2>/dev/null
    printf '%s\n' "$naked" | grep -oE "[$KATAKANA][$KATAKANA]+" 2>/dev/null
    return 0
}

# 語の近傍に定義または言い換えがあるかを見る。語が括弧注の中に置かれている形
# （「保持期間（retention）」）と、語の直後に定義が続く形の双方を許す。
is_grounded() {
    local sentence="$1" token="$2"
    local naked prefix pos before after
    naked="$(strip_codespans "$sentence")"
    case "$naked" in
        *"$token"*) ;;
        *) return 0 ;;
    esac
    prefix="${naked%%"$token"*}"
    pos="${#prefix}"

    # 語が括弧注の内側にあるかを見る。直前の語に続けて開く括弧は言い換えとみなし、
    # その内側の語をすべて免除する。開き括弧の直後の1語だけを免除すると、
    # 「強調の記号（アスタリスクとアンダースコア）」のように言い換えが2語以上並ぶ形で
    # 2語目以降だけが候補になり、同じ括弧注の中で判定が割れる。
    # 数えるのは丸括弧だけとする。鉤括弧は語を引用するための記号であって言い換えの
    # 括弧ではない。含めると、引用しただけの語まで免除される。
    local depth=0 i ch open_pos=-1
    for ((i = 0; i < pos; i++)); do
        ch="${naked:i:1}"
        case "$ch" in
            '（' | '(')
                depth=$((depth + 1))
                open_pos="$i"
                ;;
            '）' | ')')
                [ "$depth" -le 0 ] || depth=$((depth - 1))
                ;;
        esac
    done
    if [ "$depth" -gt 0 ] && [ "$open_pos" -ge 1 ]; then
        before="${naked:$((open_pos - 1)):1}"
        # 文の切れ目に続く括弧は、直前の語の言い換えではなく独立した挿入である。
        case "$before" in
            '。' | '、' | ' ' | '　') ;;
            *) return 0 ;;
        esac
    fi

    after="${naked:$((pos + ${#token}))}"
    # 引用符で囲んだ語に括弧注を続ける形（「ゲート」（通過を止める関門））では、語と
    # 括弧の間に閉じ引用符が挟まる。閉じ側の記号を読み飛ばしてから定義表現を探す。
    while true; do
        case "$after" in
            '」'* | '』'* | '】'* | '］'* | ' '*) after="${after:1}" ;;
            *) break ;;
        esac
    done
    case "$after" in
        '（'* | '('* | 'とは'* | '＝'* | '='*) return 0 ;;
    esac
    return 1
}

# 第2条。インラインコードで囲まれた識別子も対象に含める。囲みを外してから
# 説明句を探すことで、識別子と括弧注の間にバッククォートが挟まる形でも取り逃さない。
check_identifiers() {
    local file="$1" line="$2" sentence="$3"
    local naked ids id prefix pos after
    naked="${sentence//\`/}"
    ids="$(printf '%s\n' "$naked" | grep -oE 'ADR-[0-9]{8,12}-[0-9]+|#[0-9]+' 2>/dev/null)"
    [ -n "$ids" ] || return 0

    while IFS= read -r id; do
        [ -n "$id" ] || continue
        prefix="${naked%%"$id"*}"
        pos="${#prefix}"
        after="${naked:$((pos + ${#id}))}"
        after="${after#"${after%%[![:space:]]*}"}"

        case "$after" in
            '（'* | '('* | '＝'* | '='*) continue ;;
        esac
        # 骨格位置（主語・目的語）にあるものだけを候補にする。
        case "$after" in
            'は'* | 'が'* | 'を'*)
                report "$file" "$line" "不透明な識別子" \
                    "$id に説明句がない: $(excerpt "$sentence")"
                ;;
        esac
    done <<<"$ids"
    return 0
}

# ---- ファイル単位の検査 ----

# 第1条は初出の語を対象とする。初出がどこかはファイル全体を見ないと決まらないため、
# 段落を順に走査して語ごとの初出を先に決め、その初出が検査の範囲に入るときだけ報告する。
check_file() {
    # file は報告に用いる名前、source は実際に読むパス、scope は検査対象の
    # 行番号の集合（空なら全行）。差分モードでは報告名がリポジトリ相対、
    # 読み取りパスが絶対になるため、両者を分けて受け取る。
    local file="$1" source="$2" scope="$3"
    local i n_para

    collect_paragraphs "$source"
    n_para="${#PARA_TEXT[@]}"
    [ "$n_para" -gt 0 ] || return 0

    declare -A seen_token=()

    for ((i = 0; i < n_para; i++)); do
        local in_scope=0
        if [ -z "$scope" ]; then
            in_scope=1
        else
            local ln
            for ((ln = PARA_FIRST[i]; ln <= PARA_LAST[i]; ln++)); do
                case " $scope " in
                    *" $ln "*)
                        in_scope=1
                        break
                        ;;
                esac
            done
        fi

        split_sentences "${PARA_TEXT[i]}"
        local j n_sent="${#SENTS[@]}"
        for ((j = 0; j < n_sent; j++)); do
            local sentence="${SENTS[j]}" line
            line="$(line_for_offset "${PARA_OFFSETS[i]}" "${SENT_OFF[j]}")"

            local token
            while IFS= read -r token; do
                [ -n "$token" ] || continue
                [ -z "${seen_token[$token]:-}" ] || continue
                seen_token["$token"]=1
                [ "$in_scope" -eq 1 ] || continue
                [ -z "${ALLOW_EN[${token,,}]:-}" ] || continue
                [ -z "${ALLOW_KA[$token]:-}" ] || continue
                if ! is_grounded "$sentence" "$token"; then
                    report "$file" "$line" "未接地語" \
                        "$token に定義も言い換えもない: $(excerpt "$sentence")"
                fi
            done < <(scan_ungrounded_tokens "$sentence")

            [ "$in_scope" -eq 1 ] || continue
            check_length "$file" "$line" "$sentence"
            check_identifiers "$file" "$line" "$sentence"
        done
    done
    return 0
}

# ---- 差分の解決 ----

# git diff から、ファイルごとの変更後の行番号を取り出す。既定の入力単位が差分なのは、
# 規約の適用範囲が新規起草物と編集で触れた箇所に限られるためである。ファイル全体を
# 既定にすると、既存文書を1行直しただけで既存の違反が赤になる。
declare -A CHANGED_LINES=()
REPO_ROOT=""

# 連想配列を呼び出し側へ残すため、結果はコマンド置換ではなくグローバルへ書く。
# `$(...)` で呼ぶとサブシェルの中で埋めた CHANGED_LINES が呼び出し側へ届かない。
collect_changed_lines() {
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" ||
        die "git リポジトリの中ではありません（ファイル全体を検査するには --all を指定してください）"
    git rev-parse --verify --quiet "$DIFF_BASE" >/dev/null ||
        die "差分の基点を解決できません: $DIFF_BASE"

    local diff_out
    diff_out="$(git diff --unified=0 --no-color "$DIFF_BASE" -- ${PATHS[@]+"${PATHS[@]}"} 2>/dev/null)" ||
        die "git diff の実行に失敗しました"

    local line current=""
    while IFS= read -r line; do
        case "$line" in
            '+++ b/'*)
                current="${line#+++ b/}"
                ;;
            '+++ /dev/null')
                current=""
                ;;
            '@@'*)
                [ -n "$current" ] || continue
                # @@ -a,b +c,d @@ の +c,d を取る
                local spec="${line#*+}"
                spec="${spec%% *}"
                local start="${spec%%,*}" count
                if [ "$spec" = "$start" ]; then
                    count=1
                else
                    count="${spec#*,}"
                fi
                [ "$count" -gt 0 ] || continue
                local k acc="${CHANGED_LINES[$current]:-}"
                for ((k = 0; k < count; k++)); do
                    acc="$acc $((start + k))"
                done
                CHANGED_LINES["$current"]="$acc"
                ;;
        esac
    done <<<"$diff_out"
    return 0
}

# ---- 主処理 ----

resolve_max_len
load_allowlist

if [ "$SCAN_ALL" -eq 1 ]; then
    [ "${#PATHS[@]}" -gt 0 ] ||
        die "--all にはパスの指定が必要です。既存文書の一括是正は規約の範囲外であり、対象を明示させます"
    for p in "${PATHS[@]}"; do
        [ -f "$p" ] || die "ファイルが見つかりません: $p"
        check_file "$p" "$p" ""
    done
else
    collect_changed_lines
    for f in "${!CHANGED_LINES[@]}"; do
        case "$f" in
            *.md) ;;
            *) continue ;;
        esac
        target="$REPO_ROOT/$f"
        [ -f "$target" ] || continue
        check_file "$f" "$target" "${CHANGED_LINES[$f]}"
    done
fi

[ "$VIOLATIONS" -eq 0 ] || exit 1
exit 0
