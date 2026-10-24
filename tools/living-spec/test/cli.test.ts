// 入口（main.ts）の根の扱い・書き漏らしの向きのフラグ・.living-spec.json の置き場・フックの範囲を確かめる。
// 根に表の置き場が無ければ、表を読まずに「違反なし」と出さず、終了コード 2 で止まる。
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const main = process.env.RDRA_ENTRY ?? join(here, '..', 'src', 'main.ts');
const passExample = join(here, '..', 'examples', 'unknown-key', 'pass-all-allowed-keys');
// 要求票の無い UC を持つ見本。全体検査には出ず、--doc-missing にだけ出る
const requirementMissingExample = join(here, '..', 'examples', 'requirement-missing', 'fail-uc-without-requirement');
// 未定義の参照を持つ見本（全体検査で違反が出る）
const failExample = join(here, '..', 'examples', 'undefined-reference', 'fail-uc-actor');

function run(args: string[], cwd: string, input?: string, env: Record<string, string> = {}) {
  return spawnSync(process.execPath, [main, ...args], { cwd, encoding: 'utf8', input, env: { ...process.env, ...env } });
}

function scratch(): string {
  return mkdtempSync(join(tmpdir(), 'living-spec-cli-'));
}

for (const [name, args] of [
  ['全体検査', ['check']],
  ['書き漏らしの検査', ['check', '--doc-missing']],
  ['描画', ['render']],
] as [string, string[]][]) {
  test(`${name}: 今いる場所に表の置き場が無ければ終了コード 2 で止まる`, () => {
    const empty = scratch();
    try {
      const result = run(args, empty);
      assert.equal(result.status, 2);
      assert.doesNotMatch(result.stdout, /違反なし/);
      assert.ok(result.stderr.includes(join(empty, 'docs/rdra')), '探した置き場を出す');
    } finally {
      rmSync(empty, { recursive: true });
    }
  });
}

test('根に表の置き場があれば検査する', () => {
  const result = run(['check', passExample], tmpdir());
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /違反なし/);
});

test('--doc-missing: 要求票の無い UC を出して終了コード 1。全体検査には出さない', () => {
  const docMissing = run(['check', '--doc-missing', requirementMissingExample], tmpdir());
  assert.equal(docMissing.status, 1, docMissing.stdout + docMissing.stderr);
  assert.match(docMissing.stdout, /\[requirement-missing\]/);
  assert.match(docMissing.stdout, /要求票・例の書き漏らしの検査: 違反 1 件/);
  const full = run(['check', requirementMissingExample], tmpdir());
  assert.equal(full.status, 0, full.stdout + full.stderr);
});

test('引数の誤り: 使い方を出して終了コード 2', () => {
  for (const args of [[], ['nope'], ['check', '--code-missing', passExample], ['check', 'a', 'b'], ['hook', 'x']]) {
    const result = run(args, tmpdir());
    assert.equal(result.status, 2, args.join(' '));
    assert.match(result.stderr, /使い方/);
  }
});

test('.living-spec.json で置き場を変えられる', () => {
  const root = scratch();
  try {
    cpSync(passExample, root, { recursive: true });
    mkdirSync(join(root, 'spec'));
    renameSync(join(root, 'docs', 'rdra'), join(root, 'spec', 'tables'));
    assert.equal(run(['check', root], tmpdir()).status, 2, '既定の置き場には無い');
    writeFileSync(join(root, '.living-spec.json'), JSON.stringify({ tables: 'spec/tables', output: 'out/view.html' }));
    const result = run(['check', root], tmpdir());
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const rendered = run(['render', root], tmpdir());
    assert.equal(rendered.status, 0, rendered.stderr);
    assert.ok(existsSync(join(root, 'out', 'view.html')));
  } finally {
    rmSync(root, { recursive: true });
  }
});

test('.living-spec.json の誤りは終了コード 2', () => {
  const root = scratch();
  try {
    cpSync(passExample, root, { recursive: true });
    for (const body of ['{"unknown": 1}', '{"tables": 3}', '{"hook": "no"}', '[]', '{']) {
      writeFileSync(join(root, '.living-spec.json'), body);
      const result = run(['check', root], tmpdir());
      assert.equal(result.status, 2, body);
      assert.match(result.stderr, /\.living-spec\.json/);
    }
  } finally {
    rmSync(root, { recursive: true });
  }
});

function hookInput(filePath: string): string {
  return JSON.stringify({ tool_input: { file_path: filePath } });
}

test('フック: 置き場のファイルの編集で違反があれば終了コード 2、描き直す', () => {
  const root = scratch();
  try {
    cpSync(failExample, root, { recursive: true });
    const result = run(['hook'], tmpdir(), hookInput(join(root, 'docs/rdra/use-case.yaml')), { CLAUDE_PROJECT_DIR: root });
    assert.equal(result.status, 2, result.stdout + result.stderr);
    assert.match(result.stderr, /\[undefined-reference\]/);
    assert.ok(existsSync(join(root, '.cache/living-spec/index.html')), '違反があっても描く');
  } finally {
    rmSync(root, { recursive: true });
  }
});

test('フック: 範囲外のファイル・表の置き場の無いリポジトリ・hook が false なら何もしない', () => {
  const root = scratch();
  const bare = scratch();
  try {
    cpSync(failExample, root, { recursive: true });
    const outside = run(['hook'], tmpdir(), hookInput(join(root, 'src/app.ts')), { CLAUDE_PROJECT_DIR: root });
    assert.equal(outside.status, 0, outside.stderr);
    const noTables = run(['hook'], tmpdir(), hookInput(join(bare, 'docs/rdra/x.yaml')), { CLAUDE_PROJECT_DIR: bare });
    assert.equal(noTables.status, 0, noTables.stderr);
    writeFileSync(join(root, '.living-spec.json'), '{"hook": false}');
    const off = run(['hook'], tmpdir(), hookInput(join(root, 'docs/rdra/use-case.yaml')), { CLAUDE_PROJECT_DIR: root });
    assert.equal(off.status, 0, off.stderr);
    assert.ok(!existsSync(join(root, '.cache')));
  } finally {
    rmSync(root, { recursive: true });
    rmSync(bare, { recursive: true });
  }
});
