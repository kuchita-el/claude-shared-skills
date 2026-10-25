// 設計の可視化の材料を組む。RDRA の表・要求票・例を読み、状態モデルごとの遷移と UC ごとの縦串にまとめる。
// 検査はしない（違反は check.ts が拾う）。違反があっても組み、表に無い名前は known: false にして残す。
// HTML の文字列は html.ts が作る。
import { loadTables } from './check.ts';
import { readSources } from './sources.ts';
import type { Sources } from './sources.ts';
import { parseExample } from './example.ts';
import type { ExampleScenario } from './example.ts';
import { parseReferences, parseRequirement } from './requirement.ts';
import { REQUIREMENT_STATE_SEP } from './schema.ts';

type Rows = ReturnType<typeof loadTables>;
type Row = Rows[string][number];

export interface TransitionView {
  // 遷移元の状態。初期遷移（状態の無い記録）は null
  from: string | null;
  // 遷移先の状態。終端の状態の記録（遷移先の無い記録）は null
  to: string | null;
  // 遷移 UC。無ければ null
  uc: string | null;
  ucKnown: boolean;
  // 遷移先の状態が、同じ状態モデルの「状態」に現れるか（check.ts の未定義の参照と同じ見方）
  toKnown: boolean;
  description: string;
  hypothesis: boolean;
}

export interface StateModelView {
  name: string;
  // 状態の並び（表に現れた順。遷移元・遷移先の両方）
  states: string[];
  transitions: TransitionView[];
}

export interface NamedView {
  name: string;
  known: boolean;
}

export interface ScenarioView {
  name: string;
  // 例の件数（シナリオアウトラインは例の表の行数）
  count: number;
}

export interface RuleView {
  name: string;
  scenarios: ScenarioView[];
}

export interface VariationView extends NamedView {
  values: string[];
  description: string;
}

// 条件・バリエーション・情報の中身。要求文が名前で指す中身を、表を引き直さずに読めるよう行の直下に出す
export interface DefinitionView {
  // 条件は条件の説明、バリエーション・情報は説明
  description: string;
  // バリエーションの値（他は空）
  values: string[];
  // 情報の属性（他は空）
  attributes: string[];
  // 条件が持つバリエーション（バリエーションは空）
  variations: VariationView[];
}

export interface ReferenceView {
  raw: string;
  // 種類と名前が読め、表にあるか
  known: boolean;
  // 読めた種類と名前（読めなければ null）
  kind: string | null;
  name: string | null;
  // 表にある条件・バリエーション・情報の中身。他の種類と表に無い参照は null
  definition: DefinitionView | null;
}

export interface RequirementLineView {
  ordinal: number;
  text: string;
  reason: string | null;
  references: ReferenceView[];
  // 要求文と同じ名前のルールのシナリオ（照合の規則「ルール名 ＝ 要求文」）
  scenarios: ScenarioView[];
}

export interface RequirementView {
  file: string;
  reason: string | null;
  lines: RequirementLineView[];
}

export interface UseCaseView {
  name: string;
  // ページ内リンクの先（uc-1 から）
  anchor: string;
  description: string;
  // 『仮説』キーの値。キーが無ければ null
  hypothesis: string[] | null;
  actors: (NamedView & { role: string })[];
  externalSystems: (NamedView & { role: string })[];
  information: (NamedView & { description: string; attributes: string[] })[];
  conditions: (NamedView & { description: string; variations: VariationView[] })[];
  // この UC が遷移 UC になっている状態モデルの名前
  stateModels: string[];
  requirements: RequirementView[];
  exampleFiles: string[];
  // 要求票のどの行の要求文とも名前が一致しないルール
  unlinkedRules: RuleView[];
  // ルールの外（機能の直下）に置かれたシナリオ
  looseScenarios: ScenarioView[];
}

export interface View {
  root: string;
  stateModels: StateModelView[];
  useCases: UseCaseView[];
  // UC の表に無い UC を表題にした要求票（表題が読めない票は ucName が null）
  strayRequirements: { file: string; ucName: string | null }[];
  // UC の表に無い UC を機能名にした例（機能名が空なら name が ''）
  strayExamples: { file: string; name: string }[];
  // Gherkin として読めない、または機能の無い例
  unreadableExamples: { file: string; message: string }[];
  // 表にある名前すべて（状態を含む）。要求文の中の名前に印を付けるとき、長い名前の一部へ誤って付けないために使う
  tableNames: string[];
}

