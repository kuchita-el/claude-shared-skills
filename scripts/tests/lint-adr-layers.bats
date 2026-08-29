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
# 各 fixture は「front-matter 違反の検出」という単一の検査意図であるため1ケースへ束ね、
# fixture ごとの旧ラベルは引数として保持する。
# 件数の宣言は下の LAYER1_INVALID_CASE_MIN 1箇所に限る。ケース名やコメントへ具体数を
# 書き写すと、表へ1件足したときに片方だけが古い数のまま残る。
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
# 数える対象はループが実際に走らせた照合の回数であり、配列リテラルの要素数ではない。
# 宣言だけを読むと、照合ループごと消えても配列さえ残っていれば下限が緑を返し、下限自身が
# 退行しうる量を観測しなくなる（manage-adr-surface.bats の AC5 下限は実行時に抽出した行数を
# 下限とループの双方が消費する形であり、それに合わせる）。
# 下限は名目値（1件）ではなく現在の実数を置く。名目値にすると表が数件まで削られても
# 緑のまま通り、下限が検査として働かない。
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
@test "面②: レイヤ1 不正 front-matter fixture 群の検出" {
    collect_init

    local entry name needle rc_label msg_label
    local matched=0
    for entry in "${LAYER1_INVALID_CASES[@]}"; do
        IFS='|' read -r name needle rc_label msg_label <<<"$entry"
        # 期待メッセージ欄が空の行は照合として成立しない。collect_contains は空 needle に
        # 対して常に合格を返すため、空欄のまま残るとその行はメッセージ側の検出力を失う。
        # 下限にも数えず、行を名指しして落とす。
        if [ -z "$needle" ]; then
            collect_fail "AC1: 表の期待メッセージ欄が空ではない（$name）" \
                "期待メッセージ欄が空。空 needle は常に一致するため、この行のメッセージ照合は検出力を持たない"
            continue
        fi
        run_sut "$CORPUS_DIR/invalid/$name"
        # 1件目で打ち切らない。表の全 fixture を同時に壊しても1回の実行で全件出す。
        collect_rc 1 "$rc_label"
        collect_contains "$output" "$needle" "$msg_label"
        matched=$((matched + 1))
    done

    # 照合件数の下限。ループが実際に走らせた回数を数え、0件反復が緑として通る経路を塞ぐ。
    if [ "$matched" -ge "$LAYER1_INVALID_CASE_MIN" ]; then
        collect_ok "AC1: 検出対象 fixture の照合件数が下限を満たす（$matched 件 / 下限 $LAYER1_INVALID_CASE_MIN 件）"
    else
        collect_fail "AC1: 検出対象 fixture の照合件数が下限を満たす" \
            "照合件数 $matched 件が下限 $LAYER1_INVALID_CASE_MIN 件を下回る（表の欠落・照合ループの退行・fixture の削減。最後の場合のみ本定数を下げる）"
    fi

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
    collect_contains "$output" "index 同期違反（gen-adr-index.sh の出力と一致しません" \
        "AC3: index-drift corpus の drift を名指しする同期違反メッセージ"

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

# 逆方向の相互参照は2つの分岐を持つ。参照先は実在するが front-matter が宣言元を指していない
# 経路（面⑩・面⑭）と、宣言の参照先ファイルそのものが存在しない経路である。後者は Issue #800 の
# 被覆表で唯一の未被覆分岐として拾われた。当時の40 corpus のいずれでも発火せず、実装から当該
# 分岐を落としても全テストが緑のまま通る状態にあった。
# invalid/34 は単一原因で違反1件になる corpus であり、他レイヤの出力が混ざらないことも
# 併せて固定する。混ざると、当該分岐を落とす変異でこのケースが赤にならない。
@test "面⑰: レイヤ3 逆方向で宣言の参照先そのものが不在の検出" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/34-xref-reverse-dangling"
    collect_rc 1 "#800: xref-reverse-dangling corpus は exit 1"
    collect_contains "$output" '相互参照違反（逆方向: 本文 "## 関連ADR" の "Supersedes: ' \
        "#800: 逆方向の本文宣言起点であることを名指しする違反メッセージ"
    collect_contains "$output" "宣言の参照先" \
        "#800: 参照先そのものの不在であることを名指しする違反メッセージ"
    collect_contains "$output" "ADR-202612101034-01-xref-reverse-dangling-absent-old.md が見つかりません" \
        "#800: 不在の参照先を名指しする違反メッセージ"

    # 参照先が実在して front-matter だけが追随していない経路（面⑩）とは別の分岐であることを
    # 固定する。後者のメッセージが出るなら、参照先不在の分岐を通らずに済んでいる。
    collect_not_contains "$output" "front-matter superseded-by がそれを指していません" \
        "#800: 参照先が実在する側の逆方向メッセージは出ない"

    # 他レイヤの違反が混ざらないこと（単一原因の corpus であることの固定）
    collect_not_contains "$output" "index 同期違反" "#800: レイヤ2 の違反が混ざらない"
    collect_not_contains "$output" "ファイル名形式違反" "#800: レイヤ5（形式）の違反が混ざらない"
    collect_not_contains "$output" "H1 整合違反" "#800: レイヤ5（H1）の違反が混ざらない"
    collect_not_contains "$output" "識別子重複違反" "#800: レイヤ5（重複）の違反が混ざらない"
    collect_not_contains "$output" "参照先退役違反" "#800: レイヤ4（退役）の違反が混ざらない"
    collect_not_contains "$output" "dangling 参照違反" "#800: レイヤ4（dangling）の違反が混ざらない"

    collect_finish
}

