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
  for item in '対象文書、' '読み手（`audience`）' '文書種別（`documentType`）' '文書種別profileのpath' '共通規約のpath' 'plugin root path'; do
    [[ "$review_section" == *"$item"* ]]
  done
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
  [[ "$art1" != *"許可リスト"* ]]
  [[ "$art1" == *"本条の義務に免除は無い"* ]]
  [[ "$art1" == *"読み手の語彙水準"* ]]
  [[ "$art2" == *"参照（ID・略称・指示語）は、その指す先が本文から復元できるように書く"* ]]
  [[ "$art2" == *"同じ文か直後の文"* ]]
  [[ "$art2" == *"復元できない参照の例"* ]]
  [[ "$art2" == *"位置を特定できる「上記」"* ]]
  # 指示語の文は独立の禁止の規定として置かない。
  [[ "$art2" != *"指示は使わない"* ]]
}

@test "判定規則の集合を名指す箇所がF2を欠かない" {
  root="$BATS_TEST_DIRNAME/../.."
  run grep -rnE 'F1[/、,] ?F3' "$root/plugins/writing" "$root/docs/development/test-execution.md" "$root/evals/writing" "$root/scripts/tests/writing-contract.bats"
  [ "$status" -eq 1 ]
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
