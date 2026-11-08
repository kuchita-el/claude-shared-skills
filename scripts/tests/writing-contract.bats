#!/usr/bin/env bats

@test "write-docのskillとwriterが配置される" {
  [ -f "$BATS_TEST_DIRNAME/../../plugins/writing/skills/write-doc/SKILL.md" ]
  [ -f "$BATS_TEST_DIRNAME/../../plugins/writing/agents/doc-writer.md" ]
}

@test "write-docのfrontmatterとexact allowed-toolsが契約に一致する" {
  skill="$BATS_TEST_DIRNAME/../../plugins/writing/skills/write-doc/SKILL.md"
  run sed -n '1,/^---$/p' "$skill"
  [[ "$output" == *"name: write-doc"* ]]
  [[ "$output" == *"文書を起草・検査・独立レビューする"* ]]
  [[ "$output" == *"文書作成または改稿時"* ]]
  for tool in Read Write Edit 'Bash(bash *scripts/lint-ja.sh*)' Agent; do
    [[ "$output" == *"$tool"* ]]
  done
}

@test "素材なし停止とprofile優先順が明記される" {
  skill="$BATS_TEST_DIRNAME/../../plugins/writing/skills/write-doc/SKILL.md"
  run cat "$skill"
  [[ "$output" == *"materials=[]"* ]]
  [[ "$output" == *"status=blocked"* ]]
  [[ "$output" == *"writes=[]"* ]]
  [[ "$output" == *'${CLAUDE_PROJECT_DIR}/.claude/writing/type-profiles.md'* ]]
  [[ "$output" == *"references/document-type-profiles.md"* ]]
}

@test "writerにmodelとeffort frontmatterがある" {
  run sed -n '1,/^---$/p' "$BATS_TEST_DIRNAME/../../plugins/writing/agents/doc-writer.md"
  [[ "$output" == *"model: sonnet"* ]]
  [[ "$output" == *"effort: high"* ]]
}

@test "skillは段階的開示と自己完結した処理を持つ" {
  skill="$BATS_TEST_DIRNAME/../../plugins/writing/skills/write-doc/SKILL.md"
  lines=$(wc -l < "$skill")
  [ "$lines" -le 500 ]
  run grep -E '\.\./|references/[^` ]+.*references/' "$skill"
  [ "$status" -eq 1 ]
  # 各語を個別に検査する（選言の1つが一致するだけで緑にならないように）。
  for phrase in '素材、起草経緯' '最大2回' 'F1、F2、F3、F4、F5'; do
    grep -qF "$phrase" "$skill"
  done
}

@test "入力fixtureは完全入力と素材不足を分ける" {
  run jq -e '.materials|length == 1' "$BATS_TEST_DIRNAME/../fixtures/writing/write-doc/complete-input.json"
  [ "$status" -eq 0 ]
  run jq -e '.materials|length == 0' "$BATS_TEST_DIRNAME/../fixtures/writing/write-doc/missing-material.json"
  [ "$status" -eq 0 ]
}

@test "reviewerはF1〜F5を省略せず独立入力で判定する" {
  reviewer="$BATS_TEST_DIRNAME/../../plugins/writing/agents/doc-reviewer.md"
  run cat "$reviewer"
  for rule in F1 F2 F3 F4 F5; do
    [[ "$output" == *"- \`$rule\`:"* ]]
  done
  [[ "$output" == *"ruleId=<F1|F2|F3|F4|F5>"* ]]
  [[ "$output" == *"ruleId"* && "$output" == *"severity"* && "$output" == *"evidence"* && "$output" == *"suggestion"* ]]
  [[ "$output" == *"素材、起草経緯"* ]]
  [[ "$output" == *"根拠が主張から離れている"* ]]
  # F1は第1条（語の接地）だけを扱い、識別子・参照はF2が受け持つ。
  run grep -E '^- `F1`:' "$reviewer"
  [ "$status" -eq 0 ]
  [[ "$output" != *"識別子"* && "$output" != *"参照"* ]]
  run grep -E '^- `F2`:.*参照.*本文から復元' "$reviewer"
  [ "$status" -eq 0 ]
}

