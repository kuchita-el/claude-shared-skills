// 集約の子（情報の表の『集約の親』キー）を確かめる。規則ごとの判定の分岐は test/cases/（unconnected・aggregate-cycle・
// undefined-reference・invalid-shape・unknown-key）が、見本のつながりは examples.test.ts が見る。ここでは次を見る。
// - キーを持たない入力の検査の結果が、キーを足す前の判定（UC から直接参照されるかだけで決める未接続）と同じであること
// - 見本の対（キーの有無だけが違う入力）
// - 1つの規則だけを期待する件の形に載らない、規則の重なり
// - 描画（UC の縦串の情報の項に子を添える）と、差分（キーの変化を「変わった」にする）
import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { isMap, isSeq, parseDocument } from 'yaml';
import { checkDocMissingSources, checkSources, loadTables } from '../src/check.ts';
import type { Violation } from '../src/check.ts';
import { diffSources } from '../src/diff.ts';
import { renderHtml } from '../src/html.ts';
import { AGGREGATE_PARENT, HYPOTHESIS, tableById } from '../src/schema.ts';
import { sourcesFromFiles } from '../src/sources.ts';
import { buildView } from '../src/view.ts';
import type { Case } from './cases/case.ts';
import { parseTxtar } from './fixture.ts';

const here = dirname(fileURLToPath(import.meta.url));
const examplesDir = join(here, '..', 'examples');
const casesDir = join(here, 'cases');
const INFO = 'docs/rdra/information.yaml';

function filesOf(path: string): Record<string, string> {
  const files: Record<string, string> = {};
  for (const { path: p, data } of parseTxtar(readFileSync(path, 'utf8'))) if (p !== 'expected.yaml') files[p] = data;
  return files;
}

const example = (rule: string, name: string) => filesOf(join(examplesDir, rule, `${name}.txtar`));

const keyOf = (v: Violation) => `${v.rule} | ${v.file} | ${v.target}`;

function allViolations(files: Record<string, string>): Violation[] {
  const sources = sourcesFromFiles(files);
  return [...checkSources(sources), ...checkDocMissingSources(sources)];
}

// 表のどれかのレコードが『集約の親』キーを持つか（YAML として読む。読めない表は持たないとみなす）
function hasAggregateKey(files: Record<string, string>): boolean {
  return Object.entries(files).some(([path, text]) => {
    if (!path.endsWith('.yaml')) return false;
    const doc = parseDocument(text);
    return doc.errors.length === 0 && isSeq(doc.contents) && doc.contents.items.some((r) => isMap(r) && r.has(AGGREGATE_PARENT));
  });
}

// キーを足す前の未接続の判定: アクター・外部システム・情報・条件のうち、仮説でなく、どの UC の同じキーからも参照されないもの。
// 集約の親を知らない判定を、試験の側に独立に持つ（check.ts から導くと、変更後の判定を同じ実装で追認するため）
function unconnectedBefore(files: Record<string, string>): string[] {
  const rows = loadTables(sourcesFromFiles(files), []);
  const refs = (key: string) =>
    new Set(
      rows['use-case'].flatMap((uc) => {
        // 型の誤り（並びのキーに文字列）も寛容に読む。検査器の参照の読み方（check.ts の values）と同じ
        const v = uc.data[key];
        if (typeof v === 'string') return v.trim() === '' ? [] : [v.trim()];
        return Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string' && x.trim() !== '').map((x) => x.trim()) : [];
      }),
    );
  const out: string[] = [];
  for (const [id, key] of [
    ['actor', 'アクター'],
    ['external-system', '外部システム'],
    ['information', '情報'],
    ['condition', '条件'],
  ] as const) {
    const referenced = refs(key);
    for (const r of rows[id]) {
      if (Object.hasOwn(r.data, HYPOTHESIS) || referenced.has(r.name)) continue;
      out.push(`unconnected | ${tableById(id).file} | ${tableById(id).kind}:${r.name}`);
    }
  }
  return [...new Set(out)].sort();
}

