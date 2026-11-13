// 入口（main.ts）の根の探索・置き場の検証・範囲・書き漏らしの向きのフラグ・フックの範囲を確かめる。
// 置き場が根に属さない・設定を読めない・根が決まった後の探索で読めないときは、CLI もフックも同じ文面で終了コード 2 で止まる。
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, realpathSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { COMPAT } from '../src/compat.ts';
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

interface MisplacedRoot {
  name: string;
  // 検査する根
  root: string;
  // 後始末で消す一時ディレクトリ
  base: string;
  // 標準エラーに含むべき語
  words: string[];
}

// 置き場が根に属さない3つの形の木（根の外・別の根の中・境界の向こう）。どの置き場にも通る見本の表を置く
function misplacedRoots(): MisplacedRoot[] {
  const tables = join(passExample, 'docs', 'rdra');
  const outsideBase = repo();
  const outside = join(outsideBase, 'r');
  config(outside, { tables: '../shared/rdra' });
  cpSync(tables, join(outsideBase, 'shared', 'rdra'), { recursive: true });
  const nested = repo();
  config(nested, { tables: 'x/docs/rdra' });
  cpSync(tables, join(nested, 'x', 'docs', 'rdra'), { recursive: true });
  const fenced = repo();
  config(fenced, { tables: 'vendor/spec/rdra' });
  mkdirSync(join(fenced, 'vendor', 'spec', '.git'), { recursive: true });
  cpSync(tables, join(fenced, 'vendor', 'spec', 'rdra'), { recursive: true });
  return [
    {
      name: '根の外',
      root: outside,
      base: outsideBase,
      words: ['tables', '../shared/rdra', join(outsideBase, 'shared', 'rdra'), '根の外'],
    },
    { name: '別の根の中', root: nested, base: nested, words: ['x/docs/rdra', '別の根', join(nested, 'x')] },
    {
      name: '境界の向こう',
      root: fenced,
      base: fenced,
      words: ['vendor/spec/rdra', '境界', join(fenced, 'vendor', 'spec')],
    },
  ];
}

// フックを起動する。CLAUDE_PROJECT_DIR は必ず明示する（未設定は空文字）。cwd は標準入力の JSON の cwd（省略時は入れない）
function hookAt(file: string, projectDir: string, cwd?: string) {
  const input = JSON.stringify({ cwd, tool_input: { file_path: file } });
  return run(['hook'], tmpdir(), input, { CLAUDE_PROJECT_DIR: projectDir });
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

test('compat: 互換の世代を1行で出して終了コード 0', () => {
  const result = run(['compat'], tmpdir());
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, `${COMPAT}\n`);
  assert.equal(result.stderr, '');
});

