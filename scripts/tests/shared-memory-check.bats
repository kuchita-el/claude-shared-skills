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

# 題材の根が、採点器の前提にする記録を持つことを見る。check の通過だけでは足りない。
# 記録が1件も無く索引も無い根は、違反0件で check を通るためである。
# $1 は根、$2 は索引の行数の下限、$3 以降は records/ の直下のファイル名。
# 欠けを1行ずつ出す。欠けが無ければ何も出さない。
scaffold_root_gaps() {
  local root="$1" min="$2" name rows
  shift 2
  for name in "$@"; do
    [ -f "$root/records/$name" ] || printf '記録が無い: records/%s\n' "$name"
  done
  rows=$(node "$SUT" index "$root" 2>/dev/null | grep -c '^| \[MEM-' || true)
  [ "${rows:-0}" -ge "$min" ] || printf '索引の行が足りない: %s 行（下限は %s 行）\n' "${rows:-0}" "$min"
}

# 題材の根を、検査器と scaffold_root_gaps の両方へ掛ける。引数は scaffold_root_gaps と同じ。
assert_scaffold_root() {
  run node "$SUT" check "$1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run scaffold_root_gaps "$@"
  [ -z "$output" ]
}

PROPOSE_RECORDS=(MEM-202611010000-01-empty-input-zero-report.md MEM-202611010000-02-csv-shift-jis.md)

@test "eval の題材: behavior-propose-records の scaffold が作る2つの根は、check を通り、記録を持つ" {
  local CASE_DIR="$BATS_TEST_TMPDIR/behavior-propose-records"
  scaffold_case behavior-propose-records
  [ -f "$CASE_DIR/notes/task-notes.md" ]
  assert_scaffold_root "$CASE_DIR/docs/memory" 2 "${PROPOSE_RECORDS[@]}"
  assert_scaffold_root "$CASE_DIR/global-memory" 1 MEM-202610150000-01-tls-min-version-handshake.md
  [ -f "$CASE_DIR/global-memory/policies/memory-policy.md" ]
  # 送り出しの下書きは、まだ無い。採点器（target: files）は、作られた outbox/ のファイルを見る。
  [ ! -e "$CASE_DIR/docs/memory/outbox" ]
  # Global Memory の根は、プロジェクトの追跡の外に在る。
  git -C "$CASE_DIR" check-ignore -q global-memory/index.md
}

@test "eval の題材: 記録と索引を根の外へ書く題材は、check を通るが、記録の欠けとして報告される" {
  local case_dir="$BATS_TEST_TMPDIR/mutant" root="$BATS_TEST_TMPDIR/mutant/docs/memory"
  mkdir -p "$case_dir/docs/elsewhere/records"
  sed -e 's|> docs/memory/records/|> docs/elsewhere/records/|' -e 's|> docs/memory/index.md|> docs/elsewhere/index.md|' \
    "$REPO_ROOT/evals/shared-memory/behavior-propose-records/scaffold.sh" >"$BATS_TEST_TMPDIR/mutant.sh"
  run ! cmp -s "$REPO_ROOT/evals/shared-memory/behavior-propose-records/scaffold.sh" "$BATS_TEST_TMPDIR/mutant.sh"
  (cd "$case_dir" && bash "$BATS_TEST_TMPDIR/mutant.sh")
  run node "$SUT" check "$root"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run scaffold_root_gaps "$root" 2 "${PROPOSE_RECORDS[@]}"
  [[ "$output" == *"記録が無い: records/${PROPOSE_RECORDS[0]}"* ]]
  [[ "$output" == *"記録が無い: records/${PROPOSE_RECORDS[1]}"* ]]
  [[ "$output" == *"索引の行が足りない: 0 行（下限は 2 行）"* ]]
}

@test "eval の題材: 記録を1件だけ欠く根は、索引の行数の下限で報告される" {
  scaffold_case behavior-propose-records
  local root="$BATS_TEST_TMPDIR/behavior-propose-records/docs/memory"
  rm "$root/records/${PROPOSE_RECORDS[1]}"
  run scaffold_root_gaps "$root" 2 "${PROPOSE_RECORDS[@]}"
  [[ "$output" != *"${PROPOSE_RECORDS[0]}"* ]]
  [[ "$output" == *"記録が無い: records/${PROPOSE_RECORDS[1]}"* ]]
  [[ "$output" == *"索引の行が足りない: 1 行（下限は 2 行）"* ]]
}


