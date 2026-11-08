// 差分の一覧（difflist.ts）の行を、ファイルを置かずに確かめる。見本の2版は diff.test.ts と同じく test/render/diff-base.txtar・diff-head.txtar。
// 行の形（種類・区分の語・同一性の値のタブ区切り）の正本は references/format.md の「基準の版から変わった要素の一覧（`diff`）」である。
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { parseTxtar } from './fixture.ts';
import { diffSources } from '../src/diff.ts';
import type { ElementKind } from '../src/diff.ts';
import { diffListLines } from '../src/difflist.ts';
import { sourcesFromFiles } from '../src/sources.ts';
import type { Sources } from '../src/sources.ts';

const here = dirname(fileURLToPath(import.meta.url));

function sample(name: string): Sources {
  const files: Record<string, string> = {};
  for (const { path, data } of parseTxtar(readFileSync(join(here, 'render', name), 'utf8'))) files[path] = data;
  return sourcesFromFiles(files);
}

const base = sample('diff-base.txtar');
const head = sample('diff-head.txtar');

const WORD = { added: '足された', changed: '変わった', removed: '外された' } as const;

// 種類ごとの同一性の値の数。format.md「同一性と比べる中身」の表の「同一性」の列の値の数に従う
const VALUES: Record<ElementKind, number> = {
  状態: 2,
  遷移: 4,
  UC: 1,
  アクター: 1,
  外部システム: 1,
  情報: 1,
  条件: 1,
  バリエーション: 1,
  要求票: 1,
  要求文: 2,
  例: 3,
};

test('見本の2版の差分の各要素が、種類・区分・同一性の値のタブ区切りの1行になる', () => {
  const diff = diffSources(base, head);
  const lines = diffListLines(diff);
  assert.equal(lines.length, diff.elements.length);
  assert.equal(lines.length, 44);
  diff.elements.forEach((e, i) => {
    const cols = lines[i].split('\t');
    assert.equal(cols[0], e.kind);
    assert.equal(cols[1], WORD[e.status]);
    assert.equal(cols.length, VALUES[e.kind] + 2, lines[i]);
  });
  const representative = [
    '状態\t外された\t申請の状態\t差し戻し',
    '遷移\t足された\t申請の状態\t監査済み\tなし\tなし',
    '遷移\t変わった\t申請の状態\t作成中\t提出済み\t申請を提出する',
    'UC\t足された\t申請を監査する',
    'アクター\t変わった\t従業員',
    '外部システム\t外された\t通知サービス',
    '情報\t足された\t承認の記録',
    '条件\t変わった\t提出できる条件',
    'バリエーション\t外された\t旧区分',
    '要求票\t変わった\t申請を提出する',
    '要求文\t足された\t申請を提出する\t従業員が申請を提出するとき、システムは申請を提出済みにして上長へ知らせる',
    '例\t外された\t申請を提出する\t従業員が申請を提出するとき、システムは申請を提出済みにする\t提出すると提出済みになる',
  ];
  for (const line of representative) assert.ok(lines.includes(line), line);
});

test('無い値は なし と書き、列の数を保つ', () => {
  const state = 'docs/rdra/state.yaml';
  const feature = 'docs/examples/u.feature';
  const none = diffSources(sourcesFromFiles({}), sourcesFromFiles({ [state]: '- 状態モデル: M\n  遷移UC: U\n  遷移先状態: A\n' }));
  assert.deepEqual(
    diffListLines(none).filter((l) => l.startsWith('遷移')),
    ['遷移\t足された\tM\tなし\tA\tU'],
  );
  const outside = diffSources(
    sourcesFromFiles({}),
    sourcesFromFiles({ [feature]: '# language: ja\n機能: U\n\n  シナリオ: S\n    前提 甲である\n    ならば 乙になる\n' }),
  );
  assert.deepEqual(diffListLines(outside), ['例\t足された\tU\tなし\tS']);
});

test('差分が空なら行も空', () => {
  assert.deepEqual(diffListLines(diffSources(base, base)), []);
});
