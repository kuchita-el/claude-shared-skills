#!/usr/bin/env bash
# lint-adr.sh を bash 4.2 未満の実体で走らせ、版の判定が原因を示して exit 2 で止めることを確かめる。
#
# lint-adr.sh は連想配列を使うため bash 4.2 以上を要し、冒頭の版の判定で、足りない版では
# 原因と直し方を示して exit 2 で止まる。bats の側は BASH_VERSION を差し替えて判定の分岐を
# 確かめるが、それは本物の古い bash が判定より前の行を解釈できることまでは確かめない。
# 本スクリプトは、引数で受け取った古い bash の実体（例: bash 3.2 のコンテナ）で lint を起動し、
# その実測を CI に常設する。macOS の既定の /bin/bash は 3.2 である。
#
# 使い方: bash scripts/check-lint-adr-old-bash.sh <古い bash を起動するコマンド...>
#   例: bash scripts/check-lint-adr-old-bash.sh docker run --rm -v "$PWD:/w" -w /w bash:3.2.57 bash
#   与えたコマンドの後ろに、リポジトリルートからの相対パスで lint の起動を付けて実行する。
#   そのため、コマンドはリポジトリルートを作業ディレクトリとして bash を起動するものに限る。
#
# exit code:
#   0: 古い bash で lint が exit 2 になり、版が足りないことを示すメッセージが出た
#   1: 期待と異なる（exit 2 以外、またはメッセージが無い）
#   2: 引数の誤り
set -uo pipefail

if [ "$#" -eq 0 ]; then
    echo "使い方: bash scripts/check-lint-adr-old-bash.sh <古い bash を起動するコマンド...>" >&2
    exit 2
fi

# 実測した版を記録に残す（CI のログが実測の記録になる）
version_output=$("$@" -c 'printf "%s\n" "$BASH_VERSION"' 2>&1)
echo "起動した bash の版: ${version_output}"

output=$("$@" plugins/adr/scripts/lint-adr.sh docs/adr 2>&1)
rc=$?
echo "lint-adr.sh の exit code: ${rc}"
echo "lint-adr.sh の出力:"
printf '%s\n' "$output" | sed 's/^/  /'

failed=0
if [ "$rc" -ne 2 ]; then
    echo "失敗: bash 4.2 未満では exit 2 を期待したが ${rc} だった" >&2
    failed=1
fi
# 案内は出力の最初の行でなければならない。古い bash が版の判定より前の行でつまずくと、
# 解釈の誤り（syntax error 等）が先に出て、利用者は原因を読み取れない。
first_line=$(printf '%s\n' "$output" | head -n 1)
case "$first_line" in
    "エラー: lint-adr.sh は bash 4.2 以上を必要とします"*) ;;
    *)
        echo "失敗: 出力の最初の行が、版が足りないことを示すメッセージ（bash 4.2 以上を必要とします）ではない" >&2
        failed=1
        ;;
esac
exit "$failed"
