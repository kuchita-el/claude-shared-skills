#!/usr/bin/env bats
load 'helpers/common'

# shared-memory の検査器（plugins/shared-memory/scripts/memory.mjs）の試験。
# 記憶の根は試験ごとに $BATS_TEST_TMPDIR へ作る。配布物へ fixture を置かない。

setup() {
  SUT="$REPO_ROOT/plugins/shared-memory/scripts/memory.mjs"
  ROOT="$BATS_TEST_TMPDIR/memory"
  mkdir -p "$ROOT/records"
}

# 形式に合う記録を1件書く。$1 は識別子、$2 はファイル名の名前、$3 以降は front-matter へ足す行。
record() {
  local id="$1" name="$2"
  shift 2
  {
    printf '%s\n' '---' "id: $id" 'type: knowledge' "title: $name の主張" 'author: human' \
      'verification: verified' 'confidence: high' 'applies-when: いつでも' 'sources:' '  - 出典' \
      'created: 2026-11-14' 'updated: 2026-11-14'
    [ "$#" -eq 0 ] || printf '%s\n' "$@"
    printf '%s\n' '---' '' '本文。'
  } >"$ROOT/records/$id-$name.md"
}

# 記録の1行を sed の式で書き換える。$1 はファイル名、$2 は式。
edit() {
  sed -i "$2" "$ROOT/records/$1"
}

write_index() {
  node "$SUT" index "$ROOT" --write
}

# 形式に合う採用の台帳を1件書く。$1 は記録の識別子、$2 以降は front-matter へ足す行。
adopt() {
  local id="$1"
  shift
  mkdir -p "$ROOT/adopted"
  {
    printf '%s\n' '---' "record: $id" 'version: a1c5dc1' 'decisions:' '  - ADR-202611200000-01' 'adopted: 2026-11-21'
    [ "$#" -eq 0 ] || printf '%s\n' "$@"
    printf '%s\n' '---' '' '採用の理由。'
  } >"$ROOT/adopted/$id.md"
}

# 台帳の1行を sed の式で書き換える。$1 はファイル名、$2 は式。
edit_adopted() {
  sed -i "$2" "$ROOT/adopted/$1"
}

A=MEM-202611140000-01
B=MEM-202611140000-02
E=MEM-202611140000-03

@test "形式に合う記録と生成した索引は通過する" {
  record "$A" first
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "記録も索引も無い根は通過する" {
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "必ず書く項目が無い記録は required で落ちる" {
  record "$A" first
  edit "$A-first.md" '/^applies-when:/d'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"records/$A-first.md:required: applies-when が無い"* ]]
}

@test "出典が0件の記録は required で落ちる" {
  record "$A" first
  edit "$A-first.md" '/^  - 出典/d'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":required: sources が無い"* ]]
}

@test "値域に無い値は value で落ちる" {
  record "$A" first
  edit "$A-first.md" 's/^type: knowledge/type: memo/'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":value: type は"* ]]
}

@test "日付の形でない created は value で落ちる" {
  record "$A" first
  edit "$A-first.md" 's|^created: 2026-11-14|created: 2026/11/14|'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":value: created は"* ]]
}

@test "ファイル名の識別子が id と違う記録は filename で落ちる" {
  record "$A" first
  edit "$A-first.md" "s/^id: $A/id: $B/"
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":filename: ファイル名の識別子が id と一致しない"* ]]
}

@test "名前が形に合わないファイル名は filename で落ちる" {
  record "$A" First_Record
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":filename: ファイル名は"* ]]
}

@test "同じ id の記録が2件あると duplicate-id で落ちる" {
  record "$A" first
  record "$A" second
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":duplicate-id: $A は"* ]]
}

