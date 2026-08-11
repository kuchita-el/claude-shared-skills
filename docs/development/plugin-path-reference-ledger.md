# plugin path reference ledger

`growth` は既存runner導入対象として保持するが、Claudeのsession jsonl/local store依存のため、Codexでは恒久的に `surface-specific` として扱う。Codex adapterを追加する場合のみcompatibility matrixと本台帳を更新し、適合判定対象へ戻す。

| path | line | pluginPath | owner | purpose | migrationWave | expected |
|---|---:|---|---|---|---|---|
| .gitignore | 7 | plugins/growth | growth | local store exclusion | wave-0 | current |
| .gitignore | 8 | plugins/growth | growth | local store exclusion | wave-0 | current |
| CLAUDE.md | 25 | plugins/dev-workflow | dev-workflow | repository architecture | wave-0 | current |
| CLAUDE.md | 26 | plugins/dev-workflow | dev-workflow | repository architecture | wave-0 | current |
| CLAUDE.md | 27 | plugins/dev-workflow | dev-workflow | repository architecture | wave-0 | current |
| CLAUDE.md | 28 | plugins/dev-workflow | dev-workflow | repository architecture | wave-0 | current |
| CLAUDE.md | 29 | plugins/dev-workflow | dev-workflow | repository architecture | wave-0 | current |
| CLAUDE.md | 30 | plugins/adr | adr | repository architecture | wave-0 | current |
| CLAUDE.md | 36 | plugins/dev-workflow | dev-workflow | repository architecture | wave-0 | current |
| CLAUDE.md | 59 | plugins/dev-workflow | dev-workflow | repository convention | wave-0 | current |
| CLAUDE.md | 66 | plugins/dev-workflow | dev-workflow | repository convention | wave-0 | current |
| CLAUDE.md | 87 | plugins/dev-workflow | dev-workflow | repository convention | wave-0 | current |
| CLAUDE.md | 91 | plugins/dev-workflow | dev-workflow | repository convention | wave-0 | current |
| CLAUDE.md | 95 | plugins/dev-workflow | dev-workflow | repository convention | wave-0 | current |
| CLAUDE.md | 115 | plugins/dev-workflow | dev-workflow | repository convention | wave-0 | current |
| README.md | 52 | plugins/dev-workflow | dev-workflow | usage | wave-0 | current |
| README.md | 55 | plugins/dev-workflow | dev-workflow | usage | wave-0 | current |
| README.md | 60 | plugins/dev-workflow | dev-workflow | usage | wave-0 | current |
| README.md | 64 | plugins/dev-workflow | dev-workflow | usage | wave-0 | current |
| README.md | 110 | plugins/dev-workflow | dev-workflow | usage | wave-0 | current |
| docs/development/test-execution.md | 49 | plugins/adr | adr | test setup | wave-0 | current |
| docs/development/test-execution.md | 138 | plugins/adr | adr | test setup | wave-0 | current |
| docs/development/test-execution.md | 155 | plugins/adr | adr | test setup | wave-0 | current |
| docs/development/test-execution.md | 159 | plugins/adr | adr | test setup | wave-0 | current |
| .agents/plugins/marketplace.json | 11 | plugins/dev-workflow | dev-workflow | marketplace source | wave-0 | current |
| .agents/plugins/marketplace.json | 23 | plugins/growth | growth | marketplace source | wave-0 | current |
| .agents/plugins/marketplace.json | 35 | plugins/adr | adr | marketplace source | wave-0 | current |
| .agents/plugins/marketplace.json | 47 | plugins/writing | writing | marketplace source | wave-0 | current |
| .claude-plugin/marketplace.json | 9 | plugins/dev-workflow | dev-workflow | marketplace source | wave-0 | current |
| .claude-plugin/marketplace.json | 13 | plugins/growth | growth | marketplace source | wave-0 | current |
| .claude-plugin/marketplace.json | 17 | plugins/adr | adr | marketplace source | wave-0 | current |
| .claude-plugin/marketplace.json | 21 | plugins/writing | writing | marketplace source | wave-0 | current |
| CLAUDE.md | 24 | plugins/dev-workflow | dev-workflow | repository structure | wave-0 | current |
| README.md | 122 | plugins/dev-workflow | dev-workflow | usage | wave-0 | current |
| scripts/tests/adr-scoping-cases-edge.bats | 452 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/helpers/common.bash | 32 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/local-plugin-runners.bats | 51 | plugins/dev-workflow | dev-workflow | runner test | wave-0 | current |
| scripts/tests/plugin-path-references.bats | 12 | plugins/adr | adr | checker test | wave-0 | current |
| scripts/tests/plugin-path-references.bats | 17 | plugins/writing | writing | checker test | wave-0 | current |
| scripts/lint-domain-doc.sh | 9 | plugins/dev-workflow | dev-workflow | shared reference | wave-0 | current |
| scripts/tests/adr-scoping-cases-basic.bats | 2 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/adr-scoping-cases-basic.bats | 717 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/adr-scoping-cases-basic.bats | 731 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/adr-scoping-cases-basic.bats | 738 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/adr-scoping-cases-basic.bats | 783 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/adr-scoping-cases-basic.bats | 809 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/adr-scoping-cases-basic.bats | 822 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/adr-scoping-cases-basic.bats | 823 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/adr-scoping-cases-basic.bats | 824 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/adr-scoping-cases-basic.bats | 847 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/adr-scoping-cases-edge.bats | 2 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/lint-adr-index.bats | 2 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/lint-adr-layers.bats | 2 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/lint-adr-stem.bats | 2 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/lint-adr-xref.bats | 2 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/next-adr-id.bats | 2 | plugins/adr | adr | fixture | wave-0 | current |
| scripts/tests/adr-portability.bats | 18 | plugins/adr | adr | fixture | wave-1 | current |
| scripts/tests/adr-portability.bats | 22 | plugins/adr | adr | fixture | wave-1 | current |
| scripts/tests/adr-portability.bats | 27 | plugins/adr | adr | fixture | wave-1 | current |