function str(row: Row, key: string): string {
  const v = row.data[key];
  return typeof v === 'string' ? v.trim() : '';
}

// 「、」区切りの1文字列のキーと、文字列の並びのキーの両方を並びとして読む（check.ts の values と同じ寛容さ）
function list(row: Row, key: string): string[] {
  const v = row.data[key];
  if (typeof v === 'string') {
    const parts = row.def.splitKeys.includes(key) ? v.split('、') : [v];
    return parts.map((s) => s.trim()).filter((s) => s !== '');
  }
  if (Array.isArray(v)) return v.filter((x): x is string => typeof x === 'string' && x.trim() !== '').map((x) => x.trim());
  return [];
}

function hypothesisOf(row: Row): string[] | null {
  return Object.hasOwn(row.data, '仮説') ? list(row, '仮説') : null;
}

function scenarioView(s: ExampleScenario): ScenarioView {
  return { name: s.name, count: s.expansions.length };
}

function buildStateModels(rows: Rows, ucNames: Set<string>): StateModelView[] {
  const models = new Map<string, StateModelView>();
  const statesOf = new Map<string, Set<string>>();
  for (const r of rows['state']) {
    const st = str(r, '状態');
    if (st === '') continue;
    if (!statesOf.has(r.name)) statesOf.set(r.name, new Set());
    statesOf.get(r.name)!.add(st);
  }
  for (const r of rows['state']) {
    let m = models.get(r.name);
    if (m === undefined) {
      m = { name: r.name, states: [], transitions: [] };
      models.set(r.name, m);
    }
    const from = str(r, '状態') || null;
    const to = str(r, '遷移先状態') || null;
    const uc = str(r, '遷移UC') || null;
    for (const s of [from, to]) if (s !== null && !m.states.includes(s)) m.states.push(s);
    m.transitions.push({
      from,
      to,
      uc,
      ucKnown: uc === null || ucNames.has(uc),
      toKnown: to === null || (statesOf.get(r.name)?.has(to) ?? false),
      description: str(r, '状態モデル・状態の説明'),
      hypothesis: Object.hasOwn(r.data, '仮説'),
    });
  }
  return [...models.values()];
}