# ---- レイヤ単位の独立起動 ----
#
# Issue #800 の構造整理まで、レイヤ1のループが検査本体と前処理を兼ねており、他レイヤが
# 消費する事実はそのループ内で副次的に充填されていた。このためレイヤ1を実行せずに他の
# レイヤを起動できず、レイヤ単位で検査を確かめる手段が無かった。
# 以下は事実の収集だけを済ませた状態で単一レイヤを起動し、起動したレイヤの違反だけが
# 出ることを外から確かめる。読み込みは run_sut_layer が部分シェル経由で行う。
@test "面⑱: 事実の収集だけを済ませた状態で単一レイヤを起動できる" {
    collect_init

    # 起動しなかったレイヤの違反が出ないこと。invalid/32 はレイヤ2 だけが発火する corpus。
    run_sut_layer check_layer3_reverse "$CORPUS_DIR/invalid/32-index-missing"
    collect_rc 0 "#800: index 不在 corpus へレイヤ3 reverse だけを起動できる"
    collect_contains "$output" "[violations=0]" \
        "#800: index 不在 corpus でレイヤ3 reverse は違反を数えない"
    collect_not_contains "$output" "index 同期違反" \
        "#800: レイヤ3 reverse の単独起動でレイヤ2 の違反は出ない"

    # 逆向き。invalid/34 はレイヤ3 reverse だけが発火する corpus。
    run_sut_layer check_layer2_index_sync "$CORPUS_DIR/invalid/34-xref-reverse-dangling"
    collect_rc 0 "#800: 逆方向参照先不在 corpus へレイヤ2 だけを起動できる"
    collect_contains "$output" "[violations=0]" \
        "#800: 逆方向参照先不在 corpus でレイヤ2 は違反を数えない"
    collect_not_contains "$output" "相互参照違反" \
        "#800: レイヤ2 の単独起動でレイヤ3 の違反は出ない"

    # 単独起動が「何も検査しない」へ退化していないこと。起動したレイヤの違反は出る。
    # この項が無いと、レイヤ関数の中身を空にする変異でも上の2項が緑のまま通る。
    run_sut_layer check_layer3_reverse "$CORPUS_DIR/invalid/34-xref-reverse-dangling"
    collect_rc 0 "#800: 逆方向参照先不在 corpus へレイヤ3 reverse だけを起動できる"
    collect_contains "$output" "[violations=1]" \
        "#800: 起動したレイヤの違反は数える"
    collect_contains "$output" "相互参照違反（逆方向" \
        "#800: 起動したレイヤの違反は出力する"

    # 前処理結果を消費する側のレイヤが、収集済みの事実を実際に読めていること。
    # valid/02-xref-valid は双方向が揃った corpus であり、レイヤ3 reverse は参照先の
    # front-matter superseded-by を写像から読んで一致を確認する。写像を作る単位が
    # 連想配列を関数ローカルで宣言してしまうと後続のレイヤから見えなくなり、ここが
    # 「front-matter superseded-by がそれを指していません」の偽陽性として現れる。
    run_sut_layer check_layer3_reverse "$CORPUS_DIR/valid/02-xref-valid"
    collect_rc 0 "#800: 双方向一致 corpus へレイヤ3 reverse だけを起動できる"
    collect_contains "$output" "[violations=0]" \
        "#800: 収集済みの事実が揃っており偽陽性を出さない"
    collect_not_contains "$output" "がそれを指していません" \
        "#800: 写像が見えないことによる偽陽性が出ない"

    collect_finish
}

