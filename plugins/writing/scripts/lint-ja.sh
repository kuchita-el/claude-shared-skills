#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s --file PATH | --diff BASE -- PATH...\n' "${0##*/}" >&2
}

mode=''
file=''
base=''
paths=()
while (($#)); do
  case "$1" in
    --file)
      [[ -z "$mode" && $# -ge 2 ]] || { usage; exit 2; }
      mode=file; file=$2; shift 2
      ;;
    --diff)
      [[ -z "$mode" && $# -ge 2 ]] || { usage; exit 2; }
      mode=diff; base=$2; shift 2
      [[ "${1:-}" == -- ]] || { usage; exit 2; }
      shift
      (($#)) || { usage; exit 2; }
      paths=("$@")
      break
      ;;
    *) usage; exit 2 ;;
  esac
done
[[ -n "$mode" ]] || { usage; exit 2; }

declare -a inputs=()
target_dir=$(mktemp -d)
trap 'rm -rf "$target_dir"' EXIT
targets="$target_dir/targets.tsv"
: > "$targets"

if [[ "$mode" == file ]]; then
  [[ -f "$file" ]] || { printf '入力ファイルが無い: %s\n' "$file" >&2; exit 2; }
  inputs=("$file")
  printf '*\t%s\n' "$file" > "$targets"
else
  for path in "${paths[@]}"; do
    [[ -f "$path" ]] || continue
    inputs+=("$path")
    if ! git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
      # A new writer output is not in git diff yet, so the whole file is the diff.
      printf '*\t%s\n' "$path" >> "$targets"
      continue
    fi
    git diff --unified=0 --no-color "$base" -- "$path" |
      awk -v path="$path" '
        /^\+\+\+ / { next }
        /^@@/ {
          h=$0
          # 新側の開始行だけを読む。見出しの文脈部にある + を拾わないよう、
          # 旧側（-a,b）を飛ばして最初の + で止める。件数の省略形（+c）も扱う。
          sub(/^@@ [^+]*\+/, "", h)
          sub(/ .*/, "", h)
          n=split(h, range, ",")
          next_line=range[1] + 0
          # 削除だけのハンク（+c,0）は、新側の c 行と c+1 行を隣り合わせる。
          # その境目をまたぐ文を検査できるよう、境目の印（j の後に c）を残す。
          if (n == 2 && range[2] == "0") printf "j%d\t%s\n", next_line, path
          next
        }
        /^\+/ {
          printf "%d\t%s\n", next_line, path
          next_line++
        }
      ' >> "$targets"
  done
fi

limit=100
profile="${CLAUDE_PROJECT_DIR:-}/.claude/writing/type-profiles.md"
if [[ -n "${CLAUDE_PROJECT_DIR:-}" && -f "$profile" ]]; then
  parsed=$(awk -F'|' '/\|[[:space:]]*汎用[[:space:]]*\|/ { gsub(/[^0-9]/, "", $5); print $5; exit }' "$profile")
  [[ "$parsed" =~ ^[0-9]+$ ]] && limit=$parsed
fi

status=0
while IFS=$'\t' read -r path; do
  [[ -n "$path" && -f "$path" ]] || continue
  target_file="$target_dir/target-lines"
  awk -F'\t' -v path="$path" '$2 == path { print $1 }' "$targets" > "$target_file"
  set +e
  awk -v path="$path" -v limit="$limit" -v target_file="$target_file" '
    BEGIN {
      all=0
      while ((getline target < target_file) > 0) {
        if (target == "*") all=1
        else if (target ~ /^j/) joined[substr(target, 2)]=1
        else wanted[target]=1
      }
      close(target_file)
      join_pending=0
      sentence=""
      sentence_start=1
      sentence_target=all
      bad=0
      in_code=0
    }
    function marked(line) { return all || (line in wanted) }
    function finish() {
      if (sentence != "" && length(sentence) > limit && sentence_target) {
        printf "%s:%d:一文長: %d字（上限%d）\n", path, sentence_start, length(sentence), limit
        bad=1
      }
      sentence=""
      sentence_target=all
      join_pending=0
    }
    # Markdown の構造を見分ける処理はここに集める。行の種類を返し、フェンスの内外を状態に持つ。
    #   fence: 開き・閉じのフェンスの行。code: フェンスの内側の行（閉じが無ければ文書の終わりまで）
    #   table: 字下げを除いた先頭が | の表の行。heading: 見出しの行。item: 箇条書きの項目の始まり
    #   blank: 空行。text: それ以外（地の文と、字下げした項目の継続行）
    # フェンス・表・見出し・項目は、字下げの深さによらず認める。
    # フェンスの内側を先に判定するので、コードブロックの中の | や # や - で始まる行は表・見出し・項目にならない。
    # バッククォートの開きのフェンスは、情報文字列にバッククォートを含まない行に限る（行頭のインラインコードを除く）。
    function line_kind(line,    run) {
      if (in_code) {
        if (match(line, /^[ \t]*(```+|~~~+)[ \t]*$/)) {
          run=line
          gsub(/[ \t]/, "", run)
          if (substr(run, 1, 1) == fence_char && length(run) >= fence_len) {
            in_code=0
            return "fence"
          }
        }
        return "code"
      }
      if (line ~ /^[ \t]*```+[^`]*$/ || line ~ /^[ \t]*~~~+/) {
        match(line, /^[ \t]*(```+|~~~+)/)
        run=substr(line, RSTART, RLENGTH)
        gsub(/[ \t]/, "", run)
        fence_char=substr(run, 1, 1)
        fence_len=length(run)
        in_code=1
        return "fence"
      }
      if (line ~ /^[ \t]*\|/) return "table"
      if (line ~ /^[ \t]*#+([ \t]|$)/) return "heading"
      if (line ~ /^[ \t]*([-*+]|[0-9]+[.)])([ \t]|$)/) return "item"
      if (line == "") return "blank"
      return "text"
    }
    {
      # CRLF の文書でも、閉じのフェンスと空行を LF の文書と同じに見分ける。
      sub(/\r$/, "")
      kind=line_kind($0)
      # 文ではない行は一文に足さず、そこで前の文を区切る。
      if (kind == "fence" || kind == "code" || kind == "table") { finish(); next }
      # 見出しと項目の始まりは前の文を区切る。見出しはそれ自体で1つの単位として閉じる。
      if (kind == "heading" || kind == "item") finish()
      if (sentence == "") sentence_start=NR
      line_marked=marked(NR)
      if (line_marked) sentence_target=1
      # 印は文字の単位で立てる。変えた行の文字か、削除でつながった境目の後ろの文字を
      # 1字でも含む文を検査する。行の途中の終端の後から始まる文も、ここで印を持つ。
      for (i=1; i<=length($0); i++) {
        ch=substr($0, i, 1)
        sentence=sentence ch
        if (line_marked || join_pending) sentence_target=1
        if (ch ~ /[。！？!?]/) finish()
      }
      if (kind == "heading" || (kind == "blank" && sentence != "")) finish()
      # 削除で次の行と隣り合った行の終わりで文が続いていれば、次の行の文字でその文に印を立てる。
      if ((NR in joined) && sentence != "") join_pending=1
    }
    END { finish(); exit bad }
  ' "$path"
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] || status=1

  awk -v path="$path" -v target_file="$target_file" '
    BEGIN {
      all=0
      while ((getline target < target_file) > 0) {
        if (target == "*") all=1
        else wanted[target]=1
      }
      close(target_file)
    }
    function marked(line) { return all || (line in wanted) }
    {
      if (!marked(NR)) next
      token=""
      if (match($0, /ADR-[0-9][0-9][0-9][0-9]+/)) token=substr($0, RSTART, RLENGTH)
      else if (match($0, /Issue[[:space:]]*#[0-9][0-9]+/)) token=substr($0, RSTART, RLENGTH)
      else if (match($0, /#[0-9][0-9]+/)) token=substr($0, RSTART, RLENGTH)
      if (token != "" && $0 !~ /(記録|課題|決定|仕様|修正|追加)/)
        printf "%s:%d:候補: 説明のない不透明な識別子: %s\n", path, NR, token
    }
  ' "$path"
done < <(cut -f2 "$targets" | sort -u)

exit "$status"