@test "front-matter が無い記録と閉じていない記録は front-matter で落ちる" {
  printf '%s\n' '本文だけ。' >"$ROOT/records/$A-first.md"
  printf '%s\n' '---' "id: $B" >"$ROOT/records/$B-second.md"
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"records/$A-first.md:front-matter: 1行目が --- でない"* ]]
  [[ "$output" == *"records/$B-second.md:front-matter: front-matter を閉じる --- が無い"* ]]
}

@test "コロンと空白を含む値は、引用符で囲めば通り、囲まなければ落ちる" {
  record "$A" first
  edit "$A-first.md" 's/^title: .*/title: "前提: 条件つき"/'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  edit "$A-first.md" 's/^title: .*/title: 前提: 条件つき/'
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":front-matter: 値を引用符で囲む"* ]]
}

@test "知らない項目は、入れ子の値ごと読み飛ばす" {
  record "$A" first 'tags:' '  - memo' 'extra:' '  nested: value'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
}

@test "行頭から始まる「- 値」の並びも読む" {
  record "$A" first
  edit "$A-first.md" 's/^  - 出典/- 出典/'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
}

@test "superseded-by が指す記録が無いと dangling で落ちる" {
  record "$A" first "superseded-by: $B"
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":dangling: superseded-by が指す記録が無い: $B"* ]]
}

@test "置き換えは、evolution があれば通り、無ければ replacement で落ちる" {
  record "$A" first "superseded-by: $B"
  record "$B" second
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"records/$A-first.md:replacement: $B への置き換えを説明する evolution が無い"* ]]
  record "$E" change 'from:' "  - $A" 'to:' "  - $B"
  edit "$E-change.md" 's/^type: knowledge/type: evolution/'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
}

@test "evolution の from の記録が superseded-by を持たないと replacement で落ちる" {
  record "$A" first
  record "$B" second
  record "$E" change 'from:' "  - $A" 'to:' "  - $B"
  edit "$E-change.md" 's/^type: knowledge/type: evolution/'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"records/$E-change.md:replacement: from の $A が"* ]]
}

@test "to を持たない evolution と、from を持つ evolution でない記録は evolution で落ちる" {
  record "$A" first 'from:' "  - $B"
  record "$B" second
  record "$E" change 'from:' "  - $B"
  edit "$E-change.md" 's/^type: knowledge/type: evolution/'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"records/$A-first.md:evolution: from は evolution だけが持つ"* ]]
  [[ "$output" == *"records/$E-change.md:evolution: evolution は to に記録を1件以上書く"* ]]
}

@test "moved-to だけの記録は evolution が無くても通り、superseded-by と併記すると value で落ちる" {
  record "$A" first 'moved-to: lint の規則 no-foo'
  record "$B" second
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  edit "$A-first.md" "s/^moved-to: .*/&\nsuperseded-by: $B/"
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":value: superseded-by と moved-to は同時に書かない"* ]]
}

@test "索引は識別子の順に並び、置き換え済みの記録を載せない" {
  record "$B" second
  record "$A" first 'moved-to: 指示ファイル'
  record "$E" third
  run node "$SUT" index "$ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"$A"* ]]
  [[ "$output" == *"[$B](records/$B-second.md) | knowledge | second の主張 | いつでも | verified |"* ]]
  local second third
  second=$(printf '%s\n' "$output" | grep -n "$B" | cut -d: -f1)
  third=$(printf '%s\n' "$output" | grep -n "$E" | cut -d: -f1)
  [ "$second" -lt "$third" ]
}

@test "索引は、値の中の縦棒を表の区切りにしない" {
  record "$A" first
  edit "$A-first.md" 's/^applies-when: .*/applies-when: a | b/'
  run node "$SUT" index "$ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *'| a \| b |'* ]]
}

@test "記録と一致しない索引は index で落ち、作り直せば通る" {
  record "$A" first
  write_index
  record "$B" second
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == "index.md:index: 索引が記録と一致しない。index --write で作り直す" ]]
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
}

@test "記録が在るのに索引が無いと index で落ちる" {
  record "$A" first
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == "index.md:index: 索引が無い。index --write で作る" ]]
}

