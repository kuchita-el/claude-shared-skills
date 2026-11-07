// 入口（main.ts）の根の扱い・書き漏らしの向きのフラグ・.living-spec.json の置き場・フックの範囲を確かめる。
// 根に表の置き場が無ければ、表を読まずに「違反なし」と出さず、終了コード 2 で止まる。
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, realpathSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { materialize } from './fixture.ts';

const here = dirname(fileURLToPath(import.meta.url));
const main = process.env.RDRA_ENTRY ?? join(here, '..', 'src', 'main.ts');
const passExample = materialize(join(here, '..', 'examples', 'unknown-key', 'pass-all-allowed-keys.txtar'));
// 要求票の無い UC を持つ見本。全体検査には出ず、--doc-missing にだけ出る
const requirementMissingExample = materialize(
  join(here, '..', 'examples', 'requirement-missing', 'fail-uc-without-requirement.txtar'),
);
// 未定義の参照を持つ見本（全体検査で違反が出る）
const failExample = materialize(join(here, '..', 'examples', 'undefined-reference', 'fail-uc-actor.txtar'));

function run(args: string[], cwd: string, input?: string, env: Record<string, string> = {}) {
  return spawnSync(process.execPath, [main, ...args], { cwd, encoding: 'utf8', input, env: { ...process.env, ...env } });
}

function scratch(): string {
  return mkdtempSync(join(tmpdir(), 'living-spec-cli-'));
}

// シンボリックリンクを解いた一時ディレクトリ。最上段に .git ディレクトリを作り、上へ辿る探索の境界にする
function repo(): string {
  const dir = realpathSync(mkdtempSync(join(tmpdir(), 'living-spec-cli-')));
  mkdirSync(join(dir, '.git'));
  return dir;
}

// .git を作らない一時ディレクトリ（git の外）
function bare(): string {
  return realpathSync(mkdtempSync(join(tmpdir(), 'living-spec-cli-')));
}

// 展開した見本の木を dir へ写す
function put(dir: string, example: string): void {
  cpSync(example, dir, { recursive: true });
}

function config(dir: string, value: unknown): void {
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, '.living-spec.json'), JSON.stringify(value));
}

function firstLine(out: string): string {
  return out.split('\n')[0];
}

