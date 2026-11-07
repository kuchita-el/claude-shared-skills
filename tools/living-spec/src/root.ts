// 正本の根の探索。起点のディレクトリから親へ1段ずつ辿り、最も近い目印のディレクトリを根にする。
// 目印: .living-spec.json が在る（種類を問わない）か、既定の表の置き場（DEFAULT_LAYOUT.tables）がディレクトリとして在る。
// 境界: .git が在る（ディレクトリかファイルかを問わない）、かつ submodule でない。境界のディレクトリ自身の目印は見るが、その上へは辿らない。
// submodule: 親の作業ツリー（上へ辿って最初に .git を持つディレクトリ）の .gitmodules の path に載るディレクトリ。
// パスは絶対化したものを字面のまま扱い、シンボリックリンクは解かない（在るか・種類はリンクを辿って見る）。
import { type Stats, readFileSync, statSync } from 'node:fs';
import { dirname, join, relative, sep } from 'node:path';
import { CONFIG_FILE, DEFAULT_LAYOUT } from './schema.ts';

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

// 無い場合以外の読み取りの失敗。読もうとしたパスと理由（code）を持つ
export class RootSearchError extends Error {
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
    let value = line.slice(eq + 1).trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.slice(1, -1).replace(/\\(["\\])/g, '$1');
    } else {
      const cut = value.search(/[#;]/);
      if (cut >= 0) value = value.slice(0, cut).trim();
    }
    paths.push(value.replace(/\/+$/, ''));
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

function isMarker(dir: string): boolean {
  if (statIfExists(join(dir, CONFIG_FILE)) !== undefined) return true;
  return statIfExists(join(dir, DEFAULT_LAYOUT.tables))?.isDirectory() === true;
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
