#!/usr/bin/env bats
# ADR drift-lint（plugins/adr/scripts/lint-adr.sh）のうち、ADR 本文の規約を見る3つの検査のテスト。
#
#   - レイヤ1 種別10: front-matter を持つ ADR の本文に `## Status` 節を置かない
#   - レイヤ5 H1 形式: 有効な ADR の H1 から、index 生成器と同じ条件でタイトルを取り出せる
#   - レイヤ3 forward: 原 ADR の本文が `Superseded by:` を書いているなら、superseded-by の全後継を挙げる
#     （行が1行も無い原 ADR は対象外。凍結された旧い ADR に直せない違反を課さない）
#
# これらは以前 manage-adr の手順書（散文）だけが保証していた。検査器の側へ移したので、
# 退行すれば赤になることと、赤にしてはならない入力（退役・提案中の ADR、コードフェンス内の
# 見出しの例、別の語の見出し）が緑のままであることを、組で固定する。免除の側を壊す変異
# （免除の条件を外すと正例が赤に転じる）と検出の側を壊す変異の双方を、一時ディレクトリへ写した
# ADR 群で確かめる（共有 fixture を書き換えない）。
#
# 面⑤ は、既に検査されている「front-matter の値に末尾コメントを書かない」規範が、語彙・参照の検査を
# 通って赤になることを固定する（専用の検査は持たない。経路が変わって緑になる退行を防ぐ）。
#
# 【配置について】テストと fixture を配布物外へ置く境界は docs/distribution-boundary.md が定める。
#
# ADR 群は fixture ごとに異なり事前起動を共有できないため、共有 setup_file の CORPORA は
# 空にし、検査器の起動は各ケース内で bats 組み込みの `run` により行う。

load 'helpers/common'

SUT="$PLUGIN_ROOT/scripts/lint-adr.sh"
CORPUS_DIR="$FIXTURES_DIR/lint-adr"
CORPORA=()
PRECONDITION_PATHS=(
    "$CORPUS_DIR/valid/13-body-rules"
    "$CORPUS_DIR/invalid/37-body-status-section"
    "$CORPUS_DIR/invalid/38-h1-title-missing"
    "$CORPUS_DIR/invalid/39-superseded-by-not-listed"
)

# valid/13 の ADR（退役した原 ADR・コードフェンスを持つ有効 ADR・後継・提案中）
OLD="ADR-202701011013-01-retired-old.md"
FENCE="ADR-202701021013-01-fence-and-quo.md"
NEW="ADR-202701031013-01-plain-new.md"
PROPOSED="ADR-202701041013-01-proposed-no-title.md"

setup_file() {
    common_setup_file
}

# valid/13 を一時ディレクトリへ写して出力する。
copy_valid13() {
    local dir
    dir="$(mktemp -d "$BATS_TEST_TMPDIR/body-rules.XXXXXX")"
    cp "$CORPUS_DIR/valid/13-body-rules/"* "$dir/"
    printf '%s' "$dir"
}

# ファイル $1 を、sed の式 $2 で書き換える（GNU・BSD の差を避けるため一時ファイル経由）。
mutate() {
    sed "$2" "$1" >"$1.tmp" && mv "$1.tmp" "$1"
}

# ファイル $1 の、行全体が $2 に一致する行の直前へ、$3 の行を挿入する（BSD sed の `\n` 差を避けるため awk）。
insert_before() {
    awk -v pat="$2" -v ins="$3" '$0 == pat { print ins } { print }' "$1" >"$1.tmp" && mv "$1.tmp" "$1"
}

# ファイル $1 の、行全体が $2 に一致する行の直後へ、$3 の行を挿入する。
insert_after() {
    awk -v pat="$2" -v ins="$3" '{ print } $0 == pat { print ins }' "$1" >"$1.tmp" && mv "$1.tmp" "$1"
}

@test "前提: 被テスト検査器と fixture の ADR 群が存在する" {
    assert_preconditions_met
}

