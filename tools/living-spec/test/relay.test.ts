// 中継（plugins/living-spec/scripts/run.mjs）が、前提より古い検査器のフックを、その検査器自身の範囲の判定のまま扱うことを、本物の入口で確かめる。
// 中継は、古い検査器のフックが検査したかを、描き直しのファイルの書き込み・描き直しの失敗の文面・0 以外の終了で知る。ここでは入口を包んで世代だけを古く答えさせ、
// 範囲内の編集（違反なし・あり）で前提より古い旨の1行と終了コード 2 になり、検査しない編集では出力も終了コードも入口のままであることを見る。
// 中継の引数・標準入力の受け渡しと、check・render の扱いは scripts/tests/living-spec-run.bats が偽の検査器で確かめる。
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { COMPAT } from '../src/compat.ts';
import { materialize } from './fixture.ts';

const here = dirname(fileURLToPath(import.meta.url));
const main = resolve(process.env.RDRA_ENTRY ?? join(here, '..', 'src', 'main.ts'));
const relay = join(here, '..', '..', '..', 'plugins', 'living-spec', 'scripts', 'run.mjs');
const passExample = materialize(join(here, '..', 'examples', 'unknown-key', 'pass-all-allowed-keys.txtar'));
const failExample = materialize(join(here, '..', 'examples', 'undefined-reference', 'fail-uc-actor.txtar'));
const stale = /^living-spec の検査器が、このプラグインの前提より古い.*plugins\/living-spec\/README\.md.*の「検査器の導入」/m;

// 入口を包み、compat にだけ古い世代を答える検査器を作る。none は世代を答えない版のように使い方を出して終わる
function staleChecker(dir: string, answer: 'older' | 'none'): string {
  const path = join(dir, `stale-${answer}.mjs`);
  const compat =
    answer === 'older' ? `console.log('${COMPAT - 1}'); process.exit(0);` : `console.error('使い方'); process.exit(2);`;
  writeFileSync(path, `if (process.argv[2] === 'compat') { ${compat} }\nawait import(${JSON.stringify(pathToFileURL(main).href)});\n`);
  return path;
}

// checker が undefined なら中継を通さず入口のフックを直接走らせる（変更前の出力と終了コード）
function hook(checker: string | undefined, file: string, projectDir: string) {
  const input = JSON.stringify({ tool_input: { file_path: file } });
  const env: Record<string, string | undefined> = { ...process.env, CLAUDE_PROJECT_DIR: projectDir };
  delete env.LIVING_SPEC_BIN;
  if (checker !== undefined) env.LIVING_SPEC_BIN = checker;
  const argv = checker === undefined ? [main, 'hook'] : [relay, 'hook'];
  return spawnSync(process.execPath, argv, { cwd: tmpdir(), encoding: 'utf8', input, env });
}

function scratch(): string {
  return realpathSync(mkdtempSync(join(tmpdir(), 'living-spec-relay-')));
}

function tree(example: string): string {
  const dir = scratch();
  cpSync(example, dir, { recursive: true });
  return dir;
}

for (const answer of ['older', 'none'] as const) {
  test(`中継のフック（世代: ${answer}）: 範囲内の編集では、違反の有無によらず前提より古い旨の1行と終了コード 2`, () => {
    const work = scratch();
    const pass = tree(passExample);
    const fail = tree(failExample);
    try {
      const checker = staleChecker(work, answer);
      const clean = hook(checker, join(pass, 'docs/rdra/use-case.yaml'), pass);
      assert.equal(hook(undefined, join(pass, 'docs/rdra/use-case.yaml'), pass).status, 0, '入口だけなら違反なしで通る入力');
      assert.equal(clean.status, 2, clean.stderr);
      assert.match(clean.stderr, stale);
      const dirty = hook(checker, join(fail, 'docs/rdra/use-case.yaml'), fail);
      assert.equal(dirty.status, 2, dirty.stderr);
      assert.match(dirty.stderr, stale);
      assert.match(dirty.stderr, /\[undefined-reference\]/);
      assert.ok(dirty.stderr.search(stale) < dirty.stderr.indexOf('[undefined-reference]'), '古い旨の行は違反の行より前');
    } finally {
      for (const d of [work, pass, fail]) rmSync(d, { recursive: true });
    }
  });

  test(`中継のフック（世代: ${answer}）: 検査しない編集では、出力も終了コードも入口のまま`, () => {
    const work = scratch();
    const root = tree(failExample);
    const off = tree(failExample);
    const bare = scratch();
    try {
      writeFileSync(join(off, '.living-spec.json'), '{"hook": false}');
      const checker = staleChecker(work, answer);
      // 範囲外の編集・表の置き場の無いリポジトリ・hook が false
      for (const [file, projectDir] of [
        [join(root, 'src/app.ts'), root],
        [join(bare, 'docs/rdra/x.yaml'), bare],
        [join(off, 'docs/rdra/use-case.yaml'), off],
      ]) {
        const before = hook(undefined, file, projectDir);
        const after = hook(checker, file, projectDir);
        assert.equal(after.status, 0, file);
        assert.equal(after.status, before.status, file);
        assert.equal(after.stdout, before.stdout, file);
        assert.equal(after.stderr, before.stderr, file);
      }
    } finally {
      for (const d of [work, root, off, bare]) rmSync(d, { recursive: true });
    }
  });
}

test('中継のフック: 前提より古い入口が設定の誤りで止めたときは、範囲外の編集でも古い旨の1行を添える', () => {
  const work = scratch();
  const root = tree(passExample);
  try {
    writeFileSync(join(root, '.living-spec.json'), '{"unknown": 1}');
    const file = join(root, 'src/app.ts');
    const before = hook(undefined, file, root);
    const after = hook(staleChecker(work, 'none'), file, root);
    assert.equal(before.status, 2, before.stderr);
    assert.equal(after.status, 2, after.stderr);
    assert.ok(after.stderr.startsWith(before.stderr), '入口の出力はそのまま');
    assert.match(after.stderr.slice(before.stderr.length), stale);
  } finally {
    for (const d of [work, root]) rmSync(d, { recursive: true });
  }
});

test('中継のフック: 前提を満たす入口では、範囲内の編集の出力も終了コードも入口のまま', () => {
  const fail = tree(failExample);
  try {
    const file = join(fail, 'docs/rdra/use-case.yaml');
    const before = hook(undefined, file, fail);
    const after = hook(main, file, fail);
    assert.equal(after.status, 2, after.stderr);
    assert.equal(after.status, before.status);
    assert.equal(after.stdout, before.stdout);
    assert.equal(after.stderr, before.stderr);
    assert.doesNotMatch(after.stderr, stale);
  } finally {
    rmSync(fail, { recursive: true });
  }
});
