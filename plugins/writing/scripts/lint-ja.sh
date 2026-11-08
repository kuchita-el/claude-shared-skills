#!/usr/bin/env bash
set -euo pipefail

# 一文の長さを、文書種別ごとの上限で検査する。数え方の正本は references/japanese-writing.md 第5条の補則。
usage() {
  printf 'usage: %s [--type TYPE] --file PATH | [--type TYPE] --diff BASE -- PATH...\n' "${0##*/}" >&2
  printf '  TYPE: 文書種別。省略時は「汎用」。上限はプロジェクト固有のプロファイルの TYPE の行、無ければ同梱の既定の「汎用」の行から採る。\n' >&2
  printf '  PATH: Markdown として扱う拡張子 .md・.markdown（大文字小文字を問わない）のファイルに限る。\n' >&2
  printf '  終了コード: 0 違反なし、1 一文長の違反あり、2 引数の誤りか検査できない入力。\n' >&2
}

mode=''
file=''
base=''
type=''
type_given=0
paths=()
while (($#)); do
  case "$1" in
    --type)
      [[ "$type_given" -eq 0 && $# -ge 2 && -n "$2" ]] || { usage; exit 2; }
      type=$2; type_given=1; shift 2
      ;;
    --file)
      [[ -z "$mode" && $# -ge 2 ]] || { usage; exit 2; }
      mode=file; file=$2; shift 2
      ;;
    --diff)
      [[ -z "$mode" && $# -ge 2 ]] || { usage; exit 2; }
      mode=diff; base=$2; shift 2
      ;;
    --)
      [[ "$mode" == diff ]] || { usage; exit 2; }
      shift
      (($#)) || { usage; exit 2; }
      paths=("$@")
      break
      ;;
    *) usage; exit 2 ;;
  esac
done
[[ -n "$mode" ]] || { usage; exit 2; }
[[ "$mode" == file || ${#paths[@]} -gt 0 ]] || { usage; exit 2; }
type=${type:-汎用}

# 検査できない入力は、違反の有無（0・1）と区別して 2 で返す。
check_input() {
  [[ -f "$1" ]] || { printf '入力ファイルが無い: %s\n' "$1" >&2; exit 2; }
  case "${1,,}" in
    *.md|*.markdown) ;;
    *) printf 'Markdown として扱えない（拡張子が .md・.markdown でない）: %s\n' "$1" >&2; exit 2 ;;
  esac
}
if [[ "$mode" == diff ]] && ! git rev-parse --verify --quiet "${base}^{commit}" >/dev/null; then
  printf '差分の基点が commit を指さない: %s\n' "$base" >&2
  exit 2
fi

target_dir=$(mktemp -d)
trap 'rm -rf "$target_dir"' EXIT
targets="$target_dir/targets.tsv"
: > "$targets"

if [[ "$mode" == file ]]; then
  check_input "$file"
  printf '*\t%s\n' "$file" > "$targets"
else
  for path in "${paths[@]}"; do
    check_input "$path"
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

# 上限は references/document-type-profiles.md の読み込み優先順位で引く。
# プロジェクト固有のプロファイルに種別の行があればその上限、無いか読めなければ同梱の既定の「汎用」の行、
# それも読めなければ共通規約の既定値（100字）を採る。
# profile_cell はプロファイルの表で、先頭の列が種別と一致する最初の行の「一文長の上限」の欄を出力する。
# 行が無ければ失敗を返す。
profile_cell() {
  LINT_TYPE=$2 awk -F'|' '
    /^[[:space:]]*\|/ {
      name=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      if (name != ENVIRON["LINT_TYPE"]) next
      cell=$5; gsub(/^[[:space:]]+|[[:space:]]+$/, "", cell)
      print cell; found=1; exit
    }
    END { exit !found }
  ' "$1"
}
# resolve_limit は種別の行が見つかれば、その上限を数値として読んで limit に入れる。読めなければ 2 で終える。
resolve_limit() {
  local cell
  [[ -r "$1" ]] || return 1
  cell=$(profile_cell "$1" "$2") || return 1
  if [[ "$cell" =~ ^([0-9]+)[[:space:]]*字?$ ]]; then
    limit=${BASH_REMATCH[1]}
    return 0
  fi
  printf 'プロファイルの種別「%s」の一文長の上限を数値として読めない: %s: %s\n' "$2" "$1" "$cell" >&2
  exit 2
}
limit=100
project_profile="${CLAUDE_PROJECT_DIR:-}/.claude/writing/type-profiles.md"
bundled_profile="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/references/document-type-profiles.md"
if ! { [[ -n "${CLAUDE_PROJECT_DIR:-}" ]] && resolve_limit "$project_profile" "$type"; }; then
  resolve_limit "$bundled_profile" 汎用 || true
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
    #   blank: 空行（字が無いか、半角空白とタブだけの行）。text: それ以外（地の文と、字下げした項目の継続行）
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
      if (line ~ /^[ \t]*$/) return "blank"
      return "text"
    }
    {
      # CRLF の文書でも、閉じのフェンスと空行を LF の文書と同じに見分ける。
      sub(/\r$/, "")
      kind=line_kind($0)
      # 空白だけの空行は、字の無い空行と同じに扱う。空白を次の文の字として持ち越さない。
      if (kind == "blank") $0=""
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
done < <(cut -f2 "$targets" | sort -u)

exit "$status"
