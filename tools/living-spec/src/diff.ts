// 基準の版と作業ツリーの表・要求票・例を要素の名前（同一性）で突き合わせ、足された・変わった・外された要素を求める。
// ファイルを読まない純関数で、入力は2版の中身（Sources）だけである。基準の版の読み出しは base.ts、描画は diffview.ts・html.ts が持つ。
// 要素の種類・同一性・比べる中身・区分の定義の正本は references/format.md の描き分けの節で、ここはそれを実装する。
// 定義はこのファイルの1か所に持ち、描き分けの材料（diffview.ts）はこの結果から要素の区分を引くだけで、比べ方を持たない。
// 一覧（difflist.ts）もこの結果を読むだけで、比べ方を持たない。
// 描画の材料（View）同士を比べないのは、View が UC ごとに要素を写して持ち、アクターの社内外・情報の関連情報・例の手順などを
// 落としているため、「変わった」を判定できないからである。描画（diffview.ts・html.ts・render.ts）の中に埋め込まないのは、
// 読み出し（base.ts）・比較（このファイル）・描画を分け、比較を描画から切り離して、2版の中身だけを入力にした試験
// （test/diff.test.ts）で定義を確かめられるようにするためである。表の値の読み方（str・list）と区分の型だけは view.ts と共用する。
// このモジュールの分け方の判断は ADR にしない。適用先が同じ検査器の中に閉じ、理由をこの冒頭に定義の実装と同居させられるため。
import { loadTables } from './check.ts';
import { parseExample } from './example.ts';
import type { ExampleScenario } from './example.ts';
import { parseReferences, parseRequirement } from './requirement.ts';
import { HYPOTHESIS, TABLES } from './schema.ts';
import type { Sources } from './sources.ts';
import { list, str } from './view.ts';
import type { DiffStatus } from './view.ts';

type Row = ReturnType<typeof loadTables>[string][number];

export type ElementKind =
  | '状態'
  | '遷移'
  | 'UC'
  | 'アクター'
  | '外部システム'
  | '情報'
  | '条件'
  | 'バリエーション'
  | '要求票'
  | '要求文'
  | '例';

// 出力の種類の並び
const KINDS: readonly ElementKind[] = [
  '状態',
  '遷移',
  'UC',
  'アクター',
  '外部システム',
  '情報',
  '条件',
  'バリエーション',
  '要求票',
  '要求文',
  '例',
];

function isKind(kind: string): kind is ElementKind {
  return (KINDS as readonly string[]).includes(kind);
}

// 名前1つを同一性にする表と、その種類（表の定義の kind）。状態の表は遷移と状態の要素として別に集める。
// 種類が差分の種類に無い表（アーキテクチャ特性。縦串に載らない）は比べない
const NAMED_TABLES: readonly { id: string; kind: ElementKind }[] = TABLES.flatMap((def) =>
  def.id !== 'state' && isKind(def.kind) ? [{ id: def.id, kind: def.kind }] : [],
);

// 遷移の同一性に使う状態の表のキー。比べる中身から外す
const TRANSITION_IDENTITY = ['状態モデル', '状態', '遷移UC', '遷移先状態'];

// ルールの外（機能の直下）のシナリオを、例の同一性で表すルール名
export const OUTSIDE_RULE = 'なし';

export interface ElementDiff {
  kind: ElementKind;
  // 同一性のキー（elementKey）
  key: string;
  // 同一性の値。elementKey に渡す並びそのもので、format.md の同一性の列の順である。無い値は null。
  // 足された・変わったは作業ツリーの要素の値、外されたは基準の版の要素の値
  identity: (string | null)[];
  // 表示名。状態は <状態モデル>/<状態>、遷移は <状態モデル>/<遷移元>→<遷移先>（<遷移UC>）、要求票は表題の UC 名、要求文は文、
  // 例はシナリオ名、UC・アクター・外部システム・情報・条件・バリエーションは表の名前
  name: string;
  status: DiffStatus;
  // 変わった欄の名前（定義の順）。区分が changed のときだけ空でない
  changed: string[];
}

export interface SpecDiff {
  // 種類の並びの順。同じ種類の中は作業ツリーでの出現順で、外された要素はその後ろに基準の版での出現順で並ぶ。変わっていない要素は持たない
  elements: ElementDiff[];
}