# レイヤ単位の起動口は「検査器を読み込んでも検査本体が走らない」ことに依存する。
# 直接実行と読み込みを分ける判定が壊れると、読み込みだけで対象ディレクトリ不在の
# 経路へ入って終了し、テスト側がレイヤ関数へ到達できなくなる（面⑱が前提を失う）。
@test "面⑲: 検査器の読み込みだけでは対象ディレクトリ不在で終了しない" {
    collect_init

    run bash -c 'source "$1"; printf "[sourced rc=%s]\n" "$?"; printf "[pattern=%s]\n" "${ADR_STEM_PATTERN:-未定義}"' \
        _ "$SUT" </dev/null
    collect_rc 0 "#800: 対象ディレクトリを渡さない読み込みが終了コード0で戻る"
    collect_contains "$output" "[sourced rc=0]" "#800: 読み込み自体が成功する"
    collect_not_contains "$output" "[pattern=未定義]" "#800: 読み込みで定数定義が得られる"
    collect_not_contains "$output" "ディレクトリが見つかりません" \
        "#800: 読み込みでは対象ディレクトリ不在の経路へ入らない"

    # 直接実行時は従来どおり不在で exit 2（面③と同じ経路。判定の両側を1ケース内で押さえる）
    run_sut "$CORPUS_DIR/invalid/__nonexistent__"
    collect_rc 2 "#800: 直接実行では対象ディレクトリ不在が exit 2 のまま"

    collect_finish
}

# ---- FM_FILES を読む単位の独立起動 ----
#
# 面⑱ が押さえる単位は SCAN_TARGETS を読む2つ（レイヤ2・レイヤ3 reverse）に限られ、
# lint-adr-xref.bats 面⑧ を足してもレイヤ4 までである。collect_facts が構築する FM_FILES を
# 読む3単位（レイヤ1・レイヤ3 forward・レイヤ5）は1つも独立起動されておらず、Issue #800 が
# 解いた結合そのもの——ある単位のループが前処理を兼ね、他の単位が消費する事実をそのループ内で
# 副次的に充填する——を FM_FILES について再導入しても全ケースが緑のまま通った。
# 3単位それぞれが、他の単位を実行せずに自分の違反だけを出すことをここで固定する。
# 由来: Issue #800 に対する PR #801 のレビュー指摘1。
@test "面⑳: FM_FILES を読む3単位がそれぞれ独立に起動できる" {
    collect_init

    # レイヤ1。invalid/01 はレイヤ1 だけが発火する corpus。
    run_sut_layer check_layer1_frontmatter_schema "$CORPUS_DIR/invalid/01-status-missing"
    collect_rc 0 "#800: status 欠落 corpus へレイヤ1 だけを起動できる"
    collect_contains "$output" "[violations=1]" "#800: レイヤ1 の単独起動が違反を数える"
    collect_contains "$output" "status が空です" "#800: レイヤ1 の単独起動が違反を出力する"

    # レイヤ3 forward。invalid/05 はレイヤ3 forward だけが発火する corpus。
    run_sut_layer check_layer3_forward "$CORPUS_DIR/invalid/05-xref-missing"
    collect_rc 0 "#800: 相互参照欠落 corpus へレイヤ3 forward だけを起動できる"
    collect_contains "$output" "[violations=1]" "#800: レイヤ3 forward の単独起動が違反を数える"
    collect_contains "$output" 'に "Supersedes:' "#800: レイヤ3 forward の単独起動が違反を出力する"

    # レイヤ5。invalid/24 はレイヤ5 だけが発火する corpus。
    run_sut_layer check_layer5_filename_and_identifier "$CORPUS_DIR/invalid/24-filename-format-invalid"
    collect_rc 0 "#800: ファイル名形式違反 corpus へレイヤ5 だけを起動できる"
    collect_contains "$output" "[violations=1]" "#800: レイヤ5 の単独起動が違反を数える"
    collect_contains "$output" "ファイル名形式違反" "#800: レイヤ5 の単独起動が違反を出力する"

    # 逆向き。起動しなかった単位の違反は出ない。FM_FILES の充填をどれか1単位の中へ戻す
    # 変異は、その単位を起動しない下の2件のいずれかで必ず赤になる。
    run_sut_layer check_layer5_filename_and_identifier "$CORPUS_DIR/invalid/01-status-missing"
    collect_rc 0 "#800: status 欠落 corpus へレイヤ5 だけを起動できる"
    collect_contains "$output" "[violations=0]" "#800: status 欠落 corpus でレイヤ5 は違反を数えない"
    collect_not_contains "$output" "status が空です" "#800: レイヤ5 の単独起動でレイヤ1 の違反は出ない"

    run_sut_layer check_layer1_frontmatter_schema "$CORPUS_DIR/invalid/24-filename-format-invalid"
    collect_rc 0 "#800: ファイル名形式違反 corpus へレイヤ1 だけを起動できる"
    collect_contains "$output" "[violations=0]" "#800: ファイル名形式違反 corpus でレイヤ1 は違反を数えない"
    collect_not_contains "$output" "ファイル名形式違反" "#800: レイヤ1 の単独起動でレイヤ5 の違反は出ない"

    collect_finish
}