@test "index は --write が無ければファイルを書かない" {
  record "$A" first
  run node "$SUT" index "$ROOT"
  [ "$status" -eq 0 ]
  [ ! -e "$ROOT/index.md" ]
}

@test "records の下の階層は読まない" {
  record "$A" first
  mkdir -p "$ROOT/records/archive"
  printf '%s\n' '本文だけ。' >"$ROOT/records/archive/note.md"
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
}

@test "引数の誤りと、ディレクトリでない根は exit 2 で終わる" {
  run node "$SUT"
  [ "$status" -eq 2 ]
  run node "$SUT" verify "$ROOT"
  [ "$status" -eq 2 ]
  run node "$SUT" check "$ROOT" extra
  [ "$status" -eq 2 ]
  run node "$SUT" index "$ROOT" --force
  [ "$status" -eq 2 ]
  run node "$SUT" check "$ROOT/missing"
  [ "$status" -eq 2 ]
  [[ "$output" == *"記憶の根がディレクトリでない"* ]]
}

@test "records を持たないディレクトリは、記憶の根として扱わず exit 2 で終わる" {
  rmdir "$ROOT/records"
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"記憶の根に records/ が無い"* ]]
  run node "$SUT" index "$ROOT"
  [ "$status" -eq 2 ]
}

@test "author・verification・confidence は、それぞれ値域に無い値で value に落ちる" {
  local key
  for key in author verification confidence; do
    record "$A" first
    edit "$A-first.md" "s/^$key: .*/$key: other/"
    write_index
    run node "$SUT" check "$ROOT"
    [ "$status" -eq 1 ]
    [[ "$output" == *":value: $key は"* ]]
  done
}

@test "日付の形でない updated は value で落ちる" {
  record "$A" first
  edit "$A-first.md" 's/^updated: .*/updated: 昨日/'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":value: updated は"* ]]
}

@test "形に合わない id は value で落ちる" {
  record "$A" first
  edit "$A-first.md" 's/^id: .*/id: MEM-1/'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":value: id は"* ]]
}

@test "evolution の from と to が指す記録が無いと、それぞれ dangling で落ちる" {
  record "$E" change 'from:' "  - $A" 'to:' "  - $B"
  edit "$E-change.md" 's/^type: knowledge/type: evolution/'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":dangling: from が指す記録が無い: $A"* ]]
  [[ "$output" == *":dangling: to が指す記録が無い: $B"* ]]
}

@test "YAML が別の意味に読む値は、引用符で囲まなければ front-matter で落ちる" {
  local value
  for value in 'a #b' '#foo' '- foo' '? foo' ',foo' ']foo' '*foo' '-'; do
    record "$A" first
    edit "$A-first.md" "s/^title: .*/title: $value/"
    write_index
    run node "$SUT" check "$ROOT"
    [ "$status" -eq 1 ]
    [[ "$output" == *":front-matter: 値を引用符で囲む: $value"* ]]
  done
}

@test "記号で始まっても、YAML が値として読む形は通る" {
  local value
  for value in '-foo' '?foo' 'a#b' '"#foo"'; do
    record "$A" first
    edit "$A-first.md" "s/^title: .*/title: $value/"
    write_index
    run node "$SUT" check "$ROOT"
    [ "$status" -eq 0 ]
  done
}

@test "同じ項目を2回書いた記録は front-matter で落ちる" {
  record "$A" first 'title: もう1つの主張'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":front-matter: キーが重複している: title"* ]]
}