for (const [name, args] of [
  ['全体検査', ['check']],
  ['書き漏らしの検査', ['check', '--doc-missing']],
  ['描画', ['render']],
] as [string, string[]][]) {
  test(`${name}: 今いる場所から上へ辿って目印が無ければ終了コード 2 で止まる`, () => {
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

const rootLine = /^根:/m;

test('起点: 作業ディレクトリが置き場の中なら、上へ辿った根を1行目に出す', () => {
  const R = repo();
  try {
    const D = join(R, 'domains', 'a');
    put(D, passExample);
    const cwd = join(D, 'docs', 'rdra');
    const checked = run(['check'], cwd);
    assert.equal(checked.status, 0, checked.stdout + checked.stderr);
    assert.equal(firstLine(checked.stdout), `根: ${D}`);
    assert.equal(checked.stderr, '');
    const docMissing = run(['check', '--doc-missing'], cwd);
    assert.equal(firstLine(docMissing.stdout), `根: ${D}`, docMissing.stdout + docMissing.stderr);
    const rendered = run(['render'], cwd);
    const out = join(D, '.cache', 'living-spec', 'index.html');
    assert.equal(rendered.status, 0, rendered.stdout + rendered.stderr);
    assert.equal(rendered.stdout.trim(), out);
    assert.ok(existsSync(out));
    assert.equal(rendered.stderr, '');
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('起点: 引数がファイルなら、そのディレクトリから辿る', () => {
  const R = repo();
  const elsewhere = bare();
  try {
    const D = join(R, 'domains', 'a');
    put(D, passExample);
    const file = join(D, 'docs', 'rdra', 'use-case.yaml');
    const checked = run(['check', file], elsewhere);
    assert.equal(firstLine(checked.stdout), `根: ${D}`, checked.stdout + checked.stderr);
    assert.equal(checked.stderr, '');
    const rendered = run(['render', file], elsewhere);
    assert.equal(rendered.status, 0, rendered.stdout + rendered.stderr);
    assert.equal(rendered.stdout.trim(), join(D, '.cache', 'living-spec', 'index.html'));
    assert.equal(rendered.stderr, '');
  } finally {
    rmSync(R, { recursive: true });
    rmSync(elsewhere, { recursive: true });
  }
});

test('起点: 引数のパスが存在しなければ終了コード 2 で、根を出さない', () => {
  const R = repo();
  try {
    const result = run(['check', join(R, 'nope')], R);
    assert.equal(result.status, 2, result.stdout + result.stderr);
    assert.doesNotMatch(result.stdout, rootLine);
    assert.ok(result.stderr.includes('起点が見つからない'), result.stderr);
    assert.ok(result.stderr.includes(join(R, 'nope')), result.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('目印: 設定が無く docs/rdra がファイルなら、目印にしない', () => {
  const R = repo();
  try {
    mkdirSync(join(R, 'docs'));
    writeFileSync(join(R, 'docs', 'rdra'), '');
    const result = run(['check', R], R);
    assert.equal(result.status, 2, result.stdout + result.stderr);
    assert.doesNotMatch(result.stdout, rootLine);
    assert.ok(result.stderr.includes('正本が見つからない'), result.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('入れ子: 起点に最も近い目印が根になる', () => {
  const R = repo();
  try {
    put(R, passExample);
    config(R, {});
    const D = join(R, 'domains', 'a');
    put(D, failExample);
    config(D, {});
    const inner = run(['check', D], R);
    assert.equal(firstLine(inner.stdout), `根: ${D}`, inner.stdout + inner.stderr);
    assert.equal(inner.status, 1, inner.stdout + inner.stderr);
    const outer = run(['check', R], R);
    assert.equal(firstLine(outer.stdout), `根: ${R}`, outer.stdout + outer.stderr);
    assert.equal(outer.status, 0, outer.stdout + outer.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('設定の無い領域: 設定のある根の下でも、docs/rdra を持つ領域が根になる', () => {
  const R = repo();
  try {
    put(R, passExample);
    config(R, {});
    const D = join(R, 'domains', 'a');
    put(D, failExample);
    const inner = run(['check', D], R);
    assert.equal(firstLine(inner.stdout), `根: ${D}`, inner.stdout + inner.stderr);
    assert.equal(inner.status, 1, inner.stdout + inner.stderr);
    const outer = run(['check'], R);
    assert.equal(firstLine(outer.stdout), `根: ${R}`, outer.stdout + outer.stderr);
    assert.equal(outer.status, 0, outer.stdout + outer.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('作業ツリーの下の設定の無い既定の置き場は、その場所を根にする', () => {
  const R = repo();
  try {
    const sub = join(R, 'sub');
    put(sub, passExample);
    for (const projectDir of ['', R]) {
      const result = run(['check', join(sub, 'docs', 'rdra', 'use-case.yaml')], tmpdir(), undefined, {
        CLAUDE_PROJECT_DIR: projectDir,
      });
      assert.equal(firstLine(result.stdout), `根: ${sub}`, `CLAUDE_PROJECT_DIR=${projectDir}: ${result.stdout}${result.stderr}`);
    }
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('git の外でも最も近い目印を根にし、CLAUDE_PROJECT_DIR に左右されない', () => {
  const proj = bare();
  try {
    put(proj, passExample);
    for (const projectDir of ['', join(proj, 'docs')]) {
      const result = run(['check', join(proj, 'docs', 'rdra', 'use-case.yaml')], tmpdir(), undefined, {
        CLAUDE_PROJECT_DIR: projectDir,
      });
      assert.equal(firstLine(result.stdout), `根: ${proj}`, `CLAUDE_PROJECT_DIR=${projectDir}: ${result.stdout}${result.stderr}`);
    }
  } finally {
    rmSync(proj, { recursive: true });
  }
});

test('境界: worktree の .git の上の目印は根にしない', () => {
  const R = repo();
  try {
    put(R, passExample);
    config(R, {});
    const W = join(R, '.worktrees', 'w');
    mkdirSync(join(W, 'spec'), { recursive: true });
    writeFileSync(join(W, '.git'), `gitdir: ${join(R, '.git', 'worktrees', 'w')}\n`);
    writeFileSync(join(W, 'spec', 'use-case.yaml'), '');
    const env = { CLAUDE_PROJECT_DIR: R };
    const stopped = run(['check', join(W, 'spec')], R, undefined, env);
    assert.equal(stopped.status, 2, stopped.stdout + stopped.stderr);
    assert.doesNotMatch(stopped.stdout, rootLine);
    assert.ok(stopped.stderr.includes('正本が見つからない'), stopped.stderr);
    assert.ok(stopped.stderr.includes(W), stopped.stderr);
    put(W, passExample);
    const found = run(['check', join(W, 'docs', 'rdra', 'use-case.yaml')], R, undefined, env);
    assert.equal(firstLine(found.stdout), `根: ${W}`, found.stdout + found.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});
