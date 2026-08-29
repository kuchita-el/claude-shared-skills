#!/usr/bin/env bash
# ADR drift-lint: ADR 群が満たすべき機械検査可能な不変条件をレイヤ単位で検査する。
# 検査対象は front-matter スキーマ、導出ビュー（index）との同期、ADR 間参照の
# 双方向性・生存性・実在性、ファイル名と識別子の規約適合および識別子の一意性と
# H1 見出しとの整合。
# ここでは検査対象の性質のみを示し、個別レイヤの定義は以下の詳細を正とする
# （検査対象の性質が既出のいずれかに収まる限り本冒頭は追随不要。既出のどれにも
# 当たらない性質を検査するレイヤを足す場合は本冒頭の列挙にも加える）。
#
# ADR_DIR 配下の ADR-*.md を走査し、front-matter を持つ ADR
# （先頭行が `---`）のみを対象に以下を検証する。front-matter を
# 持たない旧 `## Status` 形式は検査対象外としてスキップする（違反に数えない）。
#
# front-matter の抽出は yq/jq 等のパーサを使わず行走査で行う
# （gen-adr-index.sh の抽出方式に整合）。値は前後空白を
# トリムして判定する（末尾空白等で完全一致が静かに崩れるのを防ぐ）。
# キー省略と「キーあり値空」は同じ「空」として扱う。
#
# レイヤ1（front-matter スキーマ検証）は front-matter が
# スキーマ必須ルールを満たすことを検証する。合法な状態の集合の正本は
# `../skills/manage-adr/references/adr-model.md`「状態の型」であり、
# レイヤ1 はその型が構成できない状態を違反として検出する。
# 本ヘッダは合法な状態の集合を独立に定義し直さない。ここが持つのは
# 「何を検査するか」＝次の違反種別の列挙と、「なぜその検査があるか」＝
# その採用理由までである。各違反種別がどの型の制約に対応するかは
# 同文書「型の制約と機械検査の対応」が引ける。
#
# レイヤ1違反種別:
#   1. status 欠落（空）
#   2. status=承認済み かつ validity 欠落（空）
#   3. validity=上書き済み かつ superseded-by 欠落（空）
#   4. status の値が語彙外（提案中 / 承認済み / 却下 以外）
#   5. validity の値が語彙外（有効 / 上書き済み / 廃止済み 以外。空は合法）
#   6. status=提案中 または 却下 かつ validity が非空
#   7. status=提案中 または 却下 かつ superseded-by が非空
#   8. validity=有効 または 廃止済み かつ superseded-by が非空
#
# 種別4・5（語彙）を空判定と別に持つのは、値が非空でも語彙外なら
# gen-adr-index.sh の `validity: 有効` 完全一致から外れて index から静かに
# 脱落する一方、空判定だけでは検出できないため（例: 旧英文の `status: Accepted`、
# `有効` の誤字 `有郊`）。新規 ADR の追加では、コミット済み index と再生成 index の
# 双方に当該 ADR が載らず一致するため、レイヤ2 も backstop として発火しない。
#
# レイヤ2（index 同期）: gen-adr-index.sh を ADR_DIR に対して実行し、
# その出力を ADR_DIR/index.md と比較する。差分あり、または index.md が
# 不在の場合は同期違反とする。
#
# レイヤ3（相互参照双方向性）: 「A.superseded-by=B ⟺ B 本文 `## 関連ADR` に
# `Supersedes: A`（フル slug 完全一致）」の真の双方向（⟺）を検証する。
#   - forward（front-matter起点）: front-matter に superseded-by: B を持つ
#     ADR A について、B（ADR_DIR/B.md）の本文に `Supersedes: A` があるかを
#     照合する。B が存在しない、または本文に逆参照が無ければ違反。
#   - reverse（本文起点）: 本文 `## 関連ADR` 節で `Supersedes: T` を宣言する
#     ADR C について、T（ADR_DIR/T.md）の front-matter superseded-by が C を
#     指しているかを照合する。T が存在しない、または front-matter が C を
#     指していなければ違反（本文で Supersedes 宣言したが front-matter 側の
#     更新を忘れ、T が validity: 有効 のまま index に残るドリフトを検出する）。
# forward・reverse は互いに独立した検査（片方が満たされればもう片方は
# 発火しない設計）であり、双方が揃うエッジは違反にしない（二重計上しない）。
# 本文走査は `Supersedes:` のみを対象にする。
# `Supersedes:` 行は行頭空白（入れ子/インデントされたバレット）を許容して
# 抽出する（forward の照合・reverse の抽出のいずれも同一の緩和を適用）。
#
# レイヤ4（Related 参照の生存性・実在性）: 非 Supersede 関係の
# 参照妥当性を lint する。有効 ADR（validity=有効）の本文
# `## 関連ADR` の `Related:` 行が指す ADR
# 参照先について、参照先の生存性（退役）・実在性（dangling）を検証する。
#   - 判定単位（書式非依存）: `Related:` 以降で最初に現れる ADR stem を抽出する。行頭
#     バレット（`-`）の有無・markdown リンク（`[stem](...)`）の有無・リンクラベルが stem
#     か説明文か（`- Related: [詳細](./ADR-X.md)` も ADR-X を取る）を問わない
#     （バレット無し・リンク形式・リンクラベル書式を同一に扱う）。説明散文中の後続 stem は先頭優先で拾わない
#     （誤検出回避）。
#   - 参照先退役違反: `Related:` 参照先が実在し、かつ validity が 上書き済み
#     （RELATED_RETIRED_VALIDITY）なら違反（有効 ADR が上書きされた ADR を現行の出典として
#     指す参照を残さない）。後継を持たない退役（廃止済み）は対象外とする。
#     採用理由: 参照先が上書き済みなら「その決定を引き継いだ後継へ差し替える」という一意の
#     是正先が定まるが、後継が無い場合は差し替え先が一意に定まらず、検査が具体的な直し方を
#     指示できない。除去や記録の行への改稿（cross-references.md「是正手段」）は差し替え先が
#     無くても選べる手段だが、それを検査で強制すると本来不要な編集を利用者へ課すことになる
#     ため、一意の差し替え先が存在する場合へ限定する。
#   - dangling 参照違反: `Related:` の参照先 `<slug>.md` が実在しなければ
#     違反（full slug 完全一致で解決。解決不能な参照先＝AC8 fail-safe をここに統合）。
#   - source は有効 ADR のみに限定する。検査対象を「front-matter
#     を持つ ADR」と広く書くが、退役（凍結）ADR は編集不能で dangling/退役参照を修復
#     できず修復不能な違反を課すことになる。
#     提案中・却下 ADR の参照はまだ確定した決定の一部でないため対象外と
#     する。結果として検査対象は有効 ADR に限定される。
#   - 双方向性は強制しない（一方向 `Related:` は合法）。
#     Issue 番号参照（`#<番号>`）は検査しない。
#   - 既知の限界（意図的）: (a) 1つの `Related:` 行に複数 ADR を列挙した場合は先頭 stem
#     のみ検査する（判定単位＝先頭 stem。2件目以降は対象外）。
#     (b) 参照先が旧形式（front-matter 無し）・validity 空（提案中/却下）の場合は退役でも
#     dangling でもないとして違反にしない（fail-open。RELATED_RETIRED_VALIDITY＝上書き済み
#     の完全一致のみを違反とみなすため、空値・旧形式はどの語彙とも一致しない）。
#     旧形式ADRはレイヤ1でも検査対象外である点と整合する。
#     (c) 上書き済みのみを見るため、後継を持たずに退役した参照先を指す参照が陳腐化しても
#     検出しない。陳腐化の点検は操作手順側（manage-adr の退役に伴う inbound 参照の点検）が
#     担い、機械検査は負わない。
#
# レイヤ5（ファイル名形式・識別子重複・H1 整合）: ファイル名そのものを検査対象に
# 加える。レイヤ1〜4 はいずれもファイル本文と index しか見ないため、ファイル名が
# 規約から外れても、同一識別子の ADR が複数入っても検出されなかった。
#   - ファイル名形式違反: stem が `ADR-<YYYYMMDDHHMM>-<NN>-<slug>` に適合しなければ違反。
#     時刻部は12桁であることに加え暦としての妥当性（月 01-12・日 01-31・時 00-23・
#     分 00-59）を要求する。この妥当性の水準は next-adr-id.sh の ADR_TIMESTAMP 検査と
#     同一であり、両者を揃えることで「発番器が出せる識別子を lint が弾く」状態を作らない
#     （日は月ごとの日数まで見ない。発番側の水準に合わせた意図的な緩さ）。
#     連番部は `01` 始まりの2桁ゼロ埋め（`00` は不可）、slug は小文字英数字をハイフンで
#     連結した形（先頭・末尾のハイフン、連続ハイフンは不可）。
#     ファイル名が `ADR-` 接頭辞を欠く場合も形式違反とする。走査対象の収集は `ADR-*.md`
#     グロブであり、接頭辞を欠くファイルは中身が規約に適合していても全レイヤを素通り
#     するため。判定材料は front-matter の status の値が語彙に属することとし、
#     README 等が front-matter を持つだけでは発火しない水準に絞る。
#   - 識別子重複違反: 同一の識別子部を持つ ADR が2本以上あれば違反。識別子部の抽出は
#     形式検査より緩い `ADR-<数字>[-<数字>]` の先頭一致で行う。形式適合を前提にすると
#     旧形式どうしの重複（実際に1か月以上検出されなかった事例）を取り逃すため。
#     報告は識別子ごとに1件で、該当する全ファイルを列挙する。
#     同一分に別ブランチで起票し双方が同じ連番を取った場合の重複は、識別子の時刻部が分粒度で
#     ある以上、発番側（next-adr-id.sh）では構造的に消せない。その残余を受け止めることが本検査の
#     役割である（2026-07-26 に2本の PR が当時の日単位の発番手順をそれぞれ正しく実行し、同一識別子を
#     2組ずつ ADR 群へ残した実測がある。当時の drift-lint は識別子の重複を検査せず exit 0 で通した）。
#   - H1 整合違反: 本文の最初の `# ` 見出し行から抽出した識別子部が、ファイル名の
#     識別子部と一致しなければ違反。H1 に ADR 識別子が現れない（見出しが無い場合を含む）
#     ときも違反とする。走査は front-matter 区間を読み飛ばしてから始める
#     （YAML コメント行は行頭 `# ` に当たり、読み飛ばさないと H1 と誤認するため）。
#     gen-adr-index.sh は H1 の `: ` 以降のみをタイトルとして抽出するため、
#     識別子部が陳腐化しても生成物には現れず、レイヤ2 も発火しない。
#     H1 は識別子部のみの形（`# ADR-X-01: タイトル`）と slug を含む形
#     （`# ADR-X-01-slug: タイトル`）の双方が ADR 群に実在するため、
#     照合は識別子部に限る（slug の一致は要求しない）。
#   - 検査対象集合はレイヤ1 と同一で、front-matter を持つ ADR のみを対象とする。
#     front-matter を持たない旧 `## Status` 形式はファイル名も旧規約のままであり、
#     ここで違反として数えるとレイヤ1 が同じ ADR をスキップする扱いと矛盾する。
#     この対象集合の穴（front-matter 不在による全レイヤのすり抜け）は本レイヤでは
#     塞がず、レイヤ横断の課題として別途扱う。
#
# 全違反を列挙してから最後に非0 exitする（早期returnで打ち切らない）。
#
# 使い方:
#   bash lint-adr.sh [ADR_DIR]   # 既定 ADR_DIR は docs/adr/
#
# exit code:
#   0: 違反0件
#   1: 違反検出
#   2: ADR_DIR が存在しない
set -euo pipefail