@test "面①: 本文の状態節（レイヤ1 種別10）を検出し、免除は緑のまま保つ" {
    collect_init

    # 検出: 有効・提案中の ADR が、節の見出しの形（`## Status` / `## Status:`）で赤になる
    run_sut "$CORPUS_DIR/invalid/37-body-status-section"
    collect_rc 1 "本文に ## Status 節を持つ ADR 群は exit 1"
    collect_contains "$output" "ADR-202701011037-01-body-status-active.md: 本文に \"## Status\" 節があります（7 行目" \
        "有効な ADR の状態節を、行番号つきで報告する"
    collect_contains "$output" "ADR-202701021037-01-body-status-proposed.md: 本文に \"## Status\" 節があります" \
        "提案中の ADR の状態節も報告する（コロン付きの見出しを含む）"
    collect_equals "$(printf '%s\n' "$output" | grep -c '本文に "## Status" 節があります')" "2" \
        "報告は2件ちょうど（他の検査と重ならない）"
    collect_not_contains "$output" "H1 形式違反" "状態節の ADR 群で H1 形式違反は出ない"

    # 免除: コードフェンス内の見出しの例、別の語の見出し（## Status quo）、退役した ADR の状態節は赤にならない
    run_sut "$CORPUS_DIR/valid/13-body-rules"
    collect_rc 0 "コードフェンス内の ## Status、## Status quo、退役 ADR の ## Status は違反にしない"

    # 免除側の変異（正例が赤へ転じる）: 退役を有効へ変えると、同じ状態節が違反になる
    local dir RETIRED_STATUS="ADR-202701051013-01-retired-with-status.md"
    dir="$(copy_valid13)"
    mutate "$dir/$RETIRED_STATUS" 's/^validity: 廃止済み$/validity: 有効/'
    run_sut "$dir"
    collect_contains "$output" "$RETIRED_STATUS: 本文に \"## Status\" 節があります" \
        "変異: 退役を有効へ変えると状態節が違反になる"
    dir="$(copy_valid13)"
    mutate "$dir/$RETIRED_STATUS" 's/^validity: 廃止済み$/validity: 上書き済み/'
    insert_after "$dir/$RETIRED_STATUS" "validity: 上書き済み" "superseded-by: ADR-202701031013-01-plain-new"
    collect_equals "$(grep -c '^superseded-by: ADR-202701031013-01-plain-new$' "$dir/$RETIRED_STATUS")" "1" \
        "前提: 変異した ADR が上書き済みと superseded-by を持つ（持たないと下の免除の確認が空振りする）"
    run_sut "$dir"
    collect_not_contains "$output" "$RETIRED_STATUS: 本文に \"## Status\" 節があります" \
        "上書き済みの ADR の状態節も免除する"

    # 免除側の変異（正例が赤へ転じる）: フェンスの開閉行を消すと、内側の見出しが節になる
    dir="$(copy_valid13)"
    mutate "$dir/$FENCE" '/^```/d'
    run_sut "$dir"
    collect_rc 1 "変異: フェンスを外すと見出しが節とみなされて exit 1"
    collect_contains "$output" "$FENCE: 本文に \"## Status\" 節があります" "変異: フェンスを外した ADR が報告される"

    # 免除側の変異: `## Status quo` を `## Status` へ変える
    dir="$(copy_valid13)"
    mutate "$dir/$FENCE" 's/^## Status quo$/## Status/'
    run_sut "$dir"
    collect_rc 1 "変異: 見出しを Status だけにすると exit 1"

    # 見出しの揺れ（大文字小文字・全角コロン・括弧書き）も節とみなす。観測する量（違反の件数）は
    # 保ったまま見出しの綴りだけを変える変異であり、パターンを `Status` 完全一致へ狭める退行を拾う。
    local variant
    for variant in '## STATUS' '## status:' '## Status：' '## Status（旧）' '## Status (legacy)'; do
        dir="$(copy_valid13)"
        mutate "$dir/$NEW" "s/^## Consequences\$/$variant/"
        run_sut "$dir"
        collect_rc 1 "変異: 見出し \"$variant\" は状態節とみなす"
        collect_contains "$output" "$NEW: 本文に \"## Status\" 節があります" \
            "変異: 見出し \"$variant\" の ADR が報告される"
    done

    # 検査対象は front-matter を持つ ADR のみ。持たない ADR は種別9 が報告し、状態節を重ねて数えない
    run_sut "$CORPUS_DIR/invalid/36-frontmatter-missing"
    collect_not_contains "$output" "本文に \"## Status\" 節があります" \
        "front-matter を持たない ADR の状態節を重ねて数えない（種別9 だけ）"

    # 独立起動: 種別10 はレイヤ1 の単位が持ち、他のレイヤの単位は出さない
    run_sut_layer check_layer1_frontmatter_schema "$CORPUS_DIR/invalid/37-body-status-section"
    collect_rc 0 "状態節の ADR 群へレイヤ1 だけを起動できる"
    collect_contains "$output" "[violations=2]" "レイヤ1 の単独起動が状態節を数える"
    run_sut_layer check_layer5_filename_and_identifier "$CORPUS_DIR/invalid/37-body-status-section"
    collect_contains "$output" "[violations=0]" "レイヤ5 の単独起動は状態節を数えない"

    collect_finish
}

