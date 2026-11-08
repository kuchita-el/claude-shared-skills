// 差分の計算（diff.ts）を、ファイルを置かずに確かめる。見本の2版は test/render/diff-base.txtar と diff-head.txtar。
// 見本の差分は期待の全件と完全一致で比べ、漏れも余計な印も赤くする。見本で表しにくい境界は、件ごとに要るファイルだけを書いた小さな入力で見る。
// 同一性の境界の件は、表示名ではなく同一性のキー（elementKey）で見る（例と要求文の表示名は同一性の一部しか持たないため）。
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { parseTxtar } from './fixture.ts';
import { diffIndex, diffSources, elementKey } from '../src/diff.ts';
import type { SpecDiff } from '../src/diff.ts';
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

// 差分を（種類・表示名・区分・変わった欄）の行の並びにする。並べ替えて比べるので、出力の順は見ない
function rows(diff: SpecDiff): string[] {
  return diff.elements.map((e) => `${e.kind} | ${e.name} | ${e.status} | ${e.changed.join('・')}`).sort();
}

interface Expected {
  kind: string;
  name: string;
  status: 'added' | 'changed' | 'removed';
  changed?: string[];
}

function expectedRows(list: Expected[]): string[] {
  return list.map((e) => `${e.kind} | ${e.name} | ${e.status} | ${(e.changed ?? []).join('・')}`).sort();
}

const SUBMIT = '申請を提出する';
const S1 = '提出できる条件を満たさないならば、システムは申請の提出を受け付けない';
const S2 = '従業員が申請を提出するとき、システムは申請を提出済みにする';
const S3 = '従業員が申請を提出するとき、システムは申請を提出済みにして上長へ知らせる';

// 見本の表（プランの Task 2 の手順1）から作った期待の全件。変わっていない要素（上長・申請を作成する・金額の区分 等）は持たない
const SAMPLE_EXPECTED: Expected[] = [
  { kind: '状態', name: '申請の状態/監査済み', status: 'added' },
  { kind: '状態', name: '申請の状態/差し戻し', status: 'removed' },
  { kind: '遷移', name: '申請の状態/承認済み→監査済み（申請を監査する）', status: 'added' },
  { kind: '遷移', name: '申請の状態/監査済み→（終端）', status: 'added' },
  { kind: '遷移', name: '申請の状態/作成中→提出済み（申請を提出する）', status: 'changed', changed: ['状態モデル・状態の説明'] },
  { kind: '遷移', name: '申請の状態/提出済み→差し戻し（申請を差し戻す）', status: 'removed' },
  { kind: '遷移', name: '申請の状態/差し戻し→（終端）', status: 'removed' },
  { kind: '遷移', name: '申請の状態/承認済み→（終端）', status: 'removed' },
  { kind: 'UC', name: '申請を監査する', status: 'added' },
  { kind: 'UC', name: '申請を提出する', status: 'changed', changed: ['アクター', '説明'] },
  { kind: 'UC', name: '申請を承認する', status: 'changed', changed: ['外部システム', '情報', '条件'] },
  { kind: 'UC', name: '申請を差し戻す', status: 'removed' },
  { kind: 'アクター', name: '監査役', status: 'added' },
  { kind: 'アクター', name: '従業員', status: 'changed', changed: ['役割'] },
  { kind: 'アクター', name: '経理', status: 'removed' },
  { kind: '外部システム', name: '電子署名サービス', status: 'added' },
  { kind: '外部システム', name: '会計システム', status: 'changed', changed: ['役割'] },
  { kind: '外部システム', name: '通知サービス', status: 'removed' },
  { kind: '情報', name: '承認の記録', status: 'added' },
  { kind: '情報', name: '監査記録', status: 'added' },
  { kind: '情報', name: '申請', status: 'changed', changed: ['属性'] },
  { kind: '情報', name: '承認記録', status: 'removed' },
  { kind: '情報', name: '旧台帳', status: 'removed' },
  { kind: '条件', name: '監査できる条件', status: 'added' },
  { kind: '条件', name: '提出できる条件', status: 'changed', changed: ['条件の説明'] },
  { kind: '条件', name: '期限の条件', status: 'removed' },
  { kind: 'バリエーション', name: '監査の区分', status: 'added' },
  { kind: 'バリエーション', name: '申請の種類', status: 'changed', changed: ['値'] },
  { kind: 'バリエーション', name: '旧区分', status: 'removed' },
  { kind: '要求票', name: '申請を監査する', status: 'added' },
  { kind: '要求票', name: SUBMIT, status: 'changed', changed: ['要求文'] },
  { kind: '要求票', name: '申請を差し戻す', status: 'removed' },
  { kind: '要求文', name: S3, status: 'added' },
  { kind: '要求文', name: '監査役が申請を監査するとき、システムは申請を監査済みにする', status: 'added' },
  { kind: '要求文', name: S1, status: 'changed', changed: ['理由'] },
  { kind: '要求文', name: S2, status: 'removed' },
  { kind: '要求文', name: '上長が申請を差し戻すとき、システムは申請を差し戻しにして旧台帳へ控える', status: 'removed' },
  { kind: '例', name: '金額の無い申請は出せない', status: 'added' },
  { kind: '例', name: '提出すると提出済みになる', status: 'added' },
  { kind: '例', name: '承認済みの申請を監査する', status: 'added' },
  { kind: '例', name: '種類の無い申請は出せない', status: 'changed', changed: ['手順'] },
  { kind: '例', name: '期限切れの申請は出せない', status: 'removed' },
  { kind: '例', name: '提出すると提出済みになる', status: 'removed' },
  { kind: '例', name: '差し戻すと差し戻しになる', status: 'removed' },
];

