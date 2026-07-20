#!/usr/bin/env bash
# ADR drift-lint（レイヤ1: front-matter スキーマ検証／レイヤ2: index 同期検証／
# レイヤ3: 相互参照双方向性検証）
#
# ADR_DIR 配下の ADR-*.md を走査し、front-matter を持つ ADR
# （先頭行が `---`）のみを対象に以下を検証する。front-matter を
# 持たない旧 `## Status` 形式は検査対象外としてスキップする（違反に数えない）。
#
# front-matter の抽出は yq/jq 等のパーサを使わず行走査で行う
# （scripts/gen-adr-index.sh の抽出方式に整合）。値は前後空白を
# トリムして判定する（末尾空白等で完全一致が静かに崩れるのを防ぐ）。
# キー省略と「キーあり値空」は同じ「空」として扱う。
#
# レイヤ1（front-matter スキーマ検証）は ADR-20260711-3 決定5 により
# 「決定2 のスキーマ必須ルールを満たすこと」と定義される。決定2 の必須ルールは
# 次の遷移表であり、レイヤ1はこの表に無い行を違反として検出する。
#
#   | 遷移 | status       | validity   | superseded-by |
#   |------|--------------|------------|---------------|
#   | 起票 | 提案中       | （無し）   | （無し）      |
#   | 承認 | 承認済み     | 有効       | （無し）      |
#   | 上書き| 承認済み     | 上書き済み | 必須          |
#   | 廃止 | 承認済み     | 廃止済み   | （無し）      |
#   | 却下 | 却下         | （無し）   | （無し）      |
#
# レイヤ1違反種別:
#   1. status 欠落（空）
#   2. status=承認済み かつ validity 欠落（空）
#   3. validity=上書き済み かつ superseded-by 欠落（空）
#   4. status の値が語彙外（提案中 / 承認済み / 却下 以外）
#   5. validity の値が語彙外（有効 / 上書き済み / 廃止済み 以外。空は合法）
#   6. status=提案中 または 却下 かつ validity が非空（表では「（無し）」）
#   7. status=提案中 または 却下 かつ superseded-by が非空（表では「（無し）」）
#   8. validity=有効 または 廃止済み かつ superseded-by が非空（表では「（無し）」）
#
# 種別4・5（語彙）を空判定と別に持つのは、値が非空でも語彙外なら
# gen-adr-index.sh の `validity: 有効` 完全一致から外れて index から静かに
# 脱落する一方、空判定だけでは検出できないため（例: 旧英文の `status: Accepted`、
# `有効` の誤字 `有郊`）。新規 ADR の追加では、コミット済み index と再生成 index の
# 双方に当該 ADR が載らず一致するため、レイヤ2 も backstop として発火しない。
#
# 合法（違反にしない）:
#   - status=提案中 かつ validity 空 かつ superseded-by 空（起票）
#   - status=却下 かつ validity 空 かつ superseded-by 空（却下）
#   - validity=廃止済み かつ superseded-by 無し（廃止）
#
# レイヤ2（index 同期）: scripts/gen-adr-index.sh を ADR_DIR に対して実行し、
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
# `Amends:`/`Amended by:` のみを持つエッジは凍結扱いで両方向とも検査対象外
# （本文走査は `Supersedes:` のみを対象にする）。
# `Supersedes:` 行は行頭空白（入れ子/インデントされたバレット）を許容して
# 抽出する（forward の照合・reverse の抽出のいずれも同一の緩和を適用）。
#
# レイヤ4（Related/park 参照の生存性・実在性）: ADR-20260720-4 §3（非 Supersede
# 関係の参照妥当性 lint）＋ Issue #522。有効 ADR（validity=有効）の本文
# `## 関連ADR` の `Related:` 行、および `## 保留した決定`（パーク欄）が指す ADR
# 参照先について、参照先の生存性（退役）・実在性（dangling）を検証する。
#   - 判定単位（書式非依存）: `Related:` 以降で最初に現れる ADR stem を抽出する。行頭
#     バレット（`-`）の有無・markdown リンク（`[stem](...)`）の有無・リンクラベルが stem
#     か説明文か（`- Related: [詳細](./ADR-X.md)` も ADR-X を取る）を問わない
#     （Issue #522 穴1・穴2＋リンクラベル書式）。説明散文中の後続 stem は先頭優先で拾わない
#     （誤検出回避）。判定単位はどの ADR にも成文化されておらず、本実装＋fixture
#     （scripts/fixtures/lint-adr/）を正とする。#491 決定2 の遡及改稿はしない。
#   - 参照先退役違反: `Related:` 参照先が実在し、かつ validity が 上書き済み／
#     廃止済み（RETIRED_VALIDITY）なら違反（有効 ADR が退役 ADR を指す参照を残さない）。
#   - dangling 参照違反: `Related:`／パーク欄の参照先 `<slug>.md` が実在しなければ
#     違反（full slug 完全一致で解決。解決不能な参照先＝AC8 fail-safe をここに統合）。
#   - パーク欄は dangling 検査のみ（退役検査は非適用）。パーク欄は凍結スナップショット
#     で後から編集不能なため、参照先が後に退役しても修復不能な違反を作らない
#     （§3 が `Related:` 双方向を強制しない論理と同型。Issue #522 J4）。
#   - source は有効 ADR のみに限定する。ADR-20260720-4 §3 は検査対象を「front-matter
#     を持つ ADR」と広く書くが、退役（凍結）ADR は編集不能で dangling/退役参照を修復
#     できず修復不能な違反を課すことになる（パーク欄を退役検査から外すのと同じ理由。
#     Issue #522 J4）。提案中・却下 ADR の参照はまだ確定した決定の一部でないため対象外と
#     する。結果として検査対象は Issue #522 タイトル「有効ADRの…」に一致する。
#   - 双方向性は強制しない（一方向 `Related:` は合法。§3）。パークの open/resolved 状態・
#     Issue 番号参照（`#<番号>`）は検査しない（§3 の不検査）。
#   - パーク欄の参照先抽出は節内の ADR トークンを全抽出する（J3）。将来パーク欄の
#     説明散文が退役/不在 ADR を引用すると誤検出しうる点に注意。
#   - 既知の限界（意図的）: (a) 1つの `Related:` 行に複数 ADR を列挙した場合は先頭 stem
#     のみ検査する（#491 決定2 の判定単位＝先頭 stem を継承。2件目以降は対象外）。
#     (b) 参照先が旧形式（front-matter 無し）・validity 空（提案中/却下）の場合は退役でも
#     dangling でもないとして違反にしない（fail-open。RETIRED_VALIDITY＝上書き済み/廃止済み
#     の完全一致のみを退役とみなす）。旧形式ADRはレイヤ1でも検査対象外である点と整合する。
#
# 全違反を列挙してから最後に非0 exitする（早期returnで打ち切らない）。
#
# 使い方:
#   bash scripts/lint-adr.sh [ADR_DIR]   # 既定 ADR_DIR は docs/adr/
#
# exit code:
#   0: 違反0件
#   1: 違反検出
#   2: ADR_DIR が存在しない
set -euo pipefail

