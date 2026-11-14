#!/usr/bin/env bash
# ADR 分割の逐語照合器
#
# 多決定 ADR を分割したあとの締めの検査のうち、網羅性と逐語性を機械で実行する。
# 呼び出し側の手順（いつ実行し、結果をどう読むか）は
# `../skills/manage-adr/references/transitions.md`「分割（多決定 ADR の部分上書き）」節が定める。
# ここが持つのは入力の契約・切り出し規則・判定条件と、その採用理由である。
#
# 入力は原 ADR と、決定の振り分けを書いた対応表の2つ。対応表は1行に1決定を書く。
#   <原決定番号> <後継 ADR> <後継決定番号>   後継へ逐語転記した決定
#   <原決定番号> retire                      core 反転中で退役する決定
#   <原決定番号> keep                        後継を立てず原 ADR の凍結記録に残す決定
# `<後継 ADR>` は原 ADR と同じディレクトリにあるファイルの名前で書く（`.md` は省略してよい）。
# ADR はフラットに置く規約であり、パスを許すと同じ対応表が実行場所によって別のファイルを指す。
# 空行と、先頭の空白を除いて `#` で始まる行は読み飛ばす。
# 振り分けの語を英語の固定語にしているのは、対応表が導入先のリポジトリへ残らない一時的な入力であり、
# ADR の本文に書く語（状態の値・節の見出し）と違って導入先の言語に合わせる必要が無いためである。
#
# 切り出し規則: `## Decision` 節（次の `## ` 見出しの直前まで）のトップレベル決定を単位とする。
# トップレベル決定の書き方は次の2形式を認める。節の中に `### <番号>.` 見出しが1つでもあれば見出し形式、
# 無ければ箇条形式として読む。
#   - 見出し形式: `### <番号>.` の行から、次の `#`〜`###` 見出しの直前まで（`####` 以下は本文に含む）
#   - 箇条形式: 行頭の `<番号>. ` の行から、項目の外の行が現れる直前まで。空行と、空白で字下げした
#     行は項目の続きとして含む。行頭が空白でない行も、空行を挟まずに続き、ブロックを始める形
#     （`- ` 等の箇条・`>`・`#`・`|`・`<`・区切り線）でなければ続きとして含む（Markdown の遅延継続行）。
#     遅延継続行を外すと、その行の書き換えが両辺から黙って消え、合格に化けるためである
# フェンス（``` または ~~~）の内側の行は、見出しとも項目の始まりとも扱わない。
# 各決定は末尾の空行を落とし、見出し形式では見出し直後の空行も落とす。
# 先頭番号は `N` へ正規化して比較する（分割の手順は後継での番号の振り直しを許す）。
# 番号付きの決定より前に置くリード文と、番号を持たない `###` 見出しの節は決定本文に含めない
# （手順はリード文等の非決定文を逐語の対象から外している）。
# 項目の同定は見出しの文字列で行い、行番号を使わない。原 ADR は分割の途中で front-matter と
# `## 関連ADR` が伸びるため、行番号でアンカーすると操作の途中で全項目がずれ、正しい成果物を誤って
# 不合格にする。
#
# 判定条件（後継ごと）:
#   1. 差分ゼロ — 原 ADR から切り出した担当決定（後継決定番号の昇順に連結）と、後継の
#      `## Decision` の全トップレベル決定（ファイル内の順に連結）が一致する。右辺を後継の全決定に
#      取るため、後継にだけある決定（退役する決定の混入、分割中に書き足した決定）も差分として現れる
#   2. 両辺とも非空 — 対応表が指す決定がどちらの側でも見つかる
#   3. 行数一致 — 両辺の行数が等しい
# 2・3 を差分ゼロと別に判定するのは、正規化や切り出しの失敗が空入力として差分ゼロに化けるため。
# あわせて網羅性として、原 ADR のトップレベル決定がそれぞれ対応表にちょうど1回現れることを確かめる。
# 逐語転記の行が1つも無い対応表は、何も照合しないまま合格にしないよう不合格とする。
#
# 対象外: `## Consequences` は照合しない（分割は帰結を意図的に再構成するため差分ゼロを要求できない）。
# 対応表の導出もしない（どの決定をどこへ移すかは分割する者の判断であり、ここへの入力である）。
#
# 本スクリプトは連想配列を使わない。awk は POSIX の範囲で書く。
#
# 使い方:
#   bash verify-split-verbatim.sh <原 ADR のパス> <対応表のパス>
#
# exit code:
#   0: 網羅性と、全後継の逐語性が成り立つ
#   1: 網羅性か逐語性が成り立たない（差分・空の切り出し・行数の不一致・未分類・重複を含む）
#   2: 入力の誤り（引数の数、ファイルが無い、対応表の行の書式）
set -euo pipefail