@test "面②: 有効な ADR の H1 形式（レイヤ5）を検出し、退役・提案中は免除する" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/38-h1-title-missing"
    collect_rc 1 "H1 に区切りまたはタイトルが無い有効な ADR 群は exit 1"
    collect_contains "$output" "ADR-202701011038-01-h1-no-separator.md: H1 形式違反" "区切りの無い H1 を報告する"
    collect_contains "$output" "ADR-202701021038-01-h1-empty-title.md: H1 形式違反" "タイトルが空の H1（slug を含む形）を報告する"
    collect_equals "$(printf '%s\n' "$output" | grep -c 'H1 形式違反')" "2" "報告は2件ちょうど"
    collect_not_contains "$output" "H1 整合違反" "識別子部が一致しているので H1 整合違反とは重ねない"

    # 免除: 退役した原 ADR と提案中の ADR は、H1 が崩れていても違反にしない
    run_sut "$CORPUS_DIR/valid/13-body-rules"
    collect_rc 0 "退役・提案中の ADR の H1 形式は検査しない"

    local dir
    # 免除側の変異（正例が赤へ転じる）: 提案中を有効へ変えると、同じ H1 が違反になる
    dir="$(copy_valid13)"
    mutate "$dir/$PROPOSED" 's/^status: 提案中$/status: 承認済み/; s/^validity:$/validity: 有効/'
    run_sut "$dir"
    collect_contains "$output" "$PROPOSED: H1 形式違反" "変異: 提案中を有効へ変えると H1 形式違反になる"

    # 免除側の変異: 退役を有効へ変える側（superseded-by を空にして validity を有効へ）
    dir="$(copy_valid13)"
    mutate "$dir/$OLD" 's/^validity: 上書き済み$/validity: 有効/; s/^superseded-by: .*$/superseded-by:/'
    run_sut "$dir"
    collect_contains "$output" "$OLD: H1 形式違反" "変異: 退役を有効へ変えると H1 形式違反になる"

    # 受理する形: slug を含む識別子部は受ける。違反が出ないことを rc で固定する
    dir="$(copy_valid13)"
    mutate "$dir/$NEW" 's/^# ADR-202701031013-01: /# ADR-202701031013-01-plain-new: /'
    run_sut "$dir"
    collect_rc 0 "slug を含む識別子部の H1 は受理する"

    # 検出側の変異: 半角空白の無いコロンは、gen-adr-index.sh が ": " で切れないため違反にする
    dir="$(copy_valid13)"
    mutate "$dir/$NEW" 's/^# ADR-202701031013-01: /# ADR-202701031013-01:/'
    run_sut "$dir"
    collect_contains "$output" "$NEW: H1 形式違反" "変異: コロンの後に空白が無い H1 は違反"

    # 検出側の変異: ": " はあるがタイトルが空白だけの H1 は、タイトル欄が空になるので違反
    dir="$(copy_valid13)"
    mutate "$dir/$NEW" 's/^# ADR-202701031013-01: .*$/# ADR-202701031013-01:   /'
    run_sut "$dir"
    collect_contains "$output" "$NEW: H1 形式違反" "変異: タイトルが空白だけの H1 は違反"

    # 受理する形: 識別子部とコロンのあいだに空白があっても、get_title は ": " 以降を取り出せる
    # （index 生成器が正しく扱う形を違反にしない）。index は再生成して同期させる。
    dir="$(copy_valid13)"
    mutate "$dir/$NEW" 's/^# ADR-202701031013-01: /# ADR-202701031013-01 : /'
    bash "$PLUGIN_ROOT/scripts/gen-adr-index.sh" "$dir" >"$dir/index.md"
    run_sut "$dir"
    collect_rc 0 "識別子部の後ろに空白を置いた \"ID : タイトル\" の H1 は受理する"
    collect_contains "$(cat "$dir/index.md")" "$NEW" "前提: 再生成した index が当該 ADR を載せている"

    # 識別子の不一致は従来どおり H1 整合違反だけが出る（形式違反を重ねない）
    dir="$(copy_valid13)"
    mutate "$dir/$NEW" 's/^# ADR-202701031013-01: .*$/# ADR-209901010000-01 別の識別子/'
    run_sut "$dir"
    collect_contains "$output" "H1 整合違反" "変異: 識別子の不一致は H1 整合違反として報告する"
    collect_not_contains "$output" "$NEW: H1 形式違反" "変異: 識別子の不一致に H1 形式違反を重ねない"

    # 独立起動
    run_sut_layer check_layer5_filename_and_identifier "$CORPUS_DIR/invalid/38-h1-title-missing"
    collect_rc 0 "H1 形式違反の ADR 群へレイヤ5 だけを起動できる"
    collect_contains "$output" "[violations=2]" "レイヤ5 の単独起動が H1 形式違反を数える"
    run_sut_layer check_layer1_frontmatter_schema "$CORPUS_DIR/invalid/38-h1-title-missing"
    collect_contains "$output" "[violations=0]" "レイヤ1 の単独起動は H1 形式違反を数えない"

    collect_finish
}