# 状態語彙（front-matter の値側）。
# 正本の語彙が変わったときの追随点を1箇所に集約する。
# キーが英語・値が日本語のユビキタス言語なのは、キーが状態概念そのものではなく構造的な
# フィールド名だからである（概念の正本は値側にあり、英語キーでは二重管理の drift を生まない）。
# 承認軸の `却下` と有効性軸の `上書き済み`／`廃止済み` を別語に分けているのは、1つの欄へ2軸を
# 混在させる案と英文4状態（Proposed / Accepted / Deprecated / Superseded）で表す案を却下した
# 経緯による。いずれも承認の歴史事実と現在の効力を同じ値域へ同居させ、2軸が語彙レベルで衝突する。
STATUS_VOCAB=("提案中" "承認済み" "却下")
VALIDITY_VOCAB=("有効" "上書き済み" "廃止済み")
# レイヤ4 の参照先退役違反が対象とする validity 値（VALIDITY_VOCAB の部分集合）。
# 後継を持たない退役（廃止済み）を含めない理由はファイル冒頭のレイヤ4 仕様に述べる。
# 退役語彙一般（上書き済み・廃止済み）を表す配列は置かない。どの語彙を違反とみなすかは
# 退役の種別で是正手段が異なるためレイヤごとに決まり、共通配列には消費者が付かない。
# 他レイヤが退役語彙を要するようになった時点で、そのレイヤの部分集合として定義する。
RELATED_RETIRED_VALIDITY=("上書き済み")

