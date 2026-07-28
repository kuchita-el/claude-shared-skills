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
#   1 題材ID / 2 導出すべきもの / 3-6 期待_項目1〜4 / 7 期待_合計 / 8 期待_行き先
#   9 由来 / 10 対の相手ID / 11 出所 / 12 備考
#
# 判定記録TSV の列（タブ区切り。`#` 始まりの行は注記として読み飛ばす）:
#   1 題材ID / 2 試行番号 / 3-6 項目1〜4 / 7 合計 / 8 行き先
#   9-12 根拠_項目1〜4 / 13 参照ファイル一覧 / 14 対象文書commit
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

# 題材集合ディレクトリの契約を検査する。$2 が "with-template" のとき雛形の存在も見る。
require_case_dir() {
    local dir="$1"
    local need_template="${2:-}"
    [ -n "$dir" ] || die_usage "題材集合ディレクトリが指定されていない"
    [ -d "$dir" ] || die_usage "題材集合ディレクトリが存在しない: $dir"

    local missing=()
    [ -f "$dir/cases.md" ] || missing+=("cases.md")
    [ -f "$dir/expectations.tsv" ] || missing+=("expectations.tsv")
    if [ "$need_template" = "with-template" ]; then
        [ -f "$dir/prompt-template.md" ] || missing+=("prompt-template.md")
    fi
    if [ ${#missing[@]} -gt 0 ]; then
        printf 'エラー: 題材集合ディレクトリに必要なファイルが無い: %s\n' "$dir" >&2
        printf '  欠けているファイル: %s\n' "${missing[*]}" >&2
        exit 2
    fi
}

# cases.md の題材ID を出現順に列挙する。
list_case_ids() {
    grep -oE '^## [A-Za-z0-9_-]+' "$1/cases.md" | sed 's/^## //'
}

# expectations.tsv の題材ID を出現順に列挙する（注記行とヘッダ行を除く）。
list_expectation_ids() {
    awk -F'\t' '!/^#/ && NR>0 && $1!="題材ID" && NF>0 {print $1}' "$1/expectations.tsv"
}

# cases.md から題材1件分の題材文ブロックだけを取り出す。
extract_case_text() {
    local dir="$1" case_id="$2"
    awk -v id="$case_id" '
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
    local doc_path="$1" case_id="$2" dir="$3"

    [ -f "$doc_path" ] || die_usage "対象文書が存在しない: $doc_path"
    [ -r "$doc_path" ] || die_usage "対象文書を読めない: $doc_path"
    require_case_dir "$dir" with-template

    if ! list_case_ids "$dir" | grep -qx -- "$case_id"; then
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
    body_file="$(mktemp -t adr-scoping-case-body.XXXXXX)"
    printf '%s\n' "$body" > "$body_file"

    # 雛形の差し込み記号を置換する。題材文は複数行のため行ごと流し込む。
    awk -v doc="$doc_path" -v cid="$case_id" -v bodyfile="$body_file" '
        {
            gsub(/\{\{対象文書パス\}\}/, doc)
            gsub(/\{\{題材ID\}\}/, cid)
            if ($0 ~ /\{\{題材文\}\}/) {
                while ((getline line < bodyfile) > 0) print line
                close(bodyfile)
                next
            }
            print
        }
    ' "$dir/prompt-template.md" > "$out"
    rm -f "$body_file"

    printf '%s\n' "$out"
}

# ---------------------------------------------------------------- validate

cmd_validate() {
    [ $# -eq 1 ] || die_usage "validate は引数を1つ取る（題材集合ディレクトリ）"
    local dir="$1"
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
    local ids id block asset carrier body
    ids="$(list_case_ids "$dir")"
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        block="$(awk -v id="$id" '$0 == "## " id {in_case=1; next} in_case && /^## / {exit} in_case {print}' "$dir/cases.md")"

        body="$(extract_case_text "$dir" "$id")"
        [ -n "${body//[[:space:]]/}" ] || report_violation "3層のうち題材文が欠けている: $id"

        asset="$(printf '%s\n' "$block" | sed -n 's/^- 資産種別:[[:space:]]*//p' | head -n 1)"
        [ -n "${asset//[[:space:]]/}" ] || report_violation "判定対象の資産種別が未記入: $id"

        carrier="$(printf '%s\n' "$block" | sed -n 's/^- 規範の担い方:[[:space:]]*//p' | head -n 1)"
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
        $1 == "題材ID" { header=1; if (NF != 12) printf "ヘッダの列数が12でない (%d列)\n", NF; next }
        NF == 0 { next }
        {
            id = $1
            if (NF != 12) { printf "%s: 列数が12でない (%d列)\n", id, NF; next }
            if ($2 == "" || $2 == "-") printf "%s: 3層のうち「導出すべきもの」が欠けている\n", id
            for (i = 3; i <= 6; i++) if ($i == "" || $i == "-") printf "%s: 3層のうち期待帰結（期待_項目%d）が欠けている\n", id, i - 2
            if ($7 == "" || $7 == "-") printf "%s: 3層のうち期待帰結（期待_合計）が欠けている\n", id
            if ($8 == "" || $8 == "-") printf "%s: 3層のうち期待帰結（期待_行き先）が欠けている\n", id
            if ($9 == "" || $9 == "-") printf "%s: 由来が未記入\n", id
            else if ($9 != "改訂前から在る" && $9 != "改訂の結果として追加") printf "%s: 由来が語彙外 (%s)\n", id, $9
            if ($10 == "" || $10 == "-") printf "%s: 対の相手ID が未記入（相手が居ない場合は NONE を置く）\n", id
            if ($11 == "" || $11 == "-") printf "%s: 出所が未記入\n", id
            # 期待_合計が期待_項目1〜4 の和であること（4項目すべてが数値のときのみ検査する）
            n = 0
            for (i = 3; i <= 6; i++) if ($i ~ /^[0-9]+$/) n++
            if (n == 4 && $7 ~ /^[0-9]+$/ && $7 != $3 + $4 + $5 + $6)
                printf "%s: 期待_合計が期待_項目1〜4 の和と一致しない (%s != %d)\n", id, $7, $3 + $4 + $5 + $6
        }
        END { if (!header) print "expectations.tsv にヘッダ行（先頭列 題材ID）が無い" }
    ' "$dir/expectations.tsv")"
    if [ -n "$tsv_issues" ]; then
        while IFS= read -r line; do report_violation "expectations.tsv $line"; done <<< "$tsv_issues"
    fi

    # --- 対の相手ID の相互参照
    local pair_issues
    pair_issues="$(awk -F'\t' '
        /^#/ { next }
        $1 == "題材ID" { next }
        NF >= 10 { partner[$1] = $10; seen[$1] = 1 }
        END {
            for (id in partner) {
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
    local judgments="$1" dir="$2"
    [ -f "$judgments" ] || die_usage "判定記録TSV が存在しない: $judgments"
    require_case_dir "$dir"

    local ids_file
    ids_file="$(mktemp -t adr-scoping-case-ids.XXXXXX)"
    list_case_ids "$dir" > "$ids_file"

    set +e
    awk -F'\t' -v idsfile="$ids_file" -v expfile="$dir/expectations.tsv" '
        function pct(n, d) { return d == 0 ? "n/a" : sprintf("%.1f%%", 100 * n / d) }
        BEGIN {
            while ((getline line < idsfile) > 0) if (line != "") { known[line] = 1; order[++ncases] = line }
            close(idsfile)
            FS = "\t"
            while ((getline < expfile) > 0) {
                if ($0 ~ /^#/ || $1 == "題材ID" || NF < 8) continue
                for (i = 1; i <= 4; i++) exp_item[$1, i] = $(i + 2)
                exp_total[$1] = $7; exp_dest[$1] = $8
            }
            close(expfile)
        }
        /^#/ { next }
        $1 == "題材ID" { next }
        NF == 0 { next }
        {
            id = $1; trial = $2
            if (!(id in known)) { unknown[id] = unknown[id] " " NR; next }
            key = id SUBSEP trial
            if (key in seen) { dupes[key]++ ; next }
            seen[key] = 1
            covered[id] = 1
            trials[trial] = 1
            for (i = 1; i <= 4; i++) { item[id, trial, i] = $(i + 2); if ($(i + 2) == "1") ones[trial, i]++ ; cnt[trial, i]++ }
            total[id, trial] = $7; dest[id, trial] = $8
        }
        END {
            fail = 0
            print "== カバレッジ =="
            miss = 0
            for (k = 1; k <= ncases; k++) if (!(order[k] in covered)) { printf "  未カバーの題材: %s\n", order[k]; miss++ }
            for (u in unknown) { printf "  題材集合に無い題材IDの行: %s (行%s)\n", u, unknown[u]; fail = 1 }
            for (d in dupes) { split(d, a, SUBSEP); printf "  重複した行: 題材 %s 試行 %s\n", a[1], a[2]; fail = 1 }
            if (miss > 0) fail = 1
            printf "  題材 %d 件中 %d 件を記録が覆う\n", ncases, ncases - miss

            nt = 0; for (t in trials) tlist[++nt] = t
            n = asort_simple(tlist, nt)

            printf "\n== 試行間一致（セル単位。項目1〜4 を1セルと数える） ==\n"
            if (nt < 2) {
                print "  試行が2つ未満のため一致は測れない"
            } else {
                t1 = tlist[1]; t2 = tlist[2]
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
                    if ((id, t) in total && exp_total[id] != "" && exp_total[id] != "-" && total[id, t] != exp_total[id]) {
                        printf "  %s 試行%s 合計: 期待 %s / 判定 %s\n", id, t, exp_total[id], total[id, t]; ndiff++
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
        function asort_simple(arr, n,   i, j, tmp) {
            for (i = 1; i < n; i++) for (j = i + 1; j <= n; j++) if (arr[j] < arr[i]) { tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp }
            return n
        }
    ' "$judgments"
    local rc=$?
    set -e
    rm -f "$ids_file"

    if [ "$rc" -ne 0 ]; then
        printf '\n判定記録のカバレッジ検査に落ちた: %s\n' "$judgments" >&2
        exit 1
    fi
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
