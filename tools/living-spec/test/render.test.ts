// 設計の可視化（render.ts）を確かめる。見本の表は test/render/sample/。
// 図の材料（buildView）・Mermaid の文字列（stateChart）・HTML（renderHtml）・CLI とフックの書き出しを見る。
// 見た目の良し悪しは試験しない（出し手が見て判断する）。
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { renderHtml, stateChart } from '../src/html.ts';
import { buildView } from '../src/view.ts';
import type { StateModelView, UseCaseView, View } from '../src/view.ts';

const here = dirname(fileURLToPath(import.meta.url));
const sample = join(here, 'render', 'sample');
const passExample = join(here, '..', 'examples', 'unknown-key', 'pass-all-allowed-keys');
const main = process.env.RDRA_ENTRY ?? join(here, '..', 'src', 'main.ts');
const SYMBOL_UC = '名前に<b>&"記号</b>がある';

function model(view: View): StateModelView {
  const m = view.stateModels.find((x) => x.name === '申請の状態');
  assert.ok(m, '状態モデル『申請の状態』がある');
  return m;
}

function useCase(view: View, name: string): UseCaseView {
  const uc = view.useCases.find((x) => x.name === name);
  assert.ok(uc, `UC『${name}』がある`);
  return uc;
}

// HTML のうち、UC の縦串の節（id="uc-N" の section）だけを切り出す
function sliceOf(html: string, uc: UseCaseView): string {
  const start = html.indexOf(`<section class="slice" id="${uc.anchor}"`);
  assert.ok(start >= 0, `縦串の節 ${uc.anchor} がある`);
  const end = html.indexOf('</section>', start);
  return html.slice(start, end);
}

// Mermaid の文字列のうち、名札に label を含む辺の行
function edgeLine(chart: string, label: string): string {
  const line = chart.split('\n').find((l) => /-\.?->/.test(l) && l.includes(label));
  assert.ok(line !== undefined, `名札『${label}』の辺がある\n${chart}`);
  return line;
}

function copySample(from: string): string {
  const dir = mkdtempSync(join(tmpdir(), 'living-spec-render-'));
  cpSync(from, dir, { recursive: true });
  return dir;
}