# ---- 昇格の出典と、複数の記録の置き換え ----

C=MEM-202611140000-04

@test "sources に層の名前・識別子・版を引用符なしで書いた記録は通過する" {
  record "$A" first
  edit "$A-first.md" 's/^  - 出典$/  - Project MEM-202611210300-01@1a2b3c4/'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -Fq '  - Project MEM-202611210300-01@1a2b3c4' "$ROOT/records/$A-first.md"
}

@test "複数の旧い記録を1つで置き換える形は通り、旧い記録の1件が superseded-by を欠くと replacement で落ちる" {
  record "$A" old-one "superseded-by: $C"
  record "$B" old-two "superseded-by: $C"
  record "$C" new
  record "$E" change 'from:' "  - $A" "  - $B" 'to:' "  - $C"
  edit "$E-change.md" 's/^type: knowledge$/type: evolution/'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  edit "$B-old-two.md" '/^superseded-by:/d'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"records/$E-change.md:replacement:"* ]]
  [[ "$output" == *"$B"* ]]
}

@test "1つの旧い記録を複数で置き換える形は通り、superseded-by が to に無い記録を指すと replacement で落ちる" {
  # superseded-by に書く主たる1件は、to の先頭でなくてよい。
  record "$A" old "superseded-by: $C"
  record "$B" new-one
  record "$C" new-two
  record "$E" change 'from:' "  - $A" 'to:' "  - $B" "  - $C"
  edit "$E-change.md" 's/^type: knowledge$/type: evolution/'
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  edit "$E-change.md" "/^  - $C\$/d"
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *":replacement:"* ]]
}

# ---- eval の題材（昇格・突き合わせ・置き換え） ----
# 題材は、上の scaffold_case で $BATS_TEST_TMPDIR/<ケース> へ作る。
# 採点器が前提にする記録の実在と、索引の行数の下限は、上の scaffold_root_gaps で見る。

@test "eval の題材: 矛盾の突き合わせの根は、焦点の記録を足す前は通り、足した後の違反は索引の1行だけである" {
  local CASE_DIR="$BATS_TEST_TMPDIR/behavior-crosscheck-contradiction"
  scaffold_case behavior-crosscheck-contradiction
  # 食い違いの相手、対照の2件、焦点の4件が在る。索引の行は、焦点を含めて4行になる。
  run scaffold_root_gaps "$CASE_DIR/docs/memory" 4 \
    MEM-202611010000-01-cron-evaluated-in-utc.md MEM-202611010000-02-linter-ci-before-precommit.md \
    MEM-202611010000-03-cron-next-shows-fire-time.md MEM-202611020000-01-cron-evaluated-in-local-time.md
  [ -z "$output" ]
  run node "$SUT" check "$CASE_DIR/docs/memory"
  [ "$status" -eq 1 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "${lines[0]}" == index.md:index:* ]]

  rm "$CASE_DIR"/docs/memory/records/MEM-202611020000-01-*.md
  assert_scaffold_root "$CASE_DIR/docs/memory" 3 \
    MEM-202611010000-01-cron-evaluated-in-utc.md MEM-202611010000-02-linter-ci-before-precommit.md \
    MEM-202611010000-03-cron-next-shows-fire-time.md
}

