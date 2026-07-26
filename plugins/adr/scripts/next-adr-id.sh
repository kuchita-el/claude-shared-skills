#!/usr/bin/env bash
# ADR 識別子の発番器
#
# ADR_DIR 配下の既存 ADR を見て、次に起票する ADR の識別子
# `ADR-YYYYMMDDHHMM-NN` を stdout へ1行で出力する（slug は呼び出し側が付与する）。
#
# 時刻部（YYYYMMDDHHMM）は作業者のローカル時刻から取り、連番部（NN）は
# 同一時刻部を持つ既存ファイルの最大番号 + 1 とする（既存が無ければ 01）。
# 時刻部が並行ブランチ間の一意性を担い、連番部が同一分内のバースト
# （多決定 ADR の分割で後継を同時に起票する等）の順序を担う。
# 配置ディレクトリ全体・同日全体の最大番号は見ない。日単位で最大 + 1 を取ると
# 並行ブランチがそれぞれ自分の base に対して正しく発番しても同一識別子を生むため。
#
# 時刻部は環境変数 ADR_TIMESTAMP（YYYYMMDDHHMM の12桁）で上書きできる。
# 過去時刻で発番する遡及移行と、本スクリプトのテストで用いる。
#
# 使い方:
#   bash next-adr-id.sh [ADR_DIR]                        # 既定 ADR_DIR は docs/adr
#   ADR_TIMESTAMP=203104091530 bash next-adr-id.sh docs/adr
#
# exit code:
#   0: 発番成功（識別子を stdout へ出力）
#   1: 同一時刻部の連番が上限 99 に達している、または ADR_TIMESTAMP の形式が不正
#   2: ADR_DIR が存在しない
set -euo pipefail

ADR_DIR="${1:-docs/adr}"
ADR_DIR="${ADR_DIR%/}"

if [ ! -d "$ADR_DIR" ]; then
    echo "エラー: ディレクトリが見つかりません: $ADR_DIR" >&2
    exit 2
fi

timestamp="${ADR_TIMESTAMP:-$(date +%Y%m%d%H%M)}"
if [[ ! "$timestamp" =~ ^[0-9]{12}$ ]]; then
    echo "エラー: 時刻部が YYYYMMDDHHMM の12桁ではありません: $timestamp" >&2
    exit 1
fi

# 同一時刻部を持つ既存ファイルの連番部から最大番号を取る。
# 連番部が2桁数字でないファイル（旧形式・slug 直結等）は対象外として読み飛ばす。
max=0
shopt -s nullglob
for file in "$ADR_DIR"/ADR-"$timestamp"-*.md; do
    stem="$(basename "$file" .md)"
    seq="${stem#ADR-$timestamp-}"
    seq="${seq%%-*}"
    if [[ "$seq" =~ ^[0-9][0-9]$ ]]; then
        # 10# を付けて10進として解釈する（付けないと 08/09 が8進エラーになる）
        num=$((10#$seq))
        if [ "$num" -gt "$max" ]; then
            max="$num"
        fi
    fi
done
shopt -u nullglob

next=$((max + 1))
if [ "$next" -gt 99 ]; then
    echo "エラー: 同一時刻部 $timestamp の連番が上限 99 に達しています: $ADR_DIR" >&2
    exit 1
fi

printf 'ADR-%s-%02d\n' "$timestamp" "$next"