// 規則ごとの全ての見本と、規則の試験の全ての件
async function allInputs(): Promise<{ label: string; files: Record<string, string> }[]> {
  const inputs: { label: string; files: Record<string, string> }[] = [];
  for (const rule of readdirSync(examplesDir).filter((n) => statSync(join(examplesDir, n)).isDirectory())) {
    for (const name of readdirSync(join(examplesDir, rule)).filter((n) => n.endsWith('.txtar'))) {
      inputs.push({ label: `examples/${rule}/${name}`, files: filesOf(join(examplesDir, rule, name)) });
    }
  }
  for (const f of readdirSync(casesDir).filter((n) => n.endsWith('.ts') && n !== 'case.ts')) {
    const { cases } = (await import(join(casesDir, f))) as { cases: Case[] };
    for (const c of cases) inputs.push({ label: `cases/${f}/${c.name}`, files: c.files });
  }
  return inputs;
}

test('『集約の親』を持たない全ての見本と件で、未接続はキーを足す前の判定と同じで、集約の循環は出ない', async () => {
  let compared = 0;
  for (const { label, files } of await allInputs()) {
    if (hasAggregateKey(files)) continue;
    compared++;
    const actual = allViolations(files);
    assert.deepEqual(
      [...new Set(actual.filter((v) => v.rule === 'unconnected').map(keyOf))].sort(),
      unconnectedBefore(files),
      label,
    );
    assert.deepEqual(actual.filter((v) => v.rule === 'aggregate-cycle'), [], label);
  }
  assert.ok(compared > 150, `比べた入力が少ない（${compared} 件）`);
});

test('キーを足す前の判定は、未接続の見本と件の期待を再現する（試験の側の判定が空回りしていない）', async () => {
  let failing = 0;
  for (const { label, files } of await allInputs()) {
    if (hasAggregateKey(files) || !label.includes('unconnected')) continue;
    if (unconnectedBefore(files).length > 0) failing++;
  }
  assert.ok(failing >= 5, `未接続の落ちる入力が少ない（${failing} 件）`);
});

// 見本の対: 集約の子の正例は、#928 の入力B（関連情報だけで指される情報）に『集約の親』を1行足しただけの入力である
test('集約の子の正例から『集約の親』を外すと、関連情報だけで指される見本と同じ入力になり、unconnected で落ちる', () => {
  const child = example('unconnected', 'pass-aggregate-child-via-parent');
  const relatedOnly = example('unconnected', 'fail-information-only-via-related');
  const stripped = { ...child, [INFO]: child[INFO].replace(`  ${AGGREGATE_PARENT}: 経費申請\n`, '') };
  assert.notEqual(stripped[INFO], child[INFO], '外す前と同じならキーが無い');
  assert.deepEqual(stripped, relatedOnly);
  assert.deepEqual(allViolations(child).map(keyOf), []);
  assert.deepEqual(allViolations(stripped).map(keyOf), [`unconnected | ${INFO} | 情報:経費明細`]);
});

test('集約の子の正例から親の UC からの参照を外すと、親と子の両方が unconnected で落ちる', () => {
  const child = example('unconnected', 'pass-aggregate-child-via-parent');
  const unreferenced = example('unconnected', 'fail-aggregate-parent-unreferenced');
  const uc = 'docs/rdra/use-case.yaml';
  assert.deepEqual({ ...child, [uc]: child[uc].replace('  情報:\n    - 経費申請\n', '') }, unreferenced);
  assert.deepEqual(allViolations(unreferenced).map(keyOf).sort(), [
    `unconnected | ${INFO} | 情報:経費明細`,
    `unconnected | ${INFO} | 情報:経費申請`,
  ]);
});

test('親が表に無い集約の子は、UC から直接参照されなければ undefined-reference と unconnected の両方で落ちる', () => {
  const files = { [INFO]: `- 情報: 経費明細\n  ${AGGREGATE_PARENT}: 経費申請書\n` };
  const actual = allViolations(files);
  assert.deepEqual(actual.map(keyOf).sort(), [
    `unconnected | ${INFO} | 情報:経費明細`,
    `undefined-reference | ${INFO} | 情報:経費明細`,
  ]);
  assert.match(actual.find((v) => v.rule === 'undefined-reference')!.detail, /集約の親『経費申請書』が定義されていない/);
  assert.match(actual.find((v) => v.rule === 'unconnected')!.detail, /集約の親『経費申請書』も接続していない/);
});

