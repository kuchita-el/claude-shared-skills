#!/usr/bin/env bash
# DDDドキュメントリント
# - 禁止記号の検出
# - 命名規約の検査（日本語名のみ、集約セクション配下の指定2見出し配下のコードブロック内）
#   - コマンド名: 動詞句（う段9文字終止形 う/く/ぐ/す/つ/ぬ/ぶ/む/る）
#   - イベント名: 過去形（〜した / 〜された）
# - 廃止セクション検出: `### 状態遷移`（コマンドセクションへ統合済み）
# - 廃止記法検出: `〜失敗理由 =` 独立型定義（コマンド内 `失敗時:` 配下に箇条書き化）
# - コマンドエントリの「契機:」フィールド必須化検査・値の列挙検査
#
# 使い方:
#   bash scripts/lint-domain-doc.sh             # 固定3ファイルを検査
#   bash scripts/lint-domain-doc.sh path/...    # 指定ファイルのみ検査
#
# exit code:
#   0: 違反0件
#   1: 違反検出
#   2: 入力ファイル不存在
#   3: GNU grep 不在
#
# ロケール注記:
#   bash 正規表現 `=~` のマルチバイト文字クラスはロケール依存。
#   本スクリプトでは `LC_ALL=C.UTF-8` を冒頭で明示し、
#   命名規約のう段判定は個別文字の比較（`*う` `*く` ...）でショートサーキット連結し
#   ロケール非依存にしている。
set -euo pipefail
export LC_ALL=C.UTF-8

# 環境前提検証: GNU grep（grep -P 対応）が必要
if ! grep -P -q . <<<"x" 2>/dev/null; then
    echo "エラー: GNU grep（grep -P 対応）が必要です。Linux を使うか、macOS では 'brew install grep' を実行してください。" >&2
    exit 3
fi

# 対象ファイルの決定
if [ "$#" -eq 0 ]; then
    files=(
        "docs/development/event-storming.md"
        "docs/development/domain-model.md"
        "docs/qa/event-storming.md"
    )
else
    files=("$@")
fi

# ファイル存在確認
for f in "${files[@]}"; do
    if [ ! -f "$f" ]; then
        echo "エラー: ファイルが見つかりません: $f" >&2
        exit 2
    fi
done

# 違反カウンタ（lint_file 関数内から更新する）
violations=0

# 禁止記号検出
check_prohibited() {
    local file="$1"
    local line_num="$2"
    local line="$3"

    if [[ "${line:0:9}" == '```fsharp' ]]; then
        printf '%s:%d: 禁止記号: ```fsharp\n' "$file" "$line_num"
        violations=$((violations + 1))
    fi
    if [[ "$line" =~ ^type([[:space:]]|$) ]]; then
        printf '%s:%d: 禁止記号: ^type\n' "$file" "$line_num"
        violations=$((violations + 1))
    fi
    if [[ "$line" == *'->'* ]]; then
        printf '%s:%d: 禁止記号: ->\n' "$file" "$line_num"
        violations=$((violations + 1))
    fi
    if [[ "$line" == *'=>'* ]]; then
        printf '%s:%d: 禁止記号: =>\n' "$file" "$line_num"
        violations=$((violations + 1))
    fi
    if [[ "$line" == *'<>'* ]]; then
        printf '%s:%d: 禁止記号: <>\n' "$file" "$line_num"
        violations=$((violations + 1))
    fi
    if [[ "$line" == *'Result<'* ]]; then
        printf '%s:%d: 禁止記号: Result<\n' "$file" "$line_num"
        violations=$((violations + 1))
    fi
}