test('見本の差分が、期待の全件と完全一致する（漏れも余計な印も無い）', () => {
  assert.deepEqual(rows(diffSources(base, head)), expectedRows(SAMPLE_EXPECTED));
});

test('見本の同じ表示名の例（S2 と S3 の「提出すると提出済みになる」）を、同一性のキーで区別できる', () => {
  const find = diffIndex(diffSources(base, head));
  assert.equal(find('例', [SUBMIT, S2, '提出すると提出済みになる'])?.status, 'removed');
  assert.equal(find('例', [SUBMIT, S3, '提出すると提出済みになる'])?.status, 'added');
  assert.equal(find('例', [SUBMIT, S2, '提出すると提出済みになる'])?.key, elementKey('例', [SUBMIT, S2, '提出すると提出済みになる']));
});

test('見本の差分は、種類の並び（状態・遷移・UC・…・例）の順に出る', () => {
  const order = ['状態', '遷移', 'UC', 'アクター', '外部システム', '情報', '条件', 'バリエーション', '要求票', '要求文', '例'];
  const kinds = diffSources(base, head).elements.map((e) => order.indexOf(e.kind));
  assert.deepEqual(kinds, [...kinds].sort((a, b) => a - b));
});

test('同じ中身の2版は差分が空', () => {
  assert.deepEqual(diffSources(base, base).elements, []);
  assert.deepEqual(diffSources(head, head).elements, []);
});

// --- 小さな入力の件 ---

const USE_CASE = 'docs/rdra/use-case.yaml';
const ACTOR = 'docs/rdra/actor.yaml';
const STATE = 'docs/rdra/state.yaml';
const FEATURE = 'docs/examples/u.feature';

function diffOf(before: Record<string, string>, after: Record<string, string>): SpecDiff {
  return diffSources(sourcesFromFiles(before), sourcesFromFiles(after));
}

// 状態モデル M の遷移元 A・遷移先 B の記録。仮説を持たせるときは hypothesis を真にする
function transition(uc: string, description: string, hypothesis = false): string {
  return `- 状態モデル: M\n  状態: A\n  遷移UC: ${uc}\n  遷移先状態: B\n  状態モデル・状態の説明: ${description}\n${hypothesis ? '  仮説: [H1]\n' : ''}`;
}

