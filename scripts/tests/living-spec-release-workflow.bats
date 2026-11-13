#!/usr/bin/env bats
# living-spec の Release のワークフロー（.github/workflows/living-spec-release.yml）の構造の
# 不変条件を固定する。固定するのは次の9つだけである。
#
#   契機        起動は workflow_dispatch だけ
#   入力        workflow_dispatch は入力を取らず、どの行も inputs を参照しない
#   SHA の出所  SHA を担う値（run-name・concurrency の group・env の SHA / TAG / ASSET・step の
#               with: の ref）の式は ${{ github.sha }} だけで、各値が ${{ github.sha }} を含む。
#               run-name は `living-spec release ${{ github.sha }}` に一致し、build の SHA・ASSET、
#               smoke の ASSET、release の SHA・TAG・ASSET は欠けない
#   定義の出所  build job の最初の step が、GITHUB_REF を refs/heads/main と照合して止める
#   権限        書き込み権限は release job だけ（最上位に書き込みが無く、全 job が自分の
#               permissions: を持ち、書き込みを含む job の集合が {release} に一致する）
#   待ち合わせ  release job は build と smoke を待つ
#   job の条件  どの job にも job のキーとしての if:・continue-on-error: が無い
#   step の条件 どの step にも step のキーとしての if:・continue-on-error: が無い
#   生成物の試験 build の「入口と描画の試験を生成物に掛ける」step の run: が、RDRA_ENTRY を読む
#               tools/living-spec/test/*.test.ts を全て挙げる（check_entry_tests が見る）
#
# 文字列がファイルのどこかに在ることではなく、job とキーの結び付きを見る。write の語は
# release job の外へ移しても、注記に書いても、ファイルのどこかには在り続ける。if: の語は
# run: の中身や with: の子（if-no-files-found:）にも現れる。存在だけを見る読み方は、担保を
# 落とす変異を緑で通し、担保を保つ書き換えを赤にする。
#
# 読み方はワークフローの字下げの形（job 名は2桁、job のキーは4桁、step は6桁の `- `、step の
# キーは8桁）を前提にする。この形で読めないもの（最上位の on: が無い・on: の値がインラインに
# ある・build / smoke / release の job を読めない・それらの job で step を1件も読めない）は、
# 違反の名前 `読み取り` で赤へ倒す。字下げ8桁以下の行のアンカー・エイリアス、引用符で囲んだ
# キー、キーとコロンの間の空白、明示キー（`?` で始まる要素と `:` で始まる値の行）、フロー形式の
# マッピングの要素、`- ` の後に空白を続けた要素も、キーとの結び付きを辿れない表記として同じく
# 赤へ倒す。事実を読めないまま合格を返さないためである。
#
# 覆わないものは docs/development/living-spec-release.md の (7) が定める。
load 'helpers/common'

setup() {
  WORKFLOW="$REPO_ROOT/.github/workflows/living-spec-release.yml"
  MUTANT="$BATS_TEST_TMPDIR/living-spec-release.yml"
}