test('引数の誤り: 使い方を出して終了コード 2', () => {
  for (const args of [[], ['nope'], ['check', '--code-missing', passExample], ['check', 'a', 'b'], ['hook', 'x'], ['compat', 'x']]) {
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

const gitmodulesDocs = '[submodule "docs"]\n\tpath = docs\n\turl = ../docs.git\n';

// R の docs を submodule（またはその体裁の入れ子）にした木。docsGit は R/docs/.git の作り方
function submoduleTree(docsGit: 'file' | 'dir', modules: string | null): string {
  const R = repo();
  put(R, passExample);
  if (modules !== null) writeFileSync(join(R, '.gitmodules'), modules);
  if (docsGit === 'file') writeFileSync(join(R, 'docs', '.git'), 'gitdir: ../.git/modules/docs\n');
  else mkdirSync(join(R, 'docs', '.git'));
  return R;
}

const useCase = (R: string) => join(R, 'docs', 'rdra', 'use-case.yaml');

test('境界: submodule の docs は境界にしない（ルートの設定の有無によらない）', () => {
  const R = submoduleTree('file', gitmodulesDocs);
  try {
    const plain = run(['check', useCase(R)], R);
    assert.equal(firstLine(plain.stdout), `根: ${R}`, plain.stdout + plain.stderr);
    assert.equal(plain.status, 0, plain.stdout + plain.stderr);
    config(R, {});
    const withConfig = run(['check', useCase(R)], R);
    assert.equal(firstLine(withConfig.stdout), `根: ${R}`, withConfig.stdout + withConfig.stderr);
    assert.equal(withConfig.status, 0, withConfig.stdout + withConfig.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('境界: 旧式の submodule（.git がディレクトリ）も境界にしない', () => {
  const R = submoduleTree('dir', gitmodulesDocs);
  try {
    const out = run(['check', useCase(R)], R);
    assert.equal(firstLine(out.stdout), `根: ${R}`, out.stdout + out.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('境界: .gitmodules に載らない入れ子のリポジトリは境界にする', () => {
  const R = submoduleTree('dir', null);
  try {
    const out = run(['check', useCase(R)], R);
    assert.equal(out.status, 2, out.stdout + out.stderr);
    assert.doesNotMatch(out.stdout, rootLine);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('境界: .gitmodules の書式の揺れでも submodule と判定し、注釈の行は数えない', () => {
  const R = submoduleTree('file', gitmodulesDocs);
  try {
    const yes = [
      '[Submodule "docs"]\n  PATH=docs/  # 注釈\n',
      '; 注釈\n[submodule "docs"]\n\tpath = "docs"\n',
    ];
    for (const text of yes) {
      writeFileSync(join(R, '.gitmodules'), text);
      const out = run(['check', useCase(R)], R);
      assert.equal(firstLine(out.stdout), `根: ${R}`, `${text}\n${out.stdout}${out.stderr}`);
    }
    writeFileSync(join(R, '.gitmodules'), '[submodule "docs"]\n# path = docs\n');
    const no = run(['check', useCase(R)], R);
    assert.equal(no.status, 2, no.stdout + no.stderr);
    assert.doesNotMatch(no.stdout, rootLine);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('境界: .gitmodules を読めなければ、終了コード 2 で読めない場所を示す', () => {
  const R = submoduleTree('file', null);
  try {
    mkdirSync(join(R, '.gitmodules'));
    const out = run(['check', useCase(R)], R);
    assert.equal(out.status, 2, out.stdout + out.stderr);
    assert.doesNotMatch(out.stdout, rootLine);
    assert.ok(out.stderr.includes('根の探索で読めない'), out.stderr);
    assert.ok(out.stderr.includes(join(R, '.gitmodules')), out.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('設定を読めなくても、根を1行目に示して終了コード 2', () => {
  const R = repo();
  try {
    put(R, passExample);
    writeFileSync(join(R, '.living-spec.json'), '{');
    const checked = run(['check', R], R);
    assert.equal(checked.status, 2, checked.stdout + checked.stderr);
    assert.equal(firstLine(checked.stdout), `根: ${R}`);
    assert.ok(checked.stderr.includes('.living-spec.json'), checked.stderr);
    assert.ok(checked.stderr.includes(R), checked.stderr);
    const rendered = run(['render', R], R);
    assert.equal(rendered.status, 2, rendered.stdout + rendered.stderr);
    assert.equal(rendered.stdout, '');
    assert.ok(rendered.stderr.includes(R), rendered.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('設定はあるのに表の置き場が無ければ、根を示して終了コード 2', () => {
  const R = repo();
  try {
    config(R, {});
    const checked = run(['check', R], R);
    assert.equal(checked.status, 2, checked.stdout + checked.stderr);
    assert.equal(firstLine(checked.stdout), `根: ${R}`);
    assert.ok(checked.stderr.includes('表の置き場が見つからない'), checked.stderr);
    const rendered = run(['render', R], R);
    assert.equal(rendered.status, 2, rendered.stdout + rendered.stderr);
    assert.equal(rendered.stdout, '');
    assert.ok(rendered.stderr.includes(R), rendered.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('表の置き場がディレクトリでなければ、正本が無いと扱う', () => {
  const R = repo();
  try {
    config(R, {});
    mkdirSync(join(R, 'docs'));
    writeFileSync(join(R, 'docs', 'rdra'), '');
    const checked = run(['check', R], R);
    assert.equal(checked.status, 2, checked.stdout + checked.stderr);
    assert.ok(checked.stderr.includes('表の置き場が見つからない'), checked.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('根に属さない置き場: 3つの形で check と render が同じ文面で止まる', () => {
  for (const tree of misplacedRoots()) {
    try {
      const checked = run(['check', tree.root], tree.root);
      assert.equal(checked.status, 2, `${tree.name}: ${checked.stdout}${checked.stderr}`);
      assert.equal(firstLine(checked.stdout), `根: ${tree.root}`, tree.name);
      for (const word of tree.words) assert.ok(checked.stderr.includes(word), `${tree.name}: ${word}\n${checked.stderr}`);
      const rendered = run(['render', tree.root], tree.root);
      assert.equal(rendered.status, 2, `${tree.name}: ${rendered.stdout}${rendered.stderr}`);
      assert.equal(rendered.stdout, '', tree.name);
      assert.equal(rendered.stderr, checked.stderr, tree.name);
    } finally {
      rmSync(tree.base, { recursive: true });
    }
  }
});

test('置き場の検証は置き場そのものから辿る: 置き場自身が目印なら別の根、置き場が根そのものなら属する', () => {
  const R = repo();
  const S = repo();
  try {
    put(R, passExample);
    renameSync(join(R, 'docs', 'rdra'), join(R, 'sub'));
    config(R, { tables: 'sub' });
    config(join(R, 'sub'), {});
    const checked = run(['check', R], R);
    assert.equal(checked.status, 2, checked.stdout + checked.stderr);
    assert.equal(firstLine(checked.stdout), `根: ${R}`);
    for (const word of ['sub', '別の根', join(R, 'sub')]) assert.ok(checked.stderr.includes(word), `${word}\n${checked.stderr}`);
    const rendered = run(['render', R], R);
    assert.equal(rendered.status, 2, rendered.stdout + rendered.stderr);
    assert.equal(rendered.stdout, '');
    assert.equal(rendered.stderr, checked.stderr);

    put(S, passExample);
    cpSync(join(S, 'docs', 'rdra'), S, { recursive: true });
    rmSync(join(S, 'docs', 'rdra'), { recursive: true });
    config(S, { tables: '.' });
    const self = run(['check', S], S);
    assert.equal(self.status, 0, self.stdout + self.stderr);
    assert.equal(firstLine(self.stdout), `根: ${S}`);
  } finally {
    rmSync(R, { recursive: true });
    rmSync(S, { recursive: true });
  }
});

test('置き場がまだ無くても、根に属するなら止めない', () => {
  const R = repo();
  try {
    put(R, passExample);
    config(R, { requirements: 'spec/req' });
    const checked = run(['check', R], R);
    assert.equal(checked.status, 0, checked.stdout + checked.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('外れた置き場は存在しなくても止める', () => {
  const R = repo();
  const T = repo();
  try {
    put(R, passExample);
    config(R, { examples: '../nowhere' });
    const examples = run(['check', R], R);
    assert.equal(examples.status, 2, examples.stdout + examples.stderr);
    assert.ok(examples.stderr.includes('根の外'), examples.stderr);
    config(T, { tables: '../nowhere' });
    const tables = run(['check', T], T);
    assert.equal(tables.status, 2, tables.stdout + tables.stderr);
    assert.ok(tables.stderr.includes('根の外'), tables.stderr);
    assert.ok(!tables.stderr.includes('表の置き場が見つからない'), tables.stderr);
  } finally {
    rmSync(R, { recursive: true });
    rmSync(T, { recursive: true });
  }
});

// R に通る見本と、範囲外の起点に使うファイル・ディレクトリを置く
function scopeTree(example: string = passExample): string {
  const R = repo();
  put(R, example);
  writeFileSync(join(R, 'README.md'), '# R\n');
  mkdirSync(join(R, 'src'));
  writeFileSync(join(R, 'src', 'app.ts'), '');
  mkdirSync(join(R, 'lib'));
  writeFileSync(join(R, 'docs', 'notes.md'), '');
  return R;
}

test('範囲外の起点: 根を検査し、注記で扱い2つを示す。終了コードは検査の結果', () => {
  const R = scopeTree();
  const F = scopeTree(failExample);
  try {
    for (const [root, status] of [
      [R, 0],
      [F, 1],
    ] as [string, number][]) {
      const result = run(['check', join(root, 'README.md')], root);
      assert.equal(result.status, status, result.stdout + result.stderr);
      assert.equal(firstLine(result.stdout), `根: ${root}`);
      if (status === 0) assert.match(result.stdout, /違反なし/);
      for (const word of ['注記', join(root, 'README.md'), '根の置き場へ移す', '独立した正本にする', '決められない']) {
        assert.ok(result.stderr.includes(word), `${word}\n${result.stderr}`);
      }
      assert.ok(!result.stderr.includes('候補:'), result.stderr);
    }
  } finally {
    rmSync(R, { recursive: true });
    rmSync(F, { recursive: true });
  }
});

test('候補: 作業ディレクトリが根より下で起点を含み、置き場を含まなければ、そこを示す', () => {
  const R = scopeTree();
  try {
    const result = run(['check', 'app.ts'], join(R, 'src'));
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.ok(result.stderr.includes(`候補: ${join(R, 'src')}`), result.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('候補なし: 作業ディレクトリが置き場を含む・根そのもの・根より上・起点を含まない', () => {
  const R = scopeTree();
  try {
    for (const [cwd, target] of [
      [join(R, 'docs'), join(R, 'docs', 'notes.md')],
      [R, join(R, 'README.md')],
      [dirname(R), join(R, 'README.md')],
      [join(R, 'lib'), join(R, 'src', 'app.ts')],
    ]) {
      const result = run(['check', target], cwd);
      assert.equal(result.status, 0, result.stdout + result.stderr);
      assert.ok(result.stderr.includes('注記'), `${cwd}\n${result.stderr}`);
      assert.ok(!result.stderr.includes('候補:'), `${cwd}\n${result.stderr}`);
    }
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('範囲内の起点と起点なしでは注記を出さない', () => {
  const R = scopeTree();
  try {
    config(R, {});
    for (const [args, cwd] of [
      [['check', join(R, 'docs', 'rdra', 'use-case.yaml')], R],
      [['check', join(R, 'docs', 'rdra')], R],
      [['check', join(R, 'docs')], R],
      [['check', R], R],
      [['check', join(R, '.living-spec.json')], R],
      [['check'], join(R, 'src')],
    ] as [string[], string][]) {
      const result = run(args, cwd);
      assert.equal(result.status, 0, `${args.join(' ')}\n${result.stdout}${result.stderr}`);
      assert.equal(result.stderr, '', args.join(' '));
    }
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('置き場の下の深い階層のディレクトリは範囲外', () => {
  const R = scopeTree();
  try {
    mkdirSync(join(R, 'docs', 'rdra', 'sub'));
    const result = run(['check', join(R, 'docs', 'rdra', 'sub')], R);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.ok(result.stderr.includes('注記'), result.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('render も同じ注記を出し、標準出力は書き出した場所だけ', () => {
  const R = scopeTree();
  try {
    const result = run(['render', join(R, 'README.md')], R);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.equal(result.stdout.trim(), join(R, '.cache', 'living-spec', 'index.html'));
    assert.ok(result.stderr.includes('注記'), result.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

// 既定の描画先
const view = (dir: string) => join(dir, '.cache', 'living-spec', 'index.html');

test('フック: 領域の根の表の編集で、その根を検査し、根からの相対の output に描く', () => {
  const R = repo();
  try {
    const D = join(R, 'domains', 'a');
    put(D, failExample);
    config(D, { output: 'out/view.html' });
    for (const rel of ['docs/requirements/withdraw.md', 'docs/examples/withdraw.feature']) {
      mkdirSync(dirname(join(D, rel)), { recursive: true });
      cpSync(join(requirementMissingExample, rel), join(D, rel));
    }
    const result = hookAt(join(D, 'docs', 'rdra', 'use-case.yaml'), R);
    assert.equal(result.status, 2, result.stdout + result.stderr);
    assert.match(result.stderr, /\[undefined-reference\]/);
    assert.ok(result.stderr.includes(D), result.stderr);
    assert.ok(existsSync(join(D, 'out', 'view.html')));
    assert.ok(!existsSync(join(R, '.cache')));
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('フック: 入れ子では編集したファイルに最も近い根を検査する', () => {
  const R = repo();
  try {
    put(R, passExample);
    config(R, {});
    const D = join(R, 'domains', 'a');
    put(D, failExample);
    config(D, {});
    const inner = hookAt(join(D, 'docs', 'rdra', 'use-case.yaml'), R);
    assert.equal(inner.status, 2, inner.stdout + inner.stderr);
    assert.ok(existsSync(view(D)));
    const outer = hookAt(join(R, 'docs', 'rdra', 'use-case.yaml'), R);
    assert.equal(outer.status, 0, outer.stdout + outer.stderr);
    assert.ok(existsSync(view(R)));
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('フック: 範囲外・置き場の下の深い階層・目印の無い木の編集では何もしない', () => {
  const R = repo();
  const X = repo();
  try {
    const D = join(R, 'domains', 'a');
    put(D, passExample);
    for (const rel of ['README.md', 'docs/rdra/sub/x.yaml', 'docs/examples/sub/x.feature']) {
      mkdirSync(dirname(join(D, rel)), { recursive: true });
      writeFileSync(join(D, rel), '');
      const result = hookAt(join(D, rel), R);
      assert.equal(result.status, 0, `${rel}\n${result.stdout}${result.stderr}`);
      assert.ok(!existsSync(join(D, '.cache')), rel);
    }
    const none = hookAt(join(X, 'docs', 'rdra', 'x.yaml'), X);
    assert.equal(none.status, 0, none.stdout + none.stderr);
    assert.ok(!existsSync(join(X, '.cache')));
  } finally {
    rmSync(R, { recursive: true });
    rmSync(X, { recursive: true });
  }
});

test('フック: 例と要求票の置き場の直下の編集で根を検査する', () => {
  const R = repo();
  try {
    put(R, passExample);
    const broken = join(R, 'docs', 'examples', 'broken.feature');
    mkdirSync(dirname(broken), { recursive: true });
    writeFileSync(broken, 'これは Gherkin ではない\n');
    const example = hookAt(broken, R);
    assert.equal(example.status, 2, example.stdout + example.stderr);
    assert.match(example.stderr, /\[example-syntax\]/);
    assert.ok(existsSync(view(R)));
    rmSync(join(R, '.cache'), { recursive: true });
    const requirement = join(R, 'docs', 'requirements', 'x.md');
    mkdirSync(dirname(requirement), { recursive: true });
    writeFileSync(requirement, '# x\n');
    hookAt(requirement, R);
    assert.ok(existsSync(view(R)));
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('フック: CLAUDE_PROJECT_DIR は根を変えず、外の編集も除かない', () => {
  const R = repo();
  const elsewhere = bare();
  try {
    put(R, passExample);
    config(R, { output: 'out/r.html' });
    const W = join(R, '.worktrees', 'w');
    put(W, failExample);
    writeFileSync(join(W, '.git'), `gitdir: ${join(R, '.git', 'worktrees', 'w')}\n`);
    for (const projectDir of ['', R, join(W, 'docs'), elsewhere]) {
      rmSync(join(W, '.cache'), { recursive: true, force: true });
      rmSync(join(R, 'out'), { recursive: true, force: true });
      const result = hookAt(join(W, 'docs', 'rdra', 'use-case.yaml'), projectDir);
      assert.equal(result.status, 2, `CLAUDE_PROJECT_DIR=${projectDir}: ${result.stdout}${result.stderr}`);
      assert.ok(existsSync(view(W)), projectDir);
      assert.ok(!existsSync(join(R, 'out', 'r.html')), projectDir);
    }
  } finally {
    rmSync(R, { recursive: true });
    rmSync(elsewhere, { recursive: true });
  }
});

test('フック: worktree の中の、目印の無い場所の編集では何もしない', () => {
  const R = repo();
  try {
    put(R, passExample);
    config(R, {});
    const W = join(R, '.worktrees', 'w');
    mkdirSync(join(W, 'spec'), { recursive: true });
    writeFileSync(join(W, '.git'), `gitdir: ${join(R, '.git', 'worktrees', 'w')}\n`);
    writeFileSync(join(W, 'spec', 'use-case.yaml'), '');
    const result = hookAt(join(W, 'spec', 'use-case.yaml'), R);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.equal(result.stderr, '');
    assert.ok(!existsSync(join(R, '.cache')));
    assert.ok(!existsSync(join(W, '.cache')));
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('フック: 相対の file_path は基点で絶対化し、根はそのファイルから決める', () => {
  const R = repo();
  try {
    const D = join(R, 'domains', 'a');
    put(D, passExample);
    const rel = 'domains/a/docs/rdra/use-case.yaml';
    for (const [projectDir, cwd] of [
      [R, undefined],
      ['', R],
    ] as [string, string | undefined][]) {
      rmSync(join(D, '.cache'), { recursive: true, force: true });
      const result = hookAt(rel, projectDir, cwd);
      assert.equal(result.status, 0, `CLAUDE_PROJECT_DIR=${projectDir}: ${result.stdout}${result.stderr}`);
      assert.ok(existsSync(view(D)), `CLAUDE_PROJECT_DIR=${projectDir}`);
      assert.ok(!existsSync(join(R, '.cache')), `CLAUDE_PROJECT_DIR=${projectDir}`);
    }
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('フック: 作業ツリーの下の設定の無い既定の置き場は、その場所を根にする', () => {
  const R = repo();
  try {
    const sub = join(R, 'sub');
    put(sub, failExample);
    for (const projectDir of [R, '']) {
      rmSync(join(sub, '.cache'), { recursive: true, force: true });
      const result = hookAt(join(sub, 'docs', 'rdra', 'use-case.yaml'), projectDir);
      assert.equal(result.status, 2, `CLAUDE_PROJECT_DIR=${projectDir}: ${result.stdout}${result.stderr}`);
      assert.ok(existsSync(view(sub)), `CLAUDE_PROJECT_DIR=${projectDir}`);
    }
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('フック: 設定のある根の下の設定の無い領域を、その領域の根で検査する', () => {
  const R = repo();
  try {
    put(R, passExample);
    config(R, {});
    const D = join(R, 'domains', 'a');
    put(D, failExample);
    const requirement = join(D, 'docs', 'requirements', 'x.md');
    mkdirSync(dirname(requirement), { recursive: true });
    writeFileSync(requirement, '# x\n');
    const table = hookAt(join(D, 'docs', 'rdra', 'use-case.yaml'), R);
    assert.equal(table.status, 2, table.stdout + table.stderr);
    assert.ok(!existsSync(join(R, '.cache')));
    rmSync(join(D, '.cache'), { recursive: true, force: true });
    const req = hookAt(requirement, R);
    assert.equal(req.status, 2, req.stdout + req.stderr);
    assert.ok(existsSync(view(D)));
    assert.ok(!existsSync(join(R, '.cache')));
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('フック: submodule の docs の表の編集はルートを根にする', () => {
  const R = submoduleTree('file', gitmodulesDocs);
  try {
    for (const withConfig of [false, true]) {
      if (withConfig) config(R, {});
      rmSync(join(R, '.cache'), { recursive: true, force: true });
      const result = hookAt(useCase(R), R);
      assert.ok(existsSync(view(R)), `設定${withConfig ? 'あり' : 'なし'}: ${result.stdout}${result.stderr}`);
    }
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('フック: git の外の目印も根にし、CLAUDE_PROJECT_DIR を下にしても変わらない', () => {
  const proj = bare();
  try {
    put(proj, failExample);
    for (const projectDir of [join(proj, 'docs'), '']) {
      rmSync(join(proj, '.cache'), { recursive: true, force: true });
      const result = hookAt(join(proj, 'docs', 'rdra', 'use-case.yaml'), projectDir);
      assert.equal(result.status, 2, `CLAUDE_PROJECT_DIR=${projectDir}: ${result.stdout}${result.stderr}`);
      assert.ok(existsSync(view(proj)), `CLAUDE_PROJECT_DIR=${projectDir}`);
    }
  } finally {
    rmSync(proj, { recursive: true });
  }
});

test('フック: 範囲外の明示の対象では何もしない', () => {
  const R = repo();
  try {
    put(R, passExample);
    writeFileSync(join(R, 'README.md'), '# R\n');
    const result = hookAt(join(R, 'README.md'), R);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.ok(!existsSync(join(R, '.cache')));
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('フック: 根の表の置き場が別の根を含む祖先を指しても、それぞれの根で検査する', () => {
  const R = repo();
  try {
    config(R, { tables: 'domains' });
    cpSync(join(passExample, 'docs', 'rdra'), join(R, 'domains'), { recursive: true });
    const D = join(R, 'domains', 'a');
    put(D, failExample);
    const outer = hookAt(join(R, 'domains', 'actor.yaml'), R);
    assert.equal(outer.status, 0, outer.stdout + outer.stderr);
    assert.ok(existsSync(view(R)));
    assert.ok(!existsSync(join(D, '.cache')));
    const inner = hookAt(join(D, 'docs', 'rdra', 'use-case.yaml'), R);
    assert.equal(inner.status, 2, inner.stdout + inner.stderr);
    assert.ok(existsSync(view(D)));
    const checked = run(['check', R], R);
    assert.equal(firstLine(checked.stdout), `根: ${R}`);
    assert.equal(checked.status, 0, checked.stdout + checked.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('根の探索で読めない: 置き場の検証で読めなければ、根を1行目と文面に示して終了コード 2', () => {
  const R = repo();
  try {
    put(R, passExample);
    config(R, { requirements: 'a/b' });
    mkdirSync(join(R, 'a'));
    writeFileSync(join(R, 'a', '.git'), 'gitdir: ../.git/modules/a\n');
    mkdirSync(join(R, '.gitmodules'));
    const checked = run(['check', R], R);
    assert.equal(checked.status, 2, checked.stdout + checked.stderr);
    assert.equal(firstLine(checked.stdout), `根: ${R}`);
    assert.ok(checked.stderr.includes('根の探索で読めない'), checked.stderr);
    assert.ok(checked.stderr.includes(join(R, '.gitmodules')), checked.stderr);
    assert.ok(checked.stderr.includes(`（根: ${R}）`), checked.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('根に属さない置き場: 根の設定の編集でのフックは、check と同じ文面で終了コード 2', () => {
  for (const tree of misplacedRoots()) {
    try {
      const checked = run(['check', tree.root], tree.root);
      const result = hookAt(join(tree.root, '.living-spec.json'), tree.root);
      assert.equal(result.status, 2, `${tree.name}: ${result.stdout}${result.stderr}`);
      assert.equal(result.stderr, checked.stderr, tree.name);
      if (tree.name === '根の外') {
        const requirement = join(tree.root, 'docs', 'requirements', 'x.md');
        mkdirSync(dirname(requirement), { recursive: true });
        writeFileSync(requirement, '# x\n');
        const edited = hookAt(requirement, tree.root);
        assert.equal(edited.status, 2, `${tree.name}: ${edited.stdout}${edited.stderr}`);
        assert.equal(edited.stderr, checked.stderr, tree.name);
      }
    } finally {
      rmSync(tree.base, { recursive: true });
    }
  }
});

test('根に属さない置き場があっても、範囲外の編集ではフックは何もしない', () => {
  const trees = misplacedRoots();
  try {
    const tree = trees.find((t) => t.name === '根の外');
    assert.ok(tree);
    writeFileSync(join(tree.root, 'README.md'), '# R\n');
    const result = hookAt(join(tree.root, 'README.md'), tree.root);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.equal(result.stderr, '');
  } finally {
    for (const t of trees) rmSync(t.base, { recursive: true });
  }
});

test('外れた置き場が存在しなくても、根の設定の編集で止める', () => {
  const R = repo();
  try {
    config(R, { tables: '../nowhere' });
    const result = hookAt(join(R, '.living-spec.json'), R);
    assert.equal(result.status, 2, result.stdout + result.stderr);
    assert.ok(result.stderr.includes('根の外'), result.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('フック: 設定はあるのに表の置き場が無ければ何もしない', () => {
  const R = repo();
  try {
    config(R, {});
    const result = hookAt(join(R, '.living-spec.json'), R);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.equal(result.stderr, '');
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('フック: hook が偽なら、根に属さない置き場があっても何もしないが、CLI は止まる', () => {
  const R = repo();
  try {
    config(R, { hook: false, tables: '../shared/rdra' });
    const result = hookAt(join(R, '.living-spec.json'), R);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.equal(result.stderr, '');
    const checked = run(['check', R], R);
    assert.equal(checked.status, 2, checked.stdout + checked.stderr);
    assert.equal(firstLine(checked.stdout), `根: ${R}`);
    assert.ok(checked.stderr.includes('根の外'), checked.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('フック: hook の偽はその根の編集にだけ効き、下の設定の無い領域には効かない', () => {
  const R = repo();
  try {
    put(R, passExample);
    config(R, { hook: false });
    const D = join(R, 'domains', 'a');
    put(D, failExample);
    const inner = hookAt(join(D, 'docs', 'rdra', 'use-case.yaml'), R);
    assert.equal(inner.status, 2, inner.stdout + inner.stderr);
    assert.ok(existsSync(view(D)));
    const outer = hookAt(join(R, 'docs', 'rdra', 'use-case.yaml'), R);
    assert.equal(outer.status, 0, outer.stdout + outer.stderr);
    assert.ok(!existsSync(join(R, '.cache')));
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('フック: 根の設定を読めなければ、範囲外の編集でも check と同じ文面で止まる', () => {
  const R = repo();
  try {
    put(R, passExample);
    writeFileSync(join(R, '.living-spec.json'), '{');
    mkdirSync(join(R, 'src'));
    writeFileSync(join(R, 'src', 'app.ts'), '');
    const checked = run(['check', R], R);
    const result = hookAt(join(R, 'src', 'app.ts'), R);
    assert.equal(result.status, 2, result.stdout + result.stderr);
    assert.equal(result.stderr, checked.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('フック: 入れ子のリポジトリの docs の中の既定の置き場の編集では、外側の根を拾わず何もしない', () => {
  const R = repo();
  try {
    put(R, passExample);
    config(R, {});
    mkdirSync(join(R, 'docs', '.git'));
    for (const projectDir of [R, '']) {
      const result = hookAt(join(R, 'docs', 'rdra', 'use-case.yaml'), projectDir);
      assert.equal(result.status, 0, `CLAUDE_PROJECT_DIR=${projectDir}: ${result.stdout}${result.stderr}`);
      assert.equal(result.stderr, '', `CLAUDE_PROJECT_DIR=${projectDir}`);
      assert.ok(!existsSync(join(R, '.cache')), `CLAUDE_PROJECT_DIR=${projectDir}`);
    }
    const checked = run(['check', R], R);
    assert.equal(checked.status, 2, checked.stdout + checked.stderr);
    assert.equal(firstLine(checked.stdout), `根: ${R}`);
    assert.ok(checked.stderr.includes('境界'), checked.stderr);
    assert.ok(checked.stderr.includes(join(R, 'docs')), checked.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('フック: 置き場の検証は置き場そのものから辿る', () => {
  const R = repo();
  const S = repo();
  try {
    put(R, passExample);
    renameSync(join(R, 'docs', 'rdra'), join(R, 'sub'));
    config(R, { tables: 'sub' });
    config(join(R, 'sub'), {});
    const checked = run(['check', R], R);
    const other = hookAt(join(R, '.living-spec.json'), R);
    assert.equal(other.status, 2, other.stdout + other.stderr);
    assert.equal(other.stderr, checked.stderr);

    put(S, passExample);
    cpSync(join(S, 'docs', 'rdra'), S, { recursive: true });
    rmSync(join(S, 'docs', 'rdra'), { recursive: true });
    config(S, { tables: '.' });
    const self = hookAt(join(S, 'use-case.yaml'), S);
    assert.equal(self.status, 0, self.stdout + self.stderr);
    assert.ok(existsSync(view(S)));
  } finally {
    rmSync(R, { recursive: true });
    rmSync(S, { recursive: true });
  }
});

test('フック: 根が決まる前の探索でファイルを読めなければ、何もせず終了コード 0（check は 2）', () => {
  const R = submoduleTree('file', null);
  try {
    mkdirSync(join(R, '.gitmodules'));
    const checked = run(['check', useCase(R)], R);
    assert.equal(checked.status, 2, checked.stdout + checked.stderr);
    const result = hookAt(useCase(R), R);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.equal(result.stderr, '');
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('フック: 根が決まった後の探索でファイルを読めなければ、check と同じ文面で終了コード 2', () => {
  const R = repo();
  try {
    put(R, passExample);
    config(R, { requirements: 'a/b' });
    mkdirSync(join(R, 'a'));
    writeFileSync(join(R, 'a', '.git'), 'gitdir: ../.git/modules/a\n');
    mkdirSync(join(R, '.gitmodules'));
    const checked = run(['check', R], R);
    const result = hookAt(join(R, '.living-spec.json'), R);
    assert.equal(result.status, 2, result.stdout + result.stderr);
    assert.equal(result.stderr, checked.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('注記の範囲は設定の置き場で決める: 設定の表の置き場は範囲内、既定の置き場の位置は範囲外', () => {
  const R = repo();
  try {
    put(R, passExample);
    renameSync(join(R, 'docs', 'rdra'), join(R, 'domains'));
    config(R, { tables: 'domains' });
    const inside = run(['check', join(R, 'domains', 'actor.yaml')], R);
    assert.equal(inside.status, 0, inside.stdout + inside.stderr);
    assert.equal(inside.stderr, '');
    mkdirSync(join(R, 'docs', 'rdra'));
    const outside = run(['check', join(R, 'docs', 'rdra')], R);
    assert.equal(outside.status, 0, outside.stdout + outside.stderr);
    assert.ok(outside.stderr.includes('注記'), outside.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('境界: .gitmodules の引用符で囲んだ path の後ろの注釈は値に含めない', () => {
  const R = submoduleTree('file', '[submodule "docs"]\n\tpath = "docs" # pinned\n');
  try {
    const out = run(['check', useCase(R)], R);
    assert.equal(firstLine(out.stdout), `根: ${R}`, out.stdout + out.stderr);
    assert.equal(out.status, 0, out.stdout + out.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('目印: docs が自身の設定を持てば、その docs/rdra は親の目印にならない', () => {
  const R = repo();
  try {
    config(join(R, 'docs'), { tables: 'rdra' });
    cpSync(join(passExample, 'docs', 'rdra'), join(R, 'docs', 'rdra'), { recursive: true });
    const plain = run(['check'], R);
    assert.equal(plain.status, 2, plain.stdout + plain.stderr);
    assert.doesNotMatch(plain.stdout, rootLine);
    assert.ok(plain.stderr.includes('正本が見つからない'), plain.stderr);
    const docs = run(['check', join(R, 'docs')], R);
    assert.equal(firstLine(docs.stdout), `根: ${join(R, 'docs')}`, docs.stdout + docs.stderr);
    assert.equal(docs.status, 0, docs.stdout + docs.stderr);
    const edited = hookAt(join(R, 'docs', 'rdra', 'use-case.yaml'), R);
    assert.equal(edited.status, 0, edited.stdout + edited.stderr);
    assert.ok(existsSync(view(join(R, 'docs'))));
    assert.ok(!existsSync(join(R, '.cache')));
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('目印: docs/rdra が自身の設定を持てば、親の目印にならず、そこが根になる', () => {
  const R = repo();
  try {
    config(join(R, 'docs', 'rdra'), { tables: '.' });
    cpSync(join(passExample, 'docs', 'rdra'), join(R, 'docs', 'rdra'), { recursive: true });
    const file = run(['check', join(R, 'docs', 'rdra', 'use-case.yaml')], R);
    assert.equal(firstLine(file.stdout), `根: ${join(R, 'docs', 'rdra')}`, file.stdout + file.stderr);
    const plain = run(['check'], R);
    assert.equal(plain.status, 2, plain.stdout + plain.stderr);
    assert.doesNotMatch(plain.stdout, rootLine);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('置き場の値の先頭以外に docs/rdra の並びがあれば、置き場がまだ無くても別の根の中の誤り', () => {
  const R = repo();
  try {
    put(R, passExample);
    config(R, { requirements: 'x/docs/rdra' });
    const checked = run(['check', R], R);
    assert.equal(checked.status, 2, checked.stdout + checked.stderr);
    assert.equal(firstLine(checked.stdout), `根: ${R}`);
    for (const word of ['別の根', join(R, 'x')]) assert.ok(checked.stderr.includes(word), `${word}\n${checked.stderr}`);
    assert.ok(!existsSync(join(R, 'x')));
    const edited = hookAt(join(R, '.living-spec.json'), R);
    assert.equal(edited.status, 2, edited.stdout + edited.stderr);
    assert.equal(edited.stderr, checked.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('置き場の値の先頭の docs/rdra の並びは、別の根の中の誤りにしない', () => {
  const R = repo();
  try {
    put(R, passExample);
    config(R, { requirements: 'docs/rdra/req' });
    const checked = run(['check', R], R);
    assert.equal(checked.status, 0, checked.stdout + checked.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});

test('候補なし: 作業ディレクトリが置き場の中にある', () => {
  const R = repo();
  try {
    put(R, passExample);
    mkdirSync(join(R, 'docs', 'rdra', 'sub'));
    writeFileSync(join(R, 'docs', 'rdra', 'sub', 'x.yaml'), '');
    const result = run(['check', 'x.yaml'], join(R, 'docs', 'rdra', 'sub'));
    assert.ok(result.stderr.includes('注記'), result.stderr);
    assert.ok(!result.stderr.includes('候補:'), result.stderr);
  } finally {
    rmSync(R, { recursive: true });
  }
});
