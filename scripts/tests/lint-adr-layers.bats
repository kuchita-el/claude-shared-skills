#!/usr/bin/env bats
# ADR drift-lint のレイヤ1〜3（plugins/adr/scripts/lint-adr.sh）のテスト。
#
# レイヤ1: front-matter スキーマ検証（空判定・語彙メンバシップ・遷移表の組み合わせ）
# レイヤ2: index 同期
# レイヤ3: 相互参照双方向性（forward / reverse）と list-aware N対1 検査
#
# 【レイヤ3 list-aware の仕様】
# 分割による 1→N は A が複数後継を列挙し、各後継が A を逆参照する N対1 である。
# 従来は superseded-by を行まるごと単一 stem として扱っていたため、正当な分割（リスト値）を
# 相互参照違反として誤検出していた。本ファイルの面⑫〜⑯がその是正を固定する。
#
# 【配置について】テストと fixture を配布物外へ置く境界は docs/distribution-boundary.md が定める。
#
# corpus は fixture ごとに異なり事前起動を共有できないため、共有 setup_file の CORPORA は
# 空にし、検査器の起動は各ケース内で bats 組み込みの `run` により行う
# （helpers/common.bash の「検査器の起動の型」に従う。素の `out=$(bash …)` は errexit 下で
#  exit 1 を期待する invalid corpus の初回反復で abort し、集約報告が全滅する）。

load 'helpers/common'

SUT="$PLUGIN_ROOT/scripts/lint-adr.sh"
CORPUS_DIR="$FIXTURES_DIR/lint-adr"
CORPORA=()
PRECONDITION_PATHS=("$CORPUS_DIR/valid" "$CORPUS_DIR/invalid")

setup_file() {
    common_setup_file
}

# 面②の対象。`<corpus 名>|<期待メッセージ>|<exit ラベル>|<メッセージラベル>`
# 11 fixture は「front-matter 違反の検出」という単一の検査意図であるため1ケースへ束ね、
# fixture ごとの旧ラベルは引数として保持する。
#
# 語彙メンバシップ: 値が非空でも正本の語彙に属さなければ違反にする。
# `gen-adr-index.sh` は `validity: 有効` の完全一致でしか採録しないため、語彙外の値は
# index から静かに脱落する一方、旧実装では lint を通過していた（新規追加時はコミット済み
# index と再生成 index の双方に載らず一致するため、レイヤ2 も原理的に発火しない）。
# 組み合わせ: 語彙に属する値どうしでも、決定2 の遷移表に無い行は違反にする。
LAYER1_INVALID_CASES=(
    '01-status-missing|status が空です|AC1: status 欠落: exit 1|AC1: status 欠落: 違反メッセージ部分一致'
    '02-validity-missing|validity が空です|AC1: status=承認済み かつ validity 欠落: exit 1|AC1: status=承認済み かつ validity 欠落: 違反メッセージ部分一致'
    '03-superseded-by-missing|superseded-by が空です|AC1: validity=上書き済み かつ superseded-by 欠落: exit 1|AC1: validity=上書き済み かつ superseded-by 欠落: 違反メッセージ部分一致'
    '12-status-unknown-vocab|status の値 "Accepted" が語彙にありません|AC1: status 語彙外（旧英文状態）: exit 1|AC1: status 語彙外（旧英文状態）: 違反メッセージ部分一致'
    '13-validity-unknown-vocab|validity の値 "有郊" が語彙にありません|AC1: validity 語彙外（誤字）: exit 1|AC1: validity 語彙外（誤字）: 違反メッセージ部分一致'
    '14-proposed-with-validity|status=提案中 だが validity が空ではありません|AC1: 提案中 かつ validity 非空: exit 1|AC1: 提案中 かつ validity 非空: 違反メッセージ部分一致'
    '15-rejected-with-validity|status=却下 だが validity が空ではありません|AC1: 却下 かつ validity 非空: exit 1|AC1: 却下 かつ validity 非空: 違反メッセージ部分一致'
    '16-active-with-superseded-by|validity=有効 だが superseded-by が空ではありません|AC1: 有効 かつ superseded-by 非空: exit 1|AC1: 有効 かつ superseded-by 非空: 違反メッセージ部分一致'
    '17-abandoned-with-superseded-by|validity=廃止済み だが superseded-by が空ではありません|AC1: 廃止済み かつ superseded-by 非空: exit 1|AC1: 廃止済み かつ superseded-by 非空: 違反メッセージ部分一致'
    '30-proposed-with-superseded-by|status=提案中 だが superseded-by が空ではありません|AC1: 提案中 かつ superseded-by 非空: exit 1|AC1: 提案中 かつ superseded-by 非空: 違反メッセージ部分一致'
    '31-rejected-with-superseded-by|status=却下 だが superseded-by が空ではありません|AC1: 却下 かつ superseded-by 非空: exit 1|AC1: 却下 かつ superseded-by 非空: 違反メッセージ部分一致'
)