export function buildView(root: string, sources: Sources = readSources(root)): View {
  const rows = loadTables(sources, []);
  const byName = (id: string) => new Map(rows[id].map((r) => [r.name, r] as const));
  const actors = byName('actor');
  const externalSystems = byName('external-system');
  const information = byName('information');
  const conditions = byName('condition');
  const variations = byName('variation');
  const ucNames = new Set(rows['use-case'].map((r) => r.name));
  const modelNames = new Set(rows['state'].map((r) => r.name));
  const stateModels = buildStateModels(rows, ucNames);

  // 参照の欄の要素が表にあるか。状態は「<状態モデル>/<状態>」の状態が、その状態モデルの遷移元・遷移先に現れるか
  const namesOfKind = new Map<string, Set<string>>([
    ['アクター', new Set(actors.keys())],
    ['外部システム', new Set(externalSystems.keys())],
    ['情報', new Set(information.keys())],
    ['状態モデル', modelNames],
    ['UC', ucNames],
    ['条件', new Set(conditions.keys())],
    ['バリエーション', new Set(variations.keys())],
    ['アーキテクチャ特性', new Set(rows['architecture-characteristic'].map((r) => r.name))],
  ]);
  const variationView = (name: string): VariationView => {
    const row = variations.get(name);
    return {
      name,
      known: row !== undefined,
      values: row ? list(row, '値') : [],
      description: row ? str(row, '説明') : '',
    };
  };
  const definitionOf = (kind: string | null, name: string | null): DefinitionView | null => {
    if (name === null) return null;
    if (kind === '条件') {
      const row = conditions.get(name);
      if (row === undefined) return null;
      return {
        description: str(row, '条件の説明'),
        values: [],
        attributes: [],
        variations: list(row, 'バリエーション').map(variationView),
      };
    }
    if (kind === 'バリエーション') {
      const v = variationView(name);
      return v.known ? { description: v.description, values: v.values, attributes: [], variations: [] } : null;
    }
    if (kind === '情報') {
      const row = information.get(name);
      if (row === undefined) return null;
      return { description: str(row, '説明'), values: [], attributes: list(row, '属性'), variations: [] };
    }
    return null;
  };
  const referenceKnown = (kind: string | null, name: string | null): boolean => {
    if (kind === null || name === null) return false;
    if (kind === '状態') {
      const i = name.indexOf(REQUIREMENT_STATE_SEP);
      if (i < 0) return false;
      const model = stateModels.find((m) => m.name === name.slice(0, i).trim());
      return model?.states.includes(name.slice(i + REQUIREMENT_STATE_SEP.length).trim()) ?? false;
    }
    return namesOfKind.get(kind)?.has(name) ?? false;
  };

  const requirements = sources.requirements.map(({ file, text }) => ({
    file,
    req: parseRequirement(text),
  }));

  const features: { file: string; name: string; rules: RuleView[]; loose: ScenarioView[] }[] = [];
  const unreadableExamples: View['unreadableExamples'] = [];
  for (const { file, text } of sources.examples) {
    const parsed = parseExample(text);
    if (!parsed.ok) {
      unreadableExamples.push({ file, message: parsed.message });
    } else if (parsed.feature === null) {
      unreadableExamples.push({ file, message: '機能（Feature）が無い' });
    } else {
      features.push({
        file,
        name: parsed.feature.name,
        rules: parsed.feature.rules.map((r) => ({ name: r.name, scenarios: r.scenarios.map(scenarioView) })),
        loose: parsed.feature.looseScenarios.map(scenarioView),
      });
    }
  }

  const useCases: UseCaseView[] = rows['use-case'].map((r, i) => {
    const ownRequirements = requirements.filter((q) => q.req.ucName === r.name);
    const ownFeatures = features.filter((f) => f.name === r.name);
    const rules = ownFeatures.flatMap((f) => f.rules);
    const sentences = new Set(ownRequirements.flatMap((q) => q.req.lines.map((l) => l.text)));
    return {
      name: r.name,
      anchor: `uc-${i + 1}`,
      description: str(r, '説明'),
      hypothesis: hypothesisOf(r),
      actors: list(r, 'アクター').map((name) => ({
        name,
        known: actors.has(name),
        role: actors.has(name) ? str(actors.get(name)!, '役割') : '',
      })),
      externalSystems: list(r, '外部システム').map((name) => ({
        name,
        known: externalSystems.has(name),
        role: externalSystems.has(name) ? str(externalSystems.get(name)!, '役割') : '',
      })),
      information: list(r, '情報').map((name) => {
        const row = information.get(name);
        return {
          name,
          known: row !== undefined,
          description: row ? str(row, '説明') : '',
          attributes: row ? list(row, '属性') : [],
        };
      }),
      conditions: list(r, '条件').map((name) => {
        const row = conditions.get(name);
        return {
          name,
          known: row !== undefined,
          description: row ? str(row, '条件の説明') : '',
          variations: (row ? list(row, 'バリエーション') : []).map(variationView),
        };
      }),
      stateModels: stateModels.filter((m) => m.transitions.some((t) => t.uc === r.name)).map((m) => m.name),
      requirements: ownRequirements.map(({ file, req }) => ({
        file,
        reason: req.reason,
        lines: req.lines.map((l) => ({
          ordinal: l.ordinal,
          text: l.text,
          reason: l.reason,
          references: parseReferences(l.rdra).map((ref) => ({
            raw: ref.raw,
            known: referenceKnown(ref.kind, ref.name),
            kind: ref.kind,
            name: ref.name,
            definition: definitionOf(ref.kind, ref.name),
          })),
          scenarios: rules.filter((rule) => rule.name === l.text).flatMap((rule) => rule.scenarios),
        })),
      })),
      exampleFiles: ownFeatures.map((f) => f.file),
      unlinkedRules: rules.filter((rule) => !sentences.has(rule.name)),
      looseScenarios: ownFeatures.flatMap((f) => f.loose),
    };
  });

  return {
    root,
    stateModels,
    useCases,
    strayRequirements: requirements
      .filter((q) => q.req.ucName === null || !ucNames.has(q.req.ucName))
      .map((q) => ({ file: q.file, ucName: q.req.ucName })),
    strayExamples: features.filter((f) => !ucNames.has(f.name)).map((f) => ({ file: f.file, name: f.name })),
    unreadableExamples,
    tableNames: [
      ...new Set([...Object.values(rows).flatMap((rs) => rs.map((r) => r.name)), ...stateModels.flatMap((m) => m.states)]),
    ],
  };
}
