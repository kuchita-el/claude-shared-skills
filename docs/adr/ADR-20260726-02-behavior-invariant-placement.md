---
status: 提案中
validity:
superseded-by:
---

# ADR-20260726-02: 振る舞いの規律を共有 references の単一出典に置き、配布物からポインタ参照する

## Context

実行時規約である `context-budget.md`（ADR-20260627）を参照しているのは CLAUDE.md のみで、SKILL.md からもサブエージェント定義からも参照されていない。CLAUDE.md は配布物に同梱されないため、**第三者がプラグインを導入した環境にはこの規約が届いていない**。

S2（プロンプト適応層）の規律は、配布先の実行環境で効かなければ目的を達しない。したがって配置層を決める必要がある。候補は、各 SKILL.md 本文への直接埋め込み（確実に届くが12スキルへ重複記述となり drift 源になる）、サブエージェント定義のみ（S1 と統制点は揃うがメインループの挙動に届かない）、共有 references の単一出典＋ポインタ参照、の3つであった。

あわせて、成果物の分量をどこで縛るかの責務も定める必要がある。出力形式テンプレートは「どの節が、どの順で、どの型で並ぶか」を定義するものであり、散文の分量は内容側の性質である。両者を同一ファイルへ混ぜると、形式を変えるたびに分量規定が巻き添えになる。

## Decision

1. 振る舞いの規律は `plugins/dev-workflow/references/behavior-invariants.md` を**単一出典**とし、各 SKILL.md とサブエージェント定義からは1行のポインタで参照する。規約本文を参照側へ転記しない。
2. 責務を分離する。**どの節が存在するか**は各出力形式テンプレートが定義し（定義外の節を追加しない旨をテンプレート側に明記する）、**節の中身の分量**は本規約が扱う。
3. 実行時の規律は2軸に分ける。データフロー軸（メイン context に何を載せるか）は `context-budget.md`、生成・範囲軸（どれだけ書くか・どこまでやるか）は `behavior-invariants.md`。内容を重複させない。

## Consequences

- CLAUDE.md 経由のみだった従来の参照経路の欠落を塞ぎ、配布環境へ届く経路が確立する。
- ポインタ挿入により SKILL.md 本文が各1行増える。適用後の最大は `dependency-check` の158行で、170行規律の範囲内に収まる。
- 実効性は「スキルが実行時にポインタ先を Read する」ことに依存する。Read されなければ規約は効かない。この依存は既存の共有参照（DoR デフォルト等）と同じ構造であり、本決定が新たに導入するリスクではない。
- サブエージェント定義から共有 references へ到達する経路は、呼び出し側がプラグインルートパスを渡している `issue-refiner` / `issue-refiner-batch` の2本にしか整備されていない。`plan` / `plan-reviewer` は経路の新設が必要であり、`code-reviewer` / `test-designer` / `test-spec-validator` / `refactorer` は dev-workflow のスキルが起動しないため呼び出し側が存在しない（S1 で判明した統制外経路と同じ範囲）。これらは本決定の射程外とし、follow-up で扱う。
- 既存の `context-budget.md` も同じ参照欠落を持つ。本決定の射程外だが、同じ扱いへ揃える改修が follow-up として残る。
- 対象は dev-workflow プラグインに限る。`adr` / `growth` は独立配布であり、`growth` は dev-workflow との疎結合を設計として明記しているため、単一出典を跨いで参照できない。横展開は実害が観測されてから follow-up で扱う。

## 関連ADR

- Related: ADR-20260726-01-behavior-invariant-description-style（本規約の記述様式を定める決定）
- Related: ADR-20260627-skill-context-budget-convention（実行時データフロー軸。本規約と補完関係）
- Related: ADR-20260604-dor-shared-resource-consolidation（共有参照ファイルの配置パターン）
- 関連Issue: #364