# 表が空になった（あるいは大きく削られた）まま緑になる経路を塞ぐ下限。面②のループは
# 反復0回でも collect_finish が成功を返すため、件数そのものを1検査項目として数える。
# 下限は名目値（1件）ではなく現在の実数を置く。名目値にすると表が数件まで削られても
# 緑のまま通り、下限が検査として働かない（lint-adr-surface.bats の AC5 下限と同じ方式）。
LAYER1_INVALID_CASE_MIN=11

@test "前提: 被テスト検査器と fixture corpus が存在する" {
    assert_preconditions_met
}

# ---- レイヤ1 ----

# valid corpus は違反0件で exit 0 になること
# （旧形式スキップ・却下/提案中/廃止済みが合法であることを含む）
@test "面①: レイヤ1 valid corpus が exit 0" {
    collect_init
    run_sut "$CORPUS_DIR/valid/01-mixed-validity"
    collect_rc 0 "AC1: valid corpus(01-mixed-validity) は exit 0"
    collect_finish
}

# invalid corpus は exit 1 ＋ 該当違反種別メッセージの部分一致になること
@test "面②: レイヤ1 不正 front-matter 11 fixture の検出" {
    collect_init

    # 照合件数の下限。ループより先に数え、0件反復が緑として通る経路を塞ぐ。
    if [ "${#LAYER1_INVALID_CASES[@]}" -ge "$LAYER1_INVALID_CASE_MIN" ]; then
        collect_ok "AC1: 検出対象 fixture の照合件数が下限を満たす（${#LAYER1_INVALID_CASES[@]} 件 / 下限 $LAYER1_INVALID_CASE_MIN 件）"
    else
        collect_fail "AC1: 検出対象 fixture の照合件数が下限を満たす" \
            "照合件数 ${#LAYER1_INVALID_CASES[@]} 件が下限 $LAYER1_INVALID_CASE_MIN 件を下回る（表の欠落か fixture の削減。後者なら本定数を下げる）"
    fi

    local entry name needle rc_label msg_label
    for entry in "${LAYER1_INVALID_CASES[@]}"; do
        IFS='|' read -r name needle rc_label msg_label <<<"$entry"
        run_sut "$CORPUS_DIR/invalid/$name"
        # 1件目で打ち切らない。11 fixture を同時に壊しても1回の実行で全件出す。
        collect_rc 1 "$rc_label"
        collect_contains "$output" "$needle" "$msg_label"
    done

    collect_finish
}

# ADR_DIR が存在しない場合は exit 2（fixture 不要、不在パスを渡すだけ）
@test "面③: レイヤ1 対象ディレクトリ不在" {
    collect_init
    run_sut "$CORPUS_DIR/invalid/__nonexistent__"
    collect_rc 2 "AC1: ディレクトリ不在は exit 2"
    collect_finish
}

# 複数 ADR 同時違反: 1件目で早期打ち切りせず全件出力されること
@test "面④: レイヤ1 複数違反の同時報告" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/06-multi-violation"
    collect_rc 1 "AC1(multi): exit 1"
    collect_contains "$output" \
        "ADR-202606011006-01-multi-violation-status-missing.md: status が空です" \
        "AC1(multi): 1件目(status欠落)の違反メッセージ"
    collect_contains "$output" \
        "ADR-202606021006-01-multi-violation-superseded-by-missing.md: validity=上書き済み だが superseded-by が空です" \
        "AC1(multi): 2件目(superseded-by欠落)の違反メッセージ"

    collect_finish
}

# ---- レイヤ2（index 同期） ----