test('UC が挙げる名前が表に無い情報を集約の親に挙げても、子は接続しない', () => {
  const files = {
    [INFO]: `- 情報: 経費明細\n  ${AGGREGATE_PARENT}: 経費申請\n`,
    'docs/rdra/use-case.yaml': '- UC: 経費申請を作成する\n  情報:\n    - 経費申請\n',
  };
  assert.deepEqual(allViolations(files).map(keyOf).sort(), [
    `unconnected | ${INFO} | 情報:経費明細`,
    `undefined-reference | ${INFO} | 情報:経費明細`,
    'undefined-reference | docs/rdra/use-case.yaml | UC:経費申請を作成する',
  ]);
});

test('循環の上の情報が UC から直接参照されなければ、aggregate-cycle と unconnected の両方で落ちる', () => {
  const files = {
    [INFO]: `- 情報: 経費申請\n  ${AGGREGATE_PARENT}: 経費明細\n- 情報: 経費明細\n  ${AGGREGATE_PARENT}: 経費申請\n`,
  };
  const actual = allViolations(files);
  assert.deepEqual(actual.map(keyOf).sort(), [
    `aggregate-cycle | ${INFO} | 情報:経費明細`,
    `aggregate-cycle | ${INFO} | 情報:経費申請`,
    `unconnected | ${INFO} | 情報:経費明細`,
    `unconnected | ${INFO} | 情報:経費申請`,
  ]);
  assert.deepEqual(
    actual.filter((v) => v.rule === 'aggregate-cycle').map((v) => v.detail).sort(),
    ['集約の親を辿ると自身へ戻る（経費明細 → 経費申請 → 経費明細）', '集約の親を辿ると自身へ戻る（経費申請 → 経費明細 → 経費申請）'],
  );
});

test('集約の循環は未決の一覧を止めない（表の形の違反ではない）', () => {
  const files = { [INFO]: `- 情報: 経費明細\n  ${AGGREGATE_PARENT}: 経費明細\n  未決:\n    - 説明: 明細の単位が決まっていない\n` };
  const view = buildView('/根', sourcesFromFiles(files));
  assert.equal(view.openBlocking, 0);
  assert.equal(view.open.length, 1);
});

test('描画: UC の縦串の情報の項に、集約の子と孫の名前を添える。子の無い項には添えない', () => {
  const files = example('aggregate-cycle', 'pass-grandchild-chain');
  const view = buildView('/根', sourcesFromFiles(files));
  const uc = view.useCases.find((u) => u.name === '経費申請を作成する');
  assert.ok(uc !== undefined);
  assert.deepEqual(uc.information.map((i) => i.children), [
    [{ name: '経費明細', children: [{ name: '領収書の画像', children: [] }] }],
  ]);
  const html = renderHtml(view, new Date());
  assert.ok(html.includes('<div class="note">集約の子: 経費明細（集約の子: 領収書の画像）</div>'), '子と孫が添えられていない');
  const plain = renderHtml(buildView('/根', sourcesFromFiles(example('unconnected', 'fail-information-only-via-related'))), new Date());
  assert.ok(!plain.includes('集約の子'), 'キーの無い正本に子が添えられた');
});

test('描画: 集約の循環があっても、辿っている道に現れた名前で止めて描く', () => {
  const files = {
    [INFO]: `- 情報: 経費申請\n  ${AGGREGATE_PARENT}: 経費明細\n- 情報: 経費明細\n  ${AGGREGATE_PARENT}: 経費申請\n`,
    'docs/rdra/use-case.yaml': '- UC: 経費申請を作成する\n  情報:\n    - 経費申請\n',
  };
  const view = buildView('/根', sourcesFromFiles(files));
  assert.deepEqual(view.useCases[0].information[0].children, [{ name: '経費明細', children: [] }]);
});

test('差分: 『集約の親』を足す・変えると、その情報が「変わった（集約の親）」になる', () => {
  const before = sourcesFromFiles(example('unconnected', 'fail-information-only-via-related'));
  const after = sourcesFromFiles(example('unconnected', 'pass-aggregate-child-via-parent'));
  assert.deepEqual(
    diffSources(before, after).elements.map((e) => `${e.kind} | ${e.name} | ${e.status} | ${e.changed.join('・')}`),
    ['情報 | 経費明細 | changed | 集約の親'],
  );
});