// 同一性のキー。状態は（状態モデル・状態）、遷移は（状態モデル・遷移元・遷移先・遷移UC。無いは null）、
// 要求票は（UC 名）、要求文は（UC 名・文）、例は（機能名・ルール名（ルールの外は OUTSIDE_RULE）・シナリオ名）、他は（表の名前）
export function elementKey(kind: ElementKind, parts: (string | null)[]): string {
  return JSON.stringify([kind, ...parts]);
}

// 重ね合わせの側が、要素の同一性から区分を引く。差分に無い（変わっていない・どちらの版にも無い）要素は undefined
export function diffIndex(diff: SpecDiff): (kind: ElementKind, parts: (string | null)[]) => ElementDiff | undefined {
  const byKey = new Map(diff.elements.map((e) => [e.key, e] as const));
  return (kind, parts) => byKey.get(elementKey(kind, parts));
}

// 1件の記録の比べる中身。欄名 → 比べるための値。無い欄は null
type Fields = Map<string, string | null>;

interface Element {
  kind: ElementKind;
  key: string;
  identity: (string | null)[];
  name: string;
  // 比べる欄の定義の順。表の定義に無いキーは含めず、比べるときに後ろへ足す
  fieldOrder: readonly string[];
  // 同じ版で同じ同一性を持つ記録の全て
  records: Fields[];
}

// 値の並びを集合として比べる形にする（順を問わず、重なりを1つとみなす）
function setOf(values: string[]): string {
  return JSON.stringify([...new Set(values)].sort());
}

// 表の記録の比べる中身。並びの型のキーと「、」区切りのキーは集合、文字列は前後の空白を除いた値（無い・空・null は ''）。
// 仮説だけはキーの有無も比べる（無いは null、空の並びは '[]'）。未決は（欄・内容）の組の集合。表の定義に無いキーは値をそのまま比べる
function rowFields(row: Row, identity: readonly string[]): Fields {
  const fields: Fields = new Map();
  for (const [key, type] of Object.entries(row.def.keys)) {
    if (identity.includes(key)) continue;
    if (key === HYPOTHESIS) fields.set(key, Object.hasOwn(row.data, key) ? setOf(list(row, key)) : null);
    // 未決は、読めた項目の（欄・内容）の組の集合。キーが無ければ空の集合
    else if (type === 'open') fields.set(key, setOf(row.open.map((m) => JSON.stringify([m.key, m.content]))));
    else if (type === 'list' || row.def.splitKeys.includes(key)) fields.set(key, setOf(list(row, key)));
    else fields.set(key, str(row, key));
  }
  for (const [key, value] of Object.entries(row.data)) {
    if (!Object.hasOwn(row.def.keys, key)) fields.set(key, JSON.stringify(value) ?? null);
  }
  return fields;
}

function fieldOrderOf(row: Row, identity: readonly string[]): string[] {
  return Object.keys(row.def.keys).filter((k) => !identity.includes(k));
}

function transitionName(model: string, from: string | null, to: string | null, uc: string | null): string {
  return `${model}/${from ?? '（開始）'}→${to ?? '（終端）'}${uc === null ? '' : `（${uc}）`}`;
}

