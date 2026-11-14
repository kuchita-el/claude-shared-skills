#!/usr/bin/env bats
# 誤った退役の取り消し後の状態に対する ADR drift-lint（plugins/adr/scripts/lint-adr.sh）のテスト。
#
# 取り消しの手順の正本は manage-adr スキルの `references/transitions.md`「取り消し（誤った退役の訂正）」
# である。取り消しは状態遷移ではなく記録の訂正であり、取り消し後の front-matter は状態の型の
# `有効` 構成子に収まる。本ファイルは次の2点を固定する。
#
# - 正例: 手順どおりに取り消した ADR 群（廃止の取り消し・上書きの取り消しの双方）を lint が
#   違反としない。廃止時に追記した退役理由と `## 変更履歴` の取り消しの記録が本文に残っていても、
#   取り消された後継が `Supersedes:` を `Related:` へ改めていても、exit 0 になる
# - 負例: 取り消しの手順の一部を欠いた状態を lint が検出する。正例の ADR 群を一時ディレクトリへ
#   写し、手順を1つずつ欠いた形へ変えて起動する。正例と負例が同じ ADR 群から作られるため、
#   負例の赤は「欠いた手順」だけに由来する
#
# 【配置について】テストと fixture を配布物外へ置く境界は docs/distribution-boundary.md が定める。
#
# 負例は @test ごとに異なる ADR 群を起動するため、共有 setup_file の CORPORA は空にし、
# 検査器の起動は各ケース内で bats 組み込みの `run` により行う。

load 'helpers/common'

SUT="$PLUGIN_ROOT/scripts/lint-adr.sh"
CORPUS="$FIXTURES_DIR/lint-adr/valid/12-retirement-undone"
CORPORA=()
PRECONDITION_PATHS=("$CORPUS")

ABANDON="ADR-202611010900-01-undone-abandonment"
OLD="ADR-202611010901-01-undone-supersede-old"
NEW="ADR-202611010902-01-undone-supersede-new"

setup_file() {
    common_setup_file
}

# 正例の ADR 群を一時ディレクトリへ写し、写した先のパスを出力する。
copy_corpus() {
    local dest="$BATS_TEST_TMPDIR/$1"
    cp -R "$CORPUS" "$dest"
    printf '%s\n' "$dest"
}

# file が needle を含む行を持つかを、ラベル付きで収集する（fixture・変異の前提確認用）。
collect_file_has() {
    local file="$1" needle="$2" label="$3"
    if grep -qF -- "$needle" "$file"; then
        collect_ok "$label"
    else
        collect_fail "$label" "$file に \"$needle\" を含む行が無い"
    fi
    return 0
}

# file が needle を含む行を持たないことを、ラベル付きで収集する。
collect_file_lacks() {
    local file="$1" needle="$2" label="$3"
    if grep -qF -- "$needle" "$file"; then
        collect_fail "$label" "$file に \"$needle\" を含む行が残っている"
    else
        collect_ok "$label"
    fi
    return 0
}

@test "前提: 被テスト検査器と fixture の ADR 群が存在する" {
    assert_preconditions_met
}

# 正例が自明に緑にならないよう、取り消し後の状態を表す記述が fixture に在ることを先に確かめる。
@test "面①: 手順どおりに取り消した ADR 群が exit 0" {
    collect_init

    collect_file_has "$CORPUS/$ABANDON.md" "validity: 有効" \
        "fixture の前提: 廃止を取り消した ADR が有効へ戻っている"
    collect_file_has "$CORPUS/$ABANDON.md" "に廃止した。退役理由" \
        "fixture の前提: 廃止時に追記した退役理由が本文に残っている"
    collect_file_has "$CORPUS/$ABANDON.md" "廃止を取り消した。根拠" \
        "fixture の前提: 変更履歴に廃止の取り消しの記録がある"
    collect_file_has "$CORPUS/$OLD.md" "validity: 有効" \
        "fixture の前提: 上書きを取り消した旧 ADR が有効へ戻っている"
    collect_file_lacks "$CORPUS/$OLD.md" "- Superseded by:" \
        "fixture の前提: 旧 ADR の Superseded by 行が除かれている"
    collect_file_lacks "$CORPUS/$NEW.md" "- Supersedes:" \
        "fixture の前提: 後継の Supersedes 行が除かれている"
    collect_file_has "$CORPUS/$NEW.md" "- Related: $OLD" \
        "fixture の前提: 後継が旧 ADR を Related で指している"
    collect_file_has "$CORPUS/index.md" "$ABANDON" \
        "fixture の前提: 廃止を取り消した ADR が index に載っている"
    collect_file_has "$CORPUS/index.md" "$OLD" \
        "fixture の前提: 上書きを取り消した旧 ADR が index に載っている"

    run_sut "$CORPUS"
    collect_rc 0 "取り消し後の ADR 群（12-retirement-undone）は exit 0"

    collect_finish
}