test('状態の無い記録（初期遷移）は開始点からの辺になる', () => {
  const view = buildView(sample);
  const initial = model(view).transitions.find((t) => t.uc === '申請を作成する');
  assert.equal(initial?.from, null);
  const chart = stateChart(model(view), null);
  const start = chart.match(/^\s*(\w+)\(\(/m);
  assert.ok(start !== null, `開始点（丸）の節点がある\n${chart}`);
  assert.match(edgeLine(chart, '申請を作成する'), new RegExp(`^\\s*${start[1]}\\s+-->`));
});

test('仮説の遷移は破線、仮説でない遷移は実線になる', () => {
  const view = buildView(sample);
  const chart = stateChart(model(view), null);
  assert.match(edgeLine(chart, '申請を承認する'), /-\.->/);
  assert.doesNotMatch(edgeLine(chart, '申請を提出する'), /-\.->/);
  assert.equal(model(view).transitions.find((t) => t.uc === '申請を承認する')?.hypothesis, true);
});

test('UC の縦串の図は、その UC が動かす遷移の辺だけを強調する', () => {
  const view = buildView(sample);
  const chart = stateChart(model(view), '申請を提出する');
  const edges = chart.split('\n').filter((l) => /-\.?->/.test(l));
  const index = edges.findIndex((l) => l.includes('申請を提出する'));
  const styled = chart
    .split('\n')
    .filter((l) => /^\s*linkStyle\s/.test(l))
    .map((l) => l.trim());
  const highlighted = styled.filter((l) => l.includes('stroke-width:3px'));
  assert.equal(highlighted.length, 1, chart);
  assert.match(highlighted[0], new RegExp(`^linkStyle ${index} `));
  // 強調の無い図には強調の linkStyle が無い
  assert.ok(!stateChart(model(view), null).includes('stroke-width:3px'));
});

test('要求票の行の直下に、同じ名前のルールのシナリオ名を結ぶ', () => {
  const uc = useCase(buildView(sample), '申請を提出する');
  assert.equal(uc.requirements.length, 1);
  const [first, second] = uc.requirements[0].lines;
  assert.deepEqual(
    first.scenarios.map((s) => s.name),
    ['種類の無い申請は出せない'],
  );
  assert.equal(first.reason, '種類の無い申請を上長へ回さない（P01 未決事項1）');
  assert.deepEqual(second.scenarios, []);
  assert.equal(uc.requirements[0].reason, '出した申請を上長が見られるようにするため');
});

test('要求票の行の RDRA 欄が指す条件・バリエーション・情報の中身を、その行の直下に畳んで出す', () => {
  const view = buildView(sample);
  const uc = useCase(view, '申請を提出する');
  const [first, second] = uc.requirements[0].lines;
  const condition = first.references.find((r) => r.raw === '条件「提出できる条件」');
  assert.deepEqual(condition?.definition, {
    description: '作成中で、種類が選ばれているときに提出できる',
    values: [],
    attributes: [],
    variations: [{ name: '申請の種類', known: true, values: ['通常', '特急'], description: '申請の急ぎの度合い' }],
  });
  const variation = second.references.find((r) => r.raw === 'バリエーション「申請の種類」');
  assert.deepEqual(variation?.definition, {
    description: '申請の急ぎの度合い',
    values: ['通常', '特急'],
    attributes: [],
    variations: [],
  });
  const create = useCase(view, '申請を作成する').requirements[0].lines[0];
  assert.deepEqual(create.references.find((r) => r.raw === '情報「申請」')?.definition, {
    description: '従業員が出す単位',
    values: [],
    attributes: ['申請者', '状態'],
    variations: [],
  });
  // 条件・バリエーション・情報以外の参照と、表に無い参照は中身を持たない
  assert.equal(first.references.length, 1);
  assert.equal(second.references.find((r) => r.raw === 'アクター「従業員」')?.definition, null);
  assert.equal(second.references.find((r) => r.raw === '情報「表に無い情報」')?.definition, null);

  const slice = sliceOf(renderHtml(view, new Date()), uc);
  const line = slice.slice(slice.indexOf('<ol class="lines">')).split('</li>')[0];
  // 既定で隠す。隠している間に見える見出しの行も持たない（名前をクリックするか、先頭のボタンで開く）
  assert.match(line, /<div class="defs" hidden>/);
  assert.doesNotMatch(line, /<summary>|<details/);
  assert.match(line, /作成中で、種類が選ばれているときに提出できる/);
  assert.match(line, /申請の種類: 通常、特急/);
  // 要求文の中の条件名に印を付け、重ねると説明が出る（ブラウザ標準の title は出るまで待たされるため、CSS で出す data-tip に持つ）
  assert.match(line, /<span class="term" tabindex="0" data-tip="作成中で、種類が選ばれているときに提出できる">提出できる条件<\/span>/);
  assert.doesNotMatch(line, /class="term" title=/);
});

test('要求文の中の印は、表にある長い名前の一部には付けない', () => {
  const view = buildView(sample);
  const slice = sliceOf(renderHtml(view, new Date()), useCase(view, '申請を作成する'));
  const sentence = slice.match(/<p class="sentence">(.*?)<\/p>/)![1];
  // 「申請を作成する」（UC の名前）の中の「申請」には付けず、「作成中の申請」の「申請」にだけ付ける
  assert.equal(sentence.match(/class="term"/g)?.length, 1, sentence);
  assert.match(sentence, /作成中の<span class="term" tabindex="0" data-tip="[^"]*">申請<\/span>を作る/);
});

test('票の行に結び付かない例は別枠に出る', () => {
  const view = buildView(sample);
  const uc = useCase(view, '申請を提出する');
  assert.deepEqual(
    uc.unlinkedRules.map((r) => [r.name, r.scenarios.map((s) => s.name)]),
    [['言い換えて要求文と合わなくなったルール', ['要求文に結び付かない例']]],
  );
  const slice = sliceOf(renderHtml(view, new Date()), uc);
  assert.match(slice, /要求票の行に結び付かない例/);
  assert.match(slice, /要求文に結び付かない例/);
});

test('要求票・例の欠けを明示する', () => {
  const view = buildView(sample);
  const html = renderHtml(view, new Date());
  const approve = sliceOf(html, useCase(view, '申請を承認する'));
  assert.match(approve, /要求票が無い/);
  assert.match(approve, /例が無い/);
  const create = sliceOf(html, useCase(view, '申請を作成する'));
  assert.doesNotMatch(create, /要求票が無い/);
  assert.match(create, /例が無い/);
});

test('表に無い名前で止まらず、印を付けて出す', () => {
  const view = buildView(sample);
  const stray = model(view).transitions.find((t) => t.uc === '表に無いUC');
  assert.equal(stray?.ucKnown, false);
  const submit = useCase(view, '申請を提出する');
  assert.equal(submit.actors.find((a) => a.name === '表に無いアクター')?.known, false);
  assert.equal(
    submit.requirements[0].lines[1].references.find((r) => r.raw === '情報「表に無い情報」')?.known,
    false,
  );
  assert.deepEqual(
    view.strayRequirements.map((r) => r.ucName),
    ['表に無いUC'],
  );
  assert.deepEqual(
    view.strayExamples.map((e) => e.name),
    ['表に無いUC'],
  );
  const html = renderHtml(view, new Date());
  assert.match(edgeLine(stateChart(model(view), null), '表に無いUC'), /⚠/);
  assert.match(sliceOf(html, submit), /class="unknown"[^>]*>[^<]*表に無いアクター/);
});

test('HTML と Mermaid の名札の特殊文字を逃がす', () => {
  const view = buildView(sample);
  const html = renderHtml(view, new Date());
  assert.ok(!html.includes(SYMBOL_UC), '生の名前が HTML に出ない');
  assert.ok(html.includes('名前に&lt;b&gt;&amp;&quot;記号&lt;/b&gt;がある'));
  const label = edgeLine(stateChart(model(view), null), '記号');
  // 名札は "…" で囲む。中に生の " < > & が残らない
  const inner = label.match(/\|"(.*)"\|/);
  assert.ok(inner !== null, label);
  assert.doesNotMatch(inner[1], /["<>&]/);
  assert.ok(inner[1].includes('#quot;'));
});

test('CLI: 根の .cache/living-spec/index.html へ、生成時刻と根のパスを先頭に書き出す', () => {
  const root = copySample(sample);
  try {
    const result = spawnSync(process.execPath, [main, 'render', root], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    const out = join(root, '.cache', 'living-spec', 'index.html');
    assert.ok(existsSync(out));
    const html = readFileSync(out, 'utf8');
    assert.ok(html.includes(root), '根のパスを出す');
    assert.match(html, /生成時刻/);
    assert.ok(result.stdout.includes(out), '書き出した場所を出す');
  } finally {
    rmSync(root, { recursive: true });
  }
});

test('CLI: 根に docs/rdra/ が無ければ終了コード 2 で止まり、何も書かない', () => {
  const empty = mkdtempSync(join(tmpdir(), 'living-spec-render-'));
  try {
    const result = spawnSync(process.execPath, [main, 'render'], { cwd: empty, encoding: 'utf8' });
    assert.equal(result.status, 2);
    assert.match(result.stderr, /docs\/rdra/);
    assert.ok(!existsSync(join(empty, '.cache')));
  } finally {
    rmSync(empty, { recursive: true });
  }
});

function runHook(root: string, file: string) {
  return spawnSync(process.execPath, [main, 'hook'], {
    input: JSON.stringify({ tool_input: { file_path: join(root, file) } }),
    env: { ...process.env, CLAUDE_PROJECT_DIR: root },
    encoding: 'utf8',
  });
}

test('フック: 検査の違反があっても描き直す', () => {
  const root = copySample(sample);
  try {
    const result = runHook(root, 'docs/rdra/state.yaml');
    assert.equal(result.status, 2, '見本の表には違反がある');
    assert.ok(existsSync(join(root, '.cache', 'living-spec', 'index.html')));
  } finally {
    rmSync(root, { recursive: true });
  }
});

test('フック: 描画に失敗しても編集を止めない', () => {
  const root = copySample(passExample);
  try {
    // .cache をファイルにして、書き出しの置き場を作れなくする
    writeFileSync(join(root, '.cache'), '');
    const result = runHook(root, 'docs/rdra/actor.yaml');
    assert.equal(result.status, 0, result.stderr);
  } finally {
    rmSync(root, { recursive: true });
  }
});

test('フック: 対象外のファイルの編集では描かない', () => {
  const root = copySample(passExample);
  try {
    const result = runHook(root, 'README.md');
    assert.equal(result.status, 0);
    assert.ok(!existsSync(join(root, '.cache')));
  } finally {
    rmSync(root, { recursive: true });
  }
});
