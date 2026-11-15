// 共有の記憶（Shared Memory）の検査器。記録の形式を検査し、索引を生成する。
// 形式の正本は references/format.md であり、ここはその規則に従う実装である。
// 規則を変えるときは、format.md を先に改める。
//
// 使い方は USAGE を見る。違反は「パス:規則: 説明」の形で標準出力へ出す。
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const USAGE = `usage: memory.mjs check ROOT | memory.mjs index ROOT [--write]
  ROOT: 記憶の根。records/ と index.md を直下に持つディレクトリ。
  check: 記録の形式と、index.md が記録と一致することを検査する。
  index: 索引を標準出力へ出す。--write を付けると ROOT/index.md へ書く。
  終了コード: 0 違反なし、1 違反あり、2 引数の誤りか検査できない入力。`;

const ID = /^MEM-[0-9]{12}-[0-9]{2}$/;
const FILE_NAME = /^(MEM-[0-9]{12}-[0-9]{2})-[a-z0-9]+(?:-[a-z0-9]+)*\.md$/;
const DATE = /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/;
const KEY_LINE = /^([A-Za-z][A-Za-z0-9_-]*):(?:[ \t]+(.*))?$/;
const ITEM_LINE = /^[ \t]*-[ \t]+(.*)$/;
const ENUMS = {
  type: ['knowledge', 'experience', 'belief', 'decision', 'evolution'],
  author: ['human', 'ai', 'joint'],
  verification: ['verified', 'unverified'],
  confidence: ['high', 'medium', 'low'],
};
const SCALARS = ['id', 'type', 'title', 'author', 'verification', 'confidence', 'applies-when', 'created', 'updated'];
const OPTIONAL_SCALARS = ['superseded-by', 'moved-to'];
const LISTS = ['sources', 'from', 'to'];
const KNOWN = new Set([...SCALARS, ...OPTIONAL_SCALARS, ...LISTS]);
const INDEX_HEADER = [
  '# 索引',
  '',
  '<!-- 検査器が生成する。手で編集しない。作り直すには index --write を使う。 -->',
  '',
  '| 識別子 | 種類 | 主張 | 当てはまる条件 | 検証 |',
  '|---|---|---|---|---|',
];

class Unreadable extends Error {}

/**
 * 値を1つ読む。引用符で囲んだ値は中身を返す。囲まない値は、YAML として別の意味になる形を拒む。
 * @param {string} raw
 * @returns {string}
 */