# ---- 違反の出力順 ----
#
# 起動部は「違反の出力順はこの呼び出し順で決まる」と宣言し、Issue #800 もこれを不変条件へ
# 挙げる。しかし負例 corpus は35本目を置くまで、違反が2件以上出る3本（06・28・33）が
# いずれも同一レイヤ内の違反であり、レイヤ間の相対順序をどのアサーションも観測していなかった。
# 関数抽出後は起動部の2行を入れ替えるだけで順序が壊れる（基準版では同じ破壊に100行規模の
# ブロック移動を要した）。6単位を1本ずつ同時に発火させる corpus で全5境界を固定する。
# 由来: Issue #800 に対する PR #801 のレビュー指摘2。
#
# `<needle>|<単位名>` を起動部の呼び出し順に並べる。needle は単位を一意に決める断片であり
# 互いに包含関係を持たない（レイヤ3 の2単位は `に "Supersedes:` と `（逆方向:` で分かれる。
# 共通する `相互参照違反` を needle に採ると、どちらの行にも一致して順序を観測できない）。
LAYER_ORDER_NEEDLES=(
    'status が空です|レイヤ1'
    'index 同期違反|レイヤ2'
    'の本文 "## 関連ADR" に "Supersedes:|レイヤ3 forward'
    '相互参照違反（逆方向:|レイヤ3 reverse'
    '参照先退役違反|レイヤ4'
    'ファイル名形式違反|レイヤ5'
)

# 表が空になった（あるいは削られた）まま緑になる経路を塞ぐ下限。数える対象はループが実際に
# 出力の中から見つけた単位の数であり、配列リテラルの要素数ではない。下限は名目値ではなく
# corpus が実際に発火させる実数を置く。
LAYER_ORDER_UNIT_MIN=6

@test "面㉑: 違反の出力順が起動部の呼び出し順で決まる" {
    collect_init

    run_sut "$CORPUS_DIR/invalid/35-layer-order"
    collect_rc 1 "#800: 6単位同時発火 corpus が exit 1"
    collect_equals "${#lines[@]}" "$LAYER_ORDER_UNIT_MIN" \
        "#800: 6単位同時発火 corpus の出力が1単位1件になっている"

    local entry needle unit i idx matched=0 prev_idx=-1 prev_unit=""
    for entry in "${LAYER_ORDER_NEEDLES[@]}"; do
        needle="${entry%%|*}"
        unit="${entry##*|}"

        idx=-1
        for i in "${!lines[@]}"; do
            if [[ "${lines[$i]}" == *"$needle"* ]]; then
                idx="$i"
                break
            fi
        done

        if [ "$idx" -lt 0 ]; then
            collect_fail "#800: $unit の違反が出力に現れる" \
                "needle \"$needle\" が出力に無い / output: $output"
            continue
        fi
        collect_ok "#800: $unit の違反が出力に現れる"
        matched=$((matched + 1))

        if [ -n "$prev_unit" ]; then
            if [ "$idx" -gt "$prev_idx" ]; then
                collect_ok "#800: $unit の違反が $prev_unit の違反より後に出る"
            else
                collect_fail "#800: $unit の違反が $prev_unit の違反より後に出る" \
                    "$unit は $prev_idx 行目の $prev_unit より後ろに無い（$idx 行目）/ output: $output"
            fi
        fi

        prev_idx="$idx"
        prev_unit="$unit"
    done

    if [ "$matched" -ge "$LAYER_ORDER_UNIT_MIN" ]; then
        collect_ok "#800: 順序を観測した単位数が下限を満たす（$matched 件 / 下限 $LAYER_ORDER_UNIT_MIN 件）"
    else
        collect_fail "#800: 順序を観測した単位数が下限を満たす" \
            "観測件数 $matched 件が下限 $LAYER_ORDER_UNIT_MIN 件を下回る（表の欠落・照合ループの退行・corpus の縮小）"
    fi

    collect_finish
}

