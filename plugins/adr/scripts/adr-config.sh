#!/usr/bin/env bash
# adr プラグインの設定の読み込み部。lint-adr.sh・gen-adr-index.sh・next-adr-id.sh と commit ゲートが
# 読み込んで使う（単体では実行しない。関数と定数を定義するだけで、読み込んだ時点では何も読まない）。
#
# 設定は `キー: 値` を1行ずつ並べたファイルで定める。キーと書き方の説明は、同梱の
# 既定値のファイル（adr-config.default）が持つ。
#
# 設定ファイルはシェルとして読み込まない（source・eval を使わない）。行を1つずつ読み、
# 文字列として分解するだけにする。commit ゲートは導入先のリポジトリで走るため、
# 導入先のファイルをコードとして実行すると、語を変えるためだけに「導入先の内容を
# コードとして実行しない」という境界を崩すことになる。
#
# 置き場の解決: 起点のディレクトリから git のトップレベルを決め、`<トップレベル>/.claude/adr/config`
# があればそれを読む。無ければ同梱の既定値を使う。git のトップレベルを決められなければ、
# 既定値だけを使う。起点は呼び出し側が渡す（検査・生成の対象の ADR ディレクトリ）。
#
# ADR ディレクトリ（キー adr-dir）: 単体のスクリプトは、引数で ADR ディレクトリを受け取れば
# それを使い、キーを読まない。引数を省いたときは、カレントディレクトリを起点に設定を解決し、
# adr-dir の値（導入先の設定に無ければ同梱の既定値）を git のトップレベルからの相対パスとして
# 読む。トップレベルを決められなければ、カレントディレクトリからの相対パスとして読む
# （adr_config_resolve_adr_dir）。commit ゲートは引数を取らず、常にキーから決める。
# adr-dir は語の群に属さず、語の群と独立に置いてよい。値が絶対パスであるか、`..` を含むときは
# 設定の誤りとする。トップレベルの外を指すと、ゲートが git の index から ADR を取り出せないためである。
#
# 環境変数 ADR_CONFIG_ROOT が空でなければ、git による探索をせず、その値のディレクトリを
# トップレベルとみなす（`$ADR_CONFIG_ROOT/.claude/adr/config` があれば読み、無ければ既定値）。
# 値が存在しないディレクトリを指すときは、設定の誤りとして止める。誤りの検査は同じく掛かる。
# これは、commit ゲートが git の外（一時ディレクトリ）へ取り出したツリーを検査するときと、
# テストのための内部の経路である。単体のスクリプトが引数を省いたときに、カレントディレクトリから
# 決めたトップレベルを固定するのにも使う（adr_config_resolve_adr_dir）。利用者が設定を渡す主たる手段は、リポジトリに置く
# `.claude/adr/config` のままである。設定の中身は常にリポジトリのファイルから読み、この変数は
# そのファイルの在処を示すだけなので、「設定を環境変数だけで渡す」案（利用者がフックの環境を
# 整える必要があり、リポジトリと一緒に配れない）とは別物である。
#
# 語の群（ADR_CONFIG_WORD_KEYS）は揃えて置くことを求める。導入先の設定に語の群のキーが
# 1つでもあれば、全キーを要求する。キーごとに既定値へ戻すと、一部の語だけを書き換えた
# リポジトリが2つの言語の混ざったまま検査を通るためである。
#
# 設定の誤りは、ADR の違反として報告せず、原因を標準エラーへ出して 2 を返す。呼び出し側は
# exit 2 で止める。誤りを警告にとどめて既定値で続けると、綴りを誤ったキーが黙って既定値へ
# 戻り、英語で書いた ADR が全件、語彙の違反として報告される。利用者は原因が設定にあると
# 気づけない。誤りは1件目で打ち切らず、全件を出してから戻る。
#
# 前提: lint-adr.sh は bash 4.2 以上を確かめてから読み込む。この部分自身は連想配列を
# 使わない。版の確認を持たない gen-adr-index.sh からも読み込むためである。

# 同梱の既定値のファイル。読み込み元のパスから解決する（cwd に依存しない）。
ADR_CONFIG_DEFAULT_FILE="$(dirname "${BASH_SOURCE[0]}")/adr-config.default"