@test "改行が CRLF の記録と索引も通る" {
  record "$A" first
  write_index
  sed -i 's/$/\r/' "$ROOT/records/$A-first.md" "$ROOT/index.md"
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "日本語や空白を含む名前の項目も読み飛ばす" {
  record "$A" first 'タグ: メモ' 'my prop: x' '関連:' '  - a'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
}

@test "索引は superseded-by を持つ記録を載せない" {
  record "$A" first "superseded-by: $B"
  record "$B" second
  record "$E" change 'from:' "  - $A" 'to:' "  - $B"
  edit "$E-change.md" 's/^type: knowledge/type: evolution/'
  run node "$SUT" index "$ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"[$A]"* ]]
  [[ "$output" == *"[$B]"* ]]
  [[ "$output" == *"[$E]"* ]]
}

@test "belief の author は、joint だと value で落ち、human なら通る" {
  record "$A" first
  edit "$A-first.md" 's/^type: knowledge/type: belief/'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  edit "$A-first.md" 's/^author: human/author: joint/'
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":value: belief の author は human か ai のどちらかにする"* ]]
}

@test "互いに置き換え合う記録は replacement で落ちる" {
  record "$A" first "superseded-by: $B"
  record "$B" second "superseded-by: $A"
  record "$E" change 'from:' "  - $A" "  - $B" 'to:' "  - $A" "  - $B"
  edit "$E-change.md" 's/^type: knowledge/type: evolution/'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":replacement: 置き換えが循環している"* ]]
}

# ---- 採用の台帳（adopted/） ----

@test "台帳: 形式に合う台帳は通過し、知らない項目を読み飛ばす" {
  adopt "$A"
  adopt "$B" 'note: 補足' 'タグ:' '  - memo'
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "台帳: 必ず書く項目は、どれが無くても required で落ちる" {
  local key
  for key in record version adopted decisions; do
    adopt "$A"
    edit_adopted "$A.md" "/^$key:/d"
    [ "$key" != decisions ] || edit_adopted "$A.md" '/^  - /d'
    run node "$SUT" check "$ROOT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"adopted/$A.md:required: $key が無い"* ]]
  done
}

@test "台帳: decisions が0件の台帳と、本文が空の台帳は required で落ちる" {
  adopt "$A"
  edit_adopted "$A.md" '/^  - /d'
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [ "$output" = "adopted/$A.md:required: decisions が無い" ]
  adopt "$A"
  edit_adopted "$A.md" 's/^採用の理由。$/  /'
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == "adopted/$A.md:required: 本文が無い"* ]]
}

@test "台帳: record・version・adopted は、形に合わない値で value に落ちる" {
  local line
  for line in 'record: MEM-1' 'version: a1c5dc' 'version: A1C5DC1' 'version: a1c5dcg' 'adopted: 2026/11/21'; do
    adopt "$A"
    edit_adopted "$A.md" "s|^${line%%:*}: .*|$line|"
    run node "$SUT" check "$ROOT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"adopted/$A.md:value: ${line%%:*} は"* ]]
  done
}

@test "台帳: version は7桁から64桁までを受け、65桁で value に落ちる" {
  local hex
  for hex in a1c5dc1 a1c5dc1a1c5dc1a1c5dc1a1c5dc1a1c5dc1a1c5d "$(printf 'a%.0s' {1..64})"; do
    adopt "$A"
    edit_adopted "$A.md" "s/^version: .*/version: $hex/"
    run node "$SUT" check "$ROOT"
    [ "$status" -eq 0 ]
  done
  edit_adopted "$A.md" "s/^version: .*/version: $(printf 'a%.0s' {1..65})/"
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":value: version は"* ]]
}

@test "台帳: ファイル名が <record>.md でないと filename で落ちる" {
  adopt "$A"
  mv "$ROOT/adopted/$A.md" "$ROOT/adopted/$A-first.md"
  adopt "$B"
  edit_adopted "$B.md" "s/^record: .*/record: $E/"
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"adopted/$A-first.md:filename: ファイル名は"* ]]
  [[ "$output" == *"adopted/$B.md:filename: ファイル名の識別子が record と一致しない: $E"* ]]
}

