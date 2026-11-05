// 規則ごとの判定を、ファイルを置かずに確かめる（test/cases/<規則>.ts）。
// 1件ごとに、要る表・要求票・例だけを渡して全体検査（書き漏らしの向きの規則は書き漏らしの検査も）を走らせ、
// (rule, file, target) の集合が期待と完全一致することを見る。件が counts を持つときは、重複を除く前の違反の件数も
// 対象ごとに見る（同じ対象に重なる違反の数は集合では見えないため）。読み込みから出力までのつながりは examples.test.ts が見る。
import assert from 'node:assert/strict';
import { readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { checkDocMissingSources, checkSources } from '../src/check.ts';
import { sourcesFromFiles } from '../src/sources.ts';
import type { Case } from './cases/case.ts';

const casesDir = join(dirname(fileURLToPath(import.meta.url)), 'cases');

// checkSources に含めず、書き漏らしの検査で走らせる規則
const DOC_MISSING_RULES = new Set(['requirement-missing', 'requirement-coverage', 'example-missing']);

const keyOf = (v: { rule: string; file: string; target: string }) => `${v.rule} | ${v.file} | ${v.target}`;

const ruleFiles = readdirSync(casesDir)
  .filter((f) => f.endsWith('.ts') && f !== 'case.ts')
  .sort();

for (const f of ruleFiles) {
  const rule = f.slice(0, -'.ts'.length);
  const { cases } = (await import(join(casesDir, f))) as { cases: Case[] };

  test(`${rule}: 通る件と落ちる件を1件以上持ち、名前が重ならない`, () => {
    assert.ok(cases.some((c) => c.name.startsWith('pass-')), 'pass- の件が無い');
    assert.ok(cases.some((c) => c.name.startsWith('fail-')), 'fail- の件が無い');
    for (const c of cases) assert.match(c.name, /^(pass|fail)-/);
    assert.equal(new Set(cases.map((c) => c.name)).size, cases.length, '名前が重なっている');
  });

  for (const c of cases) {
    test(`${rule}/${c.name}`, () => {
      if (c.name.startsWith('pass-')) assert.equal(c.expected.length, 0, 'pass の期待は空');
      else assert.ok(c.expected.length > 0, 'fail の期待が空');
      for (const e of c.expected) assert.equal(e.rule, rule, `期待に別の規則 ${e.rule} が混ざっている`);
      const sources = sourcesFromFiles(c.files);
      const actual = DOC_MISSING_RULES.has(rule)
        ? [...checkSources(sources), ...checkDocMissingSources(sources)]
        : checkSources(sources);
      assert.deepEqual([...new Set(actual.map(keyOf))].sort(), [...new Set(c.expected.map(keyOf))].sort());
      if (c.counts !== undefined) {
        const got: Record<string, number> = {};
        for (const v of actual) got[v.target] = (got[v.target] ?? 0) + 1;
        assert.deepEqual(got, c.counts, '対象ごとの違反の件数が counts と違う');
      }
      for (const v of actual) assert.ok(v.detail !== '', '違反の detail が空');
    });
  }
}