# レイヤ2 は index の不一致を2つの経路で検出する。
# drift: 古い index.md（有効ADRを1件欠く）を同梱した corpus は exit 1 ＋ 同期違反メッセージ。
# 不在: index.md を持たない corpus も不一致として扱う。生成し忘れた index を「差分が無い」と
# 読んで緑にしないための経路であり、drift とは別の分岐が担う。
@test "面⑤: レイヤ2 index 同期違反の検出（drift と不在）" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/04-index-drift"
    collect_rc 1 "AC3: index-drift corpus は exit 1"
    collect_contains "$output" "index 同期違反" "AC3: index-drift corpus の同期違反メッセージ"

    # fixture が index.md を持たないこと自体を検査項目として数える。誰かが index.md を
    # 足すと不在検査の負例が消えるため、その原因が読める形で落とす。
    if [ ! -f "$CORPUS_DIR/invalid/32-index-missing/index.md" ]; then
        collect_ok "AC3: index-missing corpus が index.md を持たない（fixture の前提）"
    else
        collect_fail "AC3: index-missing corpus が index.md を持たない（fixture の前提）" \
            "index.md が同梱されており、不在検査の負例として働かない"
    fi

    run_sut "$CORPUS_DIR/invalid/32-index-missing"
    collect_rc 1 "AC3: index-missing corpus は exit 1"
    collect_contains "$output" "index 同期違反（index.md が存在しません）" \
        "AC3: index-missing corpus の不在を名指しする同期違反メッセージ"

    collect_finish
}

# valid 01-mixed-validity はレイヤ2 追加後も exit 0 を維持すること
@test "面⑥: レイヤ2 追加後も valid が通り続ける" {
    collect_init
    run_sut "$CORPUS_DIR/valid/01-mixed-validity"
    collect_rc 0 "AC3: valid corpus(01-mixed-validity) はレイヤ2追加後も exit 0"
    collect_finish
}

# ---- レイヤ3（相互参照双方向性） ----

# superseded-by=B を持つが B の本文に Supersedes 逆参照が無い corpus は
# exit 1 ＋ 相互参照違反メッセージ
@test "面⑦: レイヤ3 相互参照の欠落検出" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/05-xref-missing"
    collect_rc 1 "AC2: xref-missing corpus は exit 1"
    collect_contains "$output" "相互参照違反" "AC2: xref-missing corpus の相互参照違反メッセージ"

    collect_finish
}

# 相互参照検証専用の valid corpus（双方向一致ペア＋入れ子バレット例＋未知ラベル例）は exit 0
@test "面⑧: レイヤ3 正しい相互参照が通る" {
    collect_init
    run_sut "$CORPUS_DIR/valid/02-xref-valid"
    collect_rc 0 "AC2: xref-valid corpus(02-xref-valid) は exit 0"
    collect_finish
}

# valid 01-mixed-validity はレイヤ3 追加後も exit 0 を維持すること
@test "面⑨: レイヤ3 追加後も validity 混在 corpus が通る" {
    collect_init
    run_sut "$CORPUS_DIR/valid/01-mixed-validity"
    collect_rc 0 "AC2: valid corpus(01-mixed-validity) はレイヤ3追加後も exit 0"
    collect_finish
}

# 仕様: A.superseded-by=B ⟺ B本文 Supersedes: A。
# 従来は front-matter 起点（forward）のみの片方向照合だったため、本文で Supersedes 宣言
# したが front-matter 更新を忘れたケース（逆方向のドリフト）を検出できなかった。
@test "面⑩: レイヤ3 逆向き参照の欠落検出" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/07-xref-reverse-missing"
    collect_rc 1 "PRレビュー反映(reverse-missing): exit 1"
    collect_contains "$output" "相互参照違反（逆方向" \
        "PRレビュー反映(reverse-missing): 逆方向と分かる違反メッセージ"
    collect_contains "$output" "ADR-202607011007-01-xref-reverse-missing-old" \
        "PRレビュー反映(reverse-missing): front-matter更新忘れ側(旧ADR)の言及"

    collect_finish
}

# 入れ子（インデント）バレット `  - Supersedes: ...` を持つ双方向一致ペアは誤検知せず exit 0
@test "面⑪: レイヤ3 ネストした箇条書きの参照が通る" {
    collect_init
    run_sut "$CORPUS_DIR/valid/02-xref-valid"
    collect_rc 0 \
        "PRレビュー反映(nested-bullet): 入れ子バレット双方向一致ペアを含む02-xref-validはexit 0"
    collect_finish
}

# ---- レイヤ3: list-aware N対1 検査 ----
#
# 呼び出し群は同じ汎用ランナー（旧 run_xref_list_case）から呼ばれていたが、corpus ごとに
# 検査意図が異なるため束ねず、面⑫〜⑯へ分けて割り当てる。

# AC1: リスト値の正常分割（A・B 両ファイル存在＋双方が本文逆参照）は違反0件で exit 0
@test "面⑫: list-aware リスト値の正常分割が exit 0" {
    collect_init
    run_sut "$CORPUS_DIR/valid/04-xref-list"
    collect_rc 0 "(AC1): リスト値正常分割は exit 0: exit 0"
    collect_finish
}