@test "面③: 原 ADR 本文の Superseded by: が全後継を挙げること（レイヤ3 forward）" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/39-superseded-by-not-listed"
    collect_rc 1 "後継の一部しか挙げない原 ADR は exit 1"
    collect_contains "$output" "ADR-202701011039-01-split-old.md: 相互参照違反（原 ADR 自身の本文 \"## 関連ADR\" の \"Superseded by:\" 行が後継 ADR-202701031039-01-split-new-b を挙げていません。後継の一部だけが書かれています）" \
        "挙がっていない後継を名指しして報告する"
    collect_not_contains "$output" "後継 ADR-202701021039-01-split-new-a を挙げていません" \
        "挙がっている後継は報告しない"
    collect_equals "$(printf '%s\n' "$output" | grep -c '相互参照違反')" "1" "報告は1件ちょうど（Supersedes 側の双方向は揃っている）"

    # 免除: 後継ごとにバレットを立てる形は全後継が挙がっているので緑。1行へ並べる形は valid/04 が持つ
    run_sut "$CORPUS_DIR/valid/13-body-rules"
    collect_rc 0 "後継ごとにバレットを分けた形は受理する"
    run_sut "$CORPUS_DIR/valid/04-xref-list"
    collect_rc 0 "1行へ並べた形は受理する"

    local dir
    # 検出側の変異: バレットを1つ消すと（もう1つは残る）、消した後継が報告される
    dir="$(copy_valid13)"
    mutate "$dir/$OLD" '/^- Superseded by: ADR-202701031013-01-plain-new$/d'
    run_sut "$dir"
    collect_rc 1 "変異: 後継のバレットを1つ消すと exit 1"
    collect_contains "$output" "後継 ADR-202701031013-01-plain-new を挙げていません" "変異: 消した後継が報告される"
    collect_not_contains "$output" "後継 ADR-202701021013-01-fence-and-quo を挙げていません" "変異: 残した後継は報告されない"

    # 免除（対の側）: Superseded by: の行が1行も無い原 ADR は、凍結された旧い ADR を想定して違反にしない
    dir="$(copy_valid13)"
    mutate "$dir/$OLD" '/^- Superseded by: /d'
    collect_equals "$(grep -c 'Superseded by:' "$dir/$OLD")" "0" "前提: 変異した原 ADR に Superseded by: の行が無い"
    run_sut "$dir"
    collect_rc 0 "Superseded by: の行が1行も無い原 ADR は違反にしない"

    # 観測する量（Superseded by: の行の数）を保ったまま中身を変える変異: 後継の stem を別の ADR へ差し替える
    dir="$(copy_valid13)"
    mutate "$dir/$OLD" 's/^- Superseded by: ADR-202701031013-01-plain-new$/- Superseded by: ADR-202701021013-01-fence-and-quo/'
    run_sut "$dir"
    collect_contains "$output" "後継 ADR-202701031013-01-plain-new を挙げていません" \
        "変異: 行数を保ったまま後継を差し替えても報告される"

    # 完全一致: 後継の stem を前方に含む別の長い stem は、後継を挙げたことにならない
    dir="$(copy_valid13)"
    mutate "$dir/$OLD" 's/^- Superseded by: ADR-202701031013-01-plain-new$/- Superseded by: ADR-202701031013-01-plain-new-extra/'
    run_sut "$dir"
    collect_contains "$output" "後継 ADR-202701031013-01-plain-new を挙げていません" \
        "変異: 後継の stem を前方に含む別の stem では挙げたことにならない"

    # ラベルの綴りを変えると、その行は Superseded by: の行ではなくなる（もう1行は残るので部分記載）
    dir="$(copy_valid13)"
    mutate "$dir/$OLD" 's/^- Superseded by: ADR-202701031013-01-plain-new$/- Replaced by: ADR-202701031013-01-plain-new/'
    run_sut "$dir"
    collect_contains "$output" "後継 ADR-202701031013-01-plain-new を挙げていません" "変異: 別のラベルでは挙げたことにならない"

    # 節の外の行は数えない: 2つ目のバレットを、後続の別の節（## 補足）の側へ移す
    dir="$(copy_valid13)"
    insert_before "$dir/$OLD" "- Superseded by: ADR-202701031013-01-plain-new" "## 補足"
    insert_before "$dir/$OLD" "- Superseded by: ADR-202701031013-01-plain-new" ""
    collect_equals "$(grep -c '^## 補足$' "$dir/$OLD")" "1" "前提: 変異した原 ADR に ## 補足 の節がある"
    run_sut "$dir"
    collect_contains "$output" "後継 ADR-202701031013-01-plain-new を挙げていません" "変異: 関連ADR 節の外の Superseded by: は数えない"
    collect_not_contains "$output" "後継 ADR-202701021013-01-fence-and-quo を挙げていません" "変異: 節の内側に残した後継は報告されない"

    # 独立起動: レイヤ3 forward の単位が持つ
    run_sut_layer check_layer3_forward "$CORPUS_DIR/invalid/39-superseded-by-not-listed"
    collect_rc 0 "レイヤ3 forward だけを起動できる"
    collect_contains "$output" "[violations=1]" "レイヤ3 forward の単独起動が記載漏れを数える"
    run_sut_layer check_layer3_reverse "$CORPUS_DIR/invalid/39-superseded-by-not-listed"
    collect_contains "$output" "[violations=0]" "レイヤ3 reverse の単独起動は記載漏れを数えない"

    collect_finish
}

