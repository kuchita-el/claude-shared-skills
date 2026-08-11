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
if [[ "$mode" == file ]]; then
  [[ -f "$file" ]] || { printf '入力ファイルが無い: %s\n' "$file" >&2; exit 2; }
  inputs=("$file")
else
  while IFS= read -r path; do
    [[ -n "$path" ]] && inputs+=("$path")
  done < <(git diff --name-only "$base" -- "${paths[@]}")
fi

status=0
for path in "${inputs[@]}"; do
  [[ -f "$path" ]] || continue
  line_no=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    # The profile default is 100 characters; a project profile may override it.
    limit=100
    profile='${CLAUDE_PROJECT_DIR:-}/.claude/writing/type-profiles.md'
    if [[ -n "${CLAUDE_PROJECT_DIR:-}" && -f "$profile" ]]; then
      parsed=$(awk -F'|' '/\|[[:space:]]*汎用[[:space:]]*\|/ { gsub(/[^0-9]/, "", $5); print $5; exit }' "$profile")
      [[ "$parsed" =~ ^[0-9]+$ ]] && limit=$parsed
    fi
    length=${#line}
    if (( length > limit )); then
      printf '%s:%d:一文長: %d字（上限%d）\n' "$path" "$line_no" "$length" "$limit"
      status=1
    fi
    # Candidates are advisory and deliberately do not affect the exit status.
    token=$(grep -oE 'ADR-[0-9]{4,}|Issue[[:space:]]*#[0-9]{2,}|#[0-9]{2,}' <<<"$line" | head -n1 || true)
    if [[ -n "$token" ]] &&
       [[ ! "$line" =~ (記録|課題|決定|仕様|修正|追加) ]]; then
      printf '%s:%d:候補: 説明のない不透明な識別子: %s\n' "$path" "$line_no" "$token"
    fi
  done < "$path"
done
exit "$status"