@test "台帳: front-matter が無い台帳と、同じ項目を2回書いた台帳は front-matter で落ちる" {
  mkdir -p "$ROOT/adopted"
  printf '%s\n' '本文だけ。' >"$ROOT/adopted/$A.md"
  adopt "$B" 'version: b2d6ed2'
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"adopted/$A.md:front-matter: 1行目が --- でない"* ]]
  [[ "$output" == *"adopted/$B.md:front-matter: キーが重複している: version"* ]]
}

@test "台帳: adopted の下の階層と、.md で終わらないファイルは読まない" {
  adopt "$A"
  mkdir -p "$ROOT/adopted/archive"
  printf '%s\n' '本文だけ。' >"$ROOT/adopted/archive/$B.md"
  printf '%s\n' '覚え書き。' >"$ROOT/adopted/notes.txt"
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "台帳: adopted がディレクトリでないと、検査できない入力として exit 2 で終わる" {
  : >"$ROOT/adopted"
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"adopted がディレクトリでない"* ]]
}

@test "台帳: 記録の違反と台帳の違反を、同じ実行で両方出す" {
  record "$A" first
  adopt "$B"
  edit_adopted "$B.md" '/^adopted:/d'
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"index.md:index: 索引が無い"* ]]
  [[ "$output" == *"adopted/$B.md:required: adopted が無い"* ]]
}

@test "台帳: index は台帳を読まず、索引に載せない" {
  record "$A" first
  adopt "$A"
  : >"$ROOT/adopted/broken.md"
  run node "$SUT" index "$ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"adopted"* ]]
}

@test "台帳: 記録の項目名を台帳に書いても読み飛ばし、台帳の項目名を記録に書いても読み飛ばす" {
  record "$A" first 'record: x: y' 'decisions: 1行の値'
  write_index
  adopt "$A" 'id: x: y' 'sources: 1行の値'
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
}

# ここから下は、Task Memory（tasks/）の試験である。残留の検出は、--no-task-memory を付けたときだけ働く。

@test "Task Memory: tasks と adopted は、記録の検査にも索引にも混ざらない" {
  record "$A" first
  mkdir -p "$ROOT/tasks"
  printf '%s\n' '覚え書き。front-matter は無い。' >"$ROOT/tasks/claude-x.md"
  printf '%s\n' '---' 'id: 閉じていない' >"$ROOT/tasks/MEM-202611140000-09-looks-like-record.md"
  adopt "$A"
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run node "$SUT" index "$ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"tasks/"* ]]
  [[ "$output" != *"adopted/"* ]]
  [ "$(grep -c '^| \[MEM-' <<<"$output")" -eq 1 ]
}

@test "Task Memory: --no-task-memory は、tasks の直下の1件につき1行の task-memory で落ちる" {
  mkdir -p "$ROOT/tasks/sub"
  printf '%s\n' '覚え書き。' >"$ROOT/tasks/a.md"
  : >"$ROOT/tasks/.gitkeep"
  printf '%s\n' '覚え書き。' >"$ROOT/tasks/sub/inner.md"
  run node "$SUT" check "$ROOT" --no-task-memory
  [ "$status" -eq 1 ]
  [[ "$output" == *"tasks/a.md:task-memory: "* ]]
  [[ "$output" == *"tasks/.gitkeep:task-memory: "* ]]
  [[ "$output" == *"tasks/sub:task-memory: "* ]]
  [ "$(grep -c ':task-memory: ' <<<"$output")" -eq 3 ]
  [[ "$output" != *"tasks/sub/inner.md"* ]]
}

