#!/usr/bin/env bash
# plugins/adr/scripts/adr-scoping-cases.sh の機械可読統計値を検査する共有ヘルパ。
#
# report --stats の標準出力だけをキーと値へ解析し、人が読む集計本文は判定に使わない。

stats_run() {
    local sut="$1" judgments="$2" cases_dir="$3"
    run --separate-stderr bash "$sut" report "$judgments" "$cases_dir" --stats </dev/null
}

# 本文の数値の符号化（n / m、N 件中 M 件）は抽出規則の前提である。
# この区切りや計数語を変更する場合は、ここでの抽出と対応する検査も更新する。
stats_body_ratios() {
    grep -oE '[0-9]+[[:space:]]*/[[:space:]]*[0-9]+' <<< "$1" \
        | sed -E 's/[[:space:]]+//g' | paste -sd ' ' -
}

stats_body_coverage() {
    grep -oE '[0-9]+[[:space:]]+件中[[:space:]]+[0-9]+[[:space:]]+件' <<< "$1" \
        | sed -E 's/([0-9]+)[[:space:]]+件中[[:space:]]+([0-9]+)[[:space:]]+件/\2\/\1/' | paste -sd ' ' -
}

stats_body_last_count() {
    grep -oE '[0-9]+' <<< "$1" | tail -1
}

stats_values_match() {
    local pair key value line matched_count=0
    declare -A actual=()
    while IFS= read -r line; do
        [[ "$line" =~ ^([A-Za-z0-9.]+)=(-?[0-9]*)$ ]] || return 1
        key="${BASH_REMATCH[1]}"
        actual["$key"]="${BASH_REMATCH[2]}"
    done <<< "$output"
    for pair in "$@"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        [ "${actual[$key]+yes}" = yes ] || return 1
        [ "${actual[$key]}" = "$value" ] || return 1
        matched_count=$((matched_count + 1))
    done
    [ "$matched_count" -ge "$#" ] || return 1
    return 0
}

stats_value() {
    local wanted="$1" line key
    while IFS= read -r line; do
        key="${line%%=*}"
        if [ "$key" = "$wanted" ]; then
            printf '%s' "${line#*=}"
            return 0
        fi
    done <<< "$output"
    return 1
}

stats_keys_match() {
    local wanted key line actual_count=0
    declare -A actual=()
    while IFS= read -r line; do
        [[ "$line" =~ ^([A-Za-z0-9.]+)=(-?[0-9]*)$ ]] || return 1
        key="${BASH_REMATCH[1]}"
        [ "${actual[$key]+yes}" = yes ] || actual_count=$((actual_count + 1))
        actual["$key"]=1
    done <<< "$output"
    [ "$actual_count" -eq "$#" ] || return 1
    for wanted in "$@"; do
        [ "${actual[$wanted]+yes}" = yes ] || return 1
    done
    return 0
}

collect_stats() {
    local want_rc="$1" label="$2"
    shift 2
    local ok=1 detail="" line key value pair matched_count=0
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
        else
            ok=0
            detail="${detail}${detail:+ / }統計値でない行が標準出力にある: $line"
        fi
    done <<< "$output"

    for pair in "$@"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        if [ "${actual[$key]+yes}" != yes ]; then
            ok=0
            detail="${detail}${detail:+ / }キーが無い: $key"
        elif [ "${actual[$key]}" != "$value" ]; then
            ok=0
            detail="${detail}${detail:+ / }$key の期待 $value / 実際 ${actual[$key]}"
        else
            matched_count=$((matched_count + 1))
        fi
    done
    if [ "$matched_count" -lt "$#" ]; then
        ok=0
        detail="${detail}${detail:+ / }照合した統計値が期待件数未満: $matched_count / $#"
    fi

    if [ "$ok" -eq 1 ]; then
        collect_ok "$label"
    else
        collect_fail "$label" "$detail"$'\n       stdout:\n'"$output"
    fi
    return 0
}