usage() {
    echo "使い方: bash verify-split-verbatim.sh <原 ADR のパス> <対応表のパス>" >&2
}

if [ "$#" -ne 2 ]; then
    usage
    exit 2
fi

ORIGINAL="$1"
MAPPING="$2"

if [ ! -f "$ORIGINAL" ]; then
    echo "エラー: 原 ADR が見つかりません: $ORIGINAL" >&2
    exit 2
fi
if [ ! -f "$MAPPING" ]; then
    echo "エラー: 対応表が見つかりません: $MAPPING" >&2
    exit 2
fi

ADR_DIR="$(dirname "$ORIGINAL")"
ORIGINAL_NAME="$(basename "$ORIGINAL")"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/verify-split-verbatim.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# `## Decision` 節のトップレベル決定を切り出す。
# 引数: $1 ADR のパス / $2 出力先ディレクトリ
# 出力先へ、決定ごとに `<番号>.txt`（先頭番号を正規化した本文）と、見つかった番号を出現順に並べた
# `order` を書く。`## Decision` 節が無い場合は `order` を作らず `nosection` を作る。
extract_decisions() {
    local file="$1" out="$2"
    mkdir -p "$out"
    awk -v out="$out" '
        function is_fence(s) { return s ~ /^ ? ? ?(```|~~~)/ }
        function flush(   i, last, first) {
            if (cur == "") return
            last = n
            while (last > 1 && buf[last] ~ /^[ \t]*$/) last--
            first = 2
            if (mode == "heading") {
                while (first <= last && buf[first] ~ /^[ \t]*$/) first++
            }
            path = out "/" cur ".txt"
            print buf[1] > path
            for (i = first; i <= last; i++) print buf[i] > path
            close(path)
            print cur > (out "/order")
            cur = ""
            n = 0
        }
        { sub(/\r$/, "") }
        { lines[NR] = $0 }
        END {
            # 1巡目: 節の範囲と形式を決める
            start = 0; stop = NR; fence = 0
            for (i = 1; i <= NR; i++) {
                if (is_fence(lines[i])) { fence = !fence; continue }
                if (fence) continue
                if (start == 0) {
                    if (lines[i] ~ /^## Decision[ \t]*$/) start = i + 1
                    continue
                }
                if (lines[i] ~ /^## /) { stop = i - 1; break }
            }
            if (start == 0) {
                printf "" > (out "/nosection")
                exit 0
            }
            printf "" > (out "/order")
            close(out "/order")
            mode = "list"
            fence = 0
            for (i = start; i <= stop; i++) {
                if (is_fence(lines[i])) { fence = !fence; continue }
                if (!fence && lines[i] ~ /^###[ \t]+[0-9]+\.([ \t]|$)/) { mode = "heading"; break }
            }
            # 2巡目: 決定を切り出す
            fence = 0; cur = ""; n = 0
            for (i = start; i <= stop; i++) {
                line = lines[i]
                if (is_fence(line)) {
                    fence = !fence
                    if (cur != "") buf[++n] = line
                    continue
                }
                if (fence) {
                    if (cur != "") buf[++n] = line
                    continue
                }
                if (mode == "heading") {
                    if (line ~ /^###[ \t]+[0-9]+\.([ \t]|$)/) {
                        flush()
                        num = line
                        sub(/^###[ \t]+/, "", num)
                        sub(/\..*$/, "", num)
                        cur = num + 0
                        norm = line
                        sub(/[0-9]+\./, "N.", norm)
                        buf[++n] = norm
                        continue
                    }
                    if (line ~ /^#(#(#)?)?[ \t]/ || line ~ /^#(#(#)?)?$/) { flush(); continue }
                } else {
                    if (line ~ /^[0-9]+\.[ \t]/) {
                        flush()
                        num = line
                        sub(/\..*$/, "", num)
                        cur = num + 0
                        norm = line
                        sub(/^[0-9]+\./, "N.", norm)
                        buf[++n] = norm
                        continue
                    }
                    if (line ~ /^[^ \t]/) {
                        # 空行を挟まずに続き、ブロックを始めない行は遅延継続行として項目に含める
                        if (cur != "" && n > 0 && buf[n] !~ /^[ \t]*$/ && line !~ /^([-*+]([ \t]|$)|>|#|\||<|\*\*\*+[ \t]*$|---+[ \t]*$|___+[ \t]*$)/) {
                            buf[++n] = line
                            continue
                        }
                        flush(); continue
                    }
                }
                if (cur != "") buf[++n] = line
            }
            flush()
        }
    ' "$file"
}

# 対応表を読む。行の書式の誤りは exit 2 で止める。
MAP_ORIG=()
MAP_DEST=()
MAP_SUCC_NO=()
lineno=0
while IFS= read -r raw || [ -n "$raw" ]; do
    lineno=$((lineno + 1))
    raw="${raw%$'\r'}"
    trimmed="${raw#"${raw%%[![:space:]]*}"}"
    case "$trimmed" in
        '' | '#'*) continue ;;
    esac
    # 空白で区切って読む。`set -- $trimmed` と違い、`*` などのグロブ文字を展開しない。
    read -r -a fields <<<"$trimmed"
    if [ "${#fields[@]}" -eq 3 ]; then
        orig="${fields[0]}" dest="${fields[1]}" succ_no="${fields[2]}"
        if [[ ! "$succ_no" =~ ^[0-9]+$ ]]; then
            echo "エラー: 対応表 ${lineno} 行目: 後継決定番号が数字ではありません: $succ_no" >&2
            exit 2
        fi
        case "$dest" in
            */*)
                echo "エラー: 対応表 ${lineno} 行目: 後継 ADR はパスではなくファイルの名前で書きます: $dest" >&2
                exit 2
                ;;
        esac
        dest="${dest%.md}.md"
        if [ ! -f "$ADR_DIR/$dest" ]; then
            echo "エラー: 対応表 ${lineno} 行目: 後継 ADR が原 ADR と同じディレクトリに見つかりません: $ADR_DIR/$dest" >&2
            exit 2
        fi
        if [ "$dest" = "$ORIGINAL_NAME" ]; then
            echo "エラー: 対応表 ${lineno} 行目: 後継 ADR に原 ADR 自身が書かれています: $dest" >&2
            exit 2
        fi
        succ_no=$((10#$succ_no))
    elif [ "${#fields[@]}" -eq 2 ] && { [ "${fields[1]}" = "retire" ] || [ "${fields[1]}" = "keep" ]; }; then
        orig="${fields[0]}" dest="${fields[1]}" succ_no=""
    else
        echo "エラー: 対応表 ${lineno} 行目の書式が不正です: $trimmed" >&2
        echo "  <原決定番号> <後継 ADR> <後継決定番号> / <原決定番号> retire / <原決定番号> keep のいずれかで書きます。" >&2
        exit 2
    fi
    if [[ ! "$orig" =~ ^[0-9]+$ ]]; then
        echo "エラー: 対応表 ${lineno} 行目: 原決定番号が数字ではありません: $orig" >&2
        exit 2
    fi
    MAP_ORIG+=("$((10#$orig))")
    MAP_DEST+=("$dest")
    MAP_SUCC_NO+=("$succ_no")
done <"$MAPPING"

if [ "${#MAP_ORIG[@]}" -eq 0 ]; then
    echo "NG: 対応表に決定の行が1つもありません: $MAPPING"
    echo "結果: 不合格（1 件）"
    exit 1
fi

failures=0
fail() {
    echo "NG: $*"
    failures=$((failures + 1))
}

# 原 ADR の切り出し
extract_decisions "$ORIGINAL" "$WORK/original"
if [ -e "$WORK/original/nosection" ]; then
    fail "原 ADR に \`## Decision\` 節がありません: $ORIGINAL"
    echo "結果: 不合格（${failures} 件）"
    exit 1
fi
if [ ! -s "$WORK/original/order" ]; then
    fail "原 ADR の \`## Decision\` 節からトップレベル決定を1件も切り出せません（\`### <番号>.\` 見出しか行頭の \`<番号>. \` 項目で書かれていない）: $ORIGINAL"
fi
for dup in $(sort -n "$WORK/original/order" | uniq -d); do
    fail "原 ADR に決定 ${dup} が2回以上あります（決定を一意に同定できない）"
done

# 網羅性: 原 ADR の各決定が対応表にちょうど1回現れる
count_transfer=0
count_retire=0
count_keep=0
for i in "${!MAP_ORIG[@]}"; do
    case "${MAP_DEST[$i]}" in
        retire) count_retire=$((count_retire + 1)) ;;
        keep) count_keep=$((count_keep + 1)) ;;
        *) count_transfer=$((count_transfer + 1)) ;;
    esac
done
original_total="$(sort -n -u "$WORK/original/order" | grep -c . || true)"
echo "網羅性: 原 ADR のトップレベル決定 ${original_total} 件 / 対応表 転記 ${count_transfer}・retire ${count_retire}・keep ${count_keep}"
for dup in $(printf '%s\n' ${MAP_ORIG[@]+"${MAP_ORIG[@]}"} | sort -n | uniq -d); do
    fail "網羅性: 原 ADR の決定 ${dup} が対応表に2回以上あります（行き先は1つに限る）"
done
while IFS= read -r num; do
    [ -n "$num" ] || continue
    found=0
    for o in ${MAP_ORIG[@]+"${MAP_ORIG[@]}"}; do
        if [ "$o" = "$num" ]; then
            found=1
            break
        fi
    done
    if [ "$found" -eq 0 ]; then
        fail "網羅性: 原 ADR の決定 ${num} が対応表にありません（未分類）"
    fi
done < <(sort -n -u "$WORK/original/order")
for i in "${!MAP_ORIG[@]}"; do
    if ! grep -qx "${MAP_ORIG[$i]}" "$WORK/original/order"; then
        fail "原 ADR に決定 ${MAP_ORIG[$i]} が見つかりません（切り出し結果が空。見出しの表記か対応表の誤り）"
    fi
done

if [ "$count_transfer" -eq 0 ]; then
    fail "対応表に逐語転記の行がありません（照合する後継が無い）"
fi

# 逐語性: 後継ごとに照合する（後継は対応表に現れた順）
SUCCESSORS=()
for i in "${!MAP_DEST[@]}"; do
    dest="${MAP_DEST[$i]}"
    case "$dest" in retire | keep) continue ;; esac
    seen=0
    for s in ${SUCCESSORS[@]+"${SUCCESSORS[@]}"}; do
        if [ "$s" = "$dest" ]; then
            seen=1
            break
        fi
    done
    [ "$seen" -eq 1 ] || SUCCESSORS+=("$dest")
done

sidx=0
for succ in ${SUCCESSORS[@]+"${SUCCESSORS[@]}"}; do
    sidx=$((sidx + 1))
    sdir="$WORK/successor-$sidx"
    extract_decisions "$ADR_DIR/$succ" "$sdir"
    if [ -e "$sdir/nosection" ]; then
        fail "$succ: 後継に \`## Decision\` 節がありません（切り出し結果が空）"
        continue
    fi
    if [ ! -s "$sdir/order" ]; then
        fail "$succ: 後継の \`## Decision\` 節からトップレベル決定を1件も切り出せません（切り出し結果が空）"
        continue
    fi
    succ_ok=1
    for dup in $(sort -n "$sdir/order" | uniq -d); do
        fail "$succ: 後継に決定 ${dup} が2回以上あります（決定を一意に同定できない）"
        succ_ok=0
    done

    # この後継へ転記した行を、後継決定番号の昇順に並べる
    pairs="$(for i in "${!MAP_DEST[@]}"; do
        if [ "${MAP_DEST[$i]}" = "$succ" ]; then
            printf '%s %s\n' "${MAP_SUCC_NO[$i]}" "${MAP_ORIG[$i]}"
        fi
    done | sort -n -k1,1)"
    for dup in $(printf '%s\n' "$pairs" | awk '{print $1}' | uniq -d); do
        fail "$succ: 対応表で後継の決定 ${dup} に2つ以上の原決定が対応しています"
        succ_ok=0
    done

    left="$WORK/left-$sidx.txt"
    right="$WORK/right-$sidx.txt"
    : >"$left"
    : >"$right"
    labels=()
    while read -r sno ono; do
        [ -n "$sno" ] || continue
        labels+=("原${ono}→${sno}")
        if [ ! -s "$WORK/original/$ono.txt" ]; then
            succ_ok=0
            continue
        fi
        if ! grep -qx "$sno" "$sdir/order"; then
            fail "$succ: 後継に決定 ${sno} が見つかりません（切り出し結果が空。見出しの表記か対応表の誤り）"
            succ_ok=0
            continue
        fi
        cat "$WORK/original/$ono.txt" >>"$left"
        echo >>"$left"
    done <<<"$pairs"
    while IFS= read -r sno; do
        cat "$sdir/$sno.txt" >>"$right"
        echo >>"$right"
    done <"$sdir/order"

    if [ "$succ_ok" -eq 0 ]; then
        echo "NG: $succ: 照合の前提が欠けるため差分を判定しません（${labels[*]-}）"
        continue
    fi
    if ! grep -q '[^[:space:]]' "$left" || ! grep -q '[^[:space:]]' "$right"; then
        fail "$succ: 切り出し結果が空です（左辺 $(wc -l <"$left" | tr -d ' ') 行・右辺 $(wc -l <"$right" | tr -d ' ') 行）"
        continue
    fi
    left_lines="$(wc -l <"$left" | tr -d ' ')"
    right_lines="$(wc -l <"$right" | tr -d ' ')"
    verdict_ok=1
    if [ "$left_lines" -ne "$right_lines" ]; then
        fail "$succ: 行数が一致しません（原 ADR 側 ${left_lines} 行・後継側 ${right_lines} 行）"
        verdict_ok=0
    fi
    if ! diff -u -L "原 ADR: $ORIGINAL_NAME（${labels[*]}）" -L "後継: $succ" "$left" "$right" >"$WORK/diff-$sidx.txt"; then
        fail "$succ: 決定本文に差分があります（${labels[*]}）"
        cat "$WORK/diff-$sidx.txt"
        verdict_ok=0
    fi
    if [ "$verdict_ok" -eq 1 ]; then
        echo "OK: $succ: 逐語一致（${labels[*]}・${left_lines} 行）"
    fi
done

if [ "$failures" -gt 0 ]; then
    echo "結果: 不合格（${failures} 件）"
    exit 1
fi
echo "結果: 合格"
exit 0
