// 見本（*.txtar）を一時ディレクトリへ展開する。1件の見本は、根からの相対パスごとのファイルを1つのテキストに束ねたもの:
//   -- expected.yaml --
//   <中身>
//   -- docs/rdra/actor.yaml --
//   <中身>
// 「-- <パス> --」だけの行がファイルの区切り。中身にこの形の行は書けない。
// 使い方（bats などから）: node tools/living-spec/test/fixture.ts <見本.txtar> <展開先>
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';

const MARKER = /^-- (.+) --$/;

export function parseTxtar(text: string): { path: string; data: string }[] {
  const files: { path: string; data: string }[] = [];
  for (const line of text.split(/(?<=\n)/)) {
    const m = line.replace(/\r?\n$/, '').match(MARKER);
    if (m) files.push({ path: m[1], data: '' });
    else if (files.length > 0) files[files.length - 1].data += line;
    else if (line.trim() !== '') throw new Error('最初の区切りの前に中身がある');
  }
  return files;
}

export function extract(archive: string, dest: string): string {
  for (const { path, data } of parseTxtar(readFileSync(archive, 'utf8'))) {
    const out = join(dest, path);
    mkdirSync(dirname(out), { recursive: true });
    writeFileSync(out, data);
  }
  return dest;
}

const made: string[] = [];
process.on('exit', () => {
  for (const d of made) rmSync(d, { recursive: true, force: true });
});

// 見本を新しい一時ディレクトリへ展開し、その根を返す。プロセスの終わりに消す
export function materialize(archive: string): string {
  const dest = mkdtempSync(join(tmpdir(), 'living-spec-fixture-'));
  made.push(dest);
  return extract(archive, dest);
}

if (import.meta.main) {
  const [archive, dest] = process.argv.slice(2);
  if (archive === undefined || dest === undefined) {
    console.error('使い方: node fixture.ts <見本.txtar> <展開先>');
    process.exit(2);
  }
  extract(resolve(archive), resolve(dest));
}