// 1版の中身から要素を集める。同じ同一性の記録は1つの要素にまとめる。Map の並びが出現順になる
function collect(sources: Sources): Map<string, Element> {
  const elements = new Map<string, Element>();
  const add = (kind: ElementKind, parts: (string | null)[], name: string, fieldOrder: readonly string[], fields: Fields) => {
    const key = elementKey(kind, parts);
    const found = elements.get(key);
    if (found === undefined) elements.set(key, { kind, key, identity: parts, name, fieldOrder, records: [fields] });
    else found.records.push(fields);
  };

  const rows = loadTables(sources, []);
  for (const r of rows['state']) {
    const from = str(r, '状態') || null;
    const to = str(r, '遷移先状態') || null;
    const uc = str(r, '遷移UC') || null;
    // 状態は、その状態モデルの記録の遷移元か遷移先に現れれば在る。比べる中身は持たない
    for (const s of [from, to]) if (s !== null) add('状態', [r.name, s], `${r.name}/${s}`, [], new Map());
    add(
      '遷移',
      [r.name, from, to, uc],
      transitionName(r.name, from, to, uc),
      fieldOrderOf(r, TRANSITION_IDENTITY),
      rowFields(r, TRANSITION_IDENTITY),
    );
  }
  for (const { id, kind } of NAMED_TABLES) {
    for (const r of rows[id]) {
      const identity = [r.def.nameKey];
      add(kind, [r.name], r.name, fieldOrderOf(r, identity), rowFields(r, identity));
    }
  }

  // 要求票と要求文。表題から UC 名を読めない票は同一性を取れないので比べない
  for (const { text } of sources.requirements) {
    const req = parseRequirement(text);
    if (req.ucName === null) continue;
    const lines = req.lines.map((l) => ({
      text: l.text,
      reason: l.reason ?? '',
      // 参照の欄の要素の文字列の集合。欄が無い・空・「なし」は空の集合
      rdra: setOf(parseReferences(l.rdra).map((ref) => ref.raw)),
    }));
    add(
      '要求票',
      [req.ucName],
      req.ucName,
      ['理由', '要求文'],
      new Map([
        ['理由', req.reason ?? ''],
        ['要求文', setOf(lines.map((l) => JSON.stringify([l.text, l.reason, l.rdra])))],
      ]),
    );
    for (const l of lines) {
      add('要求文', [req.ucName, l.text], l.text, ['理由', 'RDRA'], new Map([['理由', l.reason], ['RDRA', l.rdra]]));
    }
  }

  // 例。Gherkin として読めない例と機能の無い例は比べない。手順は展開した1件ごとに順を含めて比べ、展開した件どうしの順は問わない
  for (const { text } of sources.examples) {
    const parsed = parseExample(text);
    if (!parsed.ok || parsed.feature === null) continue;
    const feature = parsed.feature;
    const scenario = (rule: string, s: ExampleScenario) =>
      add('例', [feature.name, rule, s.name], s.name, ['手順'], new Map([['手順', setOf(s.expansions.map((e) => JSON.stringify(e.steps)))]]));
    for (const r of feature.rules) for (const s of r.scenarios) scenario(r.name, s);
    for (const s of feature.looseScenarios) scenario(OUTSIDE_RULE, s);
  }
  return elements;
}

function sameSet<T>(a: Set<T>, b: Set<T>): boolean {
  return a.size === b.size && [...a].every((x) => b.has(x));
}

// 両版にある要素の変わった欄。変わっていなければ空。
// 記録ごとに比べる欄の値の組を作り、組の集合（順を問わない）で比べる。違うとき、変わった欄は
// (1) 欄ごとの値の集合が違う欄、(2) それが無ければ、どちらかの版の記録の間で2つ以上の値を持つ欄
function changedFields(base: Element, head: Element): string[] {
  const unknown = new Set<string>();
  for (const r of [...base.records, ...head.records]) for (const k of r.keys()) if (!head.fieldOrder.includes(k)) unknown.add(k);
  const names = [...head.fieldOrder, ...[...unknown].sort()];
  const tuples = (records: Fields[]) => new Set(records.map((r) => JSON.stringify(names.map((n) => r.get(n) ?? null))));
  if (sameSet(tuples(base.records), tuples(head.records))) return [];
  const valuesOf = (records: Fields[], name: string) => new Set(records.map((r) => r.get(name) ?? null));
  const differing = names.filter((n) => !sameSet(valuesOf(base.records, n), valuesOf(head.records, n)));
  if (differing.length > 0) return differing;
  return names.filter((n) => valuesOf(base.records, n).size > 1 || valuesOf(head.records, n).size > 1);
}

export function diffSources(base: Sources, head: Sources): SpecDiff {
  const before = collect(base);
  const after = collect(head);
  const elements: ElementDiff[] = [];
  for (const kind of KINDS) {
    for (const e of after.values()) {
      if (e.kind !== kind) continue;
      const old = before.get(e.key);
      if (old === undefined) {
        elements.push({ kind, key: e.key, identity: e.identity, name: e.name, status: 'added', changed: [] });
        continue;
      }
      const changed = changedFields(old, e);
      if (changed.length > 0) elements.push({ kind, key: e.key, identity: e.identity, name: e.name, status: 'changed', changed });
    }
    for (const e of before.values()) {
      if (e.kind === kind && !after.has(e.key)) elements.push({ kind, key: e.key, identity: e.identity, name: e.name, status: 'removed', changed: [] });
    }
  }
  return { elements };
}
