# ADR-20260604: 複数スキルが共有する参照資源はプラグインルート references/ に集約する（DoR定義の単一ソース化）

## Status

Accepted

## Context

DoR（Definition of Ready）定義 `dor-default.md` は、これまで `refine-issue` スキル配下 `skills/refine-issue/references/dor-default.md` に置かれ、`refine-issue` のみが参照していた。

`create-issue` スキルの新設（#231）により、DoR定義は**2スキルが共有する資源**になった。`create-issue` は作成時にDoRを前倒し充足させ（shift-left）、`refine-issue` は作成後の精査で同じDoRを適用する。両者が同一基準を参照しなければ、作成側と精査側で判定基準がドリフトし、「create-issue が満たしたはずのDoRを refine-issue が不足と指摘する」矛盾が生じる。

共有資源を一方のスキル（`refine-issue`）配下に置いたままにすると、`create-issue` が `refine-issue` の内部ディレクトリ構造へ依存する**逆コンポーネント結合**が発生する。`create-issue` が `../refine-issue/references/dor-default.md` を参照する形は、スキル間の独立性を損ない、`refine-issue` のリファクタで `create-issue` が壊れる。

ADR-20260525-2 は、共有資源（サブエージェント定義）を各スキル配下から**プラグインルートへ巻き上げる**原則を既に確立している。本判断はその同型適用である。なお ADR-20260525-2 が扱った agents/ は自動検出機構によるもので、パス変数参照を伴わない。本ADRは `${CLAUDE_PLUGIN_ROOT}` によるパス参照を本リポで初めて導入する点が異なる（Claude Code 公式仕様で skill content 内のインライン置換が保証されていることを確認済み）。

## Decision

複数スキルが共有する参照資源は、特定スキル配下ではなく**プラグインルート直下 `references/` に集約**し、各スキルは `${CLAUDE_PLUGIN_ROOT}/references/<file>` で参照する。

- DoR定義を `skills/refine-issue/references/dor-default.md` から `plugins/dev-workflow/references/dor-default.md` へ移設する
- `create-issue` / `refine-issue` 双方が同一優先順位でDoRを読み込む: プロジェクト固有 `{project}/.claude/dor/definition.md`（存在すれば優先）→ プラグイン共有 `${CLAUDE_PLUGIN_ROOT}/references/dor-default.md`
- **参照基点の分離原則**: 共有資源はプラグインルート `${CLAUDE_PLUGIN_ROOT}/references/`、スキル固有資源は各スキル配下 `${CLAUDE_SKILL_DIR}/references/` に置く。1スキル内で両基点が混在することは許容する（共有か固有かで配置先が一意に決まることを優先する）
- 将来追加する共有参照資源も本原則に従いプラグインルート `references/` に配置する

### 不採用案

- **案①: `create-issue` が `refine-issue/references/dor-default.md` を直接参照** — スキル間の逆結合を生むため不採用
- **案②: プラグインルートに `dor/` 専用ディレクトリを新設** — プロジェクト側 `.claude/dor/` と対称で一案だが、既存の per-skill `references/` 慣例をプラグインスコープへ自然拡張する案を優先し不採用

## Consequences

- DoR定義が単一ソース化され、作成側（`create-issue`）と精査側（`refine-issue`）の基準ドリフトが構造的に排除される
- `create-issue` が `refine-issue` の内部構造へ依存する逆結合が解消され、両スキルの独立性が保たれる
- per-skill `references/` 慣例がプラグインスコープへ拡張される。共有資源の置き場所が「プラグインルート references/」として一意に定まる
- `refine-issue` は共有資源（DoR）を `${CLAUDE_PLUGIN_ROOT}`、固有資源（refine-prompt・output-format 等）を `${CLAUDE_SKILL_DIR}` から読む2基点構成になる。これは基点分離原則の意図した帰結であり不整合ではない
- `${CLAUDE_PLUGIN_ROOT}` の解決は Claude Code 側の仕様に依存する。将来この置換挙動が変わった場合は本ADRを再検討する

## 関連ADR

Related: ADR-20260525-2-subagent-agents-consolidation（共有資源をプラグインルートへ集約する同型の原則。本ADRはその参照資源版）。関連Issue: #231
