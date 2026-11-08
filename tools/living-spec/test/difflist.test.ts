// 差分の一覧（difflist.ts）の行を、ファイルを置かずに確かめる。見本の2版は diff.test.ts と同じく test/render/diff-base.txtar・diff-head.txtar。
// 行の形（種類・区分の語・同一性の値のタブ区切り）の正本は references/format.md の「基準の版から変わった要素の一覧（`diff`）」である。
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { extract, parseTxtar } from './fixture.ts';
import { commitAll, gitEnv, gitRepo } from './git.ts';
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

// ---- CLI: diff --base。標準出力は一覧の行だけ（根の行も注記も混ぜない） ----

const main = process.env.RDRA_ENTRY ?? join(here, '..', 'src', 'main.ts');
const DIFF_BASE = join(here, 'render', 'diff-base.txtar');
const DIFF_HEAD = join(here, 'render', 'diff-head.txtar');
const expected = diffListLines(diffSources(base, head)).map((l) => `${l}\n`).join('');

function runDiff(cwd: string, args: string[]) {
  return spawnSync(process.execPath, [main, 'diff', ...args], { cwd, env: gitEnv, encoding: 'utf8' });
}

// 止まる: 終了コード 2、標準出力が空、標準エラーに文面の語句、描き分けの置き場（.cache）を作らない
function assertStopped(result: ReturnType<typeof runDiff>, root: string, phrase: string): void {
  assert.equal(result.status, 2, result.stderr);
  assert.equal(result.stdout, '');
  assert.ok(result.stderr.includes(phrase), `標準エラーに『${phrase}』がある\n${result.stderr}`);
  assert.ok(!existsSync(join(root, '.cache')), '.cache を作らない');
}

function withDiffRepo(f: (repo: string) => void): void {
  const repo = gitRepo();
  try {
    extract(DIFF_BASE, repo);
    commitAll(repo);
    rmSync(join(repo, 'docs'), { recursive: true });
    extract(DIFF_HEAD, repo);
    f(repo);
  } finally {
    rmSync(repo, { recursive: true });
  }
}

test('CLI: diff --base は、基準の版と作業ツリーの差を一覧の行だけで標準出力へ出し、何も書かず終了コード 0', () => {
  assert.notEqual(expected, '');
  withDiffRepo((repo) => {
    const result = runDiff(repo, ['--base', 'main', repo]);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, expected);
    assert.ok(!result.stdout.startsWith('根: '));
    assert.ok(!existsSync(join(repo, '.cache')));
  });
});

test('CLI: diff --base は、作業ツリーが基準の版と同じなら標準出力が空で終了コード 0', () => {
  const repo = gitRepo();
  try {
    extract(DIFF_BASE, repo);
    commitAll(repo);
    const result = runDiff(repo, ['--base', 'main', repo]);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, '');
  } finally {
    rmSync(repo, { recursive: true });
  }
});

test('CLI: diff --base は、根が下位ディレクトリにあり両版で同じ位置なら同じ一覧を出す（--base は起点の後ろでもよい）', () => {
  const repo = gitRepo();
  const area = join(repo, 'area');
  try {
    extract(DIFF_BASE, area);
    commitAll(repo);
    rmSync(join(area, 'docs'), { recursive: true });
    extract(DIFF_HEAD, area);
    const result = runDiff(repo, [area, '--base', 'main']);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, expected);
  } finally {
    rmSync(repo, { recursive: true });
  }
});

test('CLI: diff --base は、起点が範囲外でも注記を標準エラーだけへ出し、標準出力へ混ぜない', () => {
  const repo = gitRepo();
  try {
    extract(DIFF_BASE, repo);
    writeFileSync(join(repo, 'README.md'), '# 説明\n');
    commitAll(repo);
    const result = runDiff(repo, ['--base', 'main', join(repo, 'README.md')]);
    assert.equal(result.status, 0, result.stderr);
    assert.ok(result.stderr.includes(`注記: ${join(repo, 'README.md')} は根 ${repo} の置き場`), result.stderr);
    assert.equal(result.stdout, '');
  } finally {
    rmSync(repo, { recursive: true });
  }
});

test('CLI: diff --base は、版が無ければ止まる', () => {
  const repo = gitRepo();
  try {
    extract(DIFF_BASE, repo);
    commitAll(repo);
    assertStopped(runDiff(repo, ['--base', 'no-such', repo]), repo, `基準の版が見つからない: no-such（根: ${repo}）`);
  } finally {
    rmSync(repo, { recursive: true });
  }
});