# ---- 収集を欠いた起動 ----
#
# レイヤ単位の起動を公開された使い方として位置づけた以上、その前提（事実の収集）を欠いた
# 起動は「検査したが違反なし」ではなく誤りとして現れる必要がある。構造整理の直後は、空配列
# 参照の退避形と連想配列の既定値が「未収集」と「対象0件」を同じ値へ畳み、事実を読む5単位の
# すべてが無言で違反0件・exit 0 を返していた。レイヤ5 は誤名走査だけが走るため、corpus に
# よっては出力まで出て「レイヤは動いている」ように見える経路もあった。
# 由来: Issue #800 に対する PR #801 のレビュー指摘3。
#
# `<レイヤ関数名>|<単位名>`。収集済みの事実を読む5単位をすべて並べる。
UNCOLLECTED_GUARDED_LAYERS=(
    'check_layer1_frontmatter_schema|レイヤ1'
    'check_layer3_forward|レイヤ3 forward'
    'check_layer3_reverse|レイヤ3 reverse'
    'check_layer4_related_references|レイヤ4'
    'check_layer5_filename_and_identifier|レイヤ5'
)

# 照合件数の下限。ループが実際に起動した単位の数を数える。
UNCOLLECTED_GUARDED_LAYER_MIN=5

@test "面㉒: 収集を欠いたレイヤ起動が合格を返さない" {
    collect_init

    local entry layer unit matched=0
    for entry in "${UNCOLLECTED_GUARDED_LAYERS[@]}"; do
        layer="${entry%%|*}"
        unit="${entry##*|}"

        # corpus は invalid/29 を使う。レイヤ5 が誤名走査だけで出力を出せる唯一の corpus で
        # あり、「出力が出る＝レイヤが動いている」という誤読の余地を残さない。
        run_sut_layer_uncollected "$layer" "$CORPUS_DIR/invalid/29-missing-adr-prefix"
        collect_rc 2 "#800: $unit は収集を欠いた起動を非0で拒む"
        collect_contains "$output" "事実の収集を前提とします" \
            "#800: $unit は収集を欠いた起動の理由を出す"
        collect_not_contains "$output" "[violations=" \
            "#800: $unit は収集を欠いた起動で違反件数を報告しない"
        matched=$((matched + 1))
    done

    if [ "$matched" -ge "$UNCOLLECTED_GUARDED_LAYER_MIN" ]; then
        collect_ok "#800: 収集を要求する単位の照合件数が下限を満たす（$matched 件 / 下限 $UNCOLLECTED_GUARDED_LAYER_MIN 件）"
    else
        collect_fail "#800: 収集を要求する単位の照合件数が下限を満たす" \
            "照合件数 $matched 件が下限 $UNCOLLECTED_GUARDED_LAYER_MIN 件を下回る（表の欠落・照合ループの退行）"
    fi

    # レイヤ2 は収集済みの事実を読まないため印を要求しない。要求する側と要求しない側を
    # 1ケース内で押さえ、「全単位が一律に拒む」という誤った一般化を防ぐ。要求を一律へ
    # 広げる変更はここで赤になる。
    run_sut_layer_uncollected check_layer2_index_sync "$CORPUS_DIR/invalid/32-index-missing"
    collect_rc 0 "#800: レイヤ2 は収集を欠いても起動できる"
    collect_contains "$output" "[violations=1]" "#800: レイヤ2 は収集なしでも自分の違反を数える"

    # 収集を経た起動は従来どおり検査を実行する（印そのものが検査を殺していないこと）。
    run_sut_layer check_layer5_filename_and_identifier "$CORPUS_DIR/invalid/29-missing-adr-prefix"
    collect_rc 0 "#800: 収集を済ませたレイヤ5 の単独起動は従来どおり通る"
    collect_contains "$output" "[violations=1]" "#800: 収集を済ませたレイヤ5 は違反を数える"

    collect_finish
}
