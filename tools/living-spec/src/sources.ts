// 検査と描画の入力（表・要求票・例の中身）。ファイルを読む処理と判定を分け、判定をファイルなしで試験できるようにする。
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { LAYOUT, TABLES } from './schema.ts';

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

function listDir(root: string, dir: string, ext: string): SourceFile[] {
  const path = join(root, dir);
  if (!existsSync(path)) return [];
  return readdirSync(path)
    .filter((f) => f.endsWith(ext))
    .sort()
    .map((f) => ({ file: `${dir}/${f}`, text: readFileSync(join(path, f), 'utf8') }));
}

// 根から、LAYOUT の置き場どおりに読む
export function readSources(root: string): Sources {
  const tables = new Map<string, string>();
  for (const def of TABLES) {
    const path = join(root, def.file);
    if (existsSync(path)) tables.set(def.id, readFileSync(path, 'utf8'));
  }
  return {
    tables,
    requirements: listDir(root, LAYOUT.requirements, '.md'),
    examples: listDir(root, LAYOUT.examples, '.feature'),
  };
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
