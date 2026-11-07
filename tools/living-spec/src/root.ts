// 正本の根の探索。起点のディレクトリから親へ1段ずつ辿り、最も近い目印のディレクトリを根にする。
// 目印: .living-spec.json が在る（種類を問わない）か、既定の表の置き場（DEFAULT_LAYOUT.tables）がディレクトリとして在る。
// 境界: .git が在る（ディレクトリかファイルかを問わない）。境界のディレクトリ自身の目印は見るが、その上へは辿らない。
// パスは絶対化したものを字面のまま扱い、シンボリックリンクは解かない（在るか・種類はリンクを辿って見る）。
import { type Stats, statSync } from 'node:fs';
import { dirname, join } from 'node:path';
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

// p が在れば種類を、無ければ（途中がファイルのときも）undefined を返す。それ以外の読み取りの失敗は例外のまま投げる
export function statIfExists(p: string): Stats | undefined {
  return statSync(p, { throwIfNoEntry: false });
}

function isMarker(dir: string): boolean {
  if (statIfExists(join(dir, CONFIG_FILE)) !== undefined) return true;
  return statIfExists(join(dir, DEFAULT_LAYOUT.tables))?.isDirectory() === true;
}

function isBoundary(dir: string): boolean {
  return statIfExists(join(dir, '.git')) !== undefined;
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