# レイヤ5: ファイル名 stem が満たすべき形式（`ADR-<YYYYMMDDHHMM>-<NN>-<slug>`）。
# 時刻部の暦妥当性の水準は next-adr-id.sh の ADR_TIMESTAMP 検査と同一に保つ
# （発番器が出せる識別子を lint が弾かないようにするため。片方を変えたら他方も追随する）。
ADR_STEM_PATTERN='^ADR-[0-9]{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])([01][0-9]|2[0-3])[0-5][0-9]-(0[1-9]|[1-9][0-9])-[a-z0-9]+(-[a-z0-9]+)*$'
# レイヤ5: 識別子部（`ADR-<数字>[-<数字>]`）の抽出パターン。形式検査より緩く、旧形式の
# 識別子（`ADR-YYYYMMDD-NN`）も拾う。重複検査・H1 整合検査はこの緩い抽出を使う
# （形式適合を前提にすると旧形式どうしの重複を取り逃すため）。
ADR_ID_PATTERN='(ADR-[0-9]+(-[0-9]+)?)'

# レイヤ2 が起動する index 生成器。解決は「読み込み元のパス」を基準にする（cwd 依存回避）。
# $0 ではなく BASH_SOURCE を使うのは、読み込みだけを行った場合に $0 が読み込み側のシェル名を
# 指し、生成器を解決できなくなるため。直接実行時の解決結果は $0 基準と同一である。
GEN_INDEX="$(dirname "${BASH_SOURCE[0]}")/gen-adr-index.sh"

# 値 $1 が第2引数以降の語彙集合に含まれるかを判定する。
# 戻り値: 含まれれば 0、含まれなければ 1
in_vocab() {
    local needle="$1"
    shift
    local candidate
    for candidate in "$@"; do
        if [ "$candidate" = "$needle" ]; then
            return 0
        fi
    done
    return 1
}

# 前後の空白（スペース・タブ）をトリムする
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# カンマ区切りの superseded-by 値を各要素トリム・空要素スキップで
# グローバル配列 SPLIT_RESULT へ分割する（リスト値 1→N 分割 ADR 対応）。
# 単一値はカンマを含まないため要素数1の配列となり、従来の完全一致挙動を保つ。
# 末尾・連続カンマ由来の空要素はトリム後スキップする（堅牢性目的の防御）。
split_csv() {
    local input="$1" elem
    local raw
    SPLIT_RESULT=()
    IFS=',' read -ra raw <<<"$input"
    for elem in ${raw[@]+"${raw[@]}"}; do
        elem="$(trim "$elem")"
        # `if` で追加する（`[ ... ] && ...` だと最終要素が空のとき AND-list が
        #  非0を返し、set -e 下で呼び出し元が異常終了するため）
        if [ -n "$elem" ]; then
            SPLIT_RESULT+=("$elem")
        fi
    done
}

# front-matter を持つか判定し、持つ場合は status/validity/superseded-by を
# グローバル変数 FM_STATUS/FM_VALIDITY/FM_SUPERSEDED_BY へトリム済みの値で
# 格納する（キー省略・値空はいずれも空文字）。
# 戻り値: front-matter を持てば 0、持たなければ 1
extract_frontmatter() {
    local file="$1"
    local line_num=0
    local in_fm=0
    local line key value

    FM_STATUS=""
    FM_VALIDITY=""
    FM_SUPERSEDED_BY=""

    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))
        if [ "$line_num" -eq 1 ]; then
            if [ "$line" = "---" ]; then
                in_fm=1
                continue
            else
                return 1
            fi
        fi
        if [ "$in_fm" -eq 1 ]; then
            if [ "$line" = "---" ]; then
                return 0
            fi
            if [[ "$line" =~ ^([a-zA-Z_-]+):[[:space:]]*(.*)$ ]]; then
                key="${BASH_REMATCH[1]}"
                value="$(trim "${BASH_REMATCH[2]}")"
                case "$key" in
                    status) FM_STATUS="$value" ;;
                    validity) FM_VALIDITY="$value" ;;
                    superseded-by) FM_SUPERSEDED_BY="$value" ;;
                esac
            fi
        fi
    done <"$file"

    # front-matter が閉じずにファイル末尾へ達した場合も front-matter ありとして扱う
    [ "$in_fm" -eq 1 ]
}

