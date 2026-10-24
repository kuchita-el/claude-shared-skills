// RDRA の表・要求票・例の機械検査。
import { existsSync, readFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { parseDocument } from 'yaml';
import { TABLES, tableById } from './schema.ts';
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
  | 'requirement-reference'
  | 'requirement-name-absent'
  | 'requirement-missing'
  | 'requirement-coverage'
  | 'example-feature'
  | 'example-rule-mismatch'
  | 'example-missing'
  | 'example-limit'
  | 'example-duplicate'
  | 'example-syntax';

export interface Violation {
  rule: Rule;
  file: string;
  target: string;
  detail: string;
}

type Data = Record<string, unknown>;

interface Row {
  def: TableDef;
  data: Data;
  // 名前キーの値。名前が欠落・空・非文字列のレコードは意味検査から外すため、ここへは入らない
  name: string;
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

function loadTable(root: string, def: TableDef, out: Violation[]): Row[] {
  const path = join(root, def.file);
  if (!existsSync(path)) return [];
  const tableTarget = `表:${basename(def.file)}`;
  const doc = parseDocument(readFileSync(path, 'utf8'));
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
    for (const [key, value] of Object.entries(item)) {
      const type = def.keys[key];
      if (type === undefined) {
        out.push({ rule: 'unknown-key', file: def.file, target, detail: `許されないキー『${key}』` });
        continue;
      }
      if (key === def.nameKey) continue;
      if (!typeOk(value, type, def.emptyOkKeys.includes(key))) {
        out.push({
          rule: 'invalid-shape',
          file: def.file,
          target,
          detail: `キー『${key}』の値が${typeLabel(type)}になっていない`,
        });
      }
    }
    if (hasName) rows.push({ def, data: item, name });
  });
  return rows;
}

function rowTarget(row: Row): string {
  if (row.def.id === 'state') return stateTarget(row.name, one(row, '状態'));
  return `${row.def.kind}:${row.name}`;
}

export function loadTables(root: string, out: Violation[]): Record<string, Row[]> {
  const rows: Record<string, Row[]> = {};
  for (const def of TABLES) rows[def.id] = loadTable(root, def, out);
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
  };
}

// 要求票・例の書き漏らしの向き（下の層が追い付いていない）。checkRepo には含めない（CLI の --doc-missing で走らせる）。
// 対象は requirement-missing・requirement-coverage・example-missing。
// 表の構造の違反は checkRepo が拾うため、ここでは読めた表の内容だけを使う
export function checkDocMissing(root: string): Violation[] {
  return checkTrace(root, traceContext(loadTables(root, []))).docMissing;
}

export function checkRepo(root: string): Violation[] {
  const out: Violation[] = [];
  const rows = loadTables(root, out);

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

  // 未接続: どの UC からも参照されていないアクター・外部システム・情報・条件
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
  out.push(...checkTrace(root, traceContext(rows)).checked);

  return out;
}