@test "Task Memory: --no-task-memory を付けなければ、tasks が在っても通る" {
  mkdir -p "$ROOT/tasks/sub"
  printf '%s\n' '覚え書き。' >"$ROOT/tasks/a.md"
  : >"$ROOT/tasks/.gitkeep"
  printf '%s\n' '覚え書き。' >"$ROOT/tasks/sub/inner.md"
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "Task Memory: tasks が無い根と、空の tasks は、--no-task-memory でも通る" {
  run node "$SUT" check "$ROOT" --no-task-memory
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  mkdir -p "$ROOT/tasks"
  run node "$SUT" check "$ROOT" --no-task-memory
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "Task Memory: --no-task-memory を付けても、記録の検査と索引の一致は変わらない" {
  record "$A" first
  write_index
  run node "$SUT" check "$ROOT" --no-task-memory
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  edit "$A-first.md" '/^applies-when:/d'
  mkdir -p "$ROOT/tasks"
  printf '%s\n' '覚え書き。' >"$ROOT/tasks/a.md"
  run node "$SUT" check "$ROOT" --no-task-memory
  [ "$status" -eq 1 ]
  [[ "$output" == *"records/$A-first.md:required: applies-when が無い"* ]]
  [[ "$output" == *"index.md:index: 索引が記録と一致しない"* ]]
  [[ "$output" == *"tasks/a.md:task-memory: "* ]]
}

@test "Task Memory: tasks がディレクトリでないとき、--no-task-memory は task-memory で落ちる" {
  : >"$ROOT/tasks"
  run node "$SUT" check "$ROOT" --no-task-memory
  [ "$status" -eq 1 ]
  [[ "$output" == *"tasks:task-memory: tasks がディレクトリでない"* ]]
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "Task Memory: tasks がリンクのとき、辿らずに task-memory の1行で落ちる" {
  mkdir -p "$BATS_TEST_TMPDIR/empty" "$BATS_TEST_TMPDIR/filled"
  printf '%s\n' '覚え書き。' >"$BATS_TEST_TMPDIR/filled/a.md"
  local target
  for target in "$BATS_TEST_TMPDIR/empty" "$BATS_TEST_TMPDIR/filled" "$BATS_TEST_TMPDIR/missing"; do
    rm -f "$ROOT/tasks"
    ln -s "$target" "$ROOT/tasks"
    run node "$SUT" check "$ROOT" --no-task-memory
    [ "$status" -eq 1 ]
    [ "$output" = "tasks:task-memory: tasks がディレクトリでない。リンクは辿らない。既定のブランチへ入れる前に取り除く" ]
    run node "$SUT" check "$ROOT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "Task Memory: --no-task-memory の置き方の誤りは exit 2 で終わる" {
  run node "$SUT" check "$ROOT" --no-task-memory extra
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: memory.mjs check ROOT [--no-task-memory]"* ]]
  run node "$SUT" check "$ROOT" --no-task-memory --no-task-memory
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: memory.mjs check ROOT [--no-task-memory]"* ]]
  run node "$SUT" index "$ROOT" --no-task-memory
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: memory.mjs check ROOT [--no-task-memory]"* ]]
  run node "$SUT" check "$ROOT" --write
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: memory.mjs check ROOT [--no-task-memory]"* ]]
  run node "$SUT" check --no-task-memory "$ROOT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: memory.mjs check ROOT [--no-task-memory]"* ]]
}

# eval の題材（evals/shared-memory/<ケース>/scaffold.sh）が作る根を、検査器へ掛ける。
# eval は runner に入らない。形式や索引の出力を変えたとき、題材が最初から違反を持つ状態へ
# 黙って古くなることを、ここで赤にする。$1 はケースの名前。題材は $BATS_TEST_TMPDIR/<ケース> へ作る。
scaffold_case() {
  local case_dir="$BATS_TEST_TMPDIR/$1"
  mkdir -p "$case_dir"
  (cd "$case_dir" && bash "$REPO_ROOT/evals/shared-memory/$1/scaffold.sh")
}

@test "eval の題材: behavior-propose-records の scaffold が作る根は、check を通る" {
  scaffold_case behavior-propose-records
  [ -f "$BATS_TEST_TMPDIR/behavior-propose-records/notes/task-notes.md" ]
  run node "$SUT" check "$BATS_TEST_TMPDIR/behavior-propose-records/docs/memory"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