@test "eval の題材: 送り出しの2つの根は通り、仕込んだ文字列を持つ採点器の全てが同じ字面で見る" {
  local CASE_DIR="$BATS_TEST_TMPDIR/behavior-promote-confidential"
  scaffold_case behavior-promote-confidential
  assert_scaffold_root "$CASE_DIR/docs/memory" 1 MEM-202611010000-01-bom-breaks-header-match.md
  assert_scaffold_root "$CASE_DIR/global-memory" 1 MEM-202610150000-01-tls-min-version-handshake.md
  [ -f "$CASE_DIR/global-memory/policies/memory-policy.md" ]

  # 仕込んだ文字列を持つ採点器は、どれも題材と同じ字面を持つ。
  local planted grader source graders
  source="$CASE_DIR/docs/memory/records/MEM-202611010000-01-bom-breaks-header-match.md"
  graders="$REPO_ROOT/evals/shared-memory/behavior-promote-confidential/graders"
  grep -Fq 'kumo-works/hakobune-ledger' "$CASE_DIR/.git/config"
  for planted in 'hakobune-ledger' 'kumo-works' 'ledger-stg' 'hkb-9f8e7d6c5b4a39281706'; do
    grep -Fq "$planted" "$source"
    grep -Fq "$planted" "$graders/draft-no-planted.md" || { echo "draft-no-planted に無い: $planted" >&2; return 1; }
  done
  # 下書きのファイル名も、運ぶ手順で Global へ写る。名前と所有者の語を、ファイル名の採点器も持つ。
  for planted in 'hakobune-ledger' 'kumo-works'; do
    grep -Fq "$planted" "$graders/draft-name-no-planted.md" || { echo "draft-name-no-planted に無い: $planted" >&2; return 1; }
  done
  # 報告と最終の応答は、リポジトリの名前と所有者を書いてよい。内部のホスト名とトークンだけを見る。
  for planted in 'ledger-stg' 'hkb-9f8e7d6c5b4a39281706'; do
    for grader in agent-input-no-source-body report-no-secret report-no-planted; do
      grep -Fq "$planted" "$graders/$grader.md" || { echo "$grader に無い: $planted" >&2; return 1; }
    done
  done
  for planted in 'hakobune-ledger' 'kumo-works'; do
    for grader in report-no-secret report-no-planted; do
      ! grep -Fq "$planted" "$graders/$grader.md" || { echo "$grader が、書いてよい語を見る: $planted" >&2; return 1; }
    done
  done
  for planted in 'hakobune-ledger' 'kumo-works'; do
    for grader in crosschecker-got-words word-grep-ran; do
      grep -Fq "$planted" "$graders/$grader.md" || { echo "$grader に無い: $planted" >&2; return 1; }
    done
  done
  # 逆向き: 採点器が持つ、仕込みの形の文字列は、全て題材に在る（採点器の側の書き損じを拾う）。
  local found=0
  while IFS= read -r planted; do
    found=$((found + 1))
    grep -Fq "$planted" "$source" || { echo "題材に無い文字列を、採点器が持つ: $planted" >&2; return 1; }
  done < <(grep -ohE 'hakobune-[a-z0-9-]+|kumo-[a-z0-9-]+|ledger-[a-z0-9-]+|hkb-[0-9a-z]+' "$graders"/*.md | sort -u)
  [ "$found" -eq 4 ]
}

@test "eval の題材: 置き換えの根は通り、旧い記録と無関係の記録を持つ" {
  local CASE_DIR="$BATS_TEST_TMPDIR/behavior-replace-record"
  scaffold_case behavior-replace-record
  assert_scaffold_root "$CASE_DIR/docs/memory" 2 \
    MEM-202611010000-01-failed-job-retried-three-times.md MEM-202611010000-02-job-log-kept-thirty-days.md
}

@test "eval の題材: 運ぶ題材の2つの根は通り、carry は -01 を運び済み、-02 を写すとし、-03 を見ない" {
  local CASE_DIR="$BATS_TEST_TMPDIR/behavior-carry-drafts" graders
  scaffold_case behavior-carry-drafts
  assert_scaffold_root "$CASE_DIR/docs/memory" 0
  assert_scaffold_root "$CASE_DIR/global-memory" 2 MEM-202610150000-01-tls-min-version-handshake.md
  # 題材を作る push は、採点器が読む記録に残さない。
  [ ! -e "$CASE_DIR/.remotes/global.git/push.log" ]
  # 題材は、どちらの根でも FETCH_HEAD を持たない。取り直さずに carry を実行すると、終了コード 2 で止まる。
  [ ! -e "$CASE_DIR/.git/FETCH_HEAD" ]
  run --separate-stderr node "$SUT" carry "$CASE_DIR/docs/memory" "$CASE_DIR/global-memory" --project-ref FETCH_HEAD --global-ref FETCH_HEAD
  [ "$status" -eq 2 ]
  # Global だけを取り直しても、Project を取り直さなければ止まる。
  git -C "$CASE_DIR/global-memory" fetch -q --deepen=1000 origin main
  run --separate-stderr node "$SUT" carry "$CASE_DIR/docs/memory" "$CASE_DIR/global-memory" --project-ref FETCH_HEAD --global-ref FETCH_HEAD
  [ "$status" -eq 2 ]
  # 運ぶ手順（carrying.md）と同じ取り直しの後に、carry が題材の狙いどおりに判定する。
  git -C "$CASE_DIR/docs/memory" fetch -q --deepen=1000 origin main
  git -C "$CASE_DIR/global-memory" fetch -q --deepen=1000 origin main
  run --separate-stderr node "$SUT" carry "$CASE_DIR/docs/memory" "$CASE_DIR/global-memory" --project-ref FETCH_HEAD --global-ref FETCH_HEAD
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "outbox/MEM-202611200900-01-bom-breaks-header-match.md:carried: "* ]]
  [ "${lines[1]}" = "outbox/MEM-202611200900-02-cron-evaluated-in-scheduler-zone.md:copied: candidates/MEM-202611200900-02-cron-evaluated-in-scheduler-zone.md へ写した" ]
  [ "${#lines[@]}" -eq 2 ]
  # 承認されていない -03 は、作業中のブランチの作業ツリーにだけ在る。
  [ -f "$CASE_DIR/docs/memory/outbox/MEM-202611200900-03-unpinned-linter-flaky.md" ]
  # 採点器は、題材と同じファイル名で -02 を見る。
  graders="$REPO_ROOT/evals/shared-memory/behavior-carry-drafts/graders"
  # 取り直しの採点器は、根ごとに分かれている。
  grep -Fq 'docs/memory' "$graders/fetched-project.md"
  grep -Fq 'global-memory' "$graders/fetched-global.md"
  [ ! -e "$graders/fetched-both.md" ]
  grep -Fq 'MEM-202611200900-02-cron-evaluated-in-scheduler-zone' "$graders/pushed-candidate.md"
  grep -Fq 'MEM-202611200900-02-cron-evaluated-in-scheduler-zone' "$graders/pushed-only-candidate.md"
}

@test "eval の題材: 選別の根は、索引の行を1つ欠く違反だけを出し、記録2件と候補4件を持つ" {
  local CASE_DIR="$BATS_TEST_TMPDIR/behavior-triage-candidates"
  scaffold_case behavior-triage-candidates
  local root="$CASE_DIR/global-memory"
  [ "$(find "$root/records" -name 'MEM-*.md' | wc -l)" -eq 2 ]
  [ "$(find "$root/candidates" -name 'MEM-*.md' | wc -l)" -eq 4 ]
  run node "$SUT" check "$root"
  [ "$status" -eq 1 ]
  [ "$(printf '%s\n' "$output" | grep -c .)" -eq 1 ]
  [[ "$output" == "index.md:index:"* ]]
  # 索引が欠くのは C3 の行だけである。検査器の出力には C3 が在る。
  [ "$(grep -c '^| \[MEM-202611150000-' "$root/index.md")" -eq 3 ]
  run grep -c 'MEM-202611150000-03' "$root/index.md"
  [ "$output" = 0 ]
  run node "$SUT" index "$root"
  [ "$(printf '%s\n' "$output" | grep -c '^| \[MEM-202611150000-')" -eq 4 ]
}

# ここから下は、送り出しの下書き（outbox/）と選別の前の候補（candidates/）の試験である。

# 形式に合う下書きか候補を1件書く。$1 は置き場（outbox か candidates）、$2 は識別子、$3 は名前、$4 以降は front-matter へ足す行。
draft() {
  local dir="$1" id="$2" name="$3"
  shift 3
  mkdir -p "$ROOT/$dir"
  {
    printf '%s\n' '---' "id: $id" 'type: knowledge' "title: $name の主張" 'author: ai' \
      'verification: unverified' 'confidence: medium' 'applies-when: いつでも' 'sources:' '  - 2026-11-20 に手元で実測した'
    printf '%s\n' 'created: 2026-11-20' 'updated: 2026-11-20'
    [ "$#" -eq 0 ] || printf '%s\n' "$@"
    printf '%s\n' '---' '' '本文。'
  } >"$ROOT/$dir/$id-$name.md"
}

D1=MEM-202611200000-01
D2=MEM-202611200000-02

@test "下書きと候補: 形式に合う下書きと候補は通り、下書きは索引に載らず、候補は記録の後ろの候補の表に載る" {
  record "$B" second
  draft outbox "$D1" outgoing
  draft candidates "$D2" arrived
  draft candidates "$A" earlier
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run node "$SUT" index "$ROOT"
  [[ "$output" != *"outbox/"* ]]
  [[ "$output" != *"$D1"* ]]
  # 記録の表の後ろに、見出しと、記録の表と同じ列の候補の表が続く。候補も識別子の順に並ぶ。
  local expected
  expected=$(printf '%s\n' \
    "| [$B](records/$B-second.md) | knowledge | second の主張 | いつでも | verified |" \
    '' '## 候補' '' \
    '| 識別子 | 種類 | 主張 | 当てはまる条件 | 検証 |' \
    '|---|---|---|---|---|' \
    "| [$A](candidates/$A-earlier.md) | knowledge | earlier の主張 | いつでも | unverified |" \
    "| [$D2](candidates/$D2-arrived.md) | knowledge | arrived の主張 | いつでも | unverified |")
  [ "$(tail -n 8 "$ROOT/index.md")" = "$expected" ]
}

@test "下書きと候補: 候補が無い根の索引は、候補の表を持たず、記録だけの索引とバイトで同じである" {
  record "$A" first
  write_index
  cp "$ROOT/index.md" "$BATS_TEST_TMPDIR/before.md"
  draft outbox "$D1" outgoing
  mkdir -p "$ROOT/candidates"
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  write_index
  cmp "$ROOT/index.md" "$BATS_TEST_TMPDIR/before.md"
  [[ "$(cat "$ROOT/index.md")" != *"## 候補"* ]]
}

@test "下書きと候補: 候補だけが在り索引が無い根は index で落ちる" {
  draft candidates "$D1" arrived
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [ "$output" = "index.md:index: 索引が無い。index --write で作る" ]
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
}

@test "下書きと候補: 下書きだけが在る根は、索引が無くても通る" {
  draft outbox "$D1" outgoing
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "下書きと候補: Project の出典は draft で落ち、Global の記録の識別子だけの出典は通る" {
  local dir
  for dir in outbox candidates; do
    rm -rf "$ROOT/outbox" "$ROOT/candidates" "$ROOT/index.md"
    draft "$dir" "$D1" first
    draft "$dir" "$D2" second
    sed -i "s|^  - 2026-11-20 に手元で実測した\$|&\n  - Project $A@1a2b3c4|" "$ROOT/$dir/$D1-first.md"
    sed -i "s|^  - 2026-11-20 に手元で実測した\$|&\n  - $A|" "$ROOT/$dir/$D2-second.md"
    write_index
    run node "$SUT" check "$ROOT"
    [ "$status" -eq 1 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "$output" == "$dir/$D1-first.md:draft: 下書きと候補は Project の出典を持たない。"* ]]
  done
}

@test "下書きと候補: 小文字の project の出典も draft で落ちる" {
  local dir
  for dir in outbox candidates; do
    rm -rf "$ROOT/outbox" "$ROOT/candidates" "$ROOT/index.md"
    draft "$dir" "$D1" first
    sed -i "s|^  - 2026-11-20 に手元で実測した\$|&\n  - project $A@1a2b3c4|" "$ROOT/$dir/$D1-first.md"
    write_index
    run node "$SUT" check "$ROOT"
    [ "$status" -eq 1 ]
    [[ "$output" == "$dir/$D1-first.md:draft: 下書きと候補は Project の出典を持たない。"* ]]
  done
}

@test "下書きと候補: CRLF は draft で落ち、records の CRLF は通る" {
  local dir
  for dir in outbox candidates; do
    rm -rf "$ROOT/outbox" "$ROOT/candidates" "$ROOT/index.md"
    draft "$dir" "$D1" first
    sed -i 's/$/\r/' "$ROOT/$dir/$D1-first.md"
    write_index
    run node "$SUT" check "$ROOT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$dir/$D1-first.md:draft: 下書きと候補の改行は LF だけにする"* ]]
  done
}

@test "下書きと候補: 置き換えの項目と evolution は、どれも draft で落ち、evolution の規則では出さない" {
  local dir
  for dir in outbox candidates; do
    rm -rf "$ROOT/outbox" "$ROOT/candidates" "$ROOT/index.md"
    draft "$dir" "$D1" superseded "superseded-by: $D2"
    draft "$dir" "$D2" moved 'moved-to: 指示ファイル'
    draft "$dir" "$E" evolved 'from:' "  - $A" 'to:' "  - $B"
    sed -i 's/^type: knowledge/type: evolution/' "$ROOT/$dir/$E-evolved.md"
    write_index
    run node "$SUT" check "$ROOT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$dir/$D1-superseded.md:draft: 下書きと候補は superseded-by を持たない"* ]]
    [[ "$output" == *"$dir/$D2-moved.md:draft: 下書きと候補は moved-to を持たない"* ]]
    [[ "$output" == *"$dir/$E-evolved.md:draft: 下書きと候補は from を持たない"* ]]
    [[ "$output" == *"$dir/$E-evolved.md:draft: 下書きと候補は to を持たない"* ]]
    [[ "$output" == *"$dir/$E-evolved.md:draft: 下書きと候補は evolution にしない"* ]]
    [[ "$output" != *":evolution:"* ]]
    [[ "$output" != *":dangling:"* ]]
    [ "${#lines[@]}" -eq 5 ]
  done
}

@test "下書きと候補: from だけ・type: evolution だけの下書きも draft で落ちる" {
  draft outbox "$D1" from-only 'from:' "  - $A"
  draft outbox "$D2" evolution-only
  sed -i 's/^type: knowledge/type: evolution/' "$ROOT/outbox/$D2-evolution-only.md"
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [ "$output" = "$(printf '%s\n' "outbox/$D1-from-only.md:draft: 下書きと候補は from を持たない" "outbox/$D2-evolution-only.md:draft: 下書きと候補は evolution にしない")" ]
}

@test "下書きと候補: records の記録は、Project の出典と置き換えの項目を持っても draft にしない" {
  record "$A" first "superseded-by: $B"
  record "$B" second
  record "$E" evolution 'from:' "  - $A" 'to:' "  - $B"
  edit "$E-evolution.md" 's/^type: knowledge/type: evolution/'
  edit "$B-second.md" "s|^  - 出典|  - Project $D1@1a2b3c4|"
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "sent-as: 識別子を並べた sent-as は通り、0件・識別子でない値は value、1行の値は front-matter で落ちる" {
  record "$A" first 'sent-as:' "  - $D1" "  - $D2"
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  edit "$A-first.md" "/^  - $D2/d; s/^  - $D1/  - outbox の下書き/"
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [ "$output" = "records/$A-first.md:value: sent-as は MEM-<12桁>-<2桁> の形の識別子を並べる: outbox の下書き" ]
  edit "$A-first.md" '/^  - outbox の下書き/d'
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [ "$output" = "records/$A-first.md:value: sent-as は下書きの識別子を1件以上書く" ]
  edit "$A-first.md" "s/^sent-as:\$/sent-as: $D1/"
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"records/$A-first.md:front-matter: sent-as は「- 値」の行で書く"* ]]
}

@test "sent-as: 指す下書きが outbox に無くても違反にしない" {
  record "$A" first 'sent-as:' "  - $D1"
  write_index
  [ ! -e "$ROOT/outbox" ]
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
}

@test "duplicate-id: records・outbox・candidates をまたぐ同じ識別子は duplicate-id で落ち、識別子が違えば通る" {
  record "$A" first
  draft outbox "$D1" outgoing
  draft candidates "$D2" arrived
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  draft outbox "$A" copied-id
  draft candidates "$D1" same-as-draft
  draft candidates "$A" same-as-record
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"outbox/$A-copied-id.md:duplicate-id: $A は records/$A-first.md と重複している"* ]]
  [[ "$output" == *"candidates/$D1-same-as-draft.md:duplicate-id: $D1 は outbox/$D1-outgoing.md と重複している"* ]]
  [[ "$output" == *"candidates/$A-same-as-record.md:duplicate-id: $A は records/$A-first.md と重複している"* ]]
  [ "${#lines[@]}" -eq 3 ]
}

@test "下書きと候補: 記録の形式の規則（required・value・filename・front-matter）も掛かる" {
  draft outbox "$D1" missing
  sed -i '/^applies-when:/d' "$ROOT/outbox/$D1-missing.md"
  draft candidates "$D2" Bad_Name
  draft candidates "$E" wrong-type
  sed -i 's/^type: knowledge/type: memo/' "$ROOT/candidates/$E-wrong-type.md"
  mkdir -p "$ROOT/outbox"
  printf '%s\n' '本文だけ。' >"$ROOT/outbox/$A-no-front-matter.md"
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"outbox/$D1-missing.md:required: applies-when が無い"* ]]
  [[ "$output" == *"candidates/$D2-Bad_Name.md:filename: ファイル名は"* ]]
  [[ "$output" == *"candidates/$E-wrong-type.md:value: type は"* ]]
  [[ "$output" == *"outbox/$A-no-front-matter.md:front-matter: 1行目が --- でない"* ]]
}

@test "下書きと候補: 記録の superseded-by が候補を指すと dangling で落ちる（関係は記録の間だけで見る）" {
  record "$A" first "superseded-by: $D1"
  record "$E" evolution 'from:' "  - $A" 'to:' "  - $D1"
  edit "$E-evolution.md" 's/^type: knowledge/type: evolution/'
  draft candidates "$D1" arrived
  write_index
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"records/$A-first.md:dangling: superseded-by が指す記録が無い: $D1"* ]]
  [[ "$output" == *"records/$E-evolution.md:dangling: to が指す記録が無い: $D1"* ]]
}

@test "下書きと候補: outbox の下の階層（送り出しの報告）と candidates の下の階層は読まない" {
  draft outbox "$D1" outgoing
  mkdir -p "$ROOT/outbox/reports" "$ROOT/candidates/old"
  printf '%s\n' '報告。front-matter は無い。' >"$ROOT/outbox/reports/$D1.md"
  printf '%s\n' '本文だけ。' >"$ROOT/candidates/old/note.md"
  run node "$SUT" check "$ROOT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "下書きと候補: outbox か candidates がディレクトリでないと、検査できない入力として exit 2 で終わる" {
  local name
  for name in outbox candidates; do
    rm -rf "$ROOT/outbox" "$ROOT/candidates"
    : >"$ROOT/$name"
    run --separate-stderr node "$SUT" check "$ROOT"
    [ "$status" -eq 2 ]
    [ -z "$output" ]
    [[ "$stderr" == *"$name がディレクトリでない"* ]]
    run --separate-stderr node "$SUT" index "$ROOT"
    [ "$status" -eq 2 ]
  done
}

@test "送り出しの報告: 評価の採点器が見る5つの節の見出しは、outbox-report.md が定める見出しと一致する" {
  local grader="$REPO_ROOT/evals/shared-memory/behavior-promote-confidential/graders/report-sections.md"
  local source="$REPO_ROOT/plugins/shared-memory/references/outbox-report.md"
  local heading count=0
  while IFS= read -r heading; do
    count=$((count + 1))
    grep -qxF "## $heading" "$source" || { echo "見出しが無い: $heading"; return 1; }
  done < <(grep -o '## [^)]*' "$grader" | grep -v '^## *$' | sed 's/^## //' | awk '!seen[$0]++')
  [ "$count" -eq 5 ]
}
