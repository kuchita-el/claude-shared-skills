#!/usr/bin/env bash
# adr プラグインの設定を解決し、対象の ADR ディレクトリと語の群の値を `キー: 値` の行で stdout へ出す。
#
# manage-adr スキルが、操作の対象ディレクトリと、ADR の front-matter と相互参照の節の見出しへ
# 書く値を得るために使う。スキルの手順は状態を設定のキー（status-proposed 等）で指し、書き込む値は
# 本スクリプトの出力から取る。手順や参照ファイルに値を直接書くと、語の群を書き換えた導入先で、
# 設定を読む lint が語彙外と判定する値をスキルが書き込むためである。
#
# 対象の ADR ディレクトリの決め方（引数 → 設定の adr-dir → 同梱の既定値）と、設定の解決
# （置き場・順・誤りの扱い）は同梱の adr-config.sh が持つ。本スクリプトは lint-adr.sh・
# gen-adr-index.sh と同じ形でそれを呼ぶだけである。そのため、スキルが操作する ADR ディレクトリと
# 書き込む値は、同じ引数で起動した lint が検査する対象と語に常に一致する。
#
# 出力の形:
#   - 1行目は、語の解決に使った設定ファイルを示すコメント行である
#   - 2行目は `adr-dir: <解決した ADR ディレクトリ>` である。値は設定に書いた相対パスそのもの
#     ではなく、決めたディレクトリのパスである（引数を省いたときは git のトップレベルを前に付ける）。
#     そのため、出力をそのまま設定ファイルとして置くと、絶対パスの adr-dir として誤りになりうる
#   - 続く行が語の群の全キーである（並びは adr-config.sh の ADR_CONFIG_WORD_KEYS）
#
# 使い方:
#   bash print-adr-config.sh [ADR_DIR]   # 省略時は設定の adr-dir（無ければ docs/adr）
#
# exit code:
#   0: 解決できた
#   2: ADR ディレクトリが存在しない、または設定に誤りがある（原因は標準エラーへ出し、stdout へは何も出さない）
set -euo pipefail

# shellcheck source=adr-config.sh
source "$(dirname "${BASH_SOURCE[0]}")/adr-config.sh"
adr_config_resolve_adr_dir "${1:-}" || exit 2

# ADR ディレクトリが無いまま解決すると、git のトップレベルを決められずに既定値へ落ち、導入先の
# 設定と異なる値を黙って返す。lint-adr.sh・gen-adr-index.sh と同じく、ここで止める。
if [ ! -d "$ADR_DIR" ]; then
    adr_config_report_missing_adr_dir
    exit 2
fi

adr_config_load "$ADR_DIR" || exit 2

printf '# 解決元: %s\n' "$ADR_CONFIG_SOURCE"
printf '%s: %s\n' "$ADR_CONFIG_DIR_KEY" "$ADR_DIR"
printf '%s: %s\n' \
    "${ADR_CONFIG_WORD_KEYS[0]}" "$ADR_STATUS_PROPOSED" \
    "${ADR_CONFIG_WORD_KEYS[1]}" "$ADR_STATUS_APPROVED" \
    "${ADR_CONFIG_WORD_KEYS[2]}" "$ADR_STATUS_REJECTED" \
    "${ADR_CONFIG_WORD_KEYS[3]}" "$ADR_VALIDITY_ACTIVE" \
    "${ADR_CONFIG_WORD_KEYS[4]}" "$ADR_VALIDITY_SUPERSEDED" \
    "${ADR_CONFIG_WORD_KEYS[5]}" "$ADR_VALIDITY_ABANDONED" \
    "${ADR_CONFIG_WORD_KEYS[6]}" "$ADR_XREF_HEADING" \
    "${ADR_CONFIG_WORD_KEYS[7]}" "$ADR_INDEX_TITLE" \
    "${ADR_CONFIG_WORD_KEYS[8]}" "$ADR_INDEX_NOTICE"