# AC2(forward逆参照欠落): 後継Bのみ本文逆参照を欠く → Bのエッジのみ forward 違反、
# 充足側の後継Aは違反メッセージに現れない
@test "面⑬: list-aware forward 逆参照欠落は違反側のエッジのみを報告する" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/08-xref-list-forward-missing"
    collect_rc 1 "(AC2-forward): 後継Bのみ forward 違反: exit 1"
    collect_contains "$output" "相互参照違反" \
        '(AC2-forward): 後継Bのみ forward 違反: "相互参照違反" を含む'
    collect_contains "$output" "ADR-202608121008-01-xref-list-fwd-new-b.md" \
        '(AC2-forward): 後継Bのみ forward 違反: "ADR-202608121008-01-xref-list-fwd-new-b.md" を含む'
    collect_not_contains "$output" "ADR-202608111008-01-xref-list-fwd-new-a" \
        '(AC2-forward): 後継Bのみ forward 違反: "ADR-202608111008-01-xref-list-fwd-new-a" を含まない'

    collect_finish
}

# AC3(reverse列挙欠落): 非列挙の第三ADR Cが本文で old を Supersedes 宣言 →
# Cのエッジが reverse 違反、列挙済みのA・Bは違反にならない
@test "面⑭: list-aware reverse 列挙欠落は非列挙の第三 ADR のみを報告する" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/09-xref-list-reverse-missing"
    collect_rc 1 "(AC3-reverse): 非列挙Cのみ reverse 違反: exit 1"
    collect_contains "$output" "相互参照違反（逆方向" \
        '(AC3-reverse): 非列挙Cのみ reverse 違反: "相互参照違反（逆方向" を含む'
    collect_contains "$output" "ADR-202609131009-01-xref-list-rev-extra-c" \
        '(AC3-reverse): 非列挙Cのみ reverse 違反: "ADR-202609131009-01-xref-list-rev-extra-c" を含む'
    collect_not_contains "$output" "ADR-202609111009-01-xref-list-rev-new-a.md の本文" \
        '(AC3-reverse): 非列挙Cのみ reverse 違反: "ADR-202609111009-01-xref-list-rev-new-a.md の本文" を含まない'

    collect_finish
}

# AC2(forwardファイル不在・リスト要素単位): 後継Bの実ファイルが存在しない →
# Bのエッジのみ「参照先が見つかりません」違反、実在する後継Aは独立して照合へ進み違反にならない
@test "面⑮: list-aware 後継ファイル不在はリスト要素単位の違反になる" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/10-xref-list-forward-file-missing"
    collect_rc 1 "(AC2-file-missing): 後継Bのみ参照先不在違反: exit 1"
    collect_contains "$output" "ADR-202610121010-01-xref-list-fm-missing-b" \
        '(AC2-file-missing): 後継Bのみ参照先不在違反: "ADR-202610121010-01-xref-list-fm-missing-b" を含む'
    collect_contains "$output" "が見つかりません" \
        '(AC2-file-missing): 後継Bのみ参照先不在違反: "が見つかりません" を含む'
    collect_not_contains "$output" "ADR-202610111010-01-xref-list-fm-new-a" \
        '(AC2-file-missing): 後継Bのみ参照先不在違反: "ADR-202610111010-01-xref-list-fm-new-a" を含まない'

    collect_finish
}

# 空要素のみ: superseded-by がカンマ・空白のみで有効な参照先 stem を1つも含まない病的値は、
# レイヤ1の raw 空判定を通過し forward 分割結果が0件になる。「validity=上書き済み ⟹
# 少なくとも1件の後継が照合される」不変条件を回復するため独立違反として検出する。
# 末尾カンマ: 末尾カンマ由来の空要素はスキップされ、有効な後継1本が正しく照合される
# （空要素処理が後方互換を壊さないことの回帰）。
@test "面⑯: list-aware 空要素の扱い" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/11-xref-list-empty-superseded"
    collect_rc 1 "(空要素のみ): 有効な参照先stem 0件を違反として検出: exit 1"
    collect_contains "$output" "有効な参照先 stem がありません" \
        '(空要素のみ): 有効な参照先stem 0件を違反として検出: "有効な参照先 stem がありません" を含む'

    run_sut "$CORPUS_DIR/valid/05-xref-list-trailing-comma"
    collect_rc 0 "(末尾カンマ): 末尾カンマは無害で exit 0: exit 0"

    collect_finish
}
