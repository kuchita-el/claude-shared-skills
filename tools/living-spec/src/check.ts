// RDRA の表・要求票・例の機械検査。
import { basename } from 'node:path';
import { LineCounter, isAlias, isMap as isYamlMap, isScalar, isSeq, parseDocument } from 'yaml';
import type { Node as YamlNode } from 'yaml';
import { OPEN, TABLES, tableById } from './schema.ts';
import { readSources } from './sources.ts';
import type { Sources } from './sources.ts';
import type { TableDef, ValueType } from './schema.ts';
import { checkTrace } from './trace.ts';
import type { TraceContext } from './trace.ts';

export type Rule =
  | 'unknown-key'
  | 'invalid-shape'
  | 'undefined-reference'
  | 'unconnected'
  | 'duplicate-name'
  | 'requirement-uc'
  | 'requirement-structure'
  | 'requirement-reference'
  | 'requirement-missing'
  | 'requirement-coverage'
  | 'example-feature'
  | 'example-rule-mismatch'
  | 'example-missing'
  | 'example-duplicate'
  | 'example-syntax';

export interface Violation {
  rule: Rule;
  file: string;
  target: string;
  detail: string;
}

type Data = Record<string, unknown>;

// 未決の項目1つ。key は文で書く欄、content は未決の内容（前後の空白を除き、改行をまたぐ空白を1つの空白にしたもの）、
// line は項目が表のファイルで始まる行（1から）
export interface OpenMark {
  key: string;
  content: string;
  line: number;
}

interface Row {
  def: TableDef;
  data: Data;
  // 名前キーの値。名前が欠落・空・非文字列のレコードは意味検査から外すため、ここへは入らない
  name: string;
  // 『未決』キーの項目のうち、書式どおりに読めたもの（表の順）。キーが無ければ空
  open: OpenMark[];
}

// 未決の一覧の1項目。target は違反と同じ要素の表し方（種類:名前。状態は 状態:<状態モデル>／<状態>）
export interface OpenEntry extends OpenMark {
  file: string;
  target: string;
}

export function formatViolation(v: Violation): string {
  return `[${v.rule}] ${v.file} ${v.target}: ${v.detail}`;
}

