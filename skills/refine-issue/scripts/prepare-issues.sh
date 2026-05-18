#!/usr/bin/env bash
# refine-issue 全件モード用のデータ準備スクリプト
#
# gh issue list で取得した Issue 一覧を、Issue 番号ごとの個別 JSON ファイル
# として出力ディレクトリに書き出す。
#
# 引数:
#   --output-dir <path>   出力ディレクトリ（省略時は mktemp で一意生成）
#   --repo <owner/repo>   対象リポジトリ（省略時は gh のデフォルト）
#   --label <name>        対象ラベル
#   --limit <n>           取得上限（デフォルト 100）
#
# 出力:
#   stdout 1行目: 出力ディレクトリの絶対パス
#   stdout 2行目以降: Issue 番号（1行1番号、降順）
#   stderr: 件数等の進捗情報（ログ用）
#
# 注意:
#   --output-dir 明示時、当該ディレクトリ内の既存 issue-*.json と _issues.json は
#   gh 実行直前に削除される（前回実行の残骸混入を防ぐため）。
#
# 依存: bash, gh, jq

set -euo pipefail

output_dir=""
repo=""
label=""
limit=100

require_value() {
  if [ "$#" -lt 2 ]; then
    echo "error: missing value for $1" >&2
    exit 2
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --output-dir)
      require_value "$@"
      output_dir="$2"
      shift 2
      ;;
    --repo)
      require_value "$@"
      repo="$2"
      shift 2
      ;;
    --label)
      require_value "$@"
      label="$2"
      shift 2
      ;;
    --limit)
      require_value "$@"
      limit="$2"
      shift 2
      ;;
    *)
      echo "error: unknown option: $1" >&2
      exit 2
      ;;
  esac
done

for cmd in gh jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: required command not found: $cmd" >&2
    exit 1
  fi
done

if [ -z "$output_dir" ]; then
  output_dir="$(mktemp -d -t refine-issue-XXXXXXXX)"
else
  mkdir -p "$output_dir"
  output_dir="$(cd "$output_dir" && pwd)"
fi

gh_args=(issue list --state open --json number,title,body,labels,updatedAt,comments --limit "$limit")
if [ -n "$repo" ]; then
  gh_args+=(--repo "$repo")
fi
if [ -n "$label" ]; then
  gh_args+=(--label "$label")
fi

rm -f "$output_dir"/issue-*.json "$output_dir/_issues.json"

echo "fetching issues (limit=$limit${repo:+, repo=$repo}${label:+, label=$label})..." >&2

issues_json="$output_dir/_issues.json"
gh "${gh_args[@]}" > "$issues_json"

total=$(jq 'length' "$issues_json")
echo "fetched $total issues" >&2

jq -c '.[]' "$issues_json" | while IFS= read -r issue; do
  number=$(printf '%s' "$issue" | jq -r '.number')
  printf '%s' "$issue" > "$output_dir/issue-${number}.json"
done

rm -f "$issues_json"

echo "wrote $total files to $output_dir" >&2

echo "$output_dir"
if [ "$total" -gt 0 ]; then
  jq -r '.number' "$output_dir"/issue-*.json | sort -rn
fi