@test "面④: ヘッダが3つの検査の違反条件を成文化している" {
    collect_init

    local header
    header=$(sed -n '1,/^set -euo pipefail/p' "$SUT" 2>/dev/null || true)

    collect_contains "$header" "10. 本文に \`## Status\` 節がある" "レイヤ1 の違反種別10 が列挙されている"
    collect_contains "$header" "種別10 を持つのは" "種別10 の採用理由が成文化されている"
    collect_contains "$header" "H1 形式違反:" "レイヤ5 の H1 形式違反の条件が成文化されている"
    collect_contains "$header" "行が1行も無い原 ADR は違反にしない" "レイヤ3 forward の対象外（行が無い原 ADR）が成文化されている"
    collect_contains "$header" "全後継 Bi を" "レイヤ3 forward の原 ADR 本文の照合が成文化されている"

    collect_finish
}

# 既に検査されている規範の固定。front-matter の値に末尾コメントを書くと、lint は行全体を値として
# 読むため、語彙外・非空の値として赤になる（専用の検査は持たない）。経路が変わってこの入力が
# 緑になる退行を防ぐ。YAML のコメント行（行頭 `#`）は別であり、valid/08 が緑を固定している。
@test "面⑤: front-matter の値の末尾コメントは既存の検査で赤になる" {
    collect_init

    run_sut "$CORPUS_DIR/valid/08-frontmatter-yaml-comment"
    collect_rc 0 "前提: YAML のコメント行は違反にしない"

    local dir
    dir="$(copy_valid13)"
    mutate "$dir/$NEW" 's/^status: 承認済み$/status: 承認済み # 説明/'
    run_sut "$dir"
    collect_rc 1 "status の値の末尾コメントは exit 1"
    collect_contains "$output" "語彙にありません" "status の値の末尾コメントは語彙外として報告される"

    dir="$(copy_valid13)"
    mutate "$dir/$NEW" 's/^validity: 有効$/validity: 有効 # 説明/'
    run_sut "$dir"
    collect_rc 1 "validity の値の末尾コメントは exit 1"

    dir="$(copy_valid13)"
    mutate "$dir/$PROPOSED" 's/^validity:$/validity: # 無し/'
    run_sut "$dir"
    collect_rc 1 "空であるべき validity の値がコメントだけでも exit 1"
    collect_contains "$output" "$PROPOSED: status=提案中 だが validity が空ではありません" \
        "空であるべき validity のコメントは非空として報告される"

    dir="$(copy_valid13)"
    mutate "$dir/$OLD" 's/^superseded-by: \(.*\)$/superseded-by: \1 # 説明/'
    run_sut "$dir"
    collect_rc 1 "superseded-by の値の末尾コメントは exit 1"

    collect_finish
}
