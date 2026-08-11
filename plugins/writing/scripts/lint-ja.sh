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
          sub(/^.*\+/, "", h)
          sub(/,.*/, "", h)
          next_line=h + 0
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
        else wanted[target]=1
      }
      close(target_file)
      sentence=""
      sentence_start=1
      sentence_target=all
      bad=0
    }
    function marked(line) { return all || (line in wanted) }
    function finish() {
      if (sentence != "" && length(sentence) > limit && sentence_target) {
        printf "%s:%d:一文長: %d字（上限%d）\n", path, sentence_start, length(sentence), limit
        bad=1
      }
      sentence=""
      sentence_target=all
    }
    {
      if (sentence == "") sentence_start=NR
      if (marked(NR)) sentence_target=1
      for (i=1; i<=length($0); i++) {
        ch=substr($0, i, 1)
        sentence=sentence ch
        if (ch ~ /[。！？!?]/) finish()
      }
      if ($0 == "" && sentence != "") finish()
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