# 導入先の設定ファイルの、git のトップレベルからの相対パス。
ADR_CONFIG_USER_RELPATH=".claude/adr/config"

# 語の群のキー。並びは下の ADR_CONFIG_STATE_KEY_COUNT と対応する（先頭の6つが status と
# validity の値）。値の受け取り先の変数は adr_config_load の末尾が決める。
ADR_CONFIG_WORD_KEYS=(
    status-proposed
    status-approved
    status-rejected
    validity-active
    validity-superseded
    validity-abandoned
    xref-heading
    index-title
    index-notice
)
ADR_CONFIG_STATE_KEY_COUNT=6

# ADR ディレクトリのキー。語の群に属さない。
ADR_CONFIG_DIR_KEY="adr-dir"

# 設定に書いてよいキーの全体。語の群と ADR ディレクトリのキーである。
ADR_CONFIG_KNOWN_KEYS=("${ADR_CONFIG_WORD_KEYS[@]}" "$ADR_CONFIG_DIR_KEY")

# 解決した語。adr_config_load が成功したときだけ値が入る。
ADR_STATUS_PROPOSED=""
ADR_STATUS_APPROVED=""
ADR_STATUS_REJECTED=""
ADR_VALIDITY_ACTIVE=""
ADR_VALIDITY_SUPERSEDED=""
ADR_VALIDITY_ABANDONED=""
ADR_XREF_HEADING=""
ADR_INDEX_TITLE=""
ADR_INDEX_NOTICE=""

# 解決に使った設定ファイル（導入先の設定を使ったときはそのパス、使わなかったときは既定値のパス）。
ADR_CONFIG_SOURCE=""

# 設定を探したトップレベル（ADR_CONFIG_ROOT か git のトップレベル。決められなければ空）。
ADR_CONFIG_TOPLEVEL=""
# adr-dir の値（トップレベルからの相対パス。末尾の / は落とす）と、その値を読んだ設定ファイル。
ADR_CONFIG_ADR_DIR=""
ADR_CONFIG_ADR_DIR_SOURCE=""

# キー名から ADR_CONFIG_KNOWN_KEYS の添字を求め、_ADR_CONFIG_INDEX へ格納する。
# 戻り値: 知っているキーなら 0、知らないキーなら 1
_adr_config_key_index() {
    local key="$1" i
    for i in "${!ADR_CONFIG_KNOWN_KEYS[@]}"; do
        if [ "${ADR_CONFIG_KNOWN_KEYS[$i]}" = "$key" ]; then
            _ADR_CONFIG_INDEX="$i"
            return 0
        fi
    done
    return 1
}

# 設定ファイル $1 を行単位で読み、キーごとの値を _ADR_CONFIG_VALUES、書かれた行番号を
# _ADR_CONFIG_LINES へ格納する（添字は ADR_CONFIG_KNOWN_KEYS と同じ。書かれていないキーは
# 行番号が空）。誤りは ADR_CONFIG_ERRORS へ積み、打ち切らずに最後の行まで読む。
_adr_config_parse() {
    local file="$1"
    local line body key value i n=0

    _ADR_CONFIG_VALUES=()
    _ADR_CONFIG_LINES=()
    for i in "${!ADR_CONFIG_KNOWN_KEYS[@]}"; do
        _ADR_CONFIG_VALUES[i]=""
        _ADR_CONFIG_LINES[i]=""
    done

    while IFS= read -r line || [ -n "$line" ]; do
        n=$((n + 1))
        # 前後の空白（改行コードが CRLF のときの CR を含む）を落とす
        body="${line#"${line%%[![:space:]]*}"}"
        body="${body%"${body##*[![:space:]]}"}"
        case "$body" in
            '' | '#'*) continue ;;
        esac

        if [[ ! "$body" =~ ^([A-Za-z0-9_.-]+):(.*)$ ]]; then
            ADR_CONFIG_ERRORS+=("$file:$n: \`キー: 値\` の形ではありません（行: $body）")
            continue
        fi
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        value="${value#"${value%%[![:space:]]*}"}"

        if ! _adr_config_key_index "$key"; then
            ADR_CONFIG_ERRORS+=("$file:$n: 知らないキー \"$key\" です（使えるキー: ${ADR_CONFIG_KNOWN_KEYS[*]}）")
            continue
        fi
        i="$_ADR_CONFIG_INDEX"

        if [ -n "${_ADR_CONFIG_LINES[i]}" ]; then
            ADR_CONFIG_ERRORS+=("$file:$n: キー \"$key\" が2回あります（${_ADR_CONFIG_LINES[i]} 行目にもあります）")
            continue
        fi
        _ADR_CONFIG_LINES[i]="$n"

        if [ -z "$value" ]; then
            ADR_CONFIG_ERRORS+=("$file:$n: キー \"$key\" の値が空です")
            continue
        fi
        _ADR_CONFIG_VALUES[i]="$value"
    done <"$file"
}