@test "reviewerとwrite-docが同じ6つの入力を挙げ、規約とprofileをpathで渡す" {
  root="$BATS_TEST_DIRNAME/../.."
  reviewer="$root/plugins/writing/agents/doc-reviewer.md"
  skill="$root/plugins/writing/skills/write-doc/SKILL.md"
  # 独立レビュー節だけを取り出す（機械検査節など他の節の語で充足させない）。
  review_section=$(sed -n '/^## 独立レビュー$/,/^## /p' "$skill")
  input_section=$(sed -n '/^## 入力$/,/^## 判定規則$/p' "$reviewer")
  # reviewer側は箇条の項目を数え、6つの項目が各々1行として立っていることを見る（地の文の語で充足させない）。
  run grep -cE '^- ' <<<"$input_section"
  [ "$output" = "6" ]
  for item in '対象文書' '読み手' '文書種別' '文書種別profileのpath' '共通規約のpath' 'plugin root path'; do
    grep -qE "^- ${item}(（|$)" <<<"$input_section"
  done
  # write-doc側は列挙の文を取り出して「、」で区切り、reviewer側と項目の集合を比べる（列挙の末尾へ項目を足す変更も赤にする）。
  enum=$(grep -oE '次の6つだけをdoc-reviewerへ渡す。.*である。' <<<"$review_section" | sed -E 's/^次の6つだけをdoc-reviewerへ渡す。//; s/である。$//')
  [ -n "$enum" ]
  skill_items=$(sed 's/、/\n/g' <<<"$enum" | sed -E 's/（`[^`]*`）//g' | sort)
  reviewer_items=$(grep -E '^- ' <<<"$input_section" | sed -E 's/^- //; s/（`[^`]*`）$//' | sort)
  [ "$(wc -l <<<"$skill_items")" -eq 6 ]
  [ "$skill_items" = "$reviewer_items" ]
  # profileのpathは、2段の解決を経た後のファイルを指す（reviewerは渡されていないpathを探さないため）。
  [[ "$review_section" == *"文書種別profileのpathは、「規約とprofile」節の手順で解決した後のファイルを指す"* ]]
  [[ "$review_section" == *"種別の行が無く同梱の既定を読んだときは、同梱のファイルを渡す"* ]]
  # 渡されたprofileに種別の行が無いとき、reviewerが当てる行を決めておく（同梱の既定は汎用の行だけを持つ）。
  [[ "$input_section" == *"その行がprofileに無ければ、汎用の行を当てる"* ]]
  [[ "$input_section" == *"次の6つだけを入力とする"* ]]
  [[ "$review_section" == *"だけをdoc-reviewerへ渡す"* ]]
  # 規約とprofileは本文ではなくpathで渡し、reviewerが自分で読む。
  [[ "$review_section" == *"本文ではなくpathで渡す"* ]]
  [[ "$input_section" == *"本文ではなくpathで受け取り、自分で読む"* ]]
  [[ "$input_section" == *"入力として渡されていないpathを探して読まない"* ]]
  # 素材と起草経緯を渡さない扱いは保つ。
  [[ "$review_section" == *"素材、起草経緯、writerの判断、allowlist pathは渡さない"* ]]
  [[ "$input_section" == *"素材、起草経緯、writerの判断、allowlist path、登録簿、免除語集合は入力に含めない"* ]]
}

@test "reviewerのtoolsは読み取りのReadだけに限る" {
  reviewer="$BATS_TEST_DIRNAME/../../plugins/writing/agents/doc-reviewer.md"
  frontmatter=$(sed -n '2,/^---$/p' "$reviewer")
  run grep -cE '^tools:' <<<"$frontmatter"
  [ "$output" = "1" ]
  run grep -E '^tools:' <<<"$frontmatter"
  [ "$output" = "tools: Read" ]
}

