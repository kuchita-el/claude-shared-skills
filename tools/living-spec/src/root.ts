// 正本の根の探索。起点のディレクトリから親へ1段ずつ辿り、最も近い目印のディレクトリを根にする。
// 目印: .living-spec.json が在る（種類を問わない）か、既定の表の置き場（DEFAULT_LAYOUT.tables）がディレクトリとして在る。
//   後者は、間のディレクトリか置き場自身が .living-spec.json を持てば数えない。
// 境界: .git が在る（ディレクトリかファイルかを問わない）、かつ submodule でない。境界のディレクトリ自身の目印は見るが、その上へは辿らない。
// submodule: 親の作業ツリー（上へ辿って最初に .git を持つディレクトリ）の .gitmodules の path に載るディレクトリ。
// 置き場の検証: 置き場（join(根, 値)）が根の中にあり、根からの相対の先頭以外に既定の表の置き場の並びを含まず、
//   置き場そのものを起点にした探索が根自身を返すとき、置き場は根に属する。
// パスは絶対化したものを字面のまま扱い、シンボリックリンクは解かない（在るか・種類はリンクを辿って見る）。
import { type Stats, readFileSync, statSync } from 'node:fs';
import { dirname, join, relative, sep } from 'node:path';
import { CONFIG_FILE, DEFAULT_LAYOUT, type Layout } from './schema.ts';

export interface RootFound {
  found: true;
  root: string;
}

export interface RootNotFound {
  found: false;
  // 探索を始めたディレクトリ
  start: string;
  // 探索を止めた境界。境界に当たらずファイルシステムの根まで辿ったときは null
  boundary: string | null;
}

export type RootSearch = RootFound | RootNotFound;

// 根の探索・置き場の検証を続けられないときの誤り。入口がこの型を捕えて終了コード 2 で止める
export class SearchError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'SearchError';
  }
}

// 無い場合以外の読み取りの失敗。読もうとしたパスと理由（code）を持つ
export class RootSearchError extends SearchError {
  readonly path: string;
  readonly reason: string;
  constructor(path: string, reason: string) {
    super(`根の探索で読めない: ${path}（${reason}）`);
    this.name = 'RootSearchError';
    this.path = path;
    this.reason = reason;
  }
}

function reasonOf(e: unknown): string {
  const code = (e as NodeJS.ErrnoException).code;
  return typeof code === 'string' ? code : String(e);
}

// p が在れば種類を、無ければ（途中がファイルのときも）undefined を返す。それ以外の読み取りの失敗は RootSearchError にして投げる
export function statIfExists(p: string): Stats | undefined {
  try {
    return statSync(p, { throwIfNoEntry: false });
  } catch (e) {
    throw new RootSearchError(p, reasonOf(e));
  }
}

// " で始まる値: 閉じる " までを値とし（\" と \\ を解く）、その後ろ（注釈）は捨てる。閉じなければ行末まで
function unquote(rest: string): string {
  let value = '';
  for (let i = 1; i < rest.length; i++) {
    const c = rest[i];
    if (c === '"') break;
    if (c === '\\' && (rest[i + 1] === '"' || rest[i + 1] === '\\')) {
      value += rest[i + 1];
      i++;
      continue;
    }
    value += c;
  }
  return value;
}

