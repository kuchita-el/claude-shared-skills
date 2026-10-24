// 例（docs/examples/*.feature）を Gherkin 公式のパーサー（@cucumber/gherkin）で読む。
// 手書きの読み取り器は実行器と挙動がずれるため使わない。シナリオアウトラインの展開も公式の compile に任せる。
import { AstBuilder, GherkinClassicTokenMatcher, Parser, compile } from '@cucumber/gherkin';
import { IdGenerator } from '@cucumber/messages';
import type { Pickle, Scenario } from '@cucumber/messages';

// シナリオ1件、またはシナリオアウトラインの例の表の本体の1行を展開した1件
export interface Expansion {
  // 違反の target に足す印。シナリオは ''、シナリオアウトラインは例の表の本体の何行目か（#1 始まり）
  label: string;
  // 手順の文の並び（キーワードを除き前後の空白を除いた文。<引数> は展開済み。Background の手順を含む）
  steps: string[];
}

export interface ExampleScenario {
  name: string;
  line: number;
  // 件数 = expansions.length。シナリオは1件、シナリオアウトラインは例の表の本体の行数（見出し行を除く）
  expansions: Expansion[];
}

export interface ExampleRule {
  name: string;
  line: number;
  scenarios: ExampleScenario[];
}

export interface ExampleFeature {
  name: string;
  rules: ExampleRule[];
  // ルールの外（機能の直下）に置かれたシナリオ
  looseScenarios: ExampleScenario[];
}

export type ExampleParse =
  // 読めた。機能が無いファイル（空・コメントだけ）は feature が null
  | { ok: true; feature: ExampleFeature | null }
  // Gherkin として読めない。message はパーサーのエラー
  | { ok: false; message: string };

function toScenario(s: Scenario, pickles: Map<string, Pickle>): ExampleScenario {
  const stepsOf = (key: string): string[] => (pickles.get(key)?.steps ?? []).map((st) => st.text.trim());
  const expansions: Expansion[] = [];
  if (s.examples.length === 0) {
    expansions.push({ label: '', steps: stepsOf(s.id) });
  } else {
    // 公式の compile と同じく、見出し行を持たない例の表は展開しない
    let n = 0;
    for (const ex of s.examples) {
      if (ex.tableHeader === undefined) continue;
      for (const row of ex.tableBody) {
        n++;
        expansions.push({ label: `#${n}`, steps: stepsOf(`${s.id}|${row.id}`) });
      }
    }
  }
  return { name: s.name, line: s.location.line, expansions };
}

export function parseExample(source: string): ExampleParse {
  const newId = IdGenerator.incrementing();
  let doc;
  try {
    doc = new Parser(new AstBuilder(newId), new GherkinClassicTokenMatcher()).parse(source);
  } catch (e) {
    // 先頭のエラーだけを示し、残りは件数にする（「Parser errors:」の行は除く）
    const errors = (e as Error).message
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l !== '' && l !== 'Parser errors:');
    const message =
      errors.length > 1 ? `${errors[0]}（ほか ${errors.length - 1} 件）` : (errors[0] ?? (e as Error).message);
    return { ok: false, message };
  }
  if (doc.feature === undefined) return { ok: true, feature: null };

  // 展開した1件は、シナリオなら astNodeIds が [シナリオ]、アウトラインの1行なら [シナリオ, 行]
  const pickles = new Map<string, Pickle>();
  for (const p of compile(doc, '', newId)) pickles.set(p.astNodeIds.join('|'), p);

  const feature: ExampleFeature = { name: doc.feature.name.trim(), rules: [], looseScenarios: [] };
  for (const child of doc.feature.children) {
    if (child.rule !== undefined) {
      feature.rules.push({
        name: child.rule.name.trim(),
        line: child.rule.location.line,
        scenarios: child.rule.children
          .filter((c) => c.scenario !== undefined)
          .map((c) => toScenario(c.scenario!, pickles)),
      });
    } else if (child.scenario !== undefined) {
      feature.looseScenarios.push(toScenario(child.scenario, pickles));
    }
  }
  return { ok: true, feature };
}