@test "共通規約の第1条は免除を持たず、第2条は参照の復元の1基準で書かれる" {
  rules="$BATS_TEST_DIRNAME/../../plugins/writing/references/japanese-writing.md"
  art1=$(sed -n '/^## 第1条/,/^## 第2条/p' "$rules")
  art2=$(sed -n '/^## 第2条/,/^## 第3条/p' "$rules")
  [ -n "$art1" ] && [ -n "$art2" ]
  # 免除を与える記述は、語を変えても拾う。決まり文句「本条の義務に免除は無い」は取り除いてから見る。
  run grep -nE '許可リスト|免除する|免除され|免除の対象|免除とする|除く|除外|登録|限りでない|適用しない' <<<"${art1//本条の義務に免除は無い/}"
  [ "$status" -eq 1 ]
  [[ "$art1" == *"本条の義務に免除は無い"* ]]
  [[ "$art1" == *"読み手の語彙水準"* ]]
  [[ "$art2" == *"参照（ID・略称・指示語）は、その指す先が本文から復元できるように書く"* ]]
  [[ "$art2" == *"同じ文か直後の文"* ]]
  [[ "$art2" == *"復元できない参照の例"* ]]
  [[ "$art2" == *"位置を特定できる「上記」"* ]]
  # 指示語の文は独立の禁止の規定として置かない。
  [[ "$art2" != *"指示は使わない"* ]]
}

@test "共通規約の第4条とreviewerのF4は、推奨の理由を判断軸の上で述べることを求める" {
  rules="$BATS_TEST_DIRNAME/../../plugins/writing/references/japanese-writing.md"
  reviewer="$BATS_TEST_DIRNAME/../../plugins/writing/agents/doc-reviewer.md"
  art4=$(sed -n '/^## 第4条/,/^## 第5条/p' "$rules")
  [[ "$art4" == *"推奨の理由は、挙げた判断軸の上で述べる"* ]]
  [[ "$art4" == *"その観点を判断軸に加える"* ]]
  run grep -E '^- `F4`:' "$reviewer"
  [ "$status" -eq 0 ]
  [[ "$output" == *"推奨の理由が、挙げた判断軸の上で述べられているか"* ]]
  [[ "$output" == *"第4条を判定する"* ]]
}

@test "判定規則の集合を名指す箇所がF2を欠かない" {
  root="$BATS_TEST_DIRNAME/../.."
  # F1を含む規則の集合の記述を、区切りの種類によらず拾い、F1〜F5が全てあるかを見る。範囲の形は「F1〜F5」だけを完全とみなす。
  hits=$(LC_ALL=C grep -rhoE 'F1([^A-Za-z0-9]{1,6}F[0-9])+' "$root/plugins/writing" "$root/docs/development/test-execution.md" "$root/evals/writing" "$root/scripts/tests/writing-contract.bats" || true)
  [ -n "$hits" ]
  while IFS= read -r hit; do
    if [[ "$hit" == *"〜"* ]]; then
      [[ "$hit" == "F1〜F5" ]] || { echo "範囲が不完全: $hit"; return 1; }
      continue
    fi
    for n in 1 2 3 4 5; do
      [[ "$hit" == *"F${n}"* ]] || { echo "規則を欠く集合: $hit"; return 1; }
    done
  done <<<"$hits"
  run grep -n 'doc-reviewer の F1 判定' "$root/evals/writing/behavior-write-doc/graders/status-contract-value.md"
  [ "$status" -eq 1 ]
  run jq -e '[.[0].fixtures[]] | index("writing/reviewer/f2-valid.md") != null and index("writing/reviewer/f2-invalid.md") != null' "$root/plugins/writing/compatibility.json"
  [ "$status" -eq 0 ]
}