// 仮説キーを空の並びで足しただけでも、仮説の有無が変わるので「変わった（仮説）」になる
test('仮説キーを空の並びで足した UC は「変わった（仮説）」', () => {
  const diff = diffOf({ [USE_CASE]: '- UC: U\n  説明: x\n' }, { [USE_CASE]: '- UC: U\n  説明: x\n  仮説: []\n' });
  assert.deepEqual(rows(diff), ['UC | U | changed | 仮説']);
});

// 例の手順の並びは並び順ではなく例の中身なので、文が同じでも並びの入れ替えは「変わった（手順）」になる（J5）
test('例の手順の並びの入れ替えは「変わった（手順）」', () => {
  const feature = (steps: string) => `# language: ja\n機能: U\n\n  ルール: R\n\n    シナリオ: S\n${steps}`;
  const diff = diffOf(
    { [FEATURE]: feature('      前提 甲である\n      かつ 乙である\n      もし 丙する\n      ならば 丁になる\n') },
    { [FEATURE]: feature('      前提 乙である\n      かつ 甲である\n      もし 丙する\n      ならば 丁になる\n') },
  );
  assert.deepEqual(rows(diff), ['例 | S | changed | 手順']);
});

// シナリオアウトラインの例の表の行の順は並び順なので、行の入れ替えだけでは印が付かない
test('アウトラインの例の表の行の入れ替えは印にならない', () => {
  const feature = (rows: string) =>
    `# language: ja\n機能: U\n\n  ルール: R\n\n    シナリオアウトライン: S\n      前提 件数が<件数>件である\n      ならば <結果>になる\n\n      例:\n        | 件数 | 結果 |\n${rows}`;
  const diff = diffOf(
    { [FEATURE]: feature('        | 1 | 少ない |\n        | 9 | 多い |\n') },
    { [FEATURE]: feature('        | 9 | 多い |\n        | 1 | 少ない |\n') },
  );
  assert.deepEqual(diff.elements, []);
});

// 遷移 UC は同一性に含まれるので、差し替えは旧い遷移 UC の「外された」と新しい遷移 UC の「足された」になり、X の遷移は印を持たない（J4）
test('遷移 UC を Y から Z へ差し替えると、Y の遷移が外された・Z の遷移が足されたの2件だけになる', () => {
  const diff = diffOf(
    { [STATE]: transition('X', 'x の説明') + transition('Y', 'y の説明') },
    { [STATE]: transition('X', 'x の説明') + transition('Z', 'y の説明') },
  );
  assert.deepEqual(
    diff.elements.map((e) => [e.key, e.status]),
    [
      [elementKey('遷移', ['M', 'A', 'B', 'Z']), 'added'],
      [elementKey('遷移', ['M', 'A', 'B', 'Y']), 'removed'],
    ],
  );
});

// 遷移 UC の違う2件は別の遷移なので、2件の間で説明を入れ替えると各々が「変わった」になる（J4）
test('遷移 UC の違う2件の間で説明を入れ替えると、X と Y の遷移が各々「変わった（状態モデル・状態の説明）」', () => {
  const diff = diffOf(
    { [STATE]: transition('X', '説明一') + transition('Y', '説明二') },
    { [STATE]: transition('X', '説明二') + transition('Y', '説明一') },
  );
  assert.deepEqual(
    diff.elements.map((e) => [e.key, e.status, e.changed]),
    [
      [elementKey('遷移', ['M', 'A', 'B', 'X']), 'changed', ['状態モデル・状態の説明']],
      [elementKey('遷移', ['M', 'A', 'B', 'Y']), 'changed', ['状態モデル・状態の説明']],
    ],
  );
});

// 同じ4つ組の記録が2件ある形（検査の duplicate-name）は1つの要素にまとめ、2件目だけの変化も「変わった」にする
test('同じ4つ組の2件の記録の片方（2件目）の説明だけを変えると、遷移が1件「変わった（状態モデル・状態の説明）」', () => {
  const diff = diffOf(
    { [STATE]: transition('X', '説明一') + transition('X', '説明二') },
    { [STATE]: transition('X', '説明一') + transition('X', '説明三') },
  );
  assert.deepEqual(
    diff.elements.map((e) => [e.key, e.status, e.changed]),
    [[elementKey('遷移', ['M', 'A', 'B', 'X']), 'changed', ['状態モデル・状態の説明']]],
  );
});