test('CLI: diff --base は、基準の版の .living-spec.json を読めなければ止まる', () => {
  const repo = gitRepo();
  try {
    extract(DIFF_BASE, repo);
    writeFileSync(join(repo, '.living-spec.json'), '{');
    commitAll(repo);
    rmSync(join(repo, '.living-spec.json'));
    assertStopped(runDiff(repo, ['--base', 'main', repo]), repo, `基準の版 main の .living-spec.json を読めない（根: ${repo}）: `);
  } finally {
    rmSync(repo, { recursive: true });
  }
});

test('CLI: diff の引数の誤り（--base が無い・値が無い・空・- で始まる・2回・知らない --・起点が2つ）は、使い方を出して終了コード 2', () => {
  const root = mkdtempSync(join(tmpdir(), 'living-spec-diff-args-'));
  try {
    extract(DIFF_BASE, root);
    for (const args of [
      [],
      [root],
      ['--base'],
      ['--base', '', root],
      ['--base', '-x', root],
      ['--base', 'main', '--base', 'main', root],
      ['--base', 'main', '--x', root],
      ['--base', 'main', root, root],
    ]) {
      const result = runDiff(root, args);
      assert.equal(result.status, 2, `${args.join(' ')}: ${result.stderr}`);
      assert.equal(result.stdout, '', args.join(' '));
      assert.match(result.stderr, /使い方/, args.join(' '));
    }
  } finally {
    rmSync(root, { recursive: true });
  }
});

test('CLI: diff --base は、目印の無い場所では作業ツリーの側で止まり、基準の版の文面ではない', () => {
  const dir = mkdtempSync(join(tmpdir(), 'living-spec-diff-nomark-'));
  try {
    mkdirSync(join(dir, 'sub'));
    const result = runDiff(join(dir, 'sub'), ['--base', 'main']);
    assert.equal(result.status, 2, result.stderr);
    assert.equal(result.stdout, '');
    assert.ok(result.stderr.includes('正本が見つからない: '), result.stderr);
    assert.ok(!/^基準の版/m.test(result.stderr), result.stderr);
  } finally {
    rmSync(dir, { recursive: true });
  }
});

// ---- AC4: 要求票の2行目だけを書き換えた版・UC の足し外しと条件の説明の書き換えだけの版（test/difflist/） ----

// 基準の版をコミットしてから作業ツリーを作業ツリーの版へ替え、diff --base main の標準出力と終了コードを返す
function diffOfSample(name: string) {
  const repo = gitRepo();
  try {
    extract(join(here, 'difflist', `${name}-base.txtar`), repo);
    commitAll(repo);
    rmSync(join(repo, 'docs'), { recursive: true });
    extract(join(here, 'difflist', `${name}-head.txtar`), repo);
    return runDiff(repo, ['--base', 'main', repo]);
  } finally {
    rmSync(repo, { recursive: true });
  }
}

const lines = (rows: string[]): string => rows.map((l) => `${l}\n`).join('');

test('C5: 要求票の2行目だけを書き換えると、要求票が変わった・要求文が足された・外された、が票の順に出る', () => {
  const ucs = ['申請を作成する', '申請を提出する', '申請を承認する'];
  const added = [
    '作成した申請の持ち主と日時を記録する',
    '提出の日時と提出者を記録する',
    '承認の日時と承認者を記録する',
  ];
  const removed = ['作成した申請の持ち主を記録する', '提出の日時を記録する', '承認の日時を記録する'];
  const subject = ['従業員が申請を作成する', '従業員が申請を提出する', '上長が申請を承認する'];
  const result = diffOfSample('requirement-lines');
  assert.equal(result.status, 0, result.stderr);
  assert.equal(
    result.stdout,
    lines([
      ...ucs.map((u) => `要求票\t変わった\t${u}`),
      ...ucs.map((u, i) => `要求文\t足された\t${u}\t${subject[i]}とき、システムは${added[i]}`),
      ...ucs.map((u, i) => `要求文\t外された\t${u}\t${subject[i]}とき、システムは${removed[i]}`),
    ]),
  );
});

test('C6: UC の足し外しと条件の説明の書き換えは、UC と条件の行だけが出る', () => {
  const result = diffOfSample('uc-condition');
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, lines(['UC\t足された\t申請を複製する', 'UC\t外された\t申請を取り下げる', '条件\t変わった\t金額の条件']));
});