# 直前の _adr_config_parse の結果のうち、語の群のキーが何件書かれていたかを
# _ADR_CONFIG_WORDS_PRESENT へ、書かれていないキーを _ADR_CONFIG_WORDS_MISSING へ格納する。
_adr_config_count_words() {
    local key
    _ADR_CONFIG_WORDS_PRESENT=0
    _ADR_CONFIG_WORDS_MISSING=()
    for key in "${ADR_CONFIG_WORD_KEYS[@]}"; do
        _adr_config_key_index "$key"
        if [ -n "${_ADR_CONFIG_LINES[$_ADR_CONFIG_INDEX]}" ]; then
            _ADR_CONFIG_WORDS_PRESENT=$((_ADR_CONFIG_WORDS_PRESENT + 1))
        else
            _ADR_CONFIG_WORDS_MISSING+=("$key")
        fi
    done
}

# 直前の _adr_config_parse の結果のうち、adr-dir の値を検査し、末尾の / を落とした値を
# _ADR_CONFIG_DIR_VALUE へ格納する（書かれていない・値が空のときは空）。誤りは
# ADR_CONFIG_ERRORS へ積む。引数: $1 読んだ設定ファイル
_adr_config_take_adr_dir() {
    local file="$1" value line
    _adr_config_key_index "$ADR_CONFIG_DIR_KEY"
    value="${_ADR_CONFIG_VALUES[$_ADR_CONFIG_INDEX]}"
    line="${_ADR_CONFIG_LINES[$_ADR_CONFIG_INDEX]}"
    _ADR_CONFIG_DIR_VALUE=""
    [ -n "$value" ] || return 0
    case "$value" in
        /*)
            ADR_CONFIG_ERRORS+=("$file:$line: キー \"$ADR_CONFIG_DIR_KEY\" の値 \"$value\" が絶対パスです（git のトップレベルからの相対パスを書きます）")
            return 0
            ;;
    esac
    case "/$value/" in
        */../*)
            ADR_CONFIG_ERRORS+=("$file:$line: キー \"$ADR_CONFIG_DIR_KEY\" の値 \"$value\" が \"..\" を含みます（git のトップレベルの中を指す相対パスを書きます）")
            return 0
            ;;
    esac
    while [ "${value%/}" != "$value" ]; do
        value="${value%/}"
    done
    _ADR_CONFIG_DIR_VALUE="$value"
}

# 起点のディレクトリ $1 から設定を解決し、語を ADR_STATUS_PROPOSED などの変数へ格納する。
# $1 が空なら、git のトップレベルを探さず既定値だけを使う。
# 戻り値: 解決できれば 0、設定に誤りがあれば 2（原因は標準エラーへ出す）
adr_config_load() {
    local origin="$1"
    local toplevel="" user_file="" key i
    local -a words=()

    ADR_CONFIG_ERRORS=()
    ADR_CONFIG_SOURCE=""
    ADR_CONFIG_TOPLEVEL=""
    ADR_CONFIG_ADR_DIR=""
    ADR_CONFIG_ADR_DIR_SOURCE=""

    if [ -n "${ADR_CONFIG_ROOT:-}" ]; then
        # トップレベルの明示（ヘッダの注記）。git による探索より優先する。指し先が無いときに
        # 既定値へ黙って落とすと、導入先の設定を読まないまま検査が進むため、誤りとして止める。
        if [ -d "$ADR_CONFIG_ROOT" ]; then
            toplevel="$ADR_CONFIG_ROOT"
            user_file="$toplevel/$ADR_CONFIG_USER_RELPATH"
        else
            ADR_CONFIG_ERRORS+=("ADR_CONFIG_ROOT=$ADR_CONFIG_ROOT: 設定を探すトップレベルとして指定されたディレクトリがありません")
        fi
    elif [ -n "$origin" ] && toplevel="$(git -C "$origin" rev-parse --show-toplevel 2>/dev/null)" &&
        [ -n "$toplevel" ]; then
        user_file="$toplevel/$ADR_CONFIG_USER_RELPATH"
    fi

    # 既定値は常に読む。導入先の設定が語の群を持たないときの値になる。既定値のファイル自体の
    # 誤り（同梱物の破損）も、導入先の設定の誤りと同じく原因を示して止める。
    if [ ! -f "$ADR_CONFIG_DEFAULT_FILE" ] || [ ! -r "$ADR_CONFIG_DEFAULT_FILE" ]; then
        ADR_CONFIG_ERRORS+=("$ADR_CONFIG_DEFAULT_FILE: 同梱の既定値のファイルを読めません")
    else
        _adr_config_parse "$ADR_CONFIG_DEFAULT_FILE"
        _adr_config_count_words
        if [ "${#_ADR_CONFIG_WORDS_MISSING[@]}" -gt 0 ]; then
            ADR_CONFIG_ERRORS+=("$ADR_CONFIG_DEFAULT_FILE: 同梱の既定値に語の群のキーが欠けています（${_ADR_CONFIG_WORDS_MISSING[*]}）")
        fi
        for key in "${ADR_CONFIG_WORD_KEYS[@]}"; do
            _adr_config_key_index "$key"
            words+=("${_ADR_CONFIG_VALUES[$_ADR_CONFIG_INDEX]}")
        done
        ADR_CONFIG_SOURCE="$ADR_CONFIG_DEFAULT_FILE"
        _adr_config_take_adr_dir "$ADR_CONFIG_DEFAULT_FILE"
        if [ -z "$_ADR_CONFIG_DIR_VALUE" ]; then
            ADR_CONFIG_ERRORS+=("$ADR_CONFIG_DEFAULT_FILE: 同梱の既定値に正しい $ADR_CONFIG_DIR_KEY がありません")
        fi
        ADR_CONFIG_ADR_DIR="$_ADR_CONFIG_DIR_VALUE"
        ADR_CONFIG_ADR_DIR_SOURCE="$ADR_CONFIG_DEFAULT_FILE"
    fi

    if [ -n "$user_file" ] && [ -e "$user_file" ]; then
        if [ ! -f "$user_file" ] || [ ! -r "$user_file" ]; then
            ADR_CONFIG_ERRORS+=("$user_file: 設定ファイルを読めません（通常のファイルで、読み取りできる必要があります）")
        else
            _adr_config_parse "$user_file"
            _adr_config_count_words
            if [ "$_ADR_CONFIG_WORDS_PRESENT" -gt 0 ] && [ "${#_ADR_CONFIG_WORDS_MISSING[@]}" -gt 0 ]; then
                ADR_CONFIG_ERRORS+=("$user_file: 語の群の一部だけが書かれています（書かれていないキー: ${_ADR_CONFIG_WORDS_MISSING[*]}）。語の群は全キーを書くか、1つも書かないかのどちらかにします")
            elif [ "$_ADR_CONFIG_WORDS_PRESENT" -gt 0 ]; then
                words=()
                for key in "${ADR_CONFIG_WORD_KEYS[@]}"; do
                    _adr_config_key_index "$key"
                    words+=("${_ADR_CONFIG_VALUES[$_ADR_CONFIG_INDEX]}")
                done
                ADR_CONFIG_SOURCE="$user_file"
            fi
            # adr-dir は語の群と独立に置いてよい。書かれていれば既定値を置き換える
            _adr_config_take_adr_dir "$user_file"
            if [ -n "$_ADR_CONFIG_DIR_VALUE" ]; then
                ADR_CONFIG_ADR_DIR="$_ADR_CONFIG_DIR_VALUE"
                ADR_CONFIG_ADR_DIR_SOURCE="$user_file"
            fi
        fi
    fi

    # status と validity の6つの値は互いに異なることを求める。同じ値が2つの役割を持つと、
    # front-matter の値から役割を一意に決められない。誤りの報告は、解決に使う設定ファイルを主語にする。
    if [ "${#ADR_CONFIG_ERRORS[@]}" -eq 0 ]; then
        local j
        for ((i = 0; i < ADR_CONFIG_STATE_KEY_COUNT; i++)); do
            for ((j = i + 1; j < ADR_CONFIG_STATE_KEY_COUNT; j++)); do
                if [ "${words[i]}" = "${words[j]}" ]; then
                    ADR_CONFIG_ERRORS+=("$ADR_CONFIG_SOURCE: status と validity の値に重複があります（${ADR_CONFIG_WORD_KEYS[i]} と ${ADR_CONFIG_WORD_KEYS[j]} がともに \"${words[i]}\"）")
                fi
            done
        done
    fi

    if [ "${#ADR_CONFIG_ERRORS[@]}" -gt 0 ]; then
        echo "エラー: adr プラグインの設定に誤りがあります。" >&2
        for i in "${!ADR_CONFIG_ERRORS[@]}"; do
            printf '  - %s\n' "${ADR_CONFIG_ERRORS[$i]}" >&2
        done
        echo "  設定を直してから再実行してください（書き方は同梱の adr-config.default の冒頭にあります）。" >&2
        return 2
    fi

    ADR_STATUS_PROPOSED="${words[0]}"
    ADR_STATUS_APPROVED="${words[1]}"
    ADR_STATUS_REJECTED="${words[2]}"
    ADR_VALIDITY_ACTIVE="${words[3]}"
    ADR_VALIDITY_SUPERSEDED="${words[4]}"
    ADR_VALIDITY_ABANDONED="${words[5]}"
    ADR_XREF_HEADING="${words[6]}"
    ADR_INDEX_TITLE="${words[7]}"
    ADR_INDEX_NOTICE="${words[8]}"
    ADR_CONFIG_TOPLEVEL="$toplevel"
    return 0
}

# 単体のスクリプトが受け取った引数 $1（省いたときは空）から、対象の ADR ディレクトリを決めて
# ADR_DIR へ格納する。優先順は「引数 → 設定の adr-dir → 同梱の既定値」である。
#   - 引数があれば、それを使う（末尾の / を1つ落とす）。設定はまだ読まない
#   - 引数が無ければ、カレントディレクトリを起点に設定を解決し、adr-dir の値をトップレベルからの
#     相対パスとして読む。トップレベルを決められなければ、カレントディレクトリからの相対パスとする
# 引数を省いたときは、決めたトップレベルを ADR_CONFIG_ROOT として環境へ置く。後で ADR ディレクトリを
# 起点に設定を解決し直すとき（lint が起動する index の生成器を含む）に、別のトップレベル
# （ADR ディレクトリが入れ子のリポジトリの中にある場合）の設定へずれないようにするためである。
# 戻り値: 決められれば 0、設定に誤りがあれば 2（原因は adr_config_load が標準エラーへ出す）
adr_config_resolve_adr_dir() {
    ADR_DIR_FROM_CONFIG=0
    if [ -n "$1" ]; then
        ADR_DIR="${1%/}"
        return 0
    fi
    adr_config_load "." || return 2
    ADR_DIR="${ADR_CONFIG_TOPLEVEL:+$ADR_CONFIG_TOPLEVEL/}$ADR_CONFIG_ADR_DIR"
    ADR_DIR_FROM_CONFIG=1
    if [ -n "$ADR_CONFIG_TOPLEVEL" ]; then
        ADR_CONFIG_ROOT="$ADR_CONFIG_TOPLEVEL"
        export ADR_CONFIG_ROOT
    fi
    return 0
}

# adr_config_resolve_adr_dir で決めた ADR_DIR が無いことを、標準エラーへ出す。引数を省いて設定から
# 決めたときは、どの設定ファイルのどの値から決めたかを添える。
adr_config_report_missing_adr_dir() {
    echo "エラー: ディレクトリが見つかりません: $ADR_DIR" >&2
    if [ "${ADR_DIR_FROM_CONFIG:-0}" -eq 1 ]; then
        echo "  引数を省いたため、$ADR_CONFIG_ADR_DIR_SOURCE の $ADR_CONFIG_DIR_KEY（値: $ADR_CONFIG_ADR_DIR）から決めました。" >&2
        echo "  値は git のトップレベル（決められなければカレントディレクトリ）からの相対パスとして読みます。" >&2
    fi
}