# ワークフローを読み、事実を1行ずつ出す。run-tests-runner.bats の workflow_step_facts と同じ
# 考え方だが、あちらは test.yml の step 専用なので共通化しない。出す事実は次の7種である。
#
#   trigger <名前>       on: のブロックの中の2桁のキーごと。値がインラインなら trigger ?inline
#   input-decl <行番号>  on: のブロックの中の4桁以上の行と、値をインラインに持つ2桁のキー
#   input-ref <行番号>   行末の注記を除いた行が inputs. か inputs[ を含む
#   slot <job か -> <名前> <値>  SHA を担う値。名前は run-name・concurrency.group・env.<キー>・with.ref
#   top-perm present=<0|1> write=<0|1>
#   job <id> perm= write= if= coe= steps= step-if= step-coe= ref-guard= needs=<並べ替えてカンマでつなぐ。無ければ ->
#   unreadable <行番号> <表記>  字下げ8桁以下の行で、キーと値の結び付きを辿れない表記
#
# 注記の行（最初の空白でない文字が #）はどの事実にも数えない。permissions:・needs: の値の行末の
# # 以降も除く。job のキーは4桁の行だけを見る。steps は、直前の4桁のキーが steps である6桁の
# `- ` の行の数である。step の条件は step を特定せず、jobs の下の8桁の行のキーと、6桁の `- ` の
# 行の `- ` の後のキーを完全一致で見る（10桁の行の if-no-files-found: 等は数えない）。
# ref-guard は、ref の照合の行（10桁）と exit 1 の行（12桁）の両方を run の中に持つ step のうち、
# 最初のものが job の何番目の step かである。無ければ 0 である。2行は字面の完全一致で見るため、
# 同じ効果の書き換え（引用符を外す・GITHUB_REF_NAME で照合する等）でも赤になる。照合の書き方を
# 変えるときは、ここの2行も合わせて直す。
# slot の env.<キー> は、job の env:（6桁の子）と step の env:（10桁の子）のキー SHA・TAG・ASSET を
# 見る。with.ref は step の with: の10桁の子の ref である。値は行末の注記と前後の引用符を除く。
# 式は `${{ github.sha }}` の字面の完全一致で見るため、同じ意味の書き換え（空白を変える・env を
# 経由して渡す等）でも赤になる。SHA の渡し方を変えるときは、slot の照合も合わせて直す。
release_workflow_facts() {
  awk '
    function strip_comment(s) { sub(/[ \t]+#.*$/, "", s); return s }
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function keyof(s) { sub(/^[ \t]*(- )?/, "", s); sub(/:.*$/, "", s); return s }
    function valof(s) { sub(/^[^:]*:/, "", s); return s }
    function has_write(s) { return strip_comment(s) ~ /(^|[^A-Za-z0-9_])write([^A-Za-z0-9_]|$)/ }
    function add_need(s) {
      s = trim(strip_comment(s))
      gsub(/^["\047]|["\047]$/, "", s)
      if (s != "") needs[job, ++nneeds[job]] = s
    }
    function read_needs_inline(v,   parts, k, i) {
      v = trim(strip_comment(v))
      if (v == "") return
      if (v ~ /^\[.*\]$/) {
        k = split(substr(v, 2, length(v) - 2), parts, ",")
        for (i = 1; i <= k; i++) add_need(parts[i])
      } else add_need(v)
    }
    function needs_of(j,   n, arr, i, k, t, out) {
      n = nneeds[j] + 0
      if (n == 0) return "-"
      for (i = 1; i <= n; i++) arr[i] = needs[j, i]
      for (i = 2; i <= n; i++) {
        t = arr[i]
        for (k = i - 1; k >= 1 && arr[k] > t; k--) arr[k + 1] = arr[k]
        arr[k + 1] = t
      }
      out = arr[1]
      for (i = 2; i <= n; i++) out = out "," arr[i]
      return out
    }
    function step_key(k) {
      if (k == "if") sif[job] = 1
      if (k == "continue-on-error") scoe[job] = 1
      k8 = k
    }
    function slot(j, name, l,   v) {
      v = trim(strip_comment(valof(l)))
      gsub(/^["\047]|["\047]$/, "", v)
      printf "slot %s %s %s\n", j, name, v
    }
    function sha_key(k) { return k == "SHA" || k == "TAG" || k == "ASSET" }
    # 字下げ8桁以下の行が、キーと値の結び付きを辿れない表記かを返す。10桁以上（run: | の
    # ブロックの中身、with:・env: の子）には掛けない。
    function unreadable_form(l,   s, v, item) {
      match(l, /^ */)
      if (RLENGTH > 8) return ""
      s = substr(l, RLENGTH + 1)
      if (s ~ /^-[ \t][ \t]/) return "`- ` の後に空白が続く要素"
      item = 0
      if (s ~ /^-[ \t]/) { s = substr(s, 3); item = 1 }
      if (s ~ /^[*]/) return "エイリアス（*）"
      if (s ~ /^&/) return "アンカー（&）"
      if (item && s ~ /^[{]/) return "フロー形式のマッピングの要素"
      if (s ~ /^("[^"]*"|\047[^\047]*\047)[ \t]*:/) return "引用符で囲んだキー"
      if (s ~ /^[A-Za-z0-9_-]+[ \t]+:([ \t]|$)/) return "キーとコロンの間の空白"
      if (s ~ /^[?]([ \t]|$)/) return "明示キー（?）"
      if (s ~ /^:([ \t]|$)/) return "明示キーの値（:）"
      if (s ~ /^[^:]*:([ \t]|$)/) {
        v = trim(strip_comment(valof(s)))
        if (v ~ /^[*]/) return "エイリアス（*）"
        if (v ~ /^&/) return "アンカー（&）"
      }
      return ""
    }

    /^[ \t]*#/ { next }
    /^[ \t]*$/ { next }
    { u = unreadable_form($0); if (u != "") printf "unreadable %d %s\n", NR, u }
    strip_comment($0) ~ /(^|[^A-Za-z0-9_])inputs[.[]/ { printf "input-ref %d\n", NR }

    /^[^ \t]/ {
      top = keyof($0); job = ""; k4 = ""
      if (top == "on" && trim(strip_comment(valof($0))) != "") print "trigger ?inline"
      if (top == "permissions") { tp_present = 1; if (has_write(valof($0))) tp_write = 1 }
      if (top == "run-name") slot("-", "run-name", $0)
      next
    }
    top == "on" && /^  [^ \t]/ {
      print "trigger " keyof($0)
      if (trim(strip_comment(valof($0))) != "") printf "input-decl %d\n", NR
      next
    }
    top == "on" && /^    / { printf "input-decl %d\n", NR; next }
    top == "concurrency" && /^  group:/ { slot("-", "concurrency.group", $0); next }
    top == "permissions" { if (has_write($0)) tp_write = 1; next }
    top != "jobs" { next }

    /^  [^ \t]/ {
      job = keyof($0); k4 = ""
      if (!(job in seen)) { seen[job] = 1; order[++njobs] = job }
      next
    }
    job == "" { next }

    /^    [A-Za-z0-9_-]+:/ {
      k4 = keyof($0); v = valof($0)
      if (k4 == "if") jif[job] = 1
      if (k4 == "continue-on-error") jcoe[job] = 1
      if (k4 == "permissions") { jperm[job] = 1; if (has_write(v)) jwrite[job] = 1 }
      if (k4 == "needs") read_needs_inline(v)
      next
    }
    /^      [^ \t]/ {
      if (k4 == "env" && sha_key(keyof($0))) slot(job, "env." keyof($0), $0)
      if (k4 == "permissions") { if (has_write($0)) jwrite[job] = 1 }
      else if (k4 == "needs" && /^      - /) add_need(substr($0, 9))
      else if (k4 == "steps" && /^      - /) {
        jsteps[job]++
        k8 = ""
        if ($0 ~ /^      - [A-Za-z0-9_-]+:/) step_key(keyof($0))
      }
      next
    }
    /^        [A-Za-z0-9_-]+:/ { step_key(keyof($0)) }
    k4 == "steps" && /^          [A-Za-z0-9_-]+:/ {
      if (k8 == "env" && sha_key(keyof($0))) slot(job, "env." keyof($0), $0)
      if (k8 == "with" && keyof($0) == "ref") slot(job, "with.ref", $0)
    }
    k4 == "steps" && $0 == "          if [[ \"$GITHUB_REF\" != \"refs/heads/main\" ]]; then" { rg_if[job, jsteps[job]] = 1 }
    k4 == "steps" && $0 == "            exit 1" { rg_exit[job, jsteps[job]] = 1 }

    END {
      printf "top-perm present=%d write=%d\n", tp_present, tp_write
      for (i = 1; i <= njobs; i++) {
        j = order[i]
        guard = 0
        for (s = 1; s <= jsteps[j]; s++) if (rg_if[j, s] && rg_exit[j, s]) { guard = s; break }
        printf "job %s perm=%d write=%d if=%d coe=%d steps=%d step-if=%d step-coe=%d ref-guard=%d needs=%s\n", \
          j, jperm[j], jwrite[j], jif[j], jcoe[j], jsteps[j], sif[j], scoe[j], guard, needs_of(j)
      }
    }
  ' "$1"
}

# 事実から違反を1行ずつ `違反 <違反の名前>: <理由>` の形で出し、違反があれば非0で終わる。
# 違反の名前は 契機・入力・SHA の出所・定義の出所・権限・待ち合わせ・job の条件・step の条件・
# 読み取り の9つである。
# 事実の読み出しが失敗しても事実が0件になるだけで、読み取り の違反として赤へ倒れる。
check_release_workflow() {
  release_workflow_facts "$1" | awk '
    function violate(name, reason) { printf "違反 %s: %s\n", name, reason; nv++ }
    $1 == "trigger" {
      ntrig++
      if ($2 == "?inline") inline = 1
      else trig_list = trig_list (trig_list == "" ? "" : ",") $2
      next
    }
    $1 == "input-decl" { input_decl[++ndecl] = $2; next }
    $1 == "input-ref" { input_ref[++nref] = $2; next }
    $1 == "slot" {
      v = $0
      sub(/^slot [^ ]+ [^ ]+ ?/, "", v)
      slots[++nslot] = ($2 == "-" ? "" : "job " $2 " の ") $3
      slot_val[nslot] = v
      have_slot[$2, $3] = 1
      if ($3 == "run-name") run_name = v
      next
    }
    $1 == "unreadable" {
      form = $0
      sub(/^unreadable [0-9]+ /, "", form)
      unread[++nunread] = $2 " 行目が、読めない表記（" form "）で書かれている"
      next
    }
    $1 == "top-perm" {
      tp_seen = 1
      for (i = 2; i <= NF; i++) { split($i, kv, "="); tp[kv[1]] = kv[2] }
      next
    }
    $1 == "job" {
      id = $2; has_job[id] = 1; job_order[++njobs] = id
      for (i = 3; i <= NF; i++) { eq = index($i, "="); f[id, substr($i, 1, eq - 1)] = substr($i, eq + 1) }
      next
    }
    END {
      # 読み取り
      if (ntrig == 0) violate("読み取り", "最上位の on: のブロックから契機を1件も読めない")
      if (inline) violate("読み取り", "on: の値がインラインにあり、契機を読めない")
      for (i = 1; i <= nunread; i++) violate("読み取り", unread[i])
      split("build smoke release", required, " ")
      for (r = 1; r <= 3; r++) {
        j = required[r]
        if (!(j in has_job)) violate("読み取り", "job " j " を読めない")
        else if (f[j, "steps"] + 0 == 0) violate("読み取り", "job " j " の steps: の下に6桁の `- ` の step を1件も読めない")
      }

      # 契機
      if (!inline && ntrig > 0 && trig_list != "workflow_dispatch")
        violate("契機", "on: の直下のキーが {workflow_dispatch} でない（読めたキー: " trig_list "）")

      # 入力
      for (i = 1; i <= ndecl; i++) violate("入力", input_decl[i] " 行目で、on: の下に入力の宣言かインラインの値がある")
      for (i = 1; i <= nref; i++) violate("入力", input_ref[i] " 行目が inputs を参照する")

      # SHA の出所
      for (i = 1; i <= nslot; i++) {
        rest = slot_val[i]
        gsub(/\$\{\{ github\.sha \}\}/, "", rest)
        if (rest ~ /\$\{\{/) violate("SHA の出所", slots[i] " の値が ${{ github.sha }} の外の式を含む（値: " slot_val[i] "）")
        if (index(slot_val[i], "${{ github.sha }}") == 0) violate("SHA の出所", slots[i] " の値が ${{ github.sha }} を含まない（値: " slot_val[i] "）")
      }
      if (!(("-", "run-name") in have_slot)) violate("SHA の出所", "最上位の run-name: が無い")
      else if (run_name != "living-spec release ${{ github.sha }}") violate("SHA の出所", "run-name が `living-spec release ${{ github.sha }}` でない（値: " run_name "）")
      split("build:env.SHA build:env.ASSET smoke:env.ASSET release:env.SHA release:env.TAG release:env.ASSET", req, " ")
      for (r = 1; r <= 6; r++) {
        split(req[r], jk, ":")
        if ((jk[1] in has_job) && !((jk[1], jk[2]) in have_slot)) violate("SHA の出所", "job " jk[1] " の " jk[2] " が無い")
      }

      # 定義の出所
      if ("build" in has_job && f["build", "ref-guard"] + 0 != 1)
        violate("定義の出所", "build の最初の step の run が、照合の行 `if [[ \"$GITHUB_REF\" != \"refs/heads/main\" ]]; then`（10桁）と `exit 1` の行（12桁）を持たない（両方を持つ step の位置: " f["build", "ref-guard"] "。0 は無し）")

      # 権限
      if (tp["present"] + 0 == 0) violate("権限", "最上位の permissions: が無い")
      else if (tp["write"] + 0 == 1) violate("権限", "最上位の permissions: が書き込みを含む")
      writers = ""
      for (i = 1; i <= njobs; i++) {
        j = job_order[i]
        if (f[j, "perm"] + 0 == 0) violate("権限", "job " j " が自分の permissions: を持たない")
        if (f[j, "write"] + 0 == 1) writers = writers (writers == "" ? "" : ",") j
      }
      if (writers != "release")
        violate("権限", "書き込みを含む job の集合が {release} でない（読めた集合: " (writers == "" ? "なし" : writers) "）")

      # 待ち合わせ
      if ("release" in has_job) {
        n = split(f["release", "needs"], nd, ",")
        hb = 0; hs = 0
        for (i = 1; i <= n; i++) { if (nd[i] == "build") hb = 1; if (nd[i] == "smoke") hs = 1 }
        if (!hb || !hs) violate("待ち合わせ", "release の needs が build と smoke を含まない（読めた needs: " f["release", "needs"] "）")
      }

      # job の条件・step の条件
      for (i = 1; i <= njobs; i++) {
        j = job_order[i]
        if (f[j, "if"] + 0 == 1) violate("job の条件", "job " j " が job のキーとしての if: を持つ")
        if (f[j, "coe"] + 0 == 1) violate("job の条件", "job " j " が job のキーとしての continue-on-error: を持つ")
        if (f[j, "step-if"] + 0 == 1) violate("step の条件", "job " j " の step が step のキーとしての if: を持つ")
        if (f[j, "step-coe"] + 0 == 1) violate("step の条件", "job " j " の step が step のキーとしての continue-on-error: を持つ")
      }

      exit (nv > 0 ? 1 : 0)
    }
  '
}

# 生成物の試験: 入口（RDRA_ENTRY）を読む試験は、手元のビルドだけでなく添付する生成物にも
# 掛ける。中継の印のように、ビルドした1ファイルの形で成り立つかが決まる振る舞いがあるため。
# 要る集合は tools/living-spec/test/*.test.ts のうち RDRA_ENTRY を含むもので、step の run: の
# 行が各パスを空白区切りの1語として挙げるかを見る。集合が空・step や run: を読めないときは
# 合格を返さない。
check_entry_tests() {
  local workflow="$1" run_line f rel nv=0
  local -a required=()
  for f in "$REPO_ROOT"/tools/living-spec/test/*.test.ts; do
    grep -q 'RDRA_ENTRY' "$f" && required+=("tools/living-spec/test/${f##*/}")
  done
  if [ "${#required[@]}" -eq 0 ]; then
    echo "違反 読み取り: RDRA_ENTRY を読む試験が1件も見つからない"
    return 1
  fi
  run_line="$(awk '
    /^      - name: 入口と描画の試験を生成物に掛ける$/ { inside = 1; next }
    inside && /^      - / { exit }
    inside && /^        run: / { sub(/^        run: /, ""); print; exit }
  ' "$workflow")"
  if [ -z "$run_line" ]; then
    echo "違反 読み取り: 入口と描画の試験の step の1行の run: を読めない"
    return 1
  fi
  for rel in "${required[@]}"; do
    if [[ " $run_line " != *" $rel "* ]]; then
      echo "違反 生成物の試験: $rel を生成物に掛けていない"
      nv=$((nv + 1))
    fi
  done
  [ "$nv" -eq 0 ]
}

# 実物を写して変異を当てる。変異の awk には、最上位のキー（top）と job 名（job）を読む規則を
# 前置きする。写しが元と同じなら、変異が当たらないまま緑になるので、ここで止める。
mutate() {
  awk '
    /^[^ \t#]/ { top = $0; sub(/:.*$/, "", top); job = "" }
    top == "jobs" && /^  [A-Za-z0-9_-]+:/ { job = $0; sub(/^ +/, "", job); sub(/:.*$/, "", job) }
  '"$1" "$WORKFLOW" >"$MUTANT"
  if cmp -s "$WORKFLOW" "$MUTANT"; then
    echo "変異が当たっていない: 写しが元と同じ" >&2
    return 1
  fi
}

# 検出側: 非0で終わり、当該の違反の名前を出すこと。
expect_detected() {
  run check_release_workflow "$MUTANT"
  echo "status=$status"
  echo "$output"
  if [ "$status" -eq 0 ]; then
    echo "変異を検出せず終了コード 0 で終わった" >&2
    return 1
  fi
  if [[ "$output" != *"違反 $1:"* ]]; then
    echo "違反 $1 を出していない" >&2
    return 1
  fi
  # 第2引数があれば、その違反の理由に当該の語が含まれることも確かめる。読み取り は経路が多く、
  # 別の経路で赤になっただけでは、当該の経路の規則を消しても緑のまま気付けない。
  if [ -n "${2-}" ] && ! grep -F "違反 $1:" <<<"$output" | grep -qF -- "$2"; then
    echo "違反 $1 の理由に「$2」が含まれない" >&2
    return 1
  fi
}

# 除外側: 終了コード 0 で終わること。
expect_excluded() {
  run check_release_workflow "$MUTANT"
  echo "status=$status"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "実物のワークフローは9つの不変条件を満たし、何も出さない" {
  run check_release_workflow "$WORKFLOW"
  echo "$output"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run check_entry_tests "$WORKFLOW"
  echo "$output"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- 契機 ---

@test "契機 検出: on: の下に push: を足す" {
  mutate '{ print } /^on:$/ { print "  push:" }'
  expect_detected 契機
}

@test "契機 検出: workflow_dispatch: を pull_request: に置き換える（契機の数を保つ）" {
  mutate '/^  workflow_dispatch:$/ { print "  pull_request:"; next } { print }'
  expect_detected 契機
}

@test "契機 除外: on: の直下の注記の行は契機に数えない" {
  mutate '{ print } /^on:$/ { print "  # push は契機にしない" }'
  expect_excluded
}

# --- 入力 ---

@test "入力 検出: workflow_dispatch: の下に入力 sha の宣言を戻す" {
  mutate '
    { print }
    /^  workflow_dispatch:$/ {
      print "    inputs:"
      print "      sha:"
      print "        required: true"
      print "        type: string"
    }
  '
  expect_detected 入力 "入力の宣言"
}

@test "入力 検出: workflow_dispatch: の値をインラインの入力の宣言にする（行の数を保つ）" {
  mutate '/^  workflow_dispatch:$/ { print "  workflow_dispatch: {inputs: {sha: {required: true}}}"; next } { print }'
  expect_detected 入力 "インラインの値"
}

@test "入力 検出: run: の中で inputs を参照する（SHA を担う値を変えない）" {
  mutate '{ print } job == "build" && /^          mkdir -p / { print "          echo \"${{ inputs.sha }}\"" }'
  expect_detected 入力 "inputs を参照する"
}

@test "入力 検出: release の env の SHA を github.event.inputs.sha にする" {
  mutate 'job == "release" && /^      SHA: / { print "      SHA: ${{ github.event.inputs.sha }}"; next } { print }'
  expect_detected 入力 "inputs を参照する"
}

@test "入力 除外: 注記の行と行末の注記の inputs は数えない" {
  mutate '
    job == "build" && /^      SHA: / { sub(/$/, "  # inputs.sha ではない") }
    { print }
    /^  workflow_dispatch:$/ { print "    # inputs は取らない。inputs.sha は廃止した" }
  '
  expect_excluded
}

# --- SHA の出所 ---

@test "SHA の出所 検出: run-name の式を github.ref にする" {
  mutate '/^run-name: / { print "run-name: living-spec release ${{ github.ref }}"; next } { print }'
  expect_detected "SHA の出所" "run-name"
}

@test "SHA の出所 検出: run-name の題名の形を変える（github.sha は保つ）" {
  mutate '/^run-name: / { print "run-name: release ${{ github.sha }}"; next } { print }'
  expect_detected "SHA の出所" "run-name が"
}

@test "SHA の出所 検出: run-name: を消す" {
  mutate '/^run-name: / { next } { print }'
  expect_detected "SHA の出所" "run-name: が無い"
}

@test "SHA の出所 検出: concurrency の group の式を github.run_id にする" {
  mutate '/^  group: / { print "  group: living-spec-release-${{ github.run_id }}"; next } { print }'
  expect_detected "SHA の出所" "concurrency.group"
}

@test "SHA の出所 検出: release の env の TAG の式を github.event.after にする（行の数を保つ）" {
  mutate 'job == "release" && /^      TAG: / { print "      TAG: living-spec-${{ github.event.after }}"; next } { print }'
  expect_detected "SHA の出所" "job release の env.TAG"
}

@test "SHA の出所 検出: smoke の env の ASSET を式の無い固定の SHA にする" {
  mutate 'job == "smoke" && /^      ASSET: / { print "      ASSET: living-spec-259e6b6fa83a6a7cd5e8f3a7b9f2d0e1c4b5a6d7.mjs"; next } { print }'
  expect_detected "SHA の出所" "を含まない"
}

@test "SHA の出所 検出: build の env の ASSET に github.sha と並べて別の式を足す" {
  mutate 'job == "build" && /^      ASSET: / { print "      ASSET: living-spec-${{ github.sha }}-${{ github.run_id }}.mjs"; next } { print }'
  expect_detected "SHA の出所" "外の式"
}

@test "SHA の出所 検出: build の取り出しの ref を github.ref にする" {
  mutate 'job == "build" && /^          ref: / { print "          ref: ${{ github.ref }}"; next } { print }'
  expect_detected "SHA の出所" "with.ref"
}

@test "SHA の出所 検出: build の取り出しの ref を式の無い main にする" {
  mutate 'job == "build" && /^          ref: / { print "          ref: main"; next } { print }'
  expect_detected "SHA の出所" "with.ref"
}

@test "SHA の出所 検出: build の step の env に SHA を github.event.after で足す" {
  mutate '
    { print }
    job == "build" && /^      - name: 同じ SHA の Release が無いことを確かめる$/ { want = 1 }
    want && /^        env:$/ { print "          SHA: ${{ github.event.after }}"; want = 0 }
  '
  expect_detected "SHA の出所" "job build の env.SHA"
}

@test "SHA の出所 検出: release の env の SHA を消す" {
  mutate 'job == "release" && /^      SHA: / { next } { print }'
  expect_detected "SHA の出所" "job release の env.SHA が無い"
}

@test "SHA の出所 除外: build の取り出しの ref: を消す（既定が github.sha である）" {
  mutate 'job == "build" && /^          ref: / { next } { print }'
  expect_excluded
}

@test "SHA の出所 除外: run-name の値を引用符で囲み、行末に注記を添える" {
  mutate '/^run-name: / { print "run-name: \"living-spec release ${{ github.sha }}\"  # 起動した main の先頭"; next } { print }'
  expect_excluded
}

# --- 定義の出所 ---

@test "定義の出所 検出: build の ref の照合の step を消す" {
  mutate '
    job == "build" && /^      - name: 起動した定義が main のものであることを確かめる$/ { skip = 1; next }
    skip && (/^      - / || /^      # /) { skip = 0 }
    skip { next }
    { print }
  '
  expect_detected 定義の出所
}

@test "定義の出所 検出: 照合する ref を refs/heads/develop に替える（step の数と行の数を保つ）" {
  mutate 'job == "build" && /refs\/heads\/main/ { sub(/refs\/heads\/main/, "refs/heads/develop") } { print }'
  expect_detected 定義の出所
}

@test "定義の出所 検出: ref の照合の step から exit 1 を true に替える（行の数を保つ）" {
  mutate '
    job == "build" && /^      - name: 起動した定義が main のものであることを確かめる$/ { in_guard = 1 }
    job == "build" && /^      - name: 起動したコミットを取り出す$/ { in_guard = 0 }
    in_guard && /^            exit 1$/ { print "            true"; next }
    { print }
  '
  expect_detected 定義の出所
}

@test "定義の出所 検出: ref の照合の step を取り出しの step の後へ動かす（step の数を保つ）" {
  mutate '
    job == "build" && /^      - name: 起動した定義が main のものであることを確かめる$/ { hold = 1 }
    hold && /^      - name: 起動したコミットを取り出す$/ { hold = 0; after = 1 }
    hold { buf[++nb] = $0; next }
    after && /^      # 同じ SHA の Release があれば/ { for (i = 1; i <= nb; i++) print buf[i]; after = 0 }
    { print }
  '
  expect_detected 定義の出所 "両方を持つ step の位置: 2"
}

@test "定義の出所 検出: ref の照合の step を build から release の先頭へ移す" {
  mutate '
    job == "build" && /^      - name: 起動した定義が main のものであることを確かめる$/ { hold = 1 }
    hold && /^      - name: 起動したコミットを取り出す$/ { hold = 0 }
    hold { buf[++nb] = $0; next }
    { print }
    job == "release" && /^    steps:$/ { for (i = 1; i <= nb; i++) print buf[i] }
  '
  expect_detected 定義の出所 "両方を持つ step の位置: 0"
}

@test "定義の出所 除外: ref の照合の step の失敗の文言を替える" {
  mutate 'job == "build" && /::error::このワークフローは main の定義でだけ起動する/ { print "            echo \"::error::main 以外の ref から起動した: $GITHUB_REF\" >&2"; next } { print }'
  expect_excluded
}

@test "定義の出所 除外: release の先頭にも同じ照合の step を足す" {
  mutate '
    job == "build" && /^      - name: 起動した定義が main のものであることを確かめる$/ { hold = 1 }
    hold && /^      - name: 起動したコミットを取り出す$/ { hold = 0 }
    hold { buf[++nb] = $0 }
    { print }
    job == "release" && /^    steps:$/ { for (i = 1; i <= nb; i++) print buf[i] }
  '
  expect_excluded
}

# --- 権限 ---

@test "権限 検出: release と build の contents の読み書きを入れ替える（書き込みの job の数を保つ）" {
  mutate '
    job == "build" && /^      contents: read$/ { print "      contents: write"; next }
    job == "release" && /^      contents: write$/ { print "      contents: read"; next }
    { print }
  '
  expect_detected 権限
}

@test "権限 検出: build の permissions: の子に id-token: write を足す" {
  mutate '{ print } job == "build" && /^      contents: read$/ { print "      id-token: write" }'
  expect_detected 権限
}

@test "権限 検出: smoke の permissions: のブロックを消す（継承の経路）" {
  mutate '
    job == "smoke" && /^    permissions:$/ { skip = 1; next }
    skip && /^      / { next }
    { skip = 0; print }
  '
  expect_detected 権限
}

@test "権限 検出: 最上位の permissions: の値を write-all にする" {
  mutate '
    /^permissions:$/ { print "permissions: write-all"; skip = 1; next }
    skip && /^  / { next }
    { skip = 0; print }
  '
  expect_detected 権限
}

@test "権限 除外: permissions: の子の間の注記の write は書き込みに数えない" {
  mutate '{ print } job == "build" && /^    permissions:$/ { print "      # write は release job だけに渡す" }'
  expect_excluded
}

# --- 待ち合わせ ---

@test "待ち合わせ 検出: release の needs から smoke を外す" {
  mutate 'job == "release" && /^      - smoke$/ { next } { print }'
  expect_detected 待ち合わせ
}

@test "待ち合わせ 検出: release の needs: を消す" {
  mutate '
    job == "release" && /^    needs:$/ { skip = 1; next }
    skip && /^      - / { next }
    { skip = 0; print }
  '
  expect_detected 待ち合わせ
}

@test "待ち合わせ 除外: release の needs をフロー形式の [smoke, build] に並べ替える" {
  mutate '
    job == "release" && /^    needs:$/ { print "    needs: [smoke, build]"; skip = 1; next }
    skip && /^      - / { next }
    { skip = 0; print }
  '
  expect_excluded
}

# 実物の needs は既にブロック形式なので、ブロック形式のまま要素を並べ替え、要素の行末に注記を
# 添える。並びの順と行末の注記に読みが左右されないことを確かめる。
@test "待ち合わせ 除外: release の needs をブロック形式のまま並べ替え、行末に注記を添える" {
  mutate '
    job == "release" && /^      - build$/ { next }
    { print }
    job == "release" && /^      - smoke$/ { print "      - build  # ビルドを待つ" }
  '
  expect_excluded
}

@test "待ち合わせ 除外: release の needs をフロー形式の [build, smoke] にし、行末に注記を添える" {
  mutate '
    job == "release" && /^    needs:$/ { print "    needs: [build, smoke]  # 試験を待つ"; skip = 1; next }
    skip && /^      - / { next }
    { skip = 0; print }
  '
  expect_excluded
}

# --- job の条件 ---

@test "job の条件 検出: release の job のキーに if: always() を足す" {
  mutate '{ print } job == "release" && /^    name: release$/ { print "    if: always()" }'
  expect_detected "job の条件"
}

@test "job の条件 検出: smoke の job のキーに continue-on-error: true を足す" {
  mutate '{ print } job == "smoke" && /^    runs-on:/ { print "    continue-on-error: true" }'
  expect_detected "job の条件"
}

@test "job の条件 除外: job のキーの間の注記の if: は数えない" {
  mutate '{ print } job == "smoke" && /^    runs-on:/ { print "    # if: と continue-on-error: は付けない" }'
  expect_excluded
}

# --- step の条件 ---

@test "step の条件 検出: build の入口・描画の試験の step に continue-on-error: true を足す" {
  mutate '{ print } job == "build" && /^      - name: 入口と描画の試験を生成物に掛ける$/ { print "        continue-on-error: true" }'
  expect_detected "step の条件"
}

@test "step の条件 検出: build の入口・描画の試験の step に if: false を足す" {
  mutate '{ print } job == "build" && /^      - name: 入口と描画の試験を生成物に掛ける$/ { print "        if: false" }'
  expect_detected "step の条件"
}

@test "step の条件 検出: smoke の起動確認の step の先頭のキーを if: false にする（step の数とキーの並びを保つ）" {
  mutate '
    job == "smoke" && /^      - name: 引数なしで起動して使い方を出すことを確かめる$/ {
      print "      - if: false"
      print "        name: 引数なしで起動して使い方を出すことを確かめる"
      next
    }
    { print }
  '
  expect_detected "step の条件"
}

# 行頭の if: でも、8桁でなければ step のキーでない。字下げを問わず if: を拾う読み方と、行の
# どこかの if: を拾う読み方の両方がここで赤になる。
@test "step の条件 除外: run: | のブロックの中の if: は step のキーに数えない" {
  mutate '
    job == "build" && /^        run: node --test / {
      cmd = $0
      sub(/^        run: /, "", cmd)
      print "        run: |"
      print "          if: false"
      print "          " cmd
      next
    }
    { print }
  '
  expect_excluded
}

@test "step の条件 除外: step のキーの間の注記の if: は数えない" {
  mutate '{ print } job == "build" && /^      - name: 入口と描画の試験を生成物に掛ける$/ { print "        # if: と continue-on-error: は step に付けない" }'
  expect_excluded
}

# --- 読み取り ---

@test "読み取り 検出: 全行の字下げを2桁ずらす" {
  mutate '{ print "  " $0 }'
  expect_detected 読み取り
}

# step を4桁の `- ` で書くと、step の条件を0件と読む。条件を足しても緑で通る形を、step を
# 1件も読めない job を赤にすることで止める。
@test "読み取り 検出: build の steps: の下を2桁浅くし、step に continue-on-error: true を足す" {
  mutate '
    job == "build" && /^    steps:$/ { print; in_steps = 1; next }
    in_steps && (/^  [^ ]/ || /^    [^ ]/) { in_steps = 0 }
    in_steps && /^      / {
      l = substr($0, 3)
      print l
      if (l ~ /^    - name: 入口と描画の試験を生成物に掛ける$/) print "      continue-on-error: true"
      next
    }
    { print }
  '
  expect_detected 読み取り
}

@test "読み取り 検出: 最上位の on: のブロックを消す" {
  mutate '
    /^on:$/ { skip = 1; next }
    skip && /^ / { next }
    { skip = 0; print }
  '
  expect_detected 読み取り "最上位の on:"
}

@test "読み取り 検出: on: を on: workflow_dispatch へ畳む" {
  mutate '
    /^on:$/ { print "on: workflow_dispatch"; skip = 1; next }
    skip && /^ / { next }
    { skip = 0; print }
  '
  expect_detected 読み取り "インライン"
}

# 以下は、字下げの形の上では読めても、キーと値の結び付きを awk で辿れない表記である。読み飛ばすと
# 6つの不変条件をすり抜けるため、読み取り で止める。
@test "読み取り 検出: build の permissions: の値をエイリアス（*）にする" {
  mutate '
    job == "build" && /^    permissions:$/ { print "    permissions: *rw"; skip = 1; next }
    skip && /^      / { next }
    { skip = 0; print }
  '
  expect_detected 読み取り "エイリアス"
}

@test "読み取り 検出: release の permissions: にアンカー（&）を付ける" {
  mutate '
    job == "release" && /^    permissions:$/ { print "    permissions: &rw"; next }
    { print }
  '
  expect_detected 読み取り "アンカー"
}

@test "読み取り 検出: build の入口・描画の試験の step のキーを引用符で囲んだ \"if\": false を足す" {
  mutate '{ print } job == "build" && /^      - name: 入口と描画の試験を生成物に掛ける$/ { print "        \"if\": false" }'
  expect_detected 読み取り "引用符"
}

@test "読み取り 検出: release の job のキーに引用符で囲んだ 'if': always() を足す" {
  mutate '{ print } job == "release" && /^    name: release$/ { print "    \047if\047: always()" }'
  expect_detected 読み取り "引用符"
}

@test "読み取り 検出: build の steps: にフロー形式のマッピングの step を足す" {
  mutate '{ print } job == "build" && /^    steps:$/ { print "      - { name: 何もしない, if: false, run: true }" }'
  expect_detected 読み取り "フロー形式"
}

# `-   name:` と書くと step のキーは10桁に並び、8桁の行だけを見る step の条件の読みを外れる。
@test "読み取り 検出: build の入口・描画の試験の step を -   name: で書き、10桁に if: false を足す" {
  mutate '
    job == "build" && /^      - name: 入口と描画の試験を生成物に掛ける$/ {
      print "      -   name: 入口と描画の試験を生成物に掛ける"
      print "          if: false"
      in_step = 1
      next
    }
    in_step && (/^      - / || /^  [^ ]/) { in_step = 0 }
    in_step && /^        / { print "  " $0; next }
    { print }
  '
  expect_detected 読み取り "空白が続く"
}

@test "読み取り 検出: build の steps: にエイリアス（*）の step を足す" {
  mutate '{ print } job == "build" && /^    steps:$/ { print "      - *skip_step" }'
  expect_detected 読み取り "エイリアス"
}

@test "読み取り 検出: smoke の起動確認の step にアンカー（&）を付ける（step の数とキーの並びを保つ）" {
  mutate '
    job == "smoke" && /^      - name: 引数なしで起動して使い方を出すことを確かめる$/ {
      print "      - &probe"
      print "        name: 引数なしで起動して使い方を出すことを確かめる"
      next
    }
    { print }
  '
  expect_detected 読み取り "アンカー"
}

# キーとコロンの間に空白を置くと、キーの名前が完全一致に落ちず、条件を0件と読む。
@test "読み取り 検出: build の入口・描画の試験の step に if : false（コロンの前の空白）を足す" {
  mutate '{ print } job == "build" && /^      - name: 入口と描画の試験を生成物に掛ける$/ { print "        if : false" }'
  expect_detected 読み取り "コロンの間"
}

@test "読み取り 検出: release の job のキーに if : always()（コロンの前の空白）を足す" {
  mutate '{ print } job == "release" && /^    name: release$/ { print "    if : always()" }'
  expect_detected 読み取り "コロンの間"
}

@test "読み取り 検出: smoke の job のキーに continue-on-error : true（コロンの前の空白）を足す" {
  mutate '{ print } job == "smoke" && /^    runs-on:/ { print "    continue-on-error : true" }'
  expect_detected 読み取り "コロンの間"
}

# 明示キー（? と :）は、キーと値が別の行に分かれ、キーの行を読んでも値と結び付かない。
@test "読み取り 検出: build の入口・描画の試験の step に明示キーの ? if と : false を足す" {
  mutate '{ print } job == "build" && /^      - name: 入口と描画の試験を生成物に掛ける$/ { print "        ? if"; print "        : false" }'
  expect_detected 読み取り "明示キー"
}

@test "読み取り 検出: build の入口・描画の試験の step に明示キーの ? if だけを足す" {
  mutate '{ print } job == "build" && /^      - name: 入口と描画の試験を生成物に掛ける$/ { print "        ? if" }'
  expect_detected 読み取り "明示キー（?）"
}

@test "読み取り 検出: smoke の起動確認の step を - ? if で始める（step の数を保つ）" {
  mutate '
    job == "smoke" && /^      - name: 引数なしで起動して使い方を出すことを確かめる$/ {
      print "      - ? if"
      print "        name: 引数なしで起動して使い方を出すことを確かめる"
      next
    }
    { print }
  '
  expect_detected 読み取り "明示キー（?）"
}

@test "読み取り 検出: build の入口・描画の試験の step に : で始まる行を足す" {
  mutate '{ print } job == "build" && /^      - name: 入口と描画の試験を生成物に掛ける$/ { print "        : false" }'
  expect_detected 読み取り "明示キーの値（:）"
}

# --- 生成物の試験 ---

@test "生成物の試験 検出: run: から relay.test.ts を外す" {
  mutate 'job == "build" && /^        run: node --test / { sub(/ tools\/living-spec\/test\/relay\.test\.ts/, "") } { print }'
  run check_entry_tests "$MUTANT"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"違反 生成物の試験: tools/living-spec/test/relay.test.ts を生成物に掛けていない"* ]]
}

@test "生成物の試験 検出: relay.test.ts を別の名前の接頭辞にする（部分一致で通さない）" {
  mutate 'job == "build" && /^        run: node --test / { sub(/relay\.test\.ts/, "relay.test.ts.bak") } { print }'
  run check_entry_tests "$MUTANT"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"relay.test.ts を生成物に掛けていない"* ]]
}

@test "生成物の試験 除外: run: の試験の並びを入れ替える" {
  mutate 'job == "build" && /^        run: node --test / { $0 = "        run: node --test tools/living-spec/test/relay.test.ts tools/living-spec/test/difflist.test.ts tools/living-spec/test/render.test.ts tools/living-spec/test/cli.test.ts" } { print }'
  run check_entry_tests "$MUTANT"
  echo "$output"
  [ "$status" -eq 0 ]
}
