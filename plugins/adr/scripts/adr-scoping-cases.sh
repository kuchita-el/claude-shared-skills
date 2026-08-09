#!/usr/bin/env bash
# 固定題材集合の実行支援。
#
# 判定手続きを定めた文書（以下「対象文書」）を被テスト対象とし、固定した題材を
# 通して帰結の差を見るための検査器である。判定そのものは LLM が担い、本スクリプトは
# 入力の組み立て（prompt）・題材集合の内部整合の検査（validate）・判定記録の集計
# （report）の3つだけを担う。判定の真偽をシェルで決めることはしない。
#
# 本スクリプトは特定のリポジトリのディレクトリ構成・対象文書名を前提にしない。
# 題材集合ディレクトリと対象文書パスはすべて引数で受け、既定値を持たない。
#
# 題材集合ディレクトリの契約:
#   <題材集合ディレクトリ>/cases.md            題材文層。`## <題材ID>` を見出しに持つ
#   <題材集合ディレクトリ>/expectations.tsv    期待帰結層。題材IDごとに1行
#   <題材集合ディレクトリ>/prompt-template.md  判定プロンプトの雛形（prompt でのみ使う）
#
# cases.md の題材ブロックの構造:
#   ## <題材ID>
#   - 出所: ...
#   - 資産種別: ...
#   - 規範の担い方: 体現・強制 | 散文のみ | なし
#
#   ### 題材文
#
#   （本文。次の水平線までが判定側へ渡る唯一の入力）
#
#   ---
#
# expectations.tsv の列（タブ区切り。`#` 始まりの行は注記として読み飛ばす）:
#   1 題材ID / 2 導出すべきもの / 3-6 期待_項目1〜4 / 7 期待_行き先
#   8 由来 / 9 対の相手ID / 10 出所 / 11 備考
# 期待_項目1〜4 は数値が測定対象、`-` が不問を表す。合計は項目から導出できるため、
# 期待値として保持・比較しない。
#
# 判定記録TSV の列（タブ区切り。`#` 始まりの行は注記として読み飛ばす）:
#   1 題材ID / 2 試行番号 / 3-6 項目1〜4 / 7 合計 / 8 行き先
#   9-12 根拠_項目1〜4 / 13 参照ファイル一覧 / 14 対象文書commit / 15 題材集合commit
#
# 使い方:
#   bash adr-scoping-cases.sh prompt   <対象文書パス> <題材ID> <題材集合ディレクトリ>
#   bash adr-scoping-cases.sh validate <題材集合ディレクトリ>
#   bash adr-scoping-cases.sh report   <判定記録TSV> <題材集合ディレクトリ>
#
# prompt は組み立てたプロンプトを一時ファイルへ書き出し、そのパスだけを標準出力へ返す。
# プロンプト本文を標準出力へ流さないのは、呼び出し側の文脈へ題材本文を載せないためである。
#
# exit code:
#   0: 検査に通った（prompt は組み立てに成功した）
#   1: 検査に落ちた（欠落・不整合・未知の題材ID 等）
#   2: 引数の誤り（サブコマンド不明、引数の個数不一致、パスが存在しない）
set -euo pipefail

# EXIT trap から参照する後始末対象。trap 本体の展開を EXIT 時まで遅らせるため、
# 関数の local ではなくグローバルへ置く（set -u 対策として空で初期化する）。
_cleanup_body_file=""
_cleanup_out_file=""
_cleanup_ids_file=""

# EXIT trap の本体。パスを trap 文字列へ埋め込まず関数名だけを渡すのは、$TMPDIR に
# 単一引用符が含まれる場合に trap 本体のクォートが壊れ、処理が成功していても EXIT 時の
# 構文エラーで exit 2（＝仕様上は「引数の誤り」）を返すためである。
# 空の変数は消す対象を持たないことを意味する。後始末の失敗で終了状態を書き換えないよう、
# 最後に必ず 0 を返す。
_cleanup_temp_files() {
    [ -z "$_cleanup_body_file" ] || rm -f -- "$_cleanup_body_file"
    [ -z "$_cleanup_out_file" ] || rm -f -- "$_cleanup_out_file"
    [ -z "$_cleanup_ids_file" ] || rm -f -- "$_cleanup_ids_file"
    return 0
}

usage() {
    cat >&2 <<'USAGE'
使い方:
  adr-scoping-cases.sh prompt   <対象文書パス> <題材ID> <題材集合ディレクトリ>
  adr-scoping-cases.sh validate <題材集合ディレクトリ>
  adr-scoping-cases.sh report   <判定記録TSV> <題材集合ディレクトリ>

題材集合ディレクトリは全サブコマンドで必須であり、既定値を持たない。
題材集合ディレクトリは cases.md と expectations.tsv を持つこと
（prompt はさらに prompt-template.md を要する）。
USAGE
}

die_usage() {
    printf 'エラー: %s\n' "$1" >&2
    usage
    exit 2
}

