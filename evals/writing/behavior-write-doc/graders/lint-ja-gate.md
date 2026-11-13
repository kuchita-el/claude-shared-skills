---
type: tool_used
tool: Bash
input_match: 'lint-ja\.mjs'
min: 1
---

狙う所見: 保護3類型の(2) コマンドを実行して証拠を得る検証ゲート。将来の除去作業でこのゲートが落ちていないかを検出する番人。
根拠: plugins/writing/skills/write-doc/SKILL.md:52-61「機械検査」節。57行目が `lint-ja.mjs` を `--type <documentType> --diff <base>` 付きで呼ぶ。