// 欄ごとの値の集合が同じでも記録ごとの組が違えば「変わった」で、欄名は2つ以上の値を持つ欄になる（差分の定義の (2)）
test('同じ4つ組の2件の記録の間で説明と仮説の組み合わせを入れ替えると、変わった欄が説明と仮説になる', () => {
  const diff = diffOf(
    { [STATE]: transition('X', '説明一', true) + transition('X', '説明二', false) },
    { [STATE]: transition('X', '説明一', false) + transition('X', '説明二', true) },
  );
  assert.deepEqual(
    diff.elements.map((e) => [e.key, e.status, e.changed]),
    [[elementKey('遷移', ['M', 'A', 'B', 'X']), 'changed', ['状態モデル・状態の説明', '仮説']]],
  );
});

// AC3 の4分類の外の欄（社内外）も比べる中身に入る（J7）
test('アクターの社内外だけを変えると「変わった（社内外）」', () => {
  const diff = diffOf(
    { [ACTOR]: '- アクター: 監査役\n  役割: 監査する\n  社内外: 社内\n' },
    { [ACTOR]: '- アクター: 監査役\n  役割: 監査する\n  社内外: 社外\n' },
  );
  assert.deepEqual(rows(diff), ['アクター | 監査役 | changed | 社内外']);
});

// 例の同一性はルール名を含むので、同名の例が別のルールにあっても、手順を変えた側の1件だけが「変わった」になる（J3）
test('同じシナリオ名の例が別のルールに1件ずつあり、片方の手順を変えると、その1件だけが「変わった」', () => {
  const feature = (secondThen: string) =>
    '# language: ja\n機能: U\n\n' +
    '  ルール: R1\n\n    シナリオ: S\n      もし 甲する\n      ならば 乙になる\n\n' +
    `  ルール: R2\n\n    シナリオ: S\n      もし 丙する\n      ならば ${secondThen}\n`;
  const diff = diffOf({ [FEATURE]: feature('丁になる') }, { [FEATURE]: feature('戊になる') });
  assert.deepEqual(
    diff.elements.map((e) => [e.key, e.status, e.changed]),
    [[elementKey('例', ['U', 'R2', 'S']), 'changed', ['手順']]],
  );
});

// 要求文の同一性は UC 名を含むので、同じ文が別の UC の票にあっても、理由を変えた側の1行だけが「変わった（理由）」になる（J6）。
// 行の理由は要求票の「要求文」の欄の組に入るので、変えた側の票は「変わった（要求文）」になり、もう一方の票は差分に無い
test('同じ文の要求文が別の UC の票に1行ずつあり、片方の理由だけを変えると、その1行だけが「変わった（理由）」', () => {
  const sheet = (uc: string, reason: string) =>
    `# 要求票: ${uc}\n\n## 理由\n\nなし\n\n## 仕様\n\n1. システムは記録を残す\n   - RDRA: なし\n   - 理由: ${reason}\n`;
  const before = { 'docs/requirements/u1.md': sheet('U1', 'なし'), 'docs/requirements/u2.md': sheet('U2', 'なし') };
  const after = { 'docs/requirements/u1.md': sheet('U1', 'なし'), 'docs/requirements/u2.md': sheet('U2', '監査に要る') };
  const diff = diffOf(before, after);
  assert.deepEqual(
    diff.elements.filter((e) => e.kind === '要求文').map((e) => [e.key, e.status, e.changed]),
    [[elementKey('要求文', ['U2', 'システムは記録を残す']), 'changed', ['理由']]],
  );
  assert.deepEqual(
    diff.elements.filter((e) => e.kind === '要求票').map((e) => [e.key, e.status, e.changed]),
    [[elementKey('要求票', ['U2']), 'changed', ['要求文']]],
  );
});