# 引数で受けたパスを、awk のファイルオペランドとして安全な形へ正規化し、結果を
# `_normalized` へ置く。
#
# awk は `name=value` の形のオペランドを変数代入として解釈するため、`a=b` のような
# 相対パスをそのまま渡すとファイルを開かずに標準入力を読みにいく。診断はゼロのまま
# 偽の違反が並び、原因を取り違えた結果だけが残る。`./` を前置すると `./a` が識別子として
# 不正になるので、awk はファイル名として扱う。先頭が `-` のパスにも同時に効く
# （grep 側は各呼び出しの `--` でも塞いである）。
#
# 空文字列は前置せずそのまま置く。`./` へ化けさせると、引数を空で渡した呼び出しが
# カレントディレクトリを指す正常な入力になり、usage が明記する「題材集合ディレクトリは
# 全サブコマンドで必須であり、既定値を持たない」（および `require_case_dir` の `[ -n ]`）が
# 破れる。空かどうかの判定は呼び出し先へ残す。
#
# 値をコマンド置換で受け取らずグローバルへ置くのは、置換が末尾の改行を落とすためである
# （末尾に改行を持つパスが「存在しない」へ化ける）。
_normalized=""
normalize_path() {
    case "$1" in
        ""|/*|./*|../*) _normalized="$1" ;;
        *) _normalized="./$1" ;;
    esac
}

# 題材集合ディレクトリの契約を検査する。$2 が "with-template" のとき雛形の存在も見る。
#
# 在ることだけでなく読めることまで見るのは、読めないファイルが後段で「中身が無い」と
# 区別できない形に化けるためである（雛形が読めないと grep が非0を返し、差し込み記号が
# 3つとも欠けていると報告される）。原因を名指しできる位置で落とす。
require_case_dir() {
    local dir="$1"
    local need_template="${2:-}"
    [ -n "$dir" ] || die_usage "題材集合ディレクトリが指定されていない"
    [ -d "$dir" ] || die_usage "題材集合ディレクトリが存在しない: $dir"
    # ディレクトリを辿れないと配下の `[ -f ]` が軒並み偽になり、実在するファイルが
    # 「欠けている」と報告される。ファイル単位の可読性検査と同じ理由でここでも落とす。
    #
    # 見るのは `-x` だけで足りる。本スクリプトは $dir を一度も一覧せず、既知の名前を
    # 開くだけなので、実行のみ可（mode 111）でも正常に動く。`-r` を連言へ加えると、
    # その動く構成を弾くだけで、失敗モードは1つも単独では捕まえない（000 は両方が、
    # 666 は `-x` だけが落ちる。いずれも `-x` 側で捕まる）。
    [ -x "$dir" ] || die_usage "題材集合ディレクトリを辿れない: $dir"

    local required=(cases.md expectations.tsv)
    if [ "$need_template" = "with-template" ]; then
        required+=(prompt-template.md)
    fi

    local missing=() unreadable=() f
    for f in "${required[@]}"; do
        if [ ! -f "$dir/$f" ]; then
            missing+=("$f")
        elif [ ! -r "$dir/$f" ]; then
            unreadable+=("$f")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        printf 'エラー: 題材集合ディレクトリに必要なファイルが無い: %s\n' "$dir" >&2
        printf '  欠けているファイル: %s\n' "${missing[*]}" >&2
        exit 2
    fi
    if [ ${#unreadable[@]} -gt 0 ]; then
        printf 'エラー: 題材集合ディレクトリのファイルを読めない: %s\n' "$dir" >&2
        printf '  読めないファイル: %s\n' "${unreadable[*]}" >&2
        exit 2
    fi
}

# cases.md の題材ID を出現順に列挙する。
# 題材が1件も無い場合は空を返して正常終了する（grep のマッチ0件は異常ではない。
# `|| true` を外すと set -euo pipefail 下で呼び出し側が診断を出す前に落ちる）。
list_case_ids() {
    grep -oE '^## [A-Za-z0-9_-]+' -- "$1/cases.md" | sed 's/^## //' || true
}

# 題材ブロックのうち、見出しから `### 題材文` の直前までを返す（メタ行の置き場）。
# 題材文の本文を含めないのは、メタ行を題材文の内側へ書いた場合に
# 必須フィールド検査を通過させないためである（内側にあると判定側へ漏れる）。
extract_case_meta() {
    cid="$2" awk '
        BEGIN { id = ENVIRON["cid"] }
        $0 == "## " id { in_case=1; next }
        in_case && /^## / { exit }
        in_case && $0 == "### 題材文" { exit }
        in_case { print }
    ' "$1/cases.md"
}

# 与えた本文にメタ行（`- 資産種別:` / `- 規範の担い方:` / `- 出所:` で始まる行）が
# 含まれるかを判定する。含まれれば 0、含まれなければ 1 を返す。
# 外部コマンドへパイプで流さないのは、読み手が早期に閉じると書き手が SIGPIPE を受け、
# 条件式の文脈では set -e が発火しないまま「該当なし」へ倒れるためである。
has_meta_line() {
    case "$1" in
        "- 資産種別:"*|"- 規範の担い方:"*|"- 出所:"*) return 0 ;;
        *$'\n'"- 資産種別:"*|*$'\n'"- 規範の担い方:"*|*$'\n'"- 出所:"*) return 0 ;;
        *) return 1 ;;
    esac
}

# 標準入力のメタ行から `- <ラベル>: <値>` の先頭1件の値を返す。
# 該当が無ければ空を返して正常終了する。
# 入力を最後まで読み切る実装にしてあるのは、途中で読み手を閉じると書き手が
# SIGPIPE を受け、pipefail + set -e の下で診断ゼロのまま rc=141 で落ちるためである。
first_meta_value() {
    awk -v label="$1" '
        !found {
            prefix = "- " label ":"
            if (substr($0, 1, length(prefix)) == prefix) {
                found = 1
                value = substr($0, length(prefix) + 1)
                sub(/^[[:space:]]+/, "", value)
            }
        }
        END { if (found) print value }
    '
}

# expectations.tsv の題材ID を出現順に列挙する（注記行とヘッダ行を除く）。
list_expectation_ids() {
    awk -F'\t' '!/^#/ && NR>0 && $1!="題材ID" && NF>0 {print $1}' "$1/expectations.tsv"
}

# prompt-template.md に欠けている差し込み記号を1行に1つ返す。揃っていれば空を返す。
#
# 記号を書き落とした雛形は prompt が黙って受け入れる。題材文の差し込みは記号が在る行で
# しか起きないため、記号ごと落ちていると題材文の無いプロンプトが exit 0 で出来上がる。
# 題材集合は利用者が自作する契約物なので、検査は validate（内部整合の点検）と
# prompt（成果物を生む経路）の両方から通す。片方だけに置くと塞がらない。
missing_template_markers() {
    local marker
    for marker in '{{対象文書パス}}' '{{題材ID}}' '{{題材文}}'; do
        grep -qF -- "$marker" "$1/prompt-template.md" || printf '%s\n' "$marker"
    done
}

# cases.md から題材1件分の題材文ブロックだけを取り出す。
# 題材ID を `-v` ではなく環境変数で渡すのは、`-v` が代入値のエスケープ列を解釈して
# `\` を含む値を壊すためである。ただし現状この関数へ届く題材IDは `list_case_ids`
# （`^## [A-Za-z0-9_-]+` で文字集合を制限）由来か、`grep -qxF` でその出力との完全一致を
# 確認した値に限られるので、`\` を含む値は到達しない。作りを cmd_prompt 本体へ揃えるための
# 硬化であり、現状の呼び出し規約では踏めない経路を塞いでいる（＝回帰テストを書けない）。
extract_case_text() {
    local dir="$1" case_id="$2"
    cid="$case_id" awk '
        BEGIN { id = ENVIRON["cid"] }
        $0 == "## " id { in_case=1; next }
        in_case && /^## / { exit }
        in_case && $0 == "### 題材文" { in_body=1; next }
        in_body && /^---[[:space:]]*$/ { exit }
        in_body && !started && /^[[:space:]]*$/ { next }
        in_body { started=1; buf[++n] = $0 }
        END {
            last = n
            while (last > 0 && buf[last] ~ /^[[:space:]]*$/) last--
            for (i = 1; i <= last; i++) print buf[i]
        }
    ' "$dir/cases.md"
}

# ---------------------------------------------------------------- prompt

cmd_prompt() {
    [ $# -eq 3 ] || die_usage "prompt は引数を3つ取る（対象文書パス・題材ID・題材集合ディレクトリ）"
    local doc_path="$1" case_id="$2" dir
    # 対象文書パスは正規化しない（プロンプトへそのまま差し込む値であり、
    # awk のオペランドとしては渡さないため）。題材集合ディレクトリは渡すので正規化する。
    normalize_path "$3"; dir="$_normalized"

    [ -f "$doc_path" ] || die_usage "対象文書が存在しない: $doc_path"
    [ -r "$doc_path" ] || die_usage "対象文書を読めない: $doc_path"
    require_case_dir "$dir" with-template

    # 差し込み記号を欠いた雛形からは、題材文の無いプロンプトが黙って出来上がる。
    # validate 側の同じ検査は cmd_prompt から呼ばれないため、ここで独立に通す。
    local missing_markers
    missing_markers="$(missing_template_markers "$dir")"
    if [ -n "$missing_markers" ]; then
        printf 'エラー: prompt-template.md に差し込み記号が無い: %s\n' "$dir/prompt-template.md" >&2
        printf '欠けている差し込み記号:\n' >&2
        printf '%s\n' "$missing_markers" | sed 's/^/  /' >&2
        exit 1
    fi

    # `-F` を落とすと題材ID が正規表現として解釈され、`CASE-A.` のような入力が
    # 存在検査を通過して診断が「題材文が空である」へ化ける。
    if ! list_case_ids "$dir" | grep -qxF -- "$case_id"; then
        printf 'エラー: 題材ID が題材集合に無い: %s\n' "$case_id" >&2
        printf '既知の題材ID:\n' >&2
        list_case_ids "$dir" | sed 's/^/  /' >&2
        exit 1
    fi

    local body
    body="$(extract_case_text "$dir" "$case_id")"
    if [ -z "${body//[[:space:]]/}" ]; then
        printf 'エラー: 題材文が空である: %s\n' "$case_id" >&2
        exit 1
    fi

    local out body_file
    out="$(mktemp -t adr-scoping-case-prompt.XXXXXX.md)"
    # 作った直後に登録する。2つ目の mktemp が失敗すると $out が残る窓ができるため、
    # 登録は「作った順」に置く（外す位置と対称に、登録の位置も詰める）。
    _cleanup_out_file="$out"
    trap _cleanup_temp_files EXIT
    body_file="$(mktemp -t adr-scoping-case-body.XXXXXX)"
    # 一時ファイルは失敗経路でも残さない。作業用の $body_file は常に、出力用の $out は
    # 呼び出し側へパスを返せなかった場合にかぎり消す（返した後は呼び出し側の持ち物になる
    # ので、成功時は返す直前に後始末の対象から外す）。awk が落ちる経路で $out を残すと、
    # スクリプト自身の診断がゼロのまま中身の欠けたファイルが $TMPDIR に溜まる。
    # 後始末の作りと、パスを trap 本体へ埋め込まない理由は _cleanup_temp_files を参照。
    _cleanup_body_file="$body_file"
    printf '%s\n' "$body" > "$body_file"

    # 雛形の差し込み記号を置換する。題材文は複数行のため行ごと流し込む。
    #
    # 置換に gsub を使わないのは、gsub が置換文字列中の `&` をマッチ文字列
    # （＝差し込み記号そのもの）へ展開するためである。対象文書パスと題材ID は
    # 利用者入力なので、`&` を含むと差し込み記号が出力へ再挿入され、
    # 存在しないパスを載せたプロンプトが exit 0 のまま生成されてしまう。
    #
    # 値を `-v` で渡さないのも同じ型の理由による。`-v` は代入値のエスケープ列を
    # 解釈するため、パスに `\` が含まれると値が壊れる。とくに一時ファイルのパスが
    # 壊れると題材文の読み込みが1行も回らず、`題材文が空のプロンプト`が
    # exit 0 のまま出来上がる。環境変数経由なら awk は値をそのまま受け取る。
    local awk_rc
    doc="$doc_path" cid="$case_id" bodyfile="$body_file" awk '
        BEGIN {
            doc = ENVIRON["doc"]
            cid = ENVIRON["cid"]
            bodyfile = ENVIRON["bodyfile"]
        }
        # 差し込み記号 mark を文字列 value でそのまま置き換える（& を特別扱いしない）。
        function replace_literal(s, mark, value,   out, pos) {
            out = ""
            while ((pos = index(s, mark)) > 0) {
                out = out substr(s, 1, pos - 1) value
                s = substr(s, pos + length(mark))
            }
            return out s
        }
        {
            $0 = replace_literal($0, "{{対象文書パス}}", doc)
            $0 = replace_literal($0, "{{題材ID}}", cid)
            if ($0 ~ /\{\{題材文\}\}/) {
                while ((getline line < bodyfile) > 0) { print line; nbody++ }
                close(bodyfile)
                # 題材文が空でないことは呼び出し側で確認済みなので、1行も読めないのは
                # 一時ファイルを読めていないということである。無言で空欄を出さない。
                #
                # 終了状態に 3 を使うのは cmd_report の番兵と同じ理由による。ここで 1 を
                # 返すと、下の `||` ハンドラが自前の診断と awk 自身の異常終了とを区別できず、
                # 原因を名指しした1行目の後ろへ「異常終了した」と述べる2行目を積んでしまう。
                if (nbody == 0) {
                    printf "エラー: 題材文を一時ファイルから読めなかった: %s\n", bodyfile > "/dev/stderr"
                    exit 3
                }
                next
            }
            print
        }
    ' "$dir/prompt-template.md" > "$out" || {
        # awk 自身が異常終了した場合（実行できない・強制終了された等）、set -e で
        # そのまま抜けるとスクリプト側の診断がゼロになり、中身の欠けた出力だけが残る。
        # 一時ファイルは EXIT trap が消すので、ここでは原因を名指しして仕様上の 1 で落とす。
        #
        # ただし 3 は awk 側が題材文を読めずに自分で診断を出して落ちた番兵なので、
        # ここで重ねて名指ししない。重ねると「異常終了した」と述べる2行目が、
        # 原因と無関係な prompt-template.md を名指ししてしまう。
        awk_rc=$?
        if [ "$awk_rc" -ne 3 ]; then
            printf 'エラー: プロンプトの組み立てに失敗した（雛形の処理が異常終了した）: %s\n' \
                "$dir/prompt-template.md" >&2
        fi
        exit 1
    }
    rm -f -- "$body_file"
    _cleanup_body_file=""

    # ここから先は $out のパスを呼び出し側へ返すので、後始末の対象から外す。
    # 外す位置を printf の後ろにすると、printf が失敗した場合に呼び出し側がパスを
    # 受け取れないまま実体だけが残る。
    _cleanup_out_file=""
    printf '%s\n' "$out"
}

# ---------------------------------------------------------------- validate

cmd_validate() {
    [ $# -eq 1 ] || die_usage "validate は引数を1つ取る（題材集合ディレクトリ）"
    local dir
    normalize_path "$1"; dir="$_normalized"
    require_case_dir "$dir"

    local violations=0
    report_violation() { printf '[NG] %s\n' "$1"; violations=$((violations + 1)); }

    # --- 題材ID の重複と空
    local dup
    dup="$(list_case_ids "$dir" | sort | uniq -d)"
    if [ -n "$dup" ]; then
        while IFS= read -r id; do report_violation "cases.md に題材IDの重複がある: $id"; done <<< "$dup"
    fi
    if [ -z "$(list_case_ids "$dir")" ]; then
        report_violation "cases.md に題材が1件も無い"
    fi

    # --- 雛形の差し込み記号（在る場合のみ検査する。雛形は prompt でのみ使う）
    # 検査の中身と、両経路へ置く理由は missing_template_markers を参照。
    if [ -f "$dir/prompt-template.md" ]; then
        local missing_markers marker
        missing_markers="$(missing_template_markers "$dir")"
        if [ -n "$missing_markers" ]; then
            while IFS= read -r marker; do
                report_violation "prompt-template.md に差し込み記号が無い: $marker"
            done <<< "$missing_markers"
        fi
    fi

    # --- ID集合の一致（cases.md ↔ expectations.tsv）
    local only_cases only_exp
    only_cases="$(comm -23 <(list_case_ids "$dir" | sort -u) <(list_expectation_ids "$dir" | sort -u))"
    only_exp="$(comm -13 <(list_case_ids "$dir" | sort -u) <(list_expectation_ids "$dir" | sort -u))"
    if [ -n "$only_cases" ]; then
        while IFS= read -r id; do report_violation "expectations.tsv に対応する行が無い題材: $id"; done <<< "$only_cases"
    fi
    if [ -n "$only_exp" ]; then
        while IFS= read -r id; do report_violation "cases.md に対応する題材が無い期待帰結の行: $id"; done <<< "$only_exp"
    fi

    # --- 題材文層（3層のうち第1層）と必須メタフィールド
    local ids id meta asset carrier body
    ids="$(list_case_ids "$dir")"
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        meta="$(extract_case_meta "$dir" "$id")"

        body="$(extract_case_text "$dir" "$id")"
        [ -n "${body//[[:space:]]/}" ] || report_violation "3層のうち題材文が欠けている: $id"

        # メタ行が題材文ブロックの内側にあると判定側へ渡ってしまうため違反とする。
        #
        # ここでパイプを使わないのは、`grep -q` が最初のマッチで即座に閉じるためである。
        # 題材文がパイプ長を超えると書き手の printf が EPIPE を受け、これが if の条件式で
        # あるため set -e は発火せず、pipefail によりパイプライン全体が非0になって
        # 「違反なし」と判定される。メタ行が判定側へ漏れたまま exit 0 で通ってしまい、
        # この検査の存在目的そのものが失われる（下の first_meta_value と同じ欠陥型で、
        # 診断ゼロで落ちる場合より帰結が重い）。
        if has_meta_line "$body"; then
            report_violation "メタ行が題材文ブロックの内側にある（判定側へ渡ってしまう）: $id"
        fi

        # 先頭1件だけが要る。パイプのどちら側も途中で閉じさせないこと。
        # `| head -n 1` で切ると読み手が先に閉じて sed が SIGPIPE を受け、逆に sed を
        # `q` で早期終了させると書き手の printf が SIGPIPE を受ける。いずれも
        # pipefail + set -e により診断ゼロのまま rc=141 で落ちる（メタ行が多い題材で発火）。
        # awk へ全行読ませ、先頭一致だけを END で返すことで両側とも最後まで生かす。
        asset="$(printf '%s\n' "$meta" | first_meta_value '資産種別')"
        [ -n "${asset//[[:space:]]/}" ] || report_violation "判定対象の資産種別が未記入: $id"

        carrier="$(printf '%s\n' "$meta" | first_meta_value '規範の担い方')"
        case "$carrier" in
            体現・強制|散文のみ|なし) ;;
            "") report_violation "規範の担い方が未記入: $id" ;;
            *)  report_violation "規範の担い方が語彙外（体現・強制／散文のみ／なし）: $id ($carrier)" ;;
        esac
    done <<< "$ids"

    # --- 期待帰結層（3層のうち第2層・第3層）と由来
    local tsv_issues
    tsv_issues="$(awk -F'\t' '
        /^#/ { next }
        $1 == "題材ID" { header=1; if (NF != 11) printf "ヘッダの列数が11でない (%d列)\n", NF; next }
        NF == 0 { next }
        {
            id = $1
            if (NF != 11) { printf "%s: 列数が11でない (%d列)\n", id, NF; next }
            if ($2 == "" || $2 == "-") printf "%s: 3層のうち「導出すべきもの」が欠けている\n", id
            for (i = 3; i <= 6; i++) if ($i == "") printf "%s: 3層のうち期待帰結（期待_項目%d）が欠けている\n", id, i - 2
            for (i = 3; i <= 6; i++) if ($i != "-" && $i !~ /^[0-9]+$/) printf "%s: 期待_項目%d が数値または - でない (%s)\n", id, i - 2, $i
            if ($7 == "" || $7 == "-") printf "%s: 3層のうち期待帰結（期待_行き先）が欠けている\n", id
            if ($8 == "" || $8 == "-") printf "%s: 由来が未記入\n", id
            else if ($8 != "改訂前から在る" && $8 != "改訂の結果として追加") printf "%s: 由来が語彙外 (%s)\n", id, $8
            if ($9 == "" || $9 == "-") printf "%s: 対の相手ID が未記入（相手が居ない場合は NONE を置く）\n", id
            if ($10 == "" || $10 == "-") printf "%s: 出所が未記入\n", id
        }
        END { if (!header) print "にヘッダ行（先頭列 題材ID）が無い" }
    ' "$dir/expectations.tsv")"
    if [ -n "$tsv_issues" ]; then
        while IFS= read -r line; do report_violation "expectations.tsv $line"; done <<< "$tsv_issues"
    fi

    # --- 対の相手ID の相互参照
    local pair_issues
    pair_issues="$(awk -F'\t' '
        /^#/ { next }
        $1 == "題材ID" { next }
        # 違反の並びが awk の実装依存にならないよう、初出時の出現順を添字つきで積む。
        NF >= 9 { if (!($1 in seen)) order[++n] = $1; partner[$1] = $9; seen[$1] = 1 }
        END {
            for (k = 1; k <= n; k++) {
                id = order[k]
                p = partner[id]
                if (p == "NONE" || p == "") continue
                if (!(p in seen)) { printf "%s: 対の相手ID が題材集合に無い (%s)\n", id, p; continue }
                if (partner[p] != id) printf "%s: 対の相手ID が相互参照になっていない (%s の相手は %s)\n", id, p, partner[p]
            }
        }
    ' "$dir/expectations.tsv")"
    if [ -n "$pair_issues" ]; then
        while IFS= read -r line; do report_violation "expectations.tsv $line"; done <<< "$pair_issues"
    fi

    if [ "$violations" -gt 0 ]; then
        printf '\n題材集合の検査に落ちた: 違反 %d 件 (%s)\n' "$violations" "$dir"
        exit 1
    fi
    printf '題材集合の検査に通った: 題材 %d 件 (%s)\n' "$(list_case_ids "$dir" | wc -l | tr -d ' ')" "$dir"
}

# ---------------------------------------------------------------- report

cmd_report() {
    [ $# -eq 2 ] || die_usage "report は引数を2つ取る（判定記録TSV・題材集合ディレクトリ）"
    local judgments dir
    normalize_path "$1"; judgments="$_normalized"
    # 題材集合ディレクトリ側の正規化は現状デッドである（この値は expfile の環境変数渡しと
    # `list_case_ids` の `grep --` 経由でしか使われず、awk のオペランドに現れない）。
    # 3つのサブコマンドで作りを揃えるために残してあり、単独変異では殺せない。理由と、
    # load-bearing になったときに足す検査はテストランナーの 09b 直前を参照。
    normalize_path "$2"; dir="$_normalized"
    [ -n "$judgments" ] || die_usage "判定記録TSV が指定されていない"
    [ -f "$judgments" ] || die_usage "判定記録TSV が存在しない: $judgments"
    [ -r "$judgments" ] || die_usage "判定記録TSV を読めない: $judgments"
    require_case_dir "$dir"

    local ids_file
    ids_file="$(mktemp -t adr-scoping-case-ids.XXXXXX)"
    # trap 本体・awk への値渡しはいずれも cmd_prompt と同じ作りに揃える（理由は
    # _cleanup_temp_files のコメント）。`-v` 渡しは代入値のエスケープ列を解釈するため、
    # 題材集合ディレクトリのパスに `\` が含まれると期待帰結ファイルを読めない。
    # これは無言のまま「差は無い」へ結論が反転する経路である。
    _cleanup_ids_file="$ids_file"
    trap _cleanup_temp_files EXIT
    list_case_ids "$dir" > "$ids_file"

    set +e
    idsfile="$ids_file" expfile="$dir/expectations.tsv" awk -F'\t' '
        function pct(n, d) { return d == 0 ? "n/a" : sprintf("%.1f%%", 100 * n / d) }
        BEGIN {
            idsfile = ENVIRON["idsfile"]
            expfile = ENVIRON["expfile"]
            nread = 0
            while ((getline line < idsfile) > 0) if (line != "") { known[line] = 1; order[++ncases] = line }
            close(idsfile)
            FS = "\t"
            while ((getline < expfile) > 0) {
                if ($0 ~ /^#/ || $1 == "題材ID" || NF < 7) continue
                for (i = 1; i <= 4; i++) exp_item[$1, i] = $(i + 2)
                exp_dest[$1] = $7
                nread++
            }
            close(expfile)
            # 期待帰結を1件も読めていないのに集計を続けると、期待帰結との差が
            # 「差は無い」と出て結論が無言で反転する。読めなかった時点で落とす。
            #
            # ここでの exit は END を飛ばさない（POSIX 規定）。END 末尾の `exit fail`
            # が終了状態を上書きするため、BEGIN で落としたつもりでも集計本文は最後まで
            # 印字され rc も 0 へ戻る。打ち切りはフラグで END の先頭へ伝える。
            #
            # 打ち切りの番兵は awk 自身が返さない 3 を選ぶ。fatal の終了状態は原因により
            # 分かれ、実測では gawk 5.2.1 が「開けないファイル → 2 / 構文エラー → 1」、
            # mawk がいずれも 2 を返す。**1 も 2 も awk 由来でありうる**ため、どちらを
            # 番兵にしても呼び出し側が読み違える。`case "$rc"` の `*)` を「1 はカバレッジ
            # 違反」と読んで分割すると、構文エラー由来の fatal が「カバレッジ検査の違反」
            # へ化ける。既定の枝は原因を断定しないままにしておくこと。
            #
            # 現に 2 を番兵にしていたときは、呼び出し側が awk の異常終了を
            # 「期待帰結を読めなかった」と読み違え、無関係な expectations.tsv の
            # パスを名指ししていた。
            if (nread == 0) {
                printf "エラー: 期待帰結を1件も読めなかった: %s\n", expfile > "/dev/stderr"
                noexp = 1
                exit 3
            }
        }
        /^#/ { next }
        $1 == "題材ID" { next }
        NF == 0 { next }
        {
            id = $1; trial = $2
            # 未知の題材ID・重複した行はどちらも出力が集計レポートへ貼り込まれる。
            # 連想配列の走査順（awk の実装依存）に委ねず、記録の出現順で並ぶよう
            # 添字つきの配列へ初出時の順序を積む（commit 列の未確定と同じ扱い）。
            if (!(id in known)) {
                if (!(id in unknown)) unknown_order[++nunknown] = id
                unknown[id] = unknown[id] " " NR
                next
            }
            key = id SUBSEP trial
            if (key in seen) {
                if (!(key in dupes)) dupe_order[++ndupes] = key
                dupes[key]++
                next
            }
            seen[key] = 1
            covered[id] = 1
            trials[trial] = 1
            for (i = 1; i <= 4; i++) { item[id, trial, i] = $(i + 2); if ($(i + 2) == "1") ones[trial, i]++ ; cnt[trial, i]++ }
            total[id, trial] = $7; dest[id, trial] = $8
            # commit 列は持つ場合のみ検査する（列を持たない記録も受け付ける）。
            # 埋め忘れ・プレースホルダのまま提出された記録を素通りさせないための検査であり、
            # 短縮ハッシュの形をしていない値は名指しで報告する。
            # 出力は集計レポートへ貼り込むため、連想配列の走査順（awk の実装依存）に
            # 委ねず、記録の出現順で並ぶよう添字つきの配列へ積む。
            if (NF >= 14 && $14 !~ /^[0-9a-f]{7,40}$/) {
                nbad++; bad_id[nbad] = id; bad_trial[nbad] = trial
                bad_col[nbad] = "対象文書commit"; bad_val[nbad] = $14
            }
            if (NF >= 15 && $15 !~ /^[0-9a-f]{7,40}$/) {
                nbad++; bad_id[nbad] = id; bad_trial[nbad] = trial
                bad_col[nbad] = "題材集合commit"; bad_val[nbad] = $15
            }
        }
        END {
            # BEGIN 側の打ち切りをここで実現する。集計本文を1行も出さずに抜けること。
            if (noexp) exit 3

            fail = 0
            print "== カバレッジ =="
            miss = 0
            for (k = 1; k <= ncases; k++) if (!(order[k] in covered)) { printf "  未カバーの題材: %s\n", order[k]; miss++ }
            for (u = 1; u <= nunknown; u++) {
                printf "  題材集合に無い題材IDの行: %s (行%s)\n", unknown_order[u], unknown[unknown_order[u]]; fail = 1
            }
            for (d = 1; d <= ndupes; d++) {
                split(dupe_order[d], a, SUBSEP); printf "  重複した行: 題材 %s 試行 %s\n", a[1], a[2]; fail = 1
            }
            if (miss > 0) fail = 1
            printf "  題材 %d 件中 %d 件を記録が覆う\n", ncases, ncases - miss

            if (nbad > 0) {
                printf "\n== commit 列の未確定 ==\n"
                for (b = 1; b <= nbad; b++)
                    printf "  %s 試行%s %s が短縮ハッシュでない: %s\n", bad_id[b], bad_trial[b], bad_col[b], bad_val[b]
                printf "  未確定 %d 件\n", nbad
                fail = 1
            }

            nt = 0; for (t in trials) tlist[++nt] = t
            n = asort_simple(tlist, nt)

            printf "\n== 試行間一致（セル単位。項目1〜4 を1セルと数える） ==\n"
            if (nt < 2) {
                print "  試行が2つ未満のため一致は測れない"
            } else {
                t1 = tlist[1]; t2 = tlist[2]
                if (nt > 2) printf "  試行が %d つあるため、試行 %s と 試行 %s のみを比較した（他の試行は一致の計算に入れていない）\n", nt, t1, t2
                agree = 0; cells = 0
                for (k = 1; k <= ncases; k++) {
                    id = order[k]
                    for (i = 1; i <= 4; i++) {
                        if ((id, t1, i) in item && (id, t2, i) in item) {
                            cells++
                            if (item[id, t1, i] == item[id, t2, i]) { agree++; iagree[i]++ }
                            icells[i]++
                        }
                    }
                }
                printf "  試行 %s と 試行 %s: 一致 %d / %d セル (%s)\n", t1, t2, agree, cells, pct(agree, cells)
                for (i = 1; i <= 4; i++) printf "    項目%d: 一致 %d / %d (%s)\n", i, iagree[i], icells[i], pct(iagree[i], icells[i])
                tagree = 0; tcells = 0
                for (k = 1; k <= ncases; k++) {
                    id = order[k]
                    if ((id, t1) in total && (id, t2) in total) { tcells++; if (total[id, t1] == total[id, t2]) tagree++ }
                }
                printf "    合計: 一致 %d / %d (%s)\n", tagree, tcells, pct(tagree, tcells)
                dagree = 0; dcells = 0
                for (k = 1; k <= ncases; k++) {
                    id = order[k]
                    if ((id, t1) in dest && (id, t2) in dest) { dcells++; if (dest[id, t1] == dest[id, t2]) dagree++ }
                }
                printf "    行き先: 一致 %d / %d (%s)\n", dagree, dcells, pct(dagree, dcells)
            }

            printf "\n== 各項目の1点率（周辺分布。試行ごと） ==\n"
            for (j = 1; j <= nt; j++) {
                t = tlist[j]
                printf "  試行 %s:", t
                for (i = 1; i <= 4; i++) printf "  項目%d %s (%d/%d)", i, pct(ones[t, i], cnt[t, i]), ones[t, i], cnt[t, i]
                printf "\n"
            }

            printf "\n== 期待帰結との差 ==\n"
            ndiff = 0
            for (k = 1; k <= ncases; k++) {
                id = order[k]
                for (j = 1; j <= nt; j++) {
                    t = tlist[j]
                    for (i = 1; i <= 4; i++) {
                        if (!((id, t, i) in item)) continue
                        if (exp_item[id, i] != "" && exp_item[id, i] != "-" && item[id, t, i] != exp_item[id, i]) {
                            printf "  %s 試行%s 項目%d: 期待 %s / 判定 %s\n", id, t, i, exp_item[id, i], item[id, t, i]; ndiff++
                        }
                    }
                    if ((id, t) in dest && exp_dest[id] != "" && exp_dest[id] != "-" && dest[id, t] != exp_dest[id]) {
                        printf "  %s 試行%s 行き先: 期待 %s / 判定 %s\n", id, t, exp_dest[id], dest[id, t]; ndiff++
                    }
                }
            }
            if (ndiff == 0) print "  差は無い"
            else printf "  差 %d 件\n", ndiff

            exit fail
        }
        # 試行番号は連想配列の添字（＝文字列）として集めるため、素朴に `<` で比べると
        # "10" < "2" となり、試行が10以上あると並びが崩れる（「試行1と試行2を比較した」の
        # 対象が試行1と試行10になる）。両辺が10進数の形をしている場合だけ数値で比べる。
        function lt(a, b) {
            if (a ~ /^[0-9]+$/ && b ~ /^[0-9]+$/) return (a + 0) < (b + 0)
            return a "" < b ""
        }
        function asort_simple(arr, n,   i, j, tmp) {
            for (i = 1; i < n; i++) for (j = i + 1; j <= n; j++) if (lt(arr[j], arr[i])) { tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp }
            return n
        }
    ' "$judgments"
    local rc=$?
    set -e
    rm -f -- "$ids_file"
    _cleanup_ids_file=""

    # awk の終了状態を一律で畳まない。畳むと、期待帰結を読めずに打ち切った場合まで
    # 「カバレッジ検査に落ちた」と表示され、末尾のラベルが原因を取り違える。
    # 終了状態そのものは仕様どおり 1（検査に落ちた）へ寄せる。
    #
    # 3 は本スクリプトが BEGIN で立てる打ち切りの番兵である（awk 自身は返さない値）。
    # それ以外の非0 には awk の fatal が混じり、その終了状態は原因により 1 にも 2 にも
    # なる（BEGIN 側のコメント参照）。したがって既定の枝を「1 はカバレッジ違反」と
    # 分割してはならない。判定記録TSV を名指ししたうえで、カバレッジ以外の原因も
    # ありうる表現に留める。
    case "$rc" in
        0) ;;
        3)
            printf '\n期待帰結を読めなかったため集計を打ち切った: %s\n' "$dir/expectations.tsv" >&2
            exit 1
            ;;
        *)
            printf '\n判定記録の集計に失敗した（カバレッジ検査の違反、または集計そのものの異常終了）: %s\n' "$judgments" >&2
            exit 1
            ;;
    esac
}

# ---------------------------------------------------------------- 分岐

[ $# -ge 1 ] || die_usage "サブコマンドが指定されていない"
subcommand="$1"
shift

case "$subcommand" in
    prompt)   cmd_prompt "$@" ;;
    validate) cmd_validate "$@" ;;
    report)   cmd_report "$@" ;;
    -h|--help|help) usage; exit 0 ;;
    *) die_usage "サブコマンドが不明: $subcommand" ;;
esac