function isMap(v: unknown): v is Data {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

function typeOk(v: unknown, type: ValueType, emptyOk: boolean): boolean {
  if (emptyOk && (v === null || v === '')) return true;
  if (type === 'string') return typeof v === 'string';
  return Array.isArray(v) && v.every((x) => typeof x === 'string');
}

function typeLabel(type: ValueType): string {
  return type === 'string' ? '文字列' : '文字列の並び';
}

// 未決の内容の正規化。前後の空白を除き、改行をまたぐ空白を1つの空白にする（一覧を1項目1行で出すため）
function openContent(v: string): string {
  return v.trim().replace(/\s*\n\s*/g, ' ');
}

// 『未決』キーの値を読み、書式どおりの項目を marks へ、書式の誤りを errors へ入れる。
// 値は1件以上の項目の並びで、各項目は「<文で書く欄>: <未決の内容>」の1組のマップ。欄は表の textKeys のどれか、内容は空白だけでない文字列。
// node はその値の YAML の節で、項目の行を引くために使う（引けなければ fallbackLine）
function readOpen(
  value: unknown,
  def: TableDef,
  node: YamlNode | undefined,
  lineOf: (n: unknown, fallback: number) => number,
  fallbackLine: number,
): { marks: OpenMark[]; errors: string[] } {
  const marks: OpenMark[] = [];
  const errors: string[] = [];
  const allowed = def.textKeys.map((k) => `『${k}』`).join('・');
  if (value === null || (Array.isArray(value) && value.length === 0)) {
    errors.push(`キー『${OPEN}』に項目が無い（決まったらキーごと外す）`);
    return { marks, errors };
  }
  if (!Array.isArray(value)) {
    errors.push(`キー『${OPEN}』の値が項目の並びになっていない（各項目は「<欄>: <未決の内容>」の1組。欄は ${allowed}）`);
    return { marks, errors };
  }
  const items = isSeq(node) ? node.items : [];
  value.forEach((item: unknown, j: number) => {
    const at = `キー『${OPEN}』の${j + 1}番目の項目`;
    if (!isMap(item) || Object.keys(item).length !== 1) {
      errors.push(`${at}が「<欄>: <未決の内容>」の1組になっていない（欄は ${allowed}）`);
      return;
    }
    const [key, content] = Object.entries(item)[0];
    if (!def.textKeys.includes(key)) {
      errors.push(`${at}の欄『${key}』は未決の印を付けられる欄でない（付けられる欄は ${allowed}）`);
      return;
    }
    if (typeof content !== 'string' || content.trim() === '') {
      errors.push(`${at}の未決の内容が空、または文字列でない`);
      return;
    }
    marks.push({ key, content: openContent(content), line: lineOf(items[j], fallbackLine) });
  });
  return { marks, errors };
}

function stateTarget(model: string, state: string): string {
  return `状態:${model}／${state === '' ? '（初期）' : state}`;
}

function one(row: Row, key: string): string {
  const v = row.data[key];
  return typeof v === 'string' ? v.trim() : '';
}

// 参照として読む値の並び。型が定めと違う値も、参照の検査が連鎖して増えないよう寛容に読む
// （型の誤りは invalid-shape が別に拾う）。「、」区切りのキーは分割する。
function values(row: Row, key: string): string[] {
  const v = row.data[key];
  if (typeof v === 'string') {
    if (row.def.splitKeys.includes(key)) {
      return v
        .split('、')
        .map((s) => s.trim())
        .filter((s) => s !== '');
    }
    return v.trim() === '' ? [] : [v.trim()];
  }
  if (Array.isArray(v)) {
    return v.filter((x): x is string => typeof x === 'string' && x.trim() !== '').map((x) => x.trim());
  }
  return [];
}

function loadTable(text: string | undefined, def: TableDef, out: Violation[]): Row[] {
  if (text === undefined) return [];
  const tableTarget = `表:${basename(def.file)}`;
  const lineCounter = new LineCounter();
  const doc = parseDocument(text, { lineCounter });
  // 節の始まりの行（1から）。節でない・位置を持たないときは fallback
  const lineOf = (n: unknown, fallback: number): number => {
    const range = (n as { range?: [number, number, number] | null } | undefined)?.range;
    return range === undefined || range === null ? fallback : lineCounter.linePos(range[0]).line;
  };
  if (doc.errors.length > 0) {
    const msg = doc.errors[0].message.split('\n')[0];
    out.push({ rule: 'invalid-shape', file: def.file, target: tableTarget, detail: `YAML の構文誤り: ${msg}` });
    return [];
  }
  const data: unknown = doc.toJS();
  if (data === null || data === undefined) return [];
  if (!Array.isArray(data)) {
    out.push({
      rule: 'invalid-shape',
      file: def.file,
      target: tableTarget,
      detail: 'トップレベルがレコードの並び（シーケンス）になっていない',
    });
    return [];
  }
  const rows: Row[] = [];
  const recordNodes = isSeq(doc.contents) ? doc.contents.items : [];
  data.forEach((item: unknown, i: number) => {
    const ordinal = `#${i + 1}`;
    if (!isMap(item)) {
      out.push({
        rule: 'invalid-shape',
        file: def.file,
        target: `${def.kind}:${ordinal}`,
        detail: `${i + 1}番目のレコードがマップになっていない`,
      });
      return;
    }
    const nameVal = item[def.nameKey];
    const hasName = typeof nameVal === 'string' && nameVal.trim() !== '';
    const name = hasName ? (nameVal as string).trim() : '';
    let target = `${def.kind}:${hasName ? name : ordinal}`;
    if (def.id === 'state' && hasName) {
      const st = typeof item['状態'] === 'string' ? (item['状態'] as string).trim() : '';
      target = stateTarget(name, st);
    }
    if (!hasName) {
      out.push({
        rule: 'invalid-shape',
        file: def.file,
        target,
        detail: `名前キー『${def.nameKey}』が無い、または空・文字列でない`,
      });
    }
    let open: OpenMark[] = [];
    for (const [key, value] of Object.entries(item)) {
      const type = def.keys[key];
      if (type === undefined) {
        out.push({ rule: 'unknown-key', file: def.file, target, detail: `許されないキー『${key}』` });
        continue;
      }
      if (key === def.nameKey) continue;
      if (type === 'open') {
        const recordNode = recordNodes[i];
        const found = isYamlMap(recordNode)
          ? (recordNode.items.find((p) => isScalar(p.key) && p.key.value === key)?.value as YamlNode | undefined)
          : undefined;
        // 値が別名（*a）なら、指す先の節から項目の行を引く
        const valueNode = isAlias(found) ? (found.resolve(doc) as YamlNode | undefined) : found;
        const read = readOpen(value, def, valueNode, lineOf, lineOf(recordNode, 1));
        open = read.marks;
        for (const detail of read.errors) out.push({ rule: 'invalid-shape', file: def.file, target, detail });
        continue;
      }
      if (!typeOk(value, type, def.emptyOkKeys.includes(key))) {
        out.push({
          rule: 'invalid-shape',
          file: def.file,
          target,
          detail: `キー『${key}』の値が${typeLabel(type)}になっていない`,
        });
      }
    }
    // 条件のキーに値があるのに、要されるキーが無い・空白だけなら落とす。どちらかの値が文字列でないときは上の型の検査に任せる
    for (const [from, to] of Object.entries(def.requires)) {
      const fromVal = item[from];
      if (typeof fromVal !== 'string' || fromVal.trim() === '') continue;
      const toVal = item[to];
      if (toVal !== undefined && (typeof toVal !== 'string' || toVal.trim() !== '')) continue;
      out.push({ rule: 'invalid-shape', file: def.file, target, detail: `キー『${from}』に値があるのに、キー『${to}』が無い、または空` });
    }
    if (hasName) rows.push({ def, data: item, name, open });
  });
  return rows;
}

function rowTarget(row: Row): string {
  if (row.def.id === 'state') return stateTarget(row.name, one(row, '状態'));
  return `${row.def.kind}:${row.name}`;
}

export function loadTables(sources: Sources, out: Violation[]): Record<string, Row[]> {
  const rows: Record<string, Row[]> = {};
  for (const def of TABLES) rows[def.id] = loadTable(sources.tables.get(def.id), def, out);
  return rows;
}

// 要求票・例の検査（名前照合・追跡）に渡す表の内容
function traceContext(rows: Record<string, Row[]>): TraceContext {
  const traceNames = new Map<string, Set<string>>();
  for (const def of TABLES) if (def.id !== 'state') traceNames.set(def.kind, new Set(rows[def.id].map((r) => r.name)));
  traceNames.set('状態モデル', new Set(rows['state'].map((r) => r.name)));
  // 状態の参照は「状態」「遷移先状態」のどちらに現れてもよい（初期遷移の遷移先は「状態」に現れないことがある）
  const stateNamesOf = new Map<string, Set<string>>();
  const transitions: TraceContext['transitions'] = [];
  for (const r of rows['state']) {
    if (!stateNamesOf.has(r.name)) stateNamesOf.set(r.name, new Set());
    const next = one(r, '遷移先状態');
    for (const st of [one(r, '状態'), next]) if (st !== '') stateNamesOf.get(r.name)!.add(st);
    const uc = one(r, '遷移UC');
    if (uc !== '' && next !== '') transitions.push({ model: r.name, uc, next, target: stateTarget(r.name, next) });
  }
  return {
    useCases: rows['use-case'].map((r) => ({
      name: r.name,
      hypothesis: Object.hasOwn(r.data, '仮説'),
      conditions: values(r, '条件'),
    })),
    names: traceNames,
    statesOf: stateNamesOf,
    transitions,
    verifiable: new Set(rows['architecture-characteristic'].filter((r) => one(r, '検証方法') !== '').map((r) => r.name)),
  };
}

// 要求票・例の書き漏らしの向き（下の層が追い付いていない）。checkRepo には含めない（CLI の --doc-missing で走らせる）。
// 対象は requirement-missing・requirement-coverage・example-missing。
// 表の構造の違反は checkRepo が拾うため、ここでは読めた表の内容だけを使う
export function checkDocMissing(root: string): Violation[] {
  return checkDocMissingSources(readSources(root));
}

export function checkDocMissingSources(sources: Sources): Violation[] {
  return checkTrace(sources, traceContext(loadTables(sources, []))).docMissing;
}

// 未決の一覧。表の順・レコードの順・項目の順に並べる。blocking は表の形の違反（invalid-shape）で、
// 1件でもあれば読めなかった表・レコード・項目の未決が一覧から欠けうるため、一覧を出す側はこれを先に見る
export function collectOpen(root: string): { entries: OpenEntry[]; blocking: Violation[] } {
  return collectOpenSources(readSources(root));
}

export function collectOpenSources(sources: Sources): { entries: OpenEntry[]; blocking: Violation[] } {
  const out: Violation[] = [];
  const rows = loadTables(sources, out);
  const entries: OpenEntry[] = [];
  for (const def of TABLES) {
    for (const row of rows[def.id]) {
      for (const m of row.open) entries.push({ ...m, file: def.file, target: rowTarget(row) });
    }
  }
  return { entries, blocking: out.filter((v) => v.rule === 'invalid-shape') };
}

// 未決の一覧の1行。`[未決] <ファイル>:<行> <対象> <欄>: <未決の内容>`
export function formatOpen(e: OpenEntry): string {
  return `[未決] ${e.file}:${e.line} ${e.target} ${e.key}: ${e.content}`;
}

export function checkRepo(root: string): Violation[] {
  return checkSources(readSources(root));
}

// 全体検査の本体。ファイルを読まず、読んだ中身だけから判定する
export function checkSources(sources: Sources): Violation[] {
  const out: Violation[] = [];
  const rows = loadTables(sources, out);

  // 名前の集合。state 表は状態モデルの集合と、状態モデルごとの状態の集合を別に持つ
  const names: Record<string, Set<string>> = {};
  for (const def of TABLES) names[def.id] = new Set(rows[def.id].map((r) => r.name));
  const models = names['state'];
  const statesOf = new Map<string, Set<string>>();
  for (const r of rows['state']) {
    const st = one(r, '状態');
    if (st === '') continue;
    if (!statesOf.has(r.name)) statesOf.set(r.name, new Set());
    statesOf.get(r.name)!.add(st);
  }

  // 未定義の参照（公式の11種）
  interface RefSpec {
    from: string;
    key: string;
    toKind: string;
    exists: (v: string, row: Row) => boolean;
  }
  const has = (id: string) => (v: string) => names[id].has(v);
  const refSpecs: RefSpec[] = [
    { from: 'use-case', key: 'アクター', toKind: 'アクター', exists: has('actor') },
    { from: 'use-case', key: '外部システム', toKind: '外部システム', exists: has('external-system') },
    { from: 'use-case', key: '情報', toKind: '情報', exists: has('information') },
    { from: 'use-case', key: '条件', toKind: '条件', exists: has('condition') },
    { from: 'information', key: '関連情報', toKind: '情報', exists: has('information') },
    { from: 'information', key: '状態モデル', toKind: '状態モデル', exists: (v) => models.has(v) },
    { from: 'information', key: 'バリエーション', toKind: 'バリエーション', exists: has('variation') },
    { from: 'state', key: '遷移UC', toKind: 'UC', exists: has('use-case') },
    {
      from: 'state',
      key: '遷移先状態',
      toKind: '同じ状態モデルの状態',
      exists: (v, row) => statesOf.get(row.name)?.has(v) ?? false,
    },
    { from: 'condition', key: 'バリエーション', toKind: 'バリエーション', exists: has('variation') },
    { from: 'condition', key: '状態モデル', toKind: '状態モデル', exists: (v) => models.has(v) },
  ];
  for (const spec of refSpecs) {
    const def = tableById(spec.from);
    for (const row of rows[spec.from]) {
      for (const v of values(row, spec.key)) {
        if (!spec.exists(v, row)) {
          out.push({
            rule: 'undefined-reference',
            file: def.file,
            target: rowTarget(row),
            detail: `${spec.key}『${v}』が定義されていない（${spec.toKind}）`,
          });
        }
      }
    }
  }

  // 未接続: どの UC からも参照されていないアクター・外部システム・情報・条件。
  // 『仮説』キーを持つレコード（値が空でも持つ扱い）は検証前の状態なので判定しない。仮説の UC からの参照も参照に数える
  const connectSpecs: [string, string][] = [
    ['actor', 'アクター'],
    ['external-system', '外部システム'],
    ['information', '情報'],
    ['condition', '条件'],
  ];
  for (const [id, ucKey] of connectSpecs) {
    const referenced = new Set<string>();
    for (const uc of rows['use-case']) for (const v of values(uc, ucKey)) referenced.add(v);
    const def = tableById(id);
    for (const row of rows[id]) {
      if (Object.hasOwn(row.data, '仮説')) continue;
      if (!referenced.has(row.name)) {
        out.push({
          rule: 'unconnected',
          file: def.file,
          target: rowTarget(row),
          detail: `どの UC の「${ucKey}」からも参照されていない`,
        });
      }
    }
  }

  // 名前の一意。state は（状態モデル, 状態, 遷移UC）の組
  for (const def of TABLES) {
    const seen = new Set<string>();
    const reported = new Set<string>();
    for (const row of rows[def.id]) {
      const key =
        def.id === 'state'
          ? JSON.stringify([row.name, one(row, '状態'), one(row, '遷移UC')])
          : row.name;
      if (seen.has(key) && !reported.has(key)) {
        reported.add(key);
        out.push({
          rule: 'duplicate-name',
          file: def.file,
          target: rowTarget(row),
          detail:
            def.id === 'state'
              ? `（状態モデル, 状態, 遷移UC）の組『${row.name}／${one(row, '状態')}／${one(row, '遷移UC')}』が重複している`
              : `名前『${row.name}』が重複している`,
        });
      }
      seen.add(key);
    }
  }

  // 要求票・例の検査（名前照合・追跡）。書き漏らしの向き（requirement-missing・requirement-coverage・example-missing）は含めない
  out.push(...checkTrace(sources, traceContext(rows)).checked);

  return out;
}