function scalar(raw) {
  const text = raw.trim();
  const quoted = text.match(/^"(.*)"$/) ?? text.match(/^'(.*)'$/);
  if (quoted) return quoted[1];
  if (/^[\[{>|*&!%@`"']/.test(text) || text.includes(': ') || text.includes(' #') || text.endsWith(':')) {
    throw new Unreadable(`値を引用符で囲む: ${text}`);
  }
  return text;
}

/**
 * front-matter を読む。知っているキーだけを厳密に読み、知らないキーは値ごと読み飛ばす。
 * @param {string} source
 * @returns {Map<string, string | string[]>}
 */
function frontMatter(source) {
  const lines = source.split('\n').map((line) => line.replace(/\r$/, ''));
  if (lines[0] !== '---') throw new Unreadable('1行目が --- でない');
  const end = lines.indexOf('---', 1);
  if (end === -1) throw new Unreadable('front-matter を閉じる --- が無い');
  const fields = new Map();
  let index = 1;
  while (index < end) {
    const line = lines[index];
    index += 1;
    if (line.trim() === '' || line.startsWith('#')) continue;
    const matched = line.match(KEY_LINE);
    if (!matched) throw new Unreadable(`読めない行: ${line}`);
    const [, key, rest] = matched;
    const nested = [];
    while (index < end && (/^([ \t]|-[ \t])/.test(lines[index]) || lines[index].trim() === '')) {
      if (lines[index].trim() !== '') nested.push(lines[index]);
      index += 1;
    }
    if (!KNOWN.has(key)) continue;
    if (fields.has(key)) throw new Unreadable(`キーが重複している: ${key}`);
    if (LISTS.includes(key)) {
      if (rest !== undefined && rest.trim() !== '') throw new Unreadable(`${key} は「- 値」の行で書く`);
      fields.set(key, nested.map((item) => {
        const itemMatched = item.match(ITEM_LINE);
        if (!itemMatched) throw new Unreadable(`${key} の読めない行: ${item.trim()}`);
        return scalar(itemMatched[1]);
      }));
    } else {
      if (nested.length > 0 || rest === undefined) throw new Unreadable(`${key} は1行の値で書く`);
      fields.set(key, scalar(rest));
    }
  }
  return fields;
}

/**
 * 記録を1件ずつ読み、1件の中で決まる違反を集める。
 * @param {string} root
 * @returns {{ records: { path: string, file: string, fields: Map<string, string | string[]> }[], violations: string[] }}
 */
function load(root) {
  const dir = join(root, 'records');
  const violations = [];
  const records = [];
  if (!existsSync(dir)) return { records, violations };
  for (const file of readdirSync(dir).filter((name) => name.endsWith('.md')).sort()) {
    const path = `records/${file}`;
    const report = (rule, message) => violations.push(`${path}:${rule}: ${message}`);
    let fields;
    try {
      fields = frontMatter(readFileSync(join(dir, file), 'utf8'));
    } catch (error) {
      if (!(error instanceof Unreadable)) throw error;
      report('front-matter', error.message);
      continue;
    }
    for (const key of [...SCALARS, 'sources']) {
      const value = fields.get(key);
      if (value === undefined || value.length === 0) report('required', `${key} が無い`);
    }
    for (const [key, allowed] of Object.entries(ENUMS)) {
      const value = fields.get(key);
      if (value !== undefined && !allowed.includes(value)) report('value', `${key} は ${allowed.join(' / ')} のいずれか: ${value}`);
    }
    for (const key of ['created', 'updated']) {
      const value = fields.get(key);
      if (value !== undefined && !DATE.test(value)) report('value', `${key} は YYYY-MM-DD の形で書く: ${value}`);
    }
    const id = fields.get('id');
    if (id !== undefined && !ID.test(id)) report('value', `id は MEM-<12桁>-<2桁> の形で書く: ${id}`);
    const named = file.match(FILE_NAME);
    if (!named) report('filename', 'ファイル名は <id>-<英小文字と数字をハイフンでつないだ名前>.md の形にする');
    else if (id !== undefined && named[1] !== id) report('filename', `ファイル名の識別子が id と一致しない: ${id}`);
    if (fields.has('superseded-by') && fields.has('moved-to')) report('value', 'superseded-by と moved-to は同時に書かない');
    const isEvolution = fields.get('type') === 'evolution';
    for (const key of ['from', 'to']) {
      const listed = fields.get(key) ?? [];
      if (isEvolution && listed.length === 0) report('evolution', `evolution は ${key} に記録を1件以上書く`);
      if (!isEvolution && fields.has(key)) report('evolution', `${key} は evolution だけが持つ`);
    }
    records.push({ path, file, fields });
  }
  return { records, violations };
}

/**
 * 記録どうしの関係で決まる違反を集める。
 * @param {ReturnType<typeof load>['records']} records
 * @returns {string[]}
 */
function relations(records) {
  const violations = [];
  const byId = new Map();
  for (const record of records) {
    const id = record.fields.get('id');
    if (id === undefined) continue;
    if (byId.has(id)) violations.push(`${record.path}:duplicate-id: ${id} は ${byId.get(id).path} と重複している`);
    else byId.set(id, record);
  }
  const evolutions = records.filter((record) => record.fields.get('type') === 'evolution');
  for (const record of records) {
    const refer = (key, target) => {
      if (!byId.has(target)) violations.push(`${record.path}:dangling: ${key} が指す記録が無い: ${target}`);
    };
    const next = record.fields.get('superseded-by');
    if (next !== undefined) {
      refer('superseded-by', next);
      const id = record.fields.get('id');
      const explained = evolutions.some((evolution) => (evolution.fields.get('from') ?? []).includes(id)
        && (evolution.fields.get('to') ?? []).includes(next));
      if (!explained) violations.push(`${record.path}:replacement: ${next} への置き換えを説明する evolution が無い`);
    }
    for (const key of ['from', 'to']) for (const target of record.fields.get(key) ?? []) refer(key, target);
  }
  for (const evolution of evolutions) {
    const to = evolution.fields.get('to') ?? [];
    for (const old of evolution.fields.get('from') ?? []) {
      const next = byId.get(old)?.fields.get('superseded-by');
      if (byId.has(old) && !to.includes(next)) {
        violations.push(`${evolution.path}:replacement: from の ${old} が、to の記録を superseded-by で指していない`);
      }
    }
  }
  return violations;
}

/** @param {string} text */
function cell(text) {
  return text.replaceAll('|', '\\|');
}

/**
 * 索引の本文を作る。置き換え済みの記録と、記憶の外へ移した記録は載せない。
 * @param {ReturnType<typeof load>['records']} records
 * @returns {string}
 */
function renderIndex(records) {
  const rows = records
    .filter((record) => !record.fields.has('superseded-by') && !record.fields.has('moved-to'))
    .filter((record) => ['id', 'type', 'title', 'applies-when', 'verification'].every((key) => record.fields.has(key)))
    .sort((a, b) => (a.fields.get('id') < b.fields.get('id') ? -1 : 1))
    .map((record) => {
      const field = (key) => cell(record.fields.get(key));
      return `| [${field('id')}](${record.path}) | ${field('type')} | ${field('title')} | ${field('applies-when')} | ${field('verification')} |`;
    });
  return [...INDEX_HEADER, ...rows, ''].join('\n');
}

function main(argv) {
  const [command, root, ...options] = argv;
  const write = options.length === 1 && options[0] === '--write';
  const usable = (command === 'check' && options.length === 0) || (command === 'index' && (options.length === 0 || write));
  if (!usable || root === undefined) {
    console.error(USAGE);
    return 2;
  }
  if (!existsSync(root) || !statSync(root).isDirectory()) {
    console.error(`memory: 記憶の根がディレクトリでない: ${root}`);
    return 2;
  }
  const { records, violations } = load(root);
  const indexPath = join(root, 'index.md');
  if (command === 'index') {
    if (write) writeFileSync(indexPath, renderIndex(records));
    else process.stdout.write(renderIndex(records));
    return 0;
  }
  violations.push(...relations(records));
  const hasIndex = existsSync(indexPath);
  if (records.length > 0 || hasIndex) {
    if (!hasIndex) violations.push('index.md:index: 索引が無い。index --write で作る');
    else if (readFileSync(indexPath, 'utf8') !== renderIndex(records)) {
      violations.push('index.md:index: 索引が記録と一致しない。index --write で作り直す');
    }
  }
  for (const violation of violations) console.log(violation);
  return violations.length === 0 ? 0 : 1;
}

try {
  process.exitCode = main(process.argv.slice(2));
} catch (error) {
  console.error(`memory: 検査できない: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 2;
}