# 命名規約検査
check_naming() {
    local file="$1"
    local line_num="$2"
    local line="$3"
    local section="$4"
    local name

    # 行頭定義行: インデントなしで `=` or `:` を含む
    if ! [[ "$line" =~ ^[^[:space:]][^=:]*[=:] ]]; then
        return
    fi

    # 名前部分: 最初の `=`/`:` 手前まで
    name="${line%%[=:]*}"
    # 前後空白除去
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"

    if [ -z "$name" ]; then
        return
    fi

    # 日本語含有判定（ひらがな・カタカナ・漢字）
    if ! grep -qP '[\x{3040}-\x{30ff}\x{4e00}-\x{9fff}]' <<<"$name"; then
        return  # 英語名は対象外
    fi

    case "$section" in
        コマンド)
            # う段9文字終止形（う/く/ぐ/す/つ/ぬ/ぶ/む/る）のショートサーキット連結
            if [[ "$name" != *う && "$name" != *く && "$name" != *ぐ \
               && "$name" != *す && "$name" != *つ && "$name" != *ぬ \
               && "$name" != *ぶ && "$name" != *む && "$name" != *る ]]; then
                printf '%s:%d: 命名規約: %s: コマンド名は動詞句（う段終止形）でない\n' "$file" "$line_num" "$name"
                violations=$((violations + 1))
            fi
            ;;
        発火するイベント)
            if [[ "$name" != *した && "$name" != *された ]]; then
                printf '%s:%d: 命名規約: %s: イベント名は過去形でない\n' "$file" "$line_num" "$name"
                violations=$((violations + 1))
            fi
            ;;
    esac
}

# 廃止記法: 失敗理由独立型定義（コマンドセクション配下のコードブロック内）
# 例: `作成失敗理由 =`
check_failure_reason_type() {
    local file="$1"
    local line_num="$2"
    local line="$3"

    # 行頭非空白で `〜失敗理由` の後に空白を許容して `=` が来るパターン
    if [[ "$line" =~ ^[^[:space:]].*失敗理由[[:space:]]*= ]]; then
        printf '%s:%d: 廃止記法: 失敗理由の独立型定義は廃止（コマンドの「失敗時:」配下に箇条書きで記述）\n' "$file" "$line_num"
        violations=$((violations + 1))
    fi
}

# コマンドエントリのフラッシュ（契機フィールド欠落チェック）
flush_command_entry() {
    local file="$1"
    if [ "$cmd_entry_start" -gt 0 ] && [ "$cmd_entry_has_trigger" -eq 0 ]; then
        printf '%s:%d: 契機欠落: %s: コマンドには「契機:」フィールドが必須\n' "$file" "$cmd_entry_start" "$cmd_entry_name"
        violations=$((violations + 1))
    fi
    cmd_entry_start=0
    cmd_entry_has_trigger=0
    cmd_entry_name=""
}

# 「契機:」フィールド値の列挙検査
# 4種: 外部指示 / イベント受信(...) / ポリシー(...) / スケジュール
# 全角・半角括弧両許容
check_trigger_value() {
    local file="$1"
    local line_num="$2"
    local line="$3"
    local value

    # 「契機:」以降を抽出
    value="${line#*契機:}"
    # 前後空白除去
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    if [[ "$value" == 外部指示* ]] \
       || [[ "$value" == "イベント受信("* ]] || [[ "$value" == "イベント受信（"* ]] \
       || [[ "$value" == "ポリシー("* ]] || [[ "$value" == "ポリシー（"* ]] \
       || [[ "$value" == スケジュール* ]]; then
        return 0
    fi

    printf '%s:%d: 契機値不正: 「契機:」フィールドの値は外部指示/イベント受信(...)/ポリシー(...)/スケジュールのいずれか\n' "$file" "$line_num"
    violations=$((violations + 1))
}

