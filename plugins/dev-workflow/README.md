# dev-workflow プラグイン

Issue の起票から計画・実装・レビューまでを支援するスキルとサブエージェントを配布する Claude Code プラグイン。GitHub CLI（`gh`）以外のプロジェクト固有ツールには依存しない。

スキルの一覧と使い分けは各 `skills/{name}/SKILL.md` の `description` を参照。

## サブエージェントの実行パラメータ

本プラグインのサブエージェントは、`model` と `effort` を定義ファイルの front-matter で明示している。`subagent_type` を指定して起動されたサブエージェントは、親セッションがどのモデル・どの effort で動いていても以下の値で動く。

| サブエージェント | `model` | `effort` | 値の意図 |
|---|---|---|---|
| `plan` | `opus` | `xhigh` | 必要最小水準 |
| `plan-reviewer` | `opus` | `xhigh` | 必要最小水準 |
| `code-reviewer` | `opus` | `high` | 必要最小水準 |
| `test-designer` | `opus` | `high` | 必要最小水準 |
| `test-spec-validator` | `opus` | `high` | 必要最小水準 |
| `refactorer` | `sonnet` | `high` | 必要最小水準 |
| `issue-refiner` | `opus` | `medium` | 必要最小水準 |
| `issue-refiner-batch` | `sonnet` | `medium` | 許容最大水準 |

「必要最小水準」は、その役割が成立するために必要な下限として選んだ値である。「許容最大水準」は逆に、その役割に対して許容する上限として選んだ値である。`issue-refiner-batch` は Issue の棚卸しを担い、全件モードでは 15 件 × 最大 3 並列と処理量が出るため、セッション側で高い設定を使っていても抑制する。

ラベルはその役割にとっての意図を表すもので、すべての利用者構成に対して一様に下限や上限として働くことを意味しない。`effort` のモデル既定は `high` であり、設定を変えていない環境ではこれが基準になる。したがって `medium` を指定した 2 本は、既定構成の利用者に対しては引き下げとして働く。`issue-refiner` は `model` の `opus` が下限として、`effort` の `medium` が上限として作用する組み合わせになっている。

### 統制が及ぶ範囲

上記の値が効くのは、そのサブエージェントが `subagent_type` 指定で起動された場合である。本プラグインのスキルが `subagent_type` で起動するのは `plan` / `plan-reviewer` / `issue-refiner` / `issue-refiner-batch` の 4 本で、`code-reviewer` / `test-designer` / `test-spec-validator` / `refactorer` は `@agent-dev-workflow:...` で直接起動したときに効く。`implementation` スキルは実装とレビューを superpowers 側へ委譲しており、その経路のサブエージェントは本プラグインの統制下にない。

`issue-refiner` と `issue-refiner-batch` は用途が異なる。前者は単一 Issue の着手判断が用途で、受入条件が実際に検証可能かまで踏み込む必要があるため `opus` を下限とする。後者は棚卸しが用途で、Ready / Not Ready の判定・主要ブロッカー・分割要否を押さえられればよいため `sonnet` を上限とする。

### 値を上書きする

環境変数は front-matter より優先される。プラグイン側の設定を変えずに、セッション全体で異なる値を使いたい場合に用いる。

| 環境変数 | 効果 |
|---|---|
| `CLAUDE_CODE_SUBAGENT_MODEL` | 全サブエージェントのモデルを指定した値にする |
| `CLAUDE_CODE_EFFORT_LEVEL` | 全サブエージェントの effort を指定した値にする |

いずれも全サブエージェントに一律で効くため、役割ごとに個別の値を与えることはできない。

Fable 5 のような、より能力の高いモデルで動かしたい場合は `CLAUDE_CODE_SUBAGENT_MODEL=fable` を設定する。本プラグインは既定では Fable 5 を採用していない。単発の生成・検証という各役割の性質に対して価格が見合わないためであり、必要とする利用者が明示的に選ぶ形としている。