// 囲まない値: # か ; から後ろ（注釈）を捨てる
function uncomment(rest: string): string {
  const cut = rest.search(/[#;]/);
  return cut >= 0 ? rest.slice(0, cut).trim() : rest;
}

// .gitmodules の本文から、submodule の節の path の値の並びを返す
export function readGitmodulePaths(text: string): string[] {
  const paths: string[] = [];
  let inSubmodule = false;
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (line === '' || line.startsWith('#') || line.startsWith(';')) continue;
    if (line.startsWith('[')) {
      inSubmodule = line.toLowerCase().startsWith('[submodule');
      continue;
    }
    if (!inSubmodule) continue;
    const eq = line.indexOf('=');
    if (eq < 0 || line.slice(0, eq).trim().toLowerCase() !== 'path') continue;
    const rest = line.slice(eq + 1).trim();
    paths.push((rest.startsWith('"') ? unquote(rest) : uncomment(rest)).replace(/\/+$/, ''));
  }
  return paths;
}

// 作業ツリー S の .gitmodules の path の値。無ければ（ENOENT・ENOTDIR）空
function gitmodulePaths(S: string): string[] {
  const file = join(S, '.gitmodules');
  let text: string;
  try {
    text = readFileSync(file, 'utf8');
  } catch (e) {
    const code = (e as NodeJS.ErrnoException).code;
    if (code === 'ENOENT' || code === 'ENOTDIR') return [];
    throw new RootSearchError(file, reasonOf(e));
  }
  return readGitmodulePaths(text);
}

function isSubmodule(dir: string): boolean {
  let S = dirname(dir);
  for (;;) {
    if (statIfExists(join(S, '.git')) !== undefined) break;
    const parent = dirname(S);
    if (parent === S) return false;
    S = parent;
  }
  const rel = relative(S, dir).split(sep).join('/');
  return gitmodulePaths(S).includes(rel);
}

// 既定の表の置き場の区切りの並び（docs/rdra なら ['docs', 'rdra']）
const TABLES_SEGMENTS = DEFAULT_LAYOUT.tables.split('/');

function isMarker(dir: string): boolean {
  if (statIfExists(join(dir, CONFIG_FILE)) !== undefined) return true;
  if (statIfExists(join(dir, DEFAULT_LAYOUT.tables))?.isDirectory() !== true) return false;
  // dir と既定の表の置き場の間のディレクトリか、置き場自身が設定を持てば、設定を持つ側が根になるので dir の目印に数えない
  for (let i = 1; i <= TABLES_SEGMENTS.length; i++) {
    if (statIfExists(join(dir, ...TABLES_SEGMENTS.slice(0, i), CONFIG_FILE)) !== undefined) return false;
  }
  return true;
}

function isBoundary(dir: string): boolean {
  return statIfExists(join(dir, '.git')) !== undefined && !isSubmodule(dir);
}

// startDir は絶対パスで渡す。存在しないディレクトリは目印にも境界にもならず、親へ進む
export function findRoot(startDir: string): RootSearch {
  let dir = startDir;
  for (;;) {
    if (isMarker(dir)) return { found: true, root: dir };
    if (isBoundary(dir)) return { found: false, start: startDir, boundary: dir };
    const parent = dirname(dir);
    if (parent === dir) return { found: false, start: startDir, boundary: null };
    dir = parent;
  }
}

export function formatNoRoot(result: RootNotFound): string {
  const searched = join(result.start, DEFAULT_LAYOUT.tables);
  const boundary = result.boundary === null ? '境界なし' : `境界: ${result.boundary}`;
  return (
    `正本が見つからない: ${result.start} から上へ辿っても、${CONFIG_FILE} か ${DEFAULT_LAYOUT.tables} を持つディレクトリが無い` +
    `（探した表の置き場: ${searched}。${boundary}）。根の中で実行するか、起点を引数で渡す`
  );
}

// 区切り単位の包含。p が dir と同じか dir の下なら真（/a/bc は /a/b の下ではない）。字面で比べる
export function isWithin(p: string, dir: string): boolean {
  return p === dir || p.startsWith(dir.endsWith(sep) ? dir : dir + sep);
}

// 検証する置き場のキー（output は置き場ではないので含めない）
export const PLACEMENT_KEYS = ['tables', 'requirements', 'examples'] as const;

export type PlacementKey = (typeof PLACEMENT_KEYS)[number];

interface MisplacementBase {
  key: PlacementKey;
  value: string;
  // 置き場の絶対パス（join(根, 値)）
  path: string;
}

// 根に属さない置き場。形は、根の外・別の根の中（other は置き場自身の場合を含む）・境界の向こうの3つ
export type Misplacement =
  | (MisplacementBase & { kind: 'outside' })
  // fromValue: 値の途中の既定の表の置き場の並びから決めた（置き場の有無によらない）。other はその並びの上のディレクトリ
  | (MisplacementBase & { kind: 'other-root'; other: string; fromValue: boolean })
  | (MisplacementBase & { kind: 'boundary'; boundary: string });

// 根から置き場への相対の区切りの並びの、先頭以外の位置に既定の表の置き場の並びがあれば、その位置より上のディレクトリを返す。
// 置き場を作るとそのディレクトリが目印になるため。複数あれば置き場に最も近い位置を取る（探索が最も近い目印を根にするのと同じ）
function layoutAncestor(root: string, path: string): string | undefined {
  const segments = relative(root, path).split(sep);
  const n = TABLES_SEGMENTS.length;
  for (let i = segments.length - n; i >= 1; i--) {
    if (TABLES_SEGMENTS.every((s, j) => segments[i + j] === s)) return join(root, ...segments.slice(0, i));
  }
  return undefined;
}

// root は findRoot が返した根（目印を持つ絶対パス）。置き場が無くても検証する（無いディレクトリは目印にならない）。
// 値の途中に既定の表の置き場の並びがあれば、置き場の有無によらず別の根の中とする。
// 読み取りの失敗は RootSearchError を、根の目印が途中で消えたときは SearchError を投げる
export function findMisplacements(root: string, layout: Pick<Layout, PlacementKey>): Misplacement[] {
  const found: Misplacement[] = [];
  for (const key of PLACEMENT_KEYS) {
    const value = layout[key];
    const path = join(root, value);
    if (!isWithin(path, root)) {
      found.push({ key, value, path, kind: 'outside' });
      continue;
    }
    const ancestor = layoutAncestor(root, path);
    if (ancestor !== undefined) {
      found.push({ key, value, path, kind: 'other-root', other: ancestor, fromValue: true });
      continue;
    }
    const search = findRoot(path);
    if (search.found) {
      if (search.root !== root) found.push({ key, value, path, kind: 'other-root', other: search.root, fromValue: false });
      continue;
    }
    // 根の中から辿れば、根に着くか、その手前の境界で止まる。境界なしは、根を決めた後に根の目印が消えたときだけ起きる
    if (search.boundary === null) throw new SearchError('根の目印が検査中に見つからなくなった');
    found.push({ key, value, path, kind: 'boundary', boundary: search.boundary });
  }
  return found;
}

function describe(m: Misplacement): string {
  switch (m.kind) {
    case 'outside':
      return `${m.path} は根の外にある`;
    case 'other-root':
      return m.fromValue
        ? `${m.path} は値の途中に ${DEFAULT_LAYOUT.tables} を含み、${m.other} 以下の別の根の中に入る（置き場がまだ無くても誤りにする）`
        : `${m.path} は別の根 ${m.other} の中にある`;
    case 'boundary':
      return `${m.path} と根の間に境界 ${m.boundary}（submodule でない .git）がある`;
  }
}

export function formatMisplacements(root: string, misplacements: Misplacement[]): string {
  return [
    `根に属さない置き場がある（根: ${root}）:`,
    ...misplacements.map((m) => `  - ${m.key}「${m.value}」→ ${describe(m)}`),
    `置き場は根の下に置き、根との間に別の根（${CONFIG_FILE} か ${DEFAULT_LAYOUT.tables} を持つディレクトリ）や submodule でない .git を挟まない。` +
      '別の正本にしたい領域は、その領域を根にする。',
  ].join('\n');
}
