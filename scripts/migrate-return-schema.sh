#!/usr/bin/env bash
# 保存済み返却 JSON を旧スキーマと新スキーマの間で変換する。
set -euo pipefail

usage() {
    printf '使い方: %s [--reverse] <返却JSONディレクトリ>\n' "$0" >&2
    exit 2
}

reverse=0
if [ "${1:-}" = "--reverse" ]; then reverse=1; shift; fi
[ "$#" -eq 1 ] || usage
dir="$1"
[ -d "$dir" ] || { printf 'エラー: 返却ディレクトリが存在しない: %s\n' "$dir" >&2; exit 1; }

files=()
for file in "$dir"/*.json; do [ -f "$file" ] && files+=("$file"); done
[ "${#files[@]}" -gt 0 ] || { printf 'エラー: JSON が0件: %s\n' "$dir" >&2; exit 1; }

targets='["必要条件_成立","項目1_構造変更","項目1_スキーマ変更","項目1_配布済み成果物への利用者影響","項目1_蓄積済みデータ移行","項目3_値域A","項目3_値域B","項目3_採用理由確認可能","項目3_条件1","項目3_条件2","項目3_条件3"]'
for file in "${files[@]}"; do
    tmp="$(mktemp "${file}.XXXXXX")"
    if [ "$reverse" -eq 1 ]; then
        jq --argjson targets "$targets" '
          reduce ($targets[] as $k | {k:$k}) as $entry (.;
            if .["欠測"] | has($entry.k) then .[$entry.k] = .["欠測"][$entry.k] else . end)
          | del(.["欠測"])
        ' "$file" > "$tmp"
    else
        jq --argjson targets "$targets" '
          .["欠測"] = (.["欠測"] // {}) |
          reduce $targets[] as $k (.;
            if has($k) and (.[ $k ] | type == "string") then
              .["欠測"][$k] = .[$k] | del(.[$k])
            else . end)
        ' "$file" > "$tmp"
    fi
    chmod --reference="$file" "$tmp"
    mv -- "$tmp" "$file"
done
printf '変換件数: %s\n' "${#files[@]}"