@test "READMEにreviewerとwriterのmodel・effortと値の意図の表があり、front-matterと一致する" {
  root="$BATS_TEST_DIRNAME/../.."
  readme="$root/plugins/writing/README.md"
  grep -qF '| サブエージェント | model | effort | 値の意図 |' "$readme"
  for agent in doc-reviewer doc-writer; do
    def="$root/plugins/writing/agents/$agent.md"
    model=$(sed -n '2,/^---$/s/^model: //p' "$def")
    effort=$(sed -n '2,/^---$/s/^effort: //p' "$def")
    [ -n "$model" ] && [ -n "$effort" ]
    run grep -E "^\| \`$agent\` \| \`$model\` \| \`$effort\` \| (必要最小水準|許容最大水準)" "$readme"
    [ "$status" -eq 0 ]
  done
  # 配布物のREADMEから配布元のdocs/を参照しない。
  run grep -nE '(^|[^a-z])docs/' "$readme"
  [ "$status" -eq 1 ]
}

@test "permission ledgerがreviewerの読み取り専用をCodexの縮退として記録する" {
  ledger="$BATS_TEST_DIRNAME/../../plugins/writing/permission-ledger.json"
  run jq -e 'map(select(.permission == "reviewer-read-only")) | length == 1 and .[0].verdict == "degraded" and (.[0].witness | test("tools")) and (.[0].witness | test("Read"))' "$ledger"
  [ "$status" -eq 0 ]
}

@test "compatibility matrixとpermission ledgerの全fixtureを持つ" {
  root="$BATS_TEST_DIRNAME/../.."
  run jq -e 'length > 0 and all(.[]; (.fixtures|length > 0))' "$root/plugins/writing/compatibility.json"
  [ "$status" -eq 0 ]
  run jq -e 'length >= 5 and all(.[]; has("requiredOperation") and has("witness") and has("narrowerAlternative") and has("verdict"))' "$root/plugins/writing/permission-ledger.json"
  [ "$status" -eq 0 ]
}

@test "reviewerの正負fixtureと判定行契約が揃う" {
  root="$BATS_TEST_DIRNAME/../.."
  for rule in f1 f2 f3 f4 f5; do
    [ -f "$root/scripts/fixtures/writing/reviewer/${rule}-valid.md" ]
    [ -f "$root/scripts/fixtures/writing/reviewer/${rule}-invalid.md" ]
  done
  # doc-reviewerは規則ごとの判定行を全規則分省略せず返し、修正回数と終了判定(status)は持たない。
  run grep -E '省略しない' "$root/plugins/writing/agents/doc-reviewer.md"
  [ "$status" -eq 0 ]
  run grep -E 'status=(passed|unresolved)' "$root/plugins/writing/agents/doc-reviewer.md"
  [ "$status" -eq 1 ]
  # 終了判定(最大2回・status)はSKILL.md側に一元化されている。
  run grep -E '修正は最大2回まで' "$root/plugins/writing/skills/write-doc/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -E 'status=unresolved' "$root/plugins/writing/skills/write-doc/SKILL.md"
  [ "$status" -eq 0 ]
  # 2回を待たずに修正を見送る経路も unresolved を返す（evalで status 未出力の終了が観測された経路）。
  run grep -E '修正を2回待たずに見送る場合も.*status=unresolved' "$root/plugins/writing/skills/write-doc/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "allowlistと免除語集合を導入しない" {
  root="$BATS_TEST_DIRNAME/../.."
  run grep -R -E 'allowlist path|登録簿|免除語集合' "$root/plugins/writing/compatibility.json" "$root/plugins/writing/permission-ledger.json" "$root/scripts/fixtures/writing"
  [ "$status" -eq 1 ]
}

@test "write-docの機械検査は受け取ったdocumentTypeを--typeでlintへ渡す" {
  skill="$BATS_TEST_DIRNAME/../../plugins/writing/skills/write-doc/SKILL.md"
  run grep -E 'lint-ja\.sh --type <documentType> --diff <base> -- <changed-paths>' "$skill"
  [ "$status" -eq 0 ]
}
