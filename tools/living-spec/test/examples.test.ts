// examples/<規則>/<pass|fail>-<名前>.txtar を走査し、各見本をファイルとして展開して検査器を走らせ、
// (rule, file, target) の集合が見本の expected.yaml と完全一致することを確かめる。
// 見本は規則ごとに通る1件・落ちる1件の、表一式を置いたリポジトリの形。置き場からの読み込み・違反の file と target の形まで
// つながっていることを見る。規則の分岐の網羅は、ファイルを置かない test/rules.test.ts（test/cases/）が持つ。
// 書き漏らしの向きの規則の見本は、checkRepo に checkDocMissing を足して走らせる（規則は DOC_MISSING_RULES）。
import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { parseDocument } from 'yaml';
import { checkDocMissing, checkRepo } from '../src/check.ts';
import { materialize } from './fixture.ts';

const examplesDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'examples');

const RULES = [
  'unknown-key',
  'invalid-shape',
  'undefined-reference',
  'unconnected',
  'duplicate-name',
  'requirement-uc',
  'requirement-reference',
  'requirement-name-absent',
  'requirement-missing',
  'requirement-coverage',
  'example-feature',
  'example-rule-mismatch',
  'example-missing',
  'example-limit',
  'example-duplicate',
  'example-syntax',
];

// checkRepo に含めず、CLI の --doc-missing で走らせる規則
const DOC_MISSING_RULES = new Set(['requirement-missing', 'requirement-coverage', 'example-missing']);

// 見本の規則に応じて、その見本を走らせる検査を選ぶ
function runCheck(rule: string, dir: string) {
  if (DOC_MISSING_RULES.has(rule)) return [...checkRepo(dir), ...checkDocMissing(dir)];
  return checkRepo(dir);
}

interface Triple {
  rule: string;
  file: string;
  target: string;
}

const keyOf = (t: Triple) => `${t.rule} | ${t.file} | ${t.target}`;
const dirs = (p: string) => readdirSync(p).filter((n) => !n.startsWith('.') && statSync(join(p, n)).isDirectory());
// 規則の置き場の見本の名前（拡張子を除く）
const names = (rule: string) =>
  readdirSync(join(examplesDir, rule))
    .filter((n) => n.endsWith('.txtar'))
    .map((n) => n.slice(0, -'.txtar'.length));
// 見本を展開した根。同じ見本は1度だけ展開する
const roots = new Map<string, string>();
const root = (rule: string, name: string) => {
  const key = `${rule}/${name}`;
  if (!roots.has(key)) roots.set(key, materialize(join(examplesDir, rule, `${name}.txtar`)));
  return roots.get(key)!;
};

test('見本の置き場は規則ごとに通る見本と落ちる見本を1件以上持つ', () => {
  assert.deepEqual(dirs(examplesDir).sort(), [...RULES].sort());
  for (const rule of RULES) {
    const all = readdirSync(join(examplesDir, rule));
    for (const n of all) assert.match(n, /\.txtar$/, `${rule}/${n}: 見本は .txtar の1ファイルで置く`);
    const ns = names(rule);
    assert.ok(ns.some((n) => n.startsWith('pass-')), `${rule}: pass- の見本が無い`);
    assert.ok(ns.some((n) => n.startsWith('fail-')), `${rule}: fail- の見本が無い`);
    for (const n of ns) assert.match(n, /^(pass|fail)-/, `${rule}/${n}: 名前が pass-/fail- で始まらない`);
  }
});

for (const rule of RULES) {
  for (const name of names(rule)) {
    test(`${rule}/${name}`, () => {
      const dir = root(rule, name);
      const doc = parseDocument(readFileSync(join(dir, 'expected.yaml'), 'utf8'));
      assert.equal(doc.errors.length, 0, 'expected.yaml が読めない');
      const expected = (doc.toJS() ?? []) as Triple[];
      assert.ok(Array.isArray(expected), 'expected.yaml は並びでなければならない');

      if (name.startsWith('pass-')) assert.equal(expected.length, 0, 'pass の期待は空の並び');
      else assert.ok(expected.length > 0, 'fail の期待が空');
      // 落ちる見本は、その規則の違反だけが出る入力にする
      for (const e of expected) assert.equal(e.rule, rule, `${name}: 期待に別の規則 ${e.rule} が混ざっている`);

      const actual = runCheck(rule, dir);
      const actualKeys = [...new Set(actual.map(keyOf))].sort();
      const expectedKeys = [...new Set(expected.map(keyOf))].sort();
      assert.deepEqual(actualKeys, expectedKeys);
      for (const v of actual) assert.ok(v.detail !== '', '違反の detail が空');
    });
  }
}

test('書き漏らしの向きは checkRepo に含めない', () => {
  for (const rule of [...DOC_MISSING_RULES]) {
    for (const name of names(rule)) {
      const found = checkRepo(root(rule, name)).filter((v) => v.rule === rule);
      assert.deepEqual(found, [], `${rule}/${name}: checkRepo が ${rule} を出した`);
    }
  }
});

test('checkDocMissing は要求票・例の書き漏らしの向きの規則だけを返す', () => {
  for (const rule of RULES) {
    for (const name of names(rule)) {
      for (const v of checkDocMissing(root(rule, name))) {
        assert.ok(DOC_MISSING_RULES.has(v.rule), `${rule}/${name}: checkDocMissing が別の規則 ${v.rule} を出した`);
      }
    }
  }
});

test('読めない feature ファイルがあると example-missing を出さない（構文の誤りは example-syntax が拾う）', () => {
  const failing = names('example-syntax').filter((n) => n.startsWith('fail-'));
  assert.ok(failing.length > 0, 'example-syntax の落ちる見本が無い');
  for (const name of failing) {
    const found = checkDocMissing(root('example-syntax', name)).filter((v) => v.rule === 'example-missing');
    assert.deepEqual(found, [], `example-syntax/${name}: 読めない feature があるのに example-missing を出した`);
  }
});