ADR_DIR="${1:-docs/adr}"
ADR_DIR="${ADR_DIR%/}"

if [ ! -d "$ADR_DIR" ]; then
    echo "エラー: ディレクトリが見つかりません: $ADR_DIR" >&2
    exit 2
fi

# ADR-20260711-3 決定1 が定める状態語彙（front-matter の値側）。
# 正本の語彙が変わったときの追随点を1箇所に集約する。
STATUS_VOCAB=("提案中" "承認済み" "却下")
VALIDITY_VOCAB=("有効" "上書き済み" "廃止済み")
# レイヤ4（Issue #522）で「退役」とみなす validity 値（VALIDITY_VOCAB の部分集合）。
# 正本語彙が変わった際の追随点を1箇所へ集約する。
RETIRED_VALIDITY=("上書き済み" "廃止済み")

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
                # 同一 stem の重複登録を避ける（複数 `Related:` 行が同じ退役/非存在 ADR を
                # 指す場合の二重報告を防ぐ。extract_park_adr_refs の dedup と対称）。
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

# ファイル file の本文 `## 保留した決定` 節（次の `## ` 見出しまたはファイル末尾まで）に
# ある ADR stem（`ADR-<...>`）を全て抽出し、グローバル配列 PARK_ADR_TARGETS へ格納する
# （0件なら空配列）。ADR-20260720-4 §3「パーク欄が ADR を指す <slug>」の字義に従い節内の
# ADR トークンを全抽出する（Issue #522 J3）。Issue 番号参照（`#<番号>`）は対象外。
extract_park_adr_refs() {
    local file="$1"
    local line in_section=0 rest stem existing dup

    PARK_ADR_TARGETS=()

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^##[[:space:]]+保留した決定 ]]; then
            in_section=1
            continue
        fi
        if [ "$in_section" -eq 1 ] && [[ "$line" =~ ^##[[:space:]] ]]; then
            in_section=0
            continue
        fi
        if [ "$in_section" -eq 1 ]; then
            rest="$line"
            while [[ "$rest" =~ (ADR-[A-Za-z0-9-]+) ]]; do
                stem="${BASH_REMATCH[1]}"
                rest="${rest#*"$stem"}"
                # 同一 stem の重複登録を避ける。markdown リンク形式 `[stem](./stem.md)` は
                # 1参照でラベル部とパス部に同一 stem が2回現れるため、dedup しないと違反を
                # 二重報告する。抽出は最長トークン（`+` 貪欲）ゆえ prefix 衝突は起きない。
                dup=0
                for existing in ${PARK_ADR_TARGETS[@]+"${PARK_ADR_TARGETS[@]}"}; do
                    if [ "$existing" = "$stem" ]; then
                        dup=1
                        break
                    fi
                done
                if [ "$dup" -eq 0 ]; then
                    PARK_ADR_TARGETS+=("$stem")
                fi
            done
        fi
    done <"$file"
}

# ファイル名昇順で走査対象を収集
files=()
shopt -s nullglob
for f in "$ADR_DIR"/ADR-*.md; do
    files+=("$f")
done
shopt -u nullglob

sorted=()
if [ "${#files[@]}" -gt 0 ]; then
    while IFS= read -r f; do
        sorted+=("$f")
    done < <(printf '%s\n' "${files[@]}" | LC_ALL=C sort)
fi

violations=0

# レイヤ3 forward で照合する superseded-by ペア（front-matter を持つ ADR のみ対象）
xref_sources=()
xref_targets=()

# レイヤ3 reverse の照合用: stem -> front-matter superseded-by 値
# （front-matter を持たない、または superseded-by が空の場合はキー未設定のまま。
#   参照時は "${FM_SB_BY_STEM[$stem]:-}" で空扱いにする）
declare -A FM_SB_BY_STEM=()

# レイヤ4 の照合用: stem -> front-matter validity 値（front-matter を持つ ADR のみ。
# 持たない旧形式はキー未設定＝参照時 "${FM_VALIDITY_BY_STEM[$stem]:-}" で空扱いにする）
declare -A FM_VALIDITY_BY_STEM=()

for file in "${sorted[@]}"; do
    if ! extract_frontmatter "$file"; then
        # front-matter を持たない旧形式はレイヤ1検査対象外（スキップ）
        continue
    fi

    FM_SB_BY_STEM["$(basename "$file" .md)"]="$FM_SUPERSEDED_BY"
    FM_VALIDITY_BY_STEM["$(basename "$file" .md)"]="$FM_VALIDITY"

    # 種別1・4: status の存在と語彙
    # 空のときは種別1のみを報告する（語彙違反として二重に数えない）
    if [ -z "$FM_STATUS" ]; then
        printf '%s: status が空です（front-matter に status キーの値が必要）\n' "$file"
        violations=$((violations + 1))
    elif ! in_vocab "$FM_STATUS" "${STATUS_VOCAB[@]}"; then
        printf '%s: status の値 "%s" が語彙にありません（提案中 / 承認済み / 却下 のいずれかが必要）\n' "$file" "$FM_STATUS"
        violations=$((violations + 1))
    fi

    # 種別5: validity の語彙（空は起票・却下で合法のため語彙検査の対象外）
    if [ -n "$FM_VALIDITY" ] && ! in_vocab "$FM_VALIDITY" "${VALIDITY_VOCAB[@]}"; then
        printf '%s: validity の値 "%s" が語彙にありません（有効 / 上書き済み / 廃止済み のいずれか、または空が必要）\n' "$file" "$FM_VALIDITY"
        violations=$((violations + 1))
    fi

    if [ "$FM_STATUS" = "承認済み" ] && [ -z "$FM_VALIDITY" ]; then
        printf '%s: status=承認済み だが validity が空です（validity キーの値が必要）\n' "$file"
        violations=$((violations + 1))
    fi

    if [ "$FM_VALIDITY" = "上書き済み" ] && [ -z "$FM_SUPERSEDED_BY" ]; then
        printf '%s: validity=上書き済み だが superseded-by が空です（superseded-by キーの値が必要）\n' "$file"
        violations=$((violations + 1))
    fi

    # 種別6・7: 起票（提案中）・却下 の行は validity・superseded-by とも「（無し）」。
    # 承認軸が終端（却下）または未承認（提案中）の ADR は有効性軸を持たない。
    if [ "$FM_STATUS" = "提案中" ] || [ "$FM_STATUS" = "却下" ]; then
        if [ -n "$FM_VALIDITY" ]; then
            printf '%s: status=%s だが validity が空ではありません（値 "%s"。スキーマ表では起票・却下の validity は「（無し）」）\n' "$file" "$FM_STATUS" "$FM_VALIDITY"
            violations=$((violations + 1))
        fi
        if [ -n "$FM_SUPERSEDED_BY" ]; then
            printf '%s: status=%s だが superseded-by が空ではありません（値 "%s"。スキーマ表では起票・却下の superseded-by は「（無し）」）\n' "$file" "$FM_STATUS" "$FM_SUPERSEDED_BY"
            violations=$((violations + 1))
        fi
    fi

    # 種別8: 承認（有効）・廃止（廃止済み）の行は superseded-by「（無し）」。
    # 後継を指すなら上書き済みであるべきで、有効のままなら原 ADR と後継が
    # 同時に index へ並ぶ。廃止済みは決定1 で「後継なしで放棄された」と定義される。
    if [ "$FM_VALIDITY" = "有効" ] || [ "$FM_VALIDITY" = "廃止済み" ]; then
        if [ -n "$FM_SUPERSEDED_BY" ]; then
            printf '%s: validity=%s だが superseded-by が空ではありません（値 "%s"。スキーマ表では承認・廃止の superseded-by は「（無し）」）\n' "$file" "$FM_VALIDITY" "$FM_SUPERSEDED_BY"
            violations=$((violations + 1))
        fi
    fi

    if [ -n "$FM_SUPERSEDED_BY" ]; then
        xref_sources+=("$file")
        xref_targets+=("$FM_SUPERSEDED_BY")
    fi
done

# レイヤ2: index 同期検証
# 生成器の呼び出しはスクリプト自身の位置からの相対パスで解決する（cwd 依存回避）
GEN_INDEX="$(dirname "$0")/gen-adr-index.sh"
INDEX_FILE="$ADR_DIR/index.md"

if [ ! -f "$INDEX_FILE" ]; then
    printf '%s: index 同期違反（index.md が存在しません）\n' "$INDEX_FILE"
    violations=$((violations + 1))
else
    generated="$(bash "$GEN_INDEX" "$ADR_DIR")"
    current="$(cat "$INDEX_FILE")"
    if [ "$generated" != "$current" ]; then
        printf '%s: index 同期違反（gen-adr-index.sh の出力と一致しません。再生成してください）\n' "$INDEX_FILE"
        violations=$((violations + 1))
    fi
fi

# レイヤ3 forward: front-matter superseded-by 起点で本文 Supersedes 逆参照を照合
for i in "${!xref_sources[@]}"; do
    a_file="${xref_sources[$i]}"
    a_stem="$(basename "$a_file" .md)"

    # superseded-by をカンマ分割し、各後継 stem を独立に照合する（リスト値 1→N 対応）
    split_csv "${xref_targets[$i]}"

    # superseded-by は非空だが有効な参照先 stem を1つも含まない（カンマ・空白のみ）
    # 場合、「validity=上書き済み ⟹ 少なくとも1件の後継が照合される」不変条件が
    # 崩れるため違反とする（レイヤ1の空判定は raw 値が非空のため通過してしまう）
    if [ "${#SPLIT_RESULT[@]}" -eq 0 ]; then
        printf '%s: 相互参照違反（superseded-by=%s に有効な参照先 stem がありません）\n' "$a_file" "${xref_targets[$i]}"
        violations=$((violations + 1))
        continue
    fi

    for b_stem in ${SPLIT_RESULT[@]+"${SPLIT_RESULT[@]}"}; do
        b_file="$ADR_DIR/$b_stem.md"

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

# レイヤ3 reverse: 本文 Supersedes 宣言起点で front-matter superseded-by を照合
# （C の本文が Supersedes: T を宣言するのに、T の front-matter superseded-by
#   が C を指していない＝front-matter 更新忘れを検出する。forward で既に
#   一致確認済みのエッジは reverse 側でも自然に一致するため、ここでは
#   forward 側で捕捉できない「本文はあるが front-matter が追随していない」
#   ケースのみが新たに violation として計上される＝二重計上にならない）
for c_file in "${sorted[@]}"; do
    extract_body_supersedes "$c_file"
    c_stem="$(basename "$c_file" .md)"

    for t_stem in "${BODY_SUPERSEDES_TARGETS[@]}"; do
        t_file="$ADR_DIR/$t_stem.md"

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

# レイヤ4: 有効ADRの Related/park 参照の退役・dangling 検査
# （Issue #522, ADR-20260720-4 §3。判定単位は書式非依存の先頭 stem 抽出）
for src_file in "${sorted[@]}"; do
    src_stem="$(basename "$src_file" .md)"
    # source は有効 ADR のみ（退役・提案中・却下・旧形式は検査対象外）
    if [ "${FM_VALIDITY_BY_STEM[$src_stem]:-}" != "有効" ]; then
        continue
    fi

    # `## 関連ADR` の Related 参照先: 非存在→dangling、実在かつ退役→参照先退役違反
    extract_body_related "$src_file"
    for t_stem in ${BODY_RELATED_TARGETS[@]+"${BODY_RELATED_TARGETS[@]}"}; do
        if [ ! -f "$ADR_DIR/$t_stem.md" ]; then
            printf '%s: dangling 参照違反（"## 関連ADR" の Related 参照先 %s が見つかりません）\n' "$src_file" "$t_stem"
            violations=$((violations + 1))
        elif in_vocab "${FM_VALIDITY_BY_STEM[$t_stem]:-}" "${RETIRED_VALIDITY[@]}"; then
            printf '%s: 参照先退役違反（"## 関連ADR" の Related 参照先 %s は validity=%s の退役ADRです）\n' "$src_file" "$t_stem" "${FM_VALIDITY_BY_STEM[$t_stem]:-}"
            violations=$((violations + 1))
        fi
    done

    # `## 保留した決定`（park）参照先: dangling 検査のみ（退役検査は非適用＝J4）
    extract_park_adr_refs "$src_file"
    for p_stem in ${PARK_ADR_TARGETS[@]+"${PARK_ADR_TARGETS[@]}"}; do
        if [ ! -f "$ADR_DIR/$p_stem.md" ]; then
            printf '%s: dangling 参照違反（"## 保留した決定" の参照先 %s が見つかりません）\n' "$src_file" "$p_stem"
            violations=$((violations + 1))
        fi
    done
done

if [ "$violations" -gt 0 ]; then
    exit 1
fi
exit 0