# 上書きの取り消しの手順3（後継の Supersedes 行の除去）を欠くと、レイヤ3 の逆方向が検出する。
@test "面②: 後継に Supersedes 行が残った取り消しを検出する" {
    collect_init
    local dir
    dir=$(copy_corpus supersedes-left)
    sed -i "s|^- Related: $OLD.*|- Supersedes: $OLD|" "$dir/$NEW.md"
    collect_file_has "$dir/$NEW.md" "- Supersedes: $OLD" "変異の前提: 後継に Supersedes 行を戻した"

    run_sut "$dir"
    collect_rc 1 "後継に Supersedes 行が残った ADR 群は exit 1"
    collect_contains "$output" "相互参照違反（逆方向" "逆方向の相互参照違反として報告される"

    collect_finish
}

# 上書きの取り消しの手順1（旧 ADR の front-matter の復元）を欠くと、レイヤ3 の順方向が検出する。
@test "面③: 旧 ADR の front-matter を戻し忘れた取り消しを検出する" {
    collect_init
    local dir
    dir=$(copy_corpus frontmatter-left)
    sed -i "s|^validity: 有効\$|validity: 上書き済み|; s|^superseded-by:\$|superseded-by: $NEW|" "$dir/$OLD.md"
    collect_file_has "$dir/$OLD.md" "superseded-by: $NEW" "変異の前提: 旧 ADR の superseded-by を残した"
    collect_file_has "$dir/$OLD.md" "validity: 上書き済み" "変異の前提: 旧 ADR の validity を残した"

    run_sut "$dir"
    collect_rc 1 "旧 ADR の front-matter を戻し忘れた ADR 群は exit 1"
    collect_contains "$output" "\"Supersedes: $OLD\" が見つかりません" \
        "後継に逆参照が無い順方向の相互参照違反として報告される"

    collect_finish
}

# validity だけを戻して superseded-by を残すと、レイヤ1 が検出する。
@test "面④: superseded-by を空にし忘れた取り消しを検出する" {
    collect_init
    local dir
    dir=$(copy_corpus superseded-by-left)
    sed -i "s|^superseded-by:\$|superseded-by: $NEW|" "$dir/$OLD.md"
    collect_file_has "$dir/$OLD.md" "superseded-by: $NEW" "変異の前提: 旧 ADR の superseded-by を残した"

    run_sut "$dir"
    collect_rc 1 "superseded-by を残した ADR 群は exit 1"
    collect_contains "$output" "validity=有効 だが superseded-by が空ではありません" \
        "レイヤ1 の違反として報告される"

    collect_finish
}

# 取り消しの後に index を再生成しないと、レイヤ2 が検出する。
@test "面⑤: index を再生成しなかった取り消しを検出する" {
    collect_init
    local dir
    dir=$(copy_corpus index-stale)
    grep -vF -- "$ABANDON" "$CORPUS/index.md" >"$dir/index.md"
    collect_file_lacks "$dir/index.md" "$ABANDON" "変異の前提: index が廃止済みの時点のまま"

    run_sut "$dir"
    collect_rc 1 "index を再生成しなかった ADR 群は exit 1"
    collect_contains "$output" "index 同期違反" "レイヤ2 の違反として報告される"

    collect_finish
}
