#!/usr/bin/env bash
# plugins/adr/scripts/adr-scoping-cases.sh の機械可読統計値を検査する共有ヘルパ。
#
# report --stats の標準出力だけをキーと値へ解析し、人が読む集計本文は判定に使わない。

stats_run() {
    local sut="$1" judgments="$2" cases_dir="$3"
    run --separate-stderr bash "$sut" report "$judgments" "$cases_dir" --stats </dev/null
}

stats_values_match() {
    local pair key value line actual_count=0
    declare -A actual=()
    while IFS= read -r line; do
        [[ "$line" =~ ^([A-Za-z0-9.]+)=(-?[0-9]*)$ ]] || return 1
        key="${BASH_REMATCH[1]}"
        actual["$key"]="${BASH_REMATCH[2]}"
        actual_count=$((actual_count + 1))
    done <<< "$output"
    [ "$actual_count" -ge "$#" ] || return 1
    for pair in "$@"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        [ "${actual[$key]+yes}" = yes ] || return 1
        [ "${actual[$key]}" = "$value" ] || return 1
    done
    return 0
}

collect_stats() {
    local want_rc="$1" label="$2"
    shift 2
    local ok=1 detail="" line key value pair actual_count=0
    declare -A actual=()

    if [ "$status" -ne "$want_rc" ]; then
        ok=0
        detail="exit code 期待 $want_rc / 実際 $status"
    fi

    while IFS= read -r line; do
        if [[ "$line" =~ ^([A-Za-z0-9.]+)=(-?[0-9]*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            actual["$key"]="$value"
            actual_count=$((actual_count + 1))
        else
            ok=0
            detail="${detail}${detail:+ / }統計値でない行が標準出力にある: $line"
        fi
    done <<< "$output"

    if [ "$actual_count" -lt "$#" ]; then
        ok=0
        detail="${detail}${detail:+ / }照合した統計値が期待件数未満: $actual_count / $#"
    fi

    for pair in "$@"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        if [ "${actual[$key]+yes}" != yes ]; then
            ok=0
            detail="${detail}${detail:+ / }キーが無い: $key"
        elif [ "${actual[$key]}" != "$value" ]; then
            ok=0
            detail="${detail}${detail:+ / }$key の期待 $value / 実際 ${actual[$key]}"
        fi
    done

    if [ "$ok" -eq 1 ]; then
        collect_ok "$label"
    else
        collect_fail "$label" "$detail"$'\n       stdout:\n'"$output"
    fi
    return 0
}
