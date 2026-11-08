// 検査と描画の入力（表・要求票・例の中身）。ファイルを読む処理と判定を分け、判定をファイルなしで試験できるようにする。
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { LAYOUT, TABLES, tableFile, type Layout } from './schema.ts';

export interface SourceFile {
  // 根からの相対パス（違反の file に出す）
  file: string;
  text: string;
}

export interface Sources {
  // 表の id → YAML の文字列。ファイルが無い表は持たない（空の表として扱う）
  tables: Map<string, string>;
  // 置き場の直下の *.md・*.feature。ファイル名の順
  requirements: SourceFile[];
  examples: SourceFile[];
}

// 版（作業ツリー・git の版）ごとの読み手。パスは根からの相対
export interface SourceReader {
  // 項が無ければ undefined。項が在っても読めなければ例外
  readFile(rel: string): string | undefined;
  // 直下のファイル名。無いディレクトリなら空
  listFiles(relDir: string): string[];
}

function listDir(reader: SourceReader, dir: string, ext: string): SourceFile[] {
  return reader
    .listFiles(dir)
    .filter((f) => f.endsWith(ext))
    .sort()
    .map((f) => {
      const file = `${dir}/${f}`;
      const text = reader.readFile(file);
      if (text === undefined) throw new Error(`読めないファイル: ${file}`);
      return { file, text };
    });
}

// 読み手から、与えた置き場どおりに読む
export function readSourcesFrom(reader: SourceReader, layout: Pick<Layout, 'tables' | 'requirements' | 'examples'>): Sources {
  const tables = new Map<string, string>();
  for (const def of TABLES) {
    const text = reader.readFile(tableFile(def.id, layout.tables));
    if (text !== undefined) tables.set(def.id, text);
  }
  return {
    tables,
    requirements: listDir(reader, layout.requirements, '.md'),
    examples: listDir(reader, layout.examples, '.feature'),
  };
}

// 根から、LAYOUT の置き場どおりに読む
export function readSources(root: string): Sources {
  const reader: SourceReader = {
    readFile: (rel) => {
      const path = join(root, rel);
      return existsSync(path) ? readFileSync(path, 'utf8') : undefined;
    },
    listFiles: (relDir) => {
      const path = join(root, relDir);
      return existsSync(path) ? readdirSync(path) : [];
    },
  };
  return readSourcesFrom(reader, LAYOUT);
}

// 根からの相対パス → 中身の対応から組む（試験用）。LAYOUT の置き場の直下に無いファイルは読まない（readSources と同じ）
export function sourcesFromFiles(files: Record<string, string>): Sources {
  const tables = new Map<string, string>();
  const requirements: SourceFile[] = [];
  const examples: SourceFile[] = [];
  for (const [file, text] of Object.entries(files)) {
    const slash = file.lastIndexOf('/');
    const dir = file.slice(0, slash);
    const name = file.slice(slash + 1);
    const def = TABLES.find((t) => t.file === file);
    if (def) tables.set(def.id, text);
    else if (dir === LAYOUT.requirements && name.endsWith('.md')) requirements.push({ file, text });
    else if (dir === LAYOUT.examples && name.endsWith('.feature')) examples.push({ file, text });
  }
  const byName = (a: SourceFile, b: SourceFile) => (a.file < b.file ? -1 : a.file > b.file ? 1 : 0);
  return { tables, requirements: requirements.sort(byName), examples: examples.sort(byName) };
}