# ファイル file の本文中の `## 関連ADR` 節（次の `## ` 見出しまたは
# ファイル末尾まで）に `- Supersedes: <target_stem>`（フル slug 完全一致。
# 行頭空白＝入れ子/インデントされたバレットも許容）の行が存在するかを判定する。
# 戻り値: 存在すれば 0、しなければ 1
body_has_supersedes() {
    local file="$1"
    local target_stem="$2"
    local line in_section=0 candidate

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^##[[:space:]]+関連ADR ]]; then
            in_section=1
            continue
        fi
        if [ "$in_section" -eq 1 ] && [[ "$line" =~ ^##[[:space:]] ]]; then
            in_section=0
            continue
        fi
        if [ "$in_section" -eq 1 ] && [[ "$line" =~ ^[[:space:]]*-[[:space:]]*Supersedes:[[:space:]]*([A-Za-z0-9-]+) ]]; then
            candidate="${BASH_REMATCH[1]}"
            if [ "$candidate" = "$target_stem" ]; then
                return 0
            fi
        fi
    done <"$file"

    return 1
}

# ファイル file の本文中の `## 関連ADR` 節（次の `## ` 見出しまたは
# ファイル末尾まで）にある `Supersedes: <target_stem>`（フル slug 完全一致、
# 行頭空白＝入れ子/インデントされたバレットを許容）をすべて抽出し、
# グローバル配列 BODY_SUPERSEDES_TARGETS へ格納する（0件なら空配列）。
# レイヤ3 reverse（本文起点）の照合対象を集めるために使う。
extract_body_supersedes() {
    local file="$1"
    local line in_section=0

    BODY_SUPERSEDES_TARGETS=()

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^##[[:space:]]+関連ADR ]]; then
            in_section=1
            continue
        fi
        if [ "$in_section" -eq 1 ] && [[ "$line" =~ ^##[[:space:]] ]]; then
            in_section=0
            continue
        fi
        if [ "$in_section" -eq 1 ] && [[ "$line" =~ ^[[:space:]]*-[[:space:]]*Supersedes:[[:space:]]*([A-Za-z0-9-]+) ]]; then
            BODY_SUPERSEDES_TARGETS+=("${BASH_REMATCH[1]}")
        fi
    done <"$file"
}

# ファイル file の本文 `## 関連ADR` 節（次の `## ` 見出しまたはファイル末尾まで）の
# 各 `Related:` 行について、行頭バレット（`-`）有無・markdown リンク（`[stem](...)`）
# 有無を問わず「`Related:` 以降の最初の ADR stem」を1件抽出し、グローバル配列
# BODY_RELATED_TARGETS へ格納する（0件なら空配列）。レイヤ4 の照合対象を集める。
# 先頭 stem のみを取るため、説明散文中の後続 ADR stem（退役を含む）は抽出しない
# （誤検出回避の要）。
extract_body_related() {
    local file="$1"
    local line in_section=0 after stem existing dup

    BODY_RELATED_TARGETS=()

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^##[[:space:]]+関連ADR ]]; then
            in_section=1
            continue
        fi
        if [ "$in_section" -eq 1 ] && [[ "$line" =~ ^##[[:space:]] ]]; then
            in_section=0
            continue
        fi
        # `Related:` 行（行頭バレット任意）から「`Related:` 以降で最初に現れる ADR stem」を
        # 1件抽出する。`${line#*Related:}` で `Related:` 以降へ絞り、そこから最左の
        # `ADR-<stem>` を取ることで、バレット有無・リンク有無・リンクラベルが stem か
        # 説明文か（`[詳細](./ADR-X.md)`）を問わず先頭 stem を得る。説明散文中の後続 stem は
        # 先頭優先で拾わない（誤検出回避）。
        if [ "$in_section" -eq 1 ] && [[ "$line" =~ ^[[:space:]]*(-[[:space:]]*)?Related: ]]; then
            after="${line#*Related:}"
            if [[ "$after" =~ (ADR-[A-Za-z0-9-]+) ]]; then
                stem="${BASH_REMATCH[1]}"
                # 同一 stem の重複登録を避ける（複数の `Related:` 行が同じ退役/非存在 ADR を
                # 指す場合の二重報告を防ぐ）。行内の重複は上記の先頭 stem 抽出が防いでおり、
                # 本 dedup が担うのは行をまたいだ重複のみである。
                dup=0
                for existing in ${BODY_RELATED_TARGETS[@]+"${BODY_RELATED_TARGETS[@]}"}; do
                    if [ "$existing" = "$stem" ]; then
                        dup=1
                        break
                    fi
                done
                if [ "$dup" -eq 0 ]; then
                    BODY_RELATED_TARGETS+=("$stem")
                fi
            fi
        fi
    done <"$file"
}

# ファイル file の本文の最初の `# ` 見出し行から ADR 識別子部を抽出し、グローバル変数
# H1_ADR_ID へ格納する（見出しが無い・見出しに ADR 識別子が現れない場合は空文字）。
# 見出し行全体から最左の識別子トークンを取るため、`# ADR-X-01: タイトル` と
# `# ADR-X-01-slug: タイトル` の双方から同じ識別子部が得られる。
# front-matter 区間（先頭行 `---` から閉じ `---` まで）は読み飛ばす。YAML コメント行
# （`# メモ`）は行頭 `# ` に当たるため、読み飛ばさないと H1 と誤認して識別子が
# 見つからず偽陽性を報告する。走査規約は extract_frontmatter と揃える。
extract_h1_adr_id() {
    local file="$1"
    local line
    local line_num=0
    local in_fm=0

    H1_ADR_ID=""

    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))
        if [ "$line_num" -eq 1 ] && [ "$line" = "---" ]; then
            in_fm=1
            continue
        fi
        if [ "$in_fm" -eq 1 ]; then
            if [ "$line" = "---" ]; then
                in_fm=0
            fi
            continue
        fi
        if [[ "$line" =~ ^#[[:space:]] ]]; then
            if [[ "$line" =~ $ADR_ID_PATTERN ]]; then
                H1_ADR_ID="${BASH_REMATCH[1]}"
            fi
            return 0
        fi
    done <"$file"
}

# ---- 収集の完了印 ----
#
# 収集単位が収集を終えた時点で立て、収集済みの事実を消費する単位が起動時に検査する。
# 印が無いと、空配列参照の退避形（`${ARR[@]+"${ARR[@]}"}`）と連想配列の既定値（`[key]:-`）が
# 「収集していない」と「収集した結果が0件」を同じ値へ畳むため、走査集合が一度も作られて
# いない状態が「検査したが違反なし」と区別できない。印はその2つを分ける唯一の材料である。
SCAN_TARGETS_COLLECTED=0
FACTS_COLLECTED=0

# 収集済みの印が立っていることを要求する。立っていなければ理由を標準エラーへ出して非0で
# 戻り、未収集での起動が「検査したが違反なし」として合格を返すこと（fail-open）を防ぐ。
# 戻り値: 印が立っていれば 0、立っていなければ 2（起動の誤り。検査を実行した 0 と区別する）
# 引数: $1 起動された単位の名前 / $2 印の値 / $3 印を立てる収集単位の名前
require_collected() {
    local unit="$1" flag="$2" collector="$3"

    if [ "$flag" != "1" ]; then
        printf 'エラー: %s は事実の収集を前提とします（%s を先に呼んでください）\n' "$unit" "$collector" >&2
        return 2
    fi
    return 0
}

# ADR_DIR 配下の `ADR-*.md` をファイル名昇順で収集し、グローバル配列 SCAN_TARGETS へ
# 格納する（0件なら空配列）。検査は行わず違反を1件も出力しない。
collect_scan_targets() {
    local dir="$1"
    local f
    local raw=()

    # 走査対象が入れ替わると、そこから導いた事実は古くなる。下流の印をここで倒し、
    # 収集し直さずにレイヤを起動した場合が未収集と同じ扱いになるようにする。
    FACTS_COLLECTED=0
    SCAN_TARGETS=()

    shopt -s nullglob
    for f in "$dir"/ADR-*.md; do
        raw+=("$f")
    done
    shopt -u nullglob

    if [ "${#raw[@]}" -gt 0 ]; then
        while IFS= read -r f; do
            SCAN_TARGETS+=("$f")
        done < <(printf '%s\n' "${raw[@]}" | LC_ALL=C sort)
    fi

    SCAN_TARGETS_COLLECTED=1
}

# 走査対象のうち front-matter を持つものを選別し、stem をキーとする status /
# validity / superseded-by の写像を構築する。検査は行わず違反を1件も出力しない。
# 各レイヤはここで集めた事実だけを読む。
#
# 収集の成果物:
#   FM_FILES              front-matter を持つ ADR をファイル名昇順で保持する添字配列
#                         （レイヤ1・レイヤ5 の検査対象集合）
#   FM_STATUS_BY_STEM     stem -> front-matter status 値
#   FM_VALIDITY_BY_STEM   stem -> front-matter validity 値
#   FM_SB_BY_STEM         stem -> front-matter superseded-by 値
# 写像のキーは front-matter を持つ ADR にのみ設定する（値は空でありうる）。持たない
# 旧形式はキー未設定であり、参照時は "${MAP[$stem]:-}" で空扱いにする。
#
# 連想配列は declare -gA で宣言する。関数の中で declare -A とすると関数ローカルになり、
# 後続のレイヤから見えなくなる。この取り違えは実行時に「参照先が見つかりません」型の
# 偽陽性として現れる。
#
# 前提: collect_scan_targets が済んでいること。走査対象を消費する単位であるため、レイヤと
# 同じく印を要求する（未収集で呼ぶと FM_FILES が空のまま印だけが立ち、穴が下流へ移る）。
collect_facts() {
    local file stem

    require_collected collect_facts "$SCAN_TARGETS_COLLECTED" collect_scan_targets || return 2

    FM_FILES=()
    declare -gA FM_STATUS_BY_STEM=()
    declare -gA FM_VALIDITY_BY_STEM=()
    declare -gA FM_SB_BY_STEM=()

    for file in ${SCAN_TARGETS[@]+"${SCAN_TARGETS[@]}"}; do
        if ! extract_frontmatter "$file"; then
            # front-matter を持たない旧形式は検査対象外（スキップ）
            continue
        fi

        stem="$(basename "$file" .md)"
        FM_FILES+=("$file")
        FM_STATUS_BY_STEM["$stem"]="$FM_STATUS"
        FM_VALIDITY_BY_STEM["$stem"]="$FM_VALIDITY"
        FM_SB_BY_STEM["$stem"]="$FM_SUPERSEDED_BY"
    done

    FACTS_COLLECTED=1
}

# ---- 検査レイヤ ----
#
# 各レイヤは収集済みの事実（SCAN_TARGETS / FM_FILES / FM_*_BY_STEM）だけを読み、
# 違反を標準出力へ出してグローバル変数 violations を加算する。レイヤ間に呼び出し依存は
# 無く、事実の収集さえ済んでいれば任意の1レイヤを他レイヤの検査を実行せずに起動できる。
# 呼び出し順は下の起動部が持つ（違反の出力順はこの順で決まる）。
#
# 収集を済ませずに起動した場合は、検査を実行せず理由を標準エラーへ出して非0で戻る
# （require_collected）。未収集を「違反なし」と report する経路を残さないための規定であり、
# レイヤ単位の起動を公開された使い方として位置づける以上、契約違反は合格ではなく誤りとして
# 現れる必要がある。収集済みの事実を1つも読まないレイヤ2 だけは印を要求しない（対象
# ディレクトリのみを消費するため、要求しても常に真になる無内容な検査になる）。

# レイヤ1: front-matter スキーマ検証。
# 入力: FM_FILES / FM_STATUS_BY_STEM / FM_VALIDITY_BY_STEM / FM_SB_BY_STEM
check_layer1_frontmatter_schema() {
    local file stem fm_status fm_validity fm_sb

    require_collected check_layer1_frontmatter_schema "$FACTS_COLLECTED" collect_facts || return 2

    for file in ${FM_FILES[@]+"${FM_FILES[@]}"}; do
        stem="$(basename "$file" .md)"
        fm_status="${FM_STATUS_BY_STEM[$stem]:-}"
        fm_validity="${FM_VALIDITY_BY_STEM[$stem]:-}"
        fm_sb="${FM_SB_BY_STEM[$stem]:-}"

        # 種別1・4: status の存在と語彙
        # 空のときは種別1のみを報告する（語彙違反として二重に数えない）
        if [ -z "$fm_status" ]; then
            printf '%s: status が空です（front-matter に status キーの値が必要）\n' "$file"
            violations=$((violations + 1))
        elif ! in_vocab "$fm_status" "${STATUS_VOCAB[@]}"; then
            printf '%s: status の値 "%s" が語彙にありません（提案中 / 承認済み / 却下 のいずれかが必要）\n' "$file" "$fm_status"
            violations=$((violations + 1))
        fi

        # 種別5: validity の語彙（空は起票・却下で合法のため語彙検査の対象外）
        if [ -n "$fm_validity" ] && ! in_vocab "$fm_validity" "${VALIDITY_VOCAB[@]}"; then
            printf '%s: validity の値 "%s" が語彙にありません（有効 / 上書き済み / 廃止済み のいずれか、または空が必要）\n' "$file" "$fm_validity"
            violations=$((violations + 1))
        fi

        if [ "$fm_status" = "承認済み" ] && [ -z "$fm_validity" ]; then
            printf '%s: status=承認済み だが validity が空です（validity キーの値が必要）\n' "$file"
            violations=$((violations + 1))
        fi

        if [ "$fm_validity" = "上書き済み" ] && [ -z "$fm_sb" ]; then
            printf '%s: validity=上書き済み だが superseded-by が空です（superseded-by キーの値が必要）\n' "$file"
            violations=$((violations + 1))
        fi

        # 種別6・7: 構成子 提案中 / 却下 は validity・superseded-by のいずれも伴わない。
        # 承認軸が終端（却下）または未承認（提案中）の ADR は有効性軸を持たない。
        if [ "$fm_status" = "提案中" ] || [ "$fm_status" = "却下" ]; then
            if [ -n "$fm_validity" ]; then
                printf '%s: status=%s だが validity が空ではありません（値 "%s"。提案中・却下 は validity を伴いません）\n' "$file" "$fm_status" "$fm_validity"
                violations=$((violations + 1))
            fi
            if [ -n "$fm_sb" ]; then
                printf '%s: status=%s だが superseded-by が空ではありません（値 "%s"。提案中・却下 は superseded-by を伴いません）\n' "$file" "$fm_status" "$fm_sb"
                violations=$((violations + 1))
            fi
        fi

        # 種別8: 構成子 有効 / 廃止済み は superseded-by を伴わない。
        # 後継を指すなら上書き済みであるべきで、有効のままなら原 ADR と後継が
        # 同時に index へ並ぶ。廃止済みは決定1 で「後継 ADR なしで ADR としての効力を
        # 終えた」と定義される。
        if [ "$fm_validity" = "有効" ] || [ "$fm_validity" = "廃止済み" ]; then
            if [ -n "$fm_sb" ]; then
                printf '%s: validity=%s だが superseded-by が空ではありません（値 "%s"。superseded-by を伴えるのは 上書き済み だけです）\n' "$file" "$fm_validity" "$fm_sb"
                violations=$((violations + 1))
            fi
        fi
    done
}

# レイヤ2: index 同期検証。
# 入力: 対象ディレクトリ（$1）。同梱の index 生成器を起動して出力を index.md と比較する。
# 収集済みの事実を読まない唯一のレイヤであり、収集の印を要求しない（上のレイヤ群の規定を参照）。
check_layer2_index_sync() {
    local dir="$1"
    local index_file="$dir/index.md"
    local generated current

    if [ ! -f "$index_file" ]; then
        printf '%s: index 同期違反（index.md が存在しません）\n' "$index_file"
        violations=$((violations + 1))
        return 0
    fi

    generated="$(bash "$GEN_INDEX" "$dir")"
    current="$(cat "$index_file")"
    if [ "$generated" != "$current" ]; then
        printf '%s: index 同期違反（gen-adr-index.sh の出力と一致しません。再生成してください）\n' "$index_file"
        violations=$((violations + 1))
    fi
}

# レイヤ3 forward: front-matter superseded-by 起点で本文 Supersedes 逆参照を照合。
# 入力: 対象ディレクトリ（$1）と、収集済みの FM_FILES / FM_SB_BY_STEM。
# 照合対象のペアは収集済みの事実から同じ順序で導出する（superseded-by が空の ADR は
# 照合対象を持たないため飛ばす）。
check_layer3_forward() {
    local dir="$1"
    local a_file a_stem a_sb b_stem b_file

    require_collected check_layer3_forward "$FACTS_COLLECTED" collect_facts || return 2

    for a_file in ${FM_FILES[@]+"${FM_FILES[@]}"}; do
        a_stem="$(basename "$a_file" .md)"
        a_sb="${FM_SB_BY_STEM[$a_stem]:-}"
        if [ -z "$a_sb" ]; then
            continue
        fi

        # superseded-by をカンマ分割し、各後継 stem を独立に照合する（リスト値 1→N 対応）
        split_csv "$a_sb"

        # superseded-by は非空だが有効な参照先 stem を1つも含まない（カンマ・空白のみ）
        # 場合、「validity=上書き済み ⟹ 少なくとも1件の後継が照合される」不変条件が
        # 崩れるため違反とする（レイヤ1の空判定は raw 値が非空のため通過してしまう）
        if [ "${#SPLIT_RESULT[@]}" -eq 0 ]; then
            printf '%s: 相互参照違反（superseded-by=%s に有効な参照先 stem がありません）\n' "$a_file" "$a_sb"
            violations=$((violations + 1))
            continue
        fi

        for b_stem in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
            b_file="$dir/$b_stem.md"

            if [ ! -f "$b_file" ]; then
                printf '%s: 相互参照違反（superseded-by=%s だが参照先 %s が見つかりません）\n' "$a_file" "$b_stem" "$b_file"
                violations=$((violations + 1))
                continue
            fi

            if ! body_has_supersedes "$b_file" "$a_stem"; then
                printf '%s: 相互参照違反（%s の本文 "## 関連ADR" に "Supersedes: %s" が見つかりません）\n' "$a_file" "$b_file" "$a_stem"
                violations=$((violations + 1))
            fi
        done
    done
}

# レイヤ3 reverse: 本文 Supersedes 宣言起点で front-matter superseded-by を照合
# （C の本文が Supersedes: T を宣言するのに、T の front-matter superseded-by
#   が C を指していない＝front-matter 更新忘れを検出する。forward で既に
#   一致確認済みのエッジは reverse 側でも自然に一致するため、ここでは
#   forward 側で捕捉できない「本文はあるが front-matter が追随していない」
#   ケースのみが新たに violation として計上される＝二重計上にならない）
# 入力: 対象ディレクトリ（$1）と、収集済みの SCAN_TARGETS / FM_SB_BY_STEM。
check_layer3_reverse() {
    local dir="$1"
    local c_file c_stem t_stem t_file member s

    require_collected check_layer3_reverse "$FACTS_COLLECTED" collect_facts || return 2

    for c_file in ${SCAN_TARGETS[@]+"${SCAN_TARGETS[@]}"}; do
        extract_body_supersedes "$c_file"
        c_stem="$(basename "$c_file" .md)"

        for t_stem in ${BODY_SUPERSEDES_TARGETS[@]+"${BODY_SUPERSEDES_TARGETS[@]}"}; do
            t_file="$dir/$t_stem.md"

            if [ ! -f "$t_file" ]; then
                printf '%s: 相互参照違反（逆方向: 本文 "## 関連ADR" の "Supersedes: %s" 宣言の参照先 %s が見つかりません）\n' "$c_file" "$t_stem" "$t_file"
                violations=$((violations + 1))
                continue
            fi

            # T の superseded-by をリスト分割した集合に c_stem が含まれるかで判定する
            # （完全一致から集合メンバシップへ。単一値は要素数1集合となり従来と等価＝後方互換）
            split_csv "${FM_SB_BY_STEM[$t_stem]:-}"
            member=0
            for s in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
                if [ "$s" = "$c_stem" ]; then
                    member=1
                    break
                fi
            done
            if [ "$member" -eq 0 ]; then
                printf '%s: 相互参照違反（逆方向: %s の本文 "## 関連ADR" が "Supersedes: %s" を宣言していますが、%s の front-matter superseded-by がそれを指していません）\n' "$t_file" "$c_file" "$t_stem" "$t_file"
                violations=$((violations + 1))
            fi
        done
    done
}

# 入力: 対象ディレクトリ（$1）と、収集済みの SCAN_TARGETS / FM_VALIDITY_BY_STEM。
# レイヤ4: 有効ADRの Related 参照の退役・dangling 検査
# （判定単位は書式非依存の先頭 stem 抽出）
check_layer4_related_references() {
    local dir="$1"
    local src_file src_stem t_stem

    require_collected check_layer4_related_references "$FACTS_COLLECTED" collect_facts || return 2

    for src_file in ${SCAN_TARGETS[@]+"${SCAN_TARGETS[@]}"}; do
        src_stem="$(basename "$src_file" .md)"
        # source は有効 ADR のみ（退役・提案中・却下・旧形式は検査対象外）
        if [ "${FM_VALIDITY_BY_STEM[$src_stem]:-}" != "有効" ]; then
            continue
        fi

        # `## 関連ADR` の Related 参照先: 非存在→dangling、実在かつ上書き済み→参照先退役違反
        # （後継なしの廃止済みは建設的な是正が無いため対象外。ファイル冒頭のレイヤ4 仕様を参照）
        extract_body_related "$src_file"
        for t_stem in ${BODY_RELATED_TARGETS[@]+"${BODY_RELATED_TARGETS[@]}"}; do
            if [ ! -f "$dir/$t_stem.md" ]; then
                printf '%s: dangling 参照違反（"## 関連ADR" の Related 参照先 %s が見つかりません）\n' "$src_file" "$t_stem"
                violations=$((violations + 1))
            elif in_vocab "${FM_VALIDITY_BY_STEM[$t_stem]:-}" "${RELATED_RETIRED_VALIDITY[@]}"; then
                printf '%s: 参照先退役違反（"## 関連ADR" の Related 参照先 %s は validity=%s の退役ADRです）\n' "$src_file" "$t_stem" "${FM_VALIDITY_BY_STEM[$t_stem]:-}"
                violations=$((violations + 1))
            fi
        done
    done
}

# レイヤ5: ファイル名形式・識別子重複・H1 整合、および `ADR-` 接頭辞を欠く誤名の検出。
# 入力: 対象ディレクトリ（$1）と、収集済みの FM_FILES。
check_layer5_filename_and_identifier() {
    local dir="$1"
    local file stem file_id f
    local misnamed misnamed_sorted

    # 誤名走査だけは対象ディレクトリを自前で glob するため、印を欠いたまま起動すると
    # 「3検査が無言で消えたのに出力は出る」状態になりうる。ここで先に止める。
    require_collected check_layer5_filename_and_identifier "$FACTS_COLLECTED" collect_facts || return 2

    # レイヤ5: ファイル名形式・識別子重複・H1 整合
    # 対象は front-matter を持つ ADR のみ（FM_FILES。レイヤ1 と同一の対象集合）

    # 識別子部ごとの出現ファイルを集計する（重複検査の第1パス）
    declare -A ID_FILE_COUNT=()
    declare -A ID_FILE_LIST=()

    for file in ${FM_FILES[@]+"${FM_FILES[@]}"}; do
        stem="$(basename "$file" .md)"

        # ファイル名形式検査
        if [[ ! "$stem" =~ $ADR_STEM_PATTERN ]]; then
            printf '%s: ファイル名形式違反（ADR-YYYYMMDDHHMM-NN-<slug>.md の形式に適合しません。時刻部は暦として妥当な12桁、連番部は2桁、slug は小文字英数字とハイフン）\n' "$file"
            violations=$((violations + 1))
        fi

        # 識別子部の抽出（形式違反のファイルからも可能な限り抽出し、重複・H1 整合の
        # 検査へ回す。抽出できない場合は形式違反として既に報告済みのため両検査を飛ばす）
        if [[ ! "$stem" =~ ^$ADR_ID_PATTERN ]]; then
            continue
        fi
        file_id="${BASH_REMATCH[1]}"

        ID_FILE_COUNT["$file_id"]=$((${ID_FILE_COUNT["$file_id"]:-0} + 1))
        if [ -n "${ID_FILE_LIST["$file_id"]:-}" ]; then
            ID_FILE_LIST["$file_id"]="${ID_FILE_LIST[$file_id]}, $file"
        else
            ID_FILE_LIST["$file_id"]="$file"
        fi

        # H1 整合検査
        extract_h1_adr_id "$file"
        if [ -z "$H1_ADR_ID" ]; then
            printf '%s: H1 整合違反（本文の最初の "# " 見出しに ADR 識別子が見つかりません。ファイル名の識別子部は %s）\n' "$file" "$file_id"
            violations=$((violations + 1))
        elif [ "$H1_ADR_ID" != "$file_id" ]; then
            printf '%s: H1 整合違反（H1 見出しの識別子部 %s がファイル名の識別子部 %s と一致しません）\n' "$file" "$H1_ADR_ID" "$file_id"
            violations=$((violations + 1))
        fi
    done

    # 識別子重複検査（第2パス）。連想配列の走査順は不定のため、ファイル名昇順の
    # FM_FILES を走査し、各識別子の最初の出現でのみ報告して出力順を決定的にする
    declare -A ID_REPORTED=()
    for file in ${FM_FILES[@]+"${FM_FILES[@]}"}; do
        stem="$(basename "$file" .md)"
        if [[ ! "$stem" =~ ^$ADR_ID_PATTERN ]]; then
            continue
        fi
        file_id="${BASH_REMATCH[1]}"

        if [ "${ID_FILE_COUNT[$file_id]}" -le 1 ] || [ -n "${ID_REPORTED[$file_id]:-}" ]; then
            continue
        fi
        ID_REPORTED["$file_id"]=1
        printf '%s: 識別子重複違反（識別子 %s を持つ ADR が %d 本あります: %s）\n' "$dir" "$file_id" "${ID_FILE_COUNT[$file_id]}" "${ID_FILE_LIST[$file_id]}"
        violations=$((violations + 1))
    done

    # レイヤ5: `ADR-` 接頭辞を欠く誤名 ADR の検出
    # 走査対象の収集（および gen-adr-index.sh の走査）は `ADR-*.md` グロブであり、接頭辞を
    # 欠くファイルはそもそも収集されないため、規約に適合した中身を持っていても全レイヤを
    # 素通りする。ファイル名を第一級の検査対象に据えるレイヤとしてここだけ穴を残さない。
    # 判定材料は front-matter の status の値が語彙に属することとする（`status: 承認済み` 等を
    # 持つ `*.md` は実質的に誤名の ADR である）。README 等が front-matter を持つだけでは
    # 発火しない水準に絞り、誤検出を避ける。
    # 出力順は走査対象の収集と同じく LC_ALL=C sort で正規化する（グロブ展開順のままだと
    # 実行時ロケールの LC_COLLATE に依存し、同一ファイル内で照合順の規約が揃わない）。
    misnamed=()
    shopt -s nullglob
    for file in "$dir"/*.md; do
        misnamed+=("$file")
    done
    shopt -u nullglob

    misnamed_sorted=()
    if [ "${#misnamed[@]}" -gt 0 ]; then
        while IFS= read -r f; do
            misnamed_sorted+=("$f")
        done < <(printf '%s\n' "${misnamed[@]}" | LC_ALL=C sort)
    fi

    for file in ${misnamed_sorted[@]+"${misnamed_sorted[@]}"}; do
        case "$(basename "$file")" in
            ADR-*) continue ;;
        esac
        if ! extract_frontmatter "$file"; then
            continue
        fi
        if ! in_vocab "$FM_STATUS" "${STATUS_VOCAB[@]}"; then
            continue
        fi
        printf '%s: ファイル名形式違反（ADR-YYYYMMDDHHMM-NN-<slug>.md の形式に適合しません。front-matter の status が ADR のものですが、ファイル名が "ADR-" 接頭辞を欠くため全レイヤの走査対象から外れます）\n' "$file"
        violations=$((violations + 1))
    done
}

# ---- 起動 ----
#
# 走査対象の収集 → 事実の収集 → 各レイヤの呼び出し → 終了コードの決定。
# 違反の出力順はこの呼び出し順で決まる。
#
# 検査本体を走らせるのは直接実行されたときだけとする。読み込みだけを行った場合は、
# 対象ディレクトリを指定していなくても終了せず、定数と検査単位の定義が得られる状態で戻る。
# 判定は「読み込み元のパス」と「起動されたスクリプトのパス」の一致で行う（直接実行なら
# 両者は同一の文字列になり、読み込みでは $0 が読み込み側のシェルまたはスクリプトを指す）。
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    ADR_DIR="${1:-docs/adr}"
    ADR_DIR="${ADR_DIR%/}"

    if [ ! -d "$ADR_DIR" ]; then
        echo "エラー: ディレクトリが見つかりません: $ADR_DIR" >&2
        exit 2
    fi

    violations=0

    collect_scan_targets "$ADR_DIR"
    collect_facts

    check_layer1_frontmatter_schema
    check_layer2_index_sync "$ADR_DIR"
    check_layer3_forward "$ADR_DIR"
    check_layer3_reverse "$ADR_DIR"
    check_layer4_related_references "$ADR_DIR"
    check_layer5_filename_and_identifier "$ADR_DIR"

    if [ "$violations" -gt 0 ]; then
        exit 1
    fi
    exit 0
fi