# 1ファイルを行単位で 1 パス走査
lint_file() {
    local file="$1"
    local in_mermaid=0
    local in_target_lang_block=0
    local current_aggregate=0
    local current_section=""
    local line_num=0
    local line label

    # コマンドエントリ追跡用の状態（flush_command_entry がアクセス）
    cmd_entry_start=0
    cmd_entry_has_trigger=0
    cmd_entry_name=""

    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))

        # コードブロック開閉判定（行頭3バックティック）
        if [[ "${line:0:3}" == '```' ]]; then
            if [ "$in_mermaid" -eq 1 ]; then
                in_mermaid=0
            elif [ "$in_target_lang_block" -eq 1 ]; then
                # コードブロック終端: コマンドエントリをフラッシュ
                flush_command_entry "$file"
                in_target_lang_block=0
            else
                # 開始: ラベル抽出
                label="${line:3}"
                label="${label%%[[:space:]]*}"
                if [ "$label" = "mermaid" ]; then
                    in_mermaid=1
                elif [ "$label" = "fsharp" ] || [ -z "$label" ]; then
                    in_target_lang_block=1
                fi
                # 他のラベルは何もしない
            fi
        else
            # コードブロック外でのみ見出し処理
            if [ "$in_mermaid" -eq 0 ] && [ "$in_target_lang_block" -eq 0 ]; then
                # H2 見出し（H3 とは区別）
                if [[ "$line" =~ ^##[[:space:]] ]] && ! [[ "$line" =~ ^### ]]; then
                    # 既存エントリのフラッシュ（念のため。通常はコードブロック終端でフラッシュ済み）
                    flush_command_entry "$file"
                    if [[ "$line" =~ ^##[[:space:]].+集約[[:space:]]*$ ]]; then
                        current_aggregate=1
                    else
                        current_aggregate=0
                    fi
                    current_section=""
                fi
                # H3 見出し
                if [[ "$line" =~ ^###[[:space:]](コマンド|発火するイベント)[[:space:]]*$ ]]; then
                    flush_command_entry "$file"
                    current_section="${BASH_REMATCH[1]}"
                elif [[ "$line" =~ ^###[[:space:]]状態遷移[[:space:]]*$ ]]; then
                    # 廃止セクション検出（集約配下のときのみ違反）
                    if [ "$current_aggregate" -eq 1 ]; then
                        printf '%s:%d: 廃止セクション: 状態遷移セクションは廃止（コマンドセクションに統合）\n' "$file" "$line_num"
                        violations=$((violations + 1))
                    fi
                    flush_command_entry "$file"
                    current_section=""
                elif [[ "$line" =~ ^###[[:space:]] ]]; then
                    flush_command_entry "$file"
                    current_section=""
                fi
            fi
        fi

        # 禁止記号検出（Mermaidブロック内は除外）
        if [ "$in_mermaid" -eq 0 ]; then
            check_prohibited "$file" "$line_num" "$line"
        fi

        # 命名規約検査（naming_target_block）
        if [ "$current_aggregate" -eq 1 ] && [ -n "$current_section" ] && [ "$in_target_lang_block" -eq 1 ]; then
            check_naming "$file" "$line_num" "$line" "$current_section"
        fi

        # コマンドセクション配下のコードブロック内処理
        if [ "$current_aggregate" -eq 1 ] && [ "$current_section" = "コマンド" ] && [ "$in_target_lang_block" -eq 1 ]; then
            # 廃止記法: 失敗理由独立型定義
            check_failure_reason_type "$file" "$line_num" "$line"

            # コマンドエントリ追跡
            # 行頭非空白かつ `:` を含み `=` を含まない（インデントなしの「名前:」形式）
            if [[ "$line" =~ ^[^[:space:]][^=]*: ]] && [[ "$line" != *=* ]]; then
                # 行頭のキーワード（失敗時:、契機: 等のフィールド名のみの行）はエントリ開始ではない
                # ただしコマンドセクション内でインデントなし行頭は通常コマンドエントリ
                # 名前を抽出して日本語含有を確認
                local entry_name
                entry_name="${line%%:*}"
                entry_name="${entry_name#"${entry_name%%[![:space:]]*}"}"
                entry_name="${entry_name%"${entry_name##*[![:space:]]}"}"
                if [ -n "$entry_name" ] && grep -qP '[\x{3040}-\x{30ff}\x{4e00}-\x{9fff}]' <<<"$entry_name"; then
                    # 前のエントリをフラッシュ
                    flush_command_entry "$file"
                    cmd_entry_start=$line_num
                    cmd_entry_has_trigger=0
                    cmd_entry_name="$entry_name"
                fi
            elif [ "$cmd_entry_start" -gt 0 ]; then
                # エントリ範囲内: 「契機:」フィールド検出（インデント付き）
                if [[ "$line" =~ ^[[:space:]]+契機: ]]; then
                    cmd_entry_has_trigger=1
                    check_trigger_value "$file" "$line_num" "$line"
                fi
            fi
        fi
    done < "$file"

    # ファイル末尾でフラッシュ（コードブロック未閉じの場合の保険）
    flush_command_entry "$file"
}

for file in "${files[@]}"; do
    lint_file "$file"
done

if [ "$violations" -gt 0 ]; then
    exit 1
fi
exit 0
