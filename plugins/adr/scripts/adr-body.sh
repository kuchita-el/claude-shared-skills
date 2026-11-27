#!/usr/bin/env bash
# adr プラグインの本文の走査部。lint-adr.sh と gen-adr-index.sh が読み込んで使う（単体では実行しない。
# 関数と定数を定義するだけで、読み込んだ時点では何も読まない）。
#
# 本文の見出しとコードフェンスを同じ規則で読むために、両者の共通部をここに置く。H1 の取り出し方を
# index 生成器（タイトル欄の生成）と検査器（H1 の形式・識別子の検査）が別々に持つと、index に載る
# タイトルと検査が見るタイトルが食い違う。判定の正本はこのファイルであり、呼び出し側へ写さない。
#
# コードフェンス: 行頭（空白は許容）の ``` または ~~~ の3文字以上の連なりで開く。閉じるのは、開いた
# 文字と同じ文字の連なりで、長さが開いた連なり以上、後ろに空白以外が続かない行だけである
# （CommonMark の規則。``` で開いたフェンスは ~~~ の行では閉じず、~~~ の内側の ``` の行も閉じない）。
# 閉じないままファイル末尾に達したら、末尾までをフェンスの内側とみなす。

# コードフェンスの開閉の行（行頭の空白は許容）。第1群が、開閉の文字の連なり。
ADR_FENCE_PATTERN='^[[:space:]]*(```+|~~~+)'

ADR_FENCE_MARK=""

# 行 $1 を、グローバル変数 ADR_FENCE_MARK（開いているフェンスの連なり。外側なら空文字）に照らして
# 進める。呼び出し側は、ファイルの走査の前に ADR_FENCE_MARK="" へ初期化する。
# 戻り値: 行がフェンスの開閉の行、またはフェンスの内側なら 0（読み飛ばす行）、外側の本文なら 1
adr_fence_skip() {
    local line="$1" run stripped

    if [[ "$line" =~ $ADR_FENCE_PATTERN ]]; then
        run="${BASH_REMATCH[1]}"
        if [ -z "$ADR_FENCE_MARK" ]; then
            ADR_FENCE_MARK="$run"
            return 0
        fi
        stripped="${line#"${line%%[![:space:]]*}"}"
        stripped="${stripped:${#run}}"
        if [ "${run:0:1}" = "${ADR_FENCE_MARK:0:1}" ] && [ "${#run}" -ge "${#ADR_FENCE_MARK}" ] &&
            [[ ! "$stripped" =~ [^[:space:]] ]]; then
            ADR_FENCE_MARK=""
        fi
        return 0
    fi
    [ -n "$ADR_FENCE_MARK" ]
}

# ファイル $1 の本文（front-matter 区間とコードフェンスの内側を除く）の最初の `# ` 見出し行を、
# グローバル変数 ADR_H1_LINE へ格納する（見出しが無ければ空文字）。front-matter 区間は、先頭行が
# `---` のときの、閉じの `---` までである（YAML のコメント行は行頭 `# ` に当たり、読み飛ばさないと
# H1 と誤認する）。
adr_find_h1() {
    local file="$1"
    local line line_num=0 in_fm=0

    ADR_H1_LINE=""
    ADR_FENCE_MARK=""

    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))
        if [ "$line_num" -eq 1 ] && [ "$line" = "---" ]; then
            in_fm=1
            continue
        fi
        if [ "$in_fm" -eq 1 ]; then
            if [ "$line" = "---" ]; then
                in_fm=0
            fi
            continue
        fi
        if adr_fence_skip "$line"; then
            continue
        fi
        if [[ "$line" =~ ^#[[:space:]] ]]; then
            ADR_H1_LINE="$line"
            return 0
        fi
    done <"$file"
}

# H1 見出し行 $1 からタイトルを取り出し、標準出力へ出す。タイトルは、`# ` を除いた残りの最初の
# `: ` より後ろである。取り出せなければ（`: ` が無い、または後ろが空白だけ）何も出さずに 1 を返す。
# index 生成器のタイトル欄と、検査器の H1 形式検査は、この関数の結果を使う。
adr_h1_title() {
    local rest title

    rest="${1#\# }"
    [[ "$rest" == *": "* ]] || return 1
    title="${rest#*: }"
    [[ "$title" =~ [^[:space:]] ]] || return 1
    printf '%s' "$title"
}
