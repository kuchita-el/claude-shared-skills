// 設計の可視化（render.ts）を確かめる。見本の表は test/render/sample.txtar。
// 図の材料（buildView）・Mermaid の文字列（stateChart）・HTML（renderHtml）・CLI とフックの書き出しを見る。
// 見た目の良し悪しは試験しない（出し手が見て判断する）。
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { Script } from 'node:vm';
import { cases } from './cases/requirement-reference.ts';
import { materialize } from './fixture.ts';
import { escapeHtml, renderHtml, stateChart } from '../src/html.ts';
import { sourcesFromFiles } from '../src/sources.ts';
import { buildView } from '../src/view.ts';
import type { StateModelView, UseCaseView, View } from '../src/view.ts';
import { parseTxtar } from './fixture.ts';
import { buildDiffView } from '../src/diffview.ts';
import type { Sources } from '../src/sources.ts';
import type { Marked } from '../src/view.ts';
import type { ReferenceView } from '../src/view.ts';
import { diffOutputPath, writeDiffView } from '../src/render.ts';

const here = dirname(fileURLToPath(import.meta.url));
const sample = materialize(join(here, 'render', 'sample.txtar'));
const passExample = materialize(join(here, '..', 'examples', 'unknown-key', 'pass-all-allowed-keys.txtar'));
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

test('要求文が名前を活用させたり略したりしていても描き、名前がそのまま現れる行にだけ印を付ける', () => {
  const found = cases.find((c) => c.name === 'pass-sentence-conjugates-and-abbreviates-names');
  assert.ok(found, '件 pass-sentence-conjugates-and-abbreviates-names がある');
  const view = buildView('/unused', sourcesFromFiles(found.files));
  const html = renderHtml(view, new Date());
  const slice = sliceOf(html, useCase(view, '経費申請を承認する'));
  const sentences = [...slice.matchAll(/<p class="sentence">(.*?)<\/p>/g)].map((m) => m[1]);
  assert.equal(sentences.length, 3, sentences.join('\n'));
  // 行1（略称）と行2（活用）は、表の名前がそのままは現れないので印を付けず、文をそのまま出す
  assert.doesNotMatch(sentences[0], />申請<\/span>/, `略した「申請」に印が付いている: ${sentences[0]}`);
  assert.ok(!sentences[1].includes('class="term"'), sentences[1]);
  assert.equal(sentences[1], '承認できる役割でなければ、システムは承認を受け付けない');
  // 行3は名前がそのまま現れるので印を付ける
  assert.ok(
    sentences[2].includes(
      '<span class="term" tabindex="0" data-tip="従業員が出す経費の申請（属性: 申請者、金額）">経費申請</span>',
    ),
    sentences[2],
  );
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

test('全 UC の縦串を、見出しより下を閉じた状態で出す', () => {
  const view = buildView(sample);
  const html = renderHtml(view, new Date());
  // 空の一覧を回して素通りしないよう、UC があり、全てに縦串の節があることを先に確かめる
  assert.ok(view.useCases.length > 0, '見本に UC がある');
  assert.equal(html.split('<section class="slice"').length - 1, view.useCases.length);
  for (const uc of view.useCases) {
    const slice = sliceOf(html, uc);
    const body = slice.slice(slice.indexOf('>') + 1).trimStart();
    // 節の直下に畳む要素が1つだけあり、open 属性を持たない（閉じた状態の印は open 属性の有無）
    assert.ok(body.startsWith('<details'), `${uc.anchor}: 節の直下が details\n${slice}`);
    assert.equal(slice.split('<details').length - 1, 1, `${uc.anchor}: details は1つ`);
    const openTag = body.slice(0, body.indexOf('>') + 1);
    assert.doesNotMatch(openTag, /\sopen(\s|=|>)/, `${uc.anchor}: 閉じている\n${openTag}`);
    // 見出し（UC 名）だけが summary にある
    const afterOpen = body.slice(openTag.length).trimStart();
    assert.ok(afterOpen.startsWith('<summary>'), `${uc.anchor}: details の最初の子が summary`);
    const summaryEnd = afterOpen.indexOf('</summary>');
    assert.ok(summaryEnd >= 0, `${uc.anchor}: summary が閉じる`);
    const summary = afterOpen.slice(0, summaryEnd);
    assert.ok(summary.includes('<h2>'), `${uc.anchor}: 見出しが summary にある`);
    assert.ok(summary.includes(escapeHtml(uc.name)), `${uc.anchor}: UC 名が summary にある`);
    // 本文は summary の後ろ、details の中にそろう
    const detailsEnd = afterOpen.indexOf('</details>');
    assert.ok(detailsEnd > summaryEnd, `${uc.anchor}: details が閉じる`);
    const content = afterOpen.slice(summaryEnd, detailsEnd);
    for (const part of [
      `<p>${escapeHtml(uc.description)}</p>`,
      '<h4>アクター</h4>',
      '<h4>外部システム</h4>',
      '<h3>状態の遷移</h3>',
      '<h3>情報</h3>',
      '<h3>条件</h3>',
      '<h3>要求票</h3>',
      '<h3>例</h3>',
      '先頭へ',
    ]) {
      assert.ok(content.includes(part), `${uc.anchor}: 本文に ${part} がある`);
    }
    assert.equal(afterOpen.slice(detailsEnd + '</details>'.length).trim(), '', `${uc.anchor}: details の後ろは空`);
  }
  assert.ok(html.includes('<summary><h2>名前に&lt;b&gt;&amp;&quot;記号&lt;/b&gt;がある'));
});

test('開いた直後に見せる部分（ヘッダ・状態遷移図・UC の一覧・結び付かない要求票・例）は畳まない', () => {
  const view = buildView(sample);
  const html = renderHtml(view, new Date());
  const firstSlice = html.indexOf('<section class="slice"');
  assert.ok(firstSlice >= 0);
  const overview = html.slice(0, firstSlice);
  assert.ok(!overview.includes('<details'), '縦串より前に畳む要素が無い');
  assert.ok(overview.indexOf('</header>') > overview.indexOf('<header>'), 'ヘッダが閉じる');
  const header = overview.slice(overview.indexOf('<header>'), overview.indexOf('</header>'));
  for (const part of ['生成時刻', escapeHtml(view.root), '<nav>', 'data-defs="open"', 'data-defs="close"']) {
    assert.ok(header.includes(part), `ヘッダに ${part} がある`);
  }
  const order = ['<header>', '<section id="states">', '<section id="use-cases">', '<section id="stray">'].map((s) =>
    overview.indexOf(s),
  );
  assert.ok(order.every((i) => i >= 0), `全体像の各部がある: ${order}`);
  assert.deepEqual([...order].sort((a, b) => a - b), order, '全体像の各部がこの順に並ぶ');
  const states = overview.slice(order[1], order[2]);
  assert.ok(states.includes('実線は事実、破線は仮説の遷移'), '凡例がある');
  assert.ok(states.includes('<th>元の状態</th>'), '遷移の表がある');
  assert.ok(states.includes('<pre class="mermaid">'), '状態遷移図がある');
  const stray = overview.slice(order[3]);
  const unknown = '<span class="unknown" title="表に無い名前">⚠ 表に無いUC</span>';
  assert.ok(stray.includes(`<li>要求票 docs/requirements/ghost.md: UC『${unknown}』`), stray);
  assert.ok(stray.includes(`<li>例 docs/examples/ghost.feature: 機能名『${unknown}』`), stray);
  // 結び付かない要求票・例が無ければ、その節もヘッダの案内も出ない
  const clean = renderHtml(buildView(passExample), new Date());
  assert.ok(!clean.includes('<section id="stray">'));
  assert.ok(!clean.includes('href="#stray"'));
});

test('外から読む資源は Mermaid だけにする', () => {
  const html = renderHtml(buildView(sample), new Date());
  // 絶対 URL（scheme の大文字小文字と種類を問わない）と、引用符・=・( の直後のプロトコル相対の参照（//…）を集める。
  // https:// の中の // は : の直後なので二重に集めない
  const urls = [
    ...[...html.matchAll(/[a-z][a-z0-9+.-]*:\/\/[^\s"'<>)]+/gi)].map((m) => m[0]),
    ...[...html.matchAll(/["'=(]\s*(\/\/[^\s"'<>)]+)/g)].map((m) => m[1]),
  ];
  assert.ok(urls.length > 0, '外部の参照を集められている');
  for (const url of urls) {
    assert.ok(url.startsWith('https://cdn.jsdelivr.net/npm/mermaid@'), `Mermaid 以外の外部資源: ${url}`);
  }
});

test('埋め込んだスクリプトは構文として読める', () => {
  const html = renderHtml(buildView(sample), new Date());
  const classic = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
  const modules = [...html.matchAll(/<script type="module">([\s\S]*?)<\/script>/g)].map((m) => m[1]);
  assert.ok(classic.length > 0, '通常のスクリプトがある');
  assert.ok(modules.length > 0, 'モジュールのスクリプトがある');
  // 通常のスクリプトはブラウザと同じくトップレベルで読む（.cjs の --check は関数で包むため return 等を通してしまう）
  for (const code of classic) assert.doesNotThrow(() => new Script(code), code);
  const dir = mkdtempSync(join(tmpdir(), 'living-spec-script-'));
  try {
    modules.forEach((code, i) => {
      const file = join(dir, `m${i}.mjs`);
      writeFileSync(file, code);
      // --check は構文だけを見るため、https:// からの import は解決しない
      const result = spawnSync(process.execPath, ['--check', file], { encoding: 'utf8' });
      assert.equal(result.status, 0, `${result.stderr}\n${code}`);
    });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
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

test('CLI: 今いる場所から上へ辿って目印が無ければ終了コード 2 で止まり、何も書かない', () => {
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

// ---- 描き分けの材料（diffview.ts の buildDiffView）。見本の2版は test/render/diff-base.txtar と diff-head.txtar ----
// 材料の区分だけを見る（HTML と図の文字列は見ない）。区分の無い要素は diff・changed を自分の欄として持たない。

function diffSample(name: string): Sources {
  const files: Record<string, string> = {};
  for (const { path, data } of parseTxtar(readFileSync(join(here, 'render', name), 'utf8'))) files[path] = data;
  return sourcesFromFiles(files);
}

const diffBase = diffSample('diff-base.txtar');
const diffHead = diffSample('diff-head.txtar');
const BASE_COMMIT = '0123456789abcdef0123456789abcdef01234567';

function diffView(): View {
  return buildDiffView('/unused', { ref: 'main', commit: BASE_COMMIT, sources: diffBase }, diffHead);
}

// 区分を文字列にする。区分の無い要素は ''。変わった要素は欄名を添える
function tag(x: Marked): string {
  if (!Object.hasOwn(x, 'diff') && !Object.hasOwn(x, 'changed')) return '';
  return x.changed === undefined ? String(x.diff) : `${x.diff} ${JSON.stringify(x.changed)}`;
}

function marks(xs: (Marked & { name: string })[]): [string, string][] {
  return xs.map((x) => [x.name, tag(x)]);
}

function lineOf(uc: UseCaseView, text: string): UseCaseView['requirements'][number]['lines'][number] {
  const found = uc.requirements.flatMap((r) => r.lines).filter((l) => l.text === text);
  assert.equal(found.length, 1, `UC『${uc.name}』に行『${text}』が1つある`);
  return found[0];
}

function conditionOf(uc: UseCaseView, name: string): UseCaseView['conditions'][number] {
  const c = uc.conditions.find((x) => x.name === name);
  assert.ok(c, `UC『${uc.name}』に条件『${name}』がある`);
  return c;
}

const D_SUBMIT = '申請を提出する';
const D_S1 = '提出できる条件を満たさないならば、システムは申請の提出を受け付けない';
const D_S2 = '従業員が申請を提出するとき、システムは申請を提出済みにする';
const D_S3 = '従業員が申請を提出するとき、システムは申請を提出済みにして上長へ知らせる';
const D_AUDIT_LINE = '監査役が申請を監査するとき、システムは申請を監査済みにする';
const D_RETURN_LINE = '上長が申請を差し戻すとき、システムは申請を差し戻しにして旧台帳へ控える';

test('描き分けの材料: 状態と遷移は、作業ツリーの並びに区分を付け、外された状態・遷移を後ろに足す', () => {
  const m = model(diffView());
  assert.deepEqual(m.states, ['作成中', '提出済み', '承認済み', '監査済み', '差し戻し']);
  assert.deepEqual(m.stateDiff, { 監査済み: 'added', 差し戻し: 'removed' });
  assert.deepEqual(
    m.transitions.map((t) => [t.from, t.to, t.uc, tag(t)]),
    [
      [null, '作成中', '申請を作成する', ''],
      ['作成中', '提出済み', '申請を提出する', 'changed ["状態モデル・状態の説明"]'],
      ['提出済み', '承認済み', '申請を承認する', ''],
      ['承認済み', '監査済み', '申請を監査する', 'added'],
      ['監査済み', null, null, 'added'],
      ['提出済み', '差し戻し', '申請を差し戻す', 'removed'],
      ['差し戻し', null, null, 'removed'],
      ['承認済み', null, null, 'removed'],
    ],
  );
});

test('描き分けの材料: 外された UC は作業ツリーの UC の後ろに続き番号のアンカーで並び、遷移 UC の状態モデルを重ね合わせた後の遷移から持つ', () => {
  const view = diffView();
  const headCount = buildView('/unused', diffHead).useCases.length;
  assert.equal(headCount, 4);
  assert.deepEqual(marks(view.useCases), [
    ['申請を作成する', ''],
    [D_SUBMIT, 'changed ["アクター","説明"]'],
    ['申請を承認する', 'changed ["外部システム","情報","条件"]'],
    ['申請を監査する', 'added'],
    ['申請を差し戻す', 'removed'],
  ]);
  const removed = view.useCases[view.useCases.length - 1];
  assert.equal(removed.anchor, `uc-${headCount + 1}`);
  assert.deepEqual(removed.stateModels, ['申請の状態']);
});

test('描き分けの材料: 見本の足された・外された要素が、UC の中の該当の位置で区分を持つ', () => {
  const view = diffView();
  const approve = useCase(view, '申請を承認する');
  assert.deepEqual(marks(approve.externalSystems), [
    ['会計システム', 'changed ["役割"]'],
    ['電子署名サービス', 'added'],
    ['通知サービス', 'removed'],
  ]);
  assert.deepEqual(marks(approve.information), [
    ['申請', 'changed ["属性"]'],
    ['承認の記録', 'added'],
    ['承認記録', 'removed'],
  ]);
  assert.deepEqual(marks(approve.conditions), [['期限の条件', 'removed']]);
  assert.deepEqual(marks(conditionOf(approve, '期限の条件').variations), [['旧区分', 'removed']]);

  const audit = useCase(view, '申請を監査する');
  assert.deepEqual(marks(audit.actors), [['監査役', 'added']]);
  assert.deepEqual(marks(audit.information), [
    ['申請', 'changed ["属性"]'],
    ['監査記録', 'added'],
  ]);
  assert.deepEqual(marks(audit.conditions), [['監査できる条件', 'added']]);
  assert.deepEqual(marks(conditionOf(audit, '監査できる条件').variations), [['監査の区分', 'added']]);
  assert.deepEqual(
    audit.requirements.map((r) => [r.file, tag(r)]),
    [['docs/requirements/監査.md', 'added']],
  );
  const auditLine = lineOf(audit, D_AUDIT_LINE);
  assert.equal(tag(auditLine), 'added');
  assert.deepEqual(marks(auditLine.scenarios), [['承認済みの申請を監査する', 'added']]);
  // 行の参照の中身（条件・バリエーション・情報）は参照先の要素の区分を持つ。RDRA 欄の他の種類には付けない
  assert.deepEqual(
    auditLine.references.map((r) => [r.raw, tag(r)]),
    [
      ['アクター「監査役」', ''],
      ['情報「監査記録」', 'added'],
      ['条件「監査できる条件」', 'added'],
      ['バリエーション「監査の区分」', 'added'],
      ['状態「申請の状態/監査済み」', ''],
    ],
  );
  const auditCondition = auditLine.references.find((r) => r.name === '監査できる条件');
  assert.ok(auditCondition?.definition);
  assert.deepEqual(marks(auditCondition.definition.variations), [['監査の区分', 'added']]);

  const submit = useCase(view, D_SUBMIT);
  assert.deepEqual(
    submit.requirements.map((r) => [r.file, tag(r)]),
    [['docs/requirements/submit.md', 'changed ["要求文"]']],
  );
  // 外された行は同じ UC の最初の票の後ろに足す
  assert.deepEqual(
    submit.requirements[0].lines.map((l) => [l.text, tag(l)]),
    [
      [D_S1, 'changed ["理由"]'],
      [D_S3, 'added'],
      [D_S2, 'removed'],
    ],
  );
  assert.deepEqual(marks(lineOf(submit, D_S1).scenarios), [
    ['種類の無い申請は出せない', 'changed ["手順"]'],
    ['金額の無い申請は出せない', 'added'],
    ['期限切れの申請は出せない', 'removed'],
  ]);
  // 同じシナリオ名でも、ルール（要求文）が違えば別の例として区分を持つ
  assert.deepEqual(marks(lineOf(submit, D_S3).scenarios), [['提出すると提出済みになる', 'added']]);
  assert.deepEqual(marks(lineOf(submit, D_S2).scenarios), [['提出すると提出済みになる', 'removed']]);

  // 外された UC の中は、子自身の区分を持つ
  const returned = useCase(view, '申請を差し戻す');
  assert.deepEqual(marks(returned.actors), [
    ['上長', ''],
    ['経理', 'removed'],
  ]);
  assert.deepEqual(marks(returned.information), [
    ['申請', 'changed ["属性"]'],
    ['旧台帳', 'removed'],
  ]);
  assert.deepEqual(
    returned.requirements.map((r) => [r.file, tag(r)]),
    [['docs/requirements/差し戻し.md', 'removed']],
  );
  const returnLine = lineOf(returned, D_RETURN_LINE);
  assert.equal(tag(returnLine), 'removed');
  assert.deepEqual(marks(returnLine.scenarios), [['差し戻すと差し戻しになる', 'removed']]);
  assert.deepEqual(
    returnLine.references.map((r) => [r.raw, tag(r)]),
    [
      ['アクター「上長」', ''],
      ['情報「申請」', 'changed ["属性"]'],
      ['情報「旧台帳」', 'removed'],
      ['状態「申請の状態/差し戻し」', ''],
    ],
  );
});

test('描き分けの材料: 変わった要素は区分 changed と変わった欄の名前を持つ', () => {
  const submit = useCase(diffView(), D_SUBMIT);
  assert.deepEqual(marks(submit.actors), [['従業員', 'changed ["役割"]']]);
  assert.deepEqual(submit.actors[0].changed, ['役割']);
  assert.deepEqual(marks(submit.conditions), [['提出できる条件', 'changed ["条件の説明"]']]);
  assert.deepEqual(marks(conditionOf(submit, '提出できる条件').variations), [['申請の種類', 'changed ["値"]']]);
  assert.deepEqual(
    lineOf(submit, D_S1).references.map((r) => [r.raw, tag(r)]),
    [
      ['条件「提出できる条件」', 'changed ["条件の説明"]'],
      ['バリエーション「申請の種類」', 'changed ["値"]'],
    ],
  );
});

test('描き分けの材料: 容れ物（UC）から外れただけで表に残る要素は、その容れ物に載せない', () => {
  const submit = useCase(diffView(), D_SUBMIT);
  assert.ok(!submit.actors.some((a) => a.name === '上長'), '申請を提出する のアクターに 上長 が無い');
});

test('描き分けの材料: 外された容れ物の中の変わっていない要素と、変わっていない要素は区分を持たない', () => {
  const view = diffView();
  const boss = useCase(view, '申請を差し戻す').actors.find((a) => a.name === '上長');
  assert.ok(boss, '外された UC 申請を差し戻す に 上長 がある');
  assert.ok(!Object.hasOwn(boss, 'diff') && !Object.hasOwn(boss, 'changed'), '上長 は区分を持たない');

  const create = useCase(view, '申請を作成する');
  const unmarked = [
    create,
    ...create.requirements,
    ...create.requirements.flatMap((r) => r.lines),
    ...create.requirements.flatMap((r) => r.lines.flatMap((l) => l.scenarios)),
    ...create.unlinkedRules.flatMap((r) => r.scenarios),
    ...create.looseScenarios,
  ];
  assert.equal(unmarked.length, 1 + 1 + 2 + 2);
  for (const x of unmarked) assert.ok(!Object.hasOwn(x, 'diff') && !Object.hasOwn(x, 'changed'), JSON.stringify(x));

  // 金額の区分は値の順を入れ替えただけなので、参照の中身に区分を持たない
  const amount = create.requirements
    .flatMap((r) => r.lines.flatMap((l) => l.references))
    .find((r) => r.name === '金額の区分');
  assert.ok(amount, '申請を作成する の行が 金額の区分 を参照する');
  assert.ok(!Object.hasOwn(amount, 'diff') && !Object.hasOwn(amount, 'changed'));
});

test('描き分けの材料: 基準の版の版とコミットを持つ', () => {
  assert.deepEqual(diffView().base, { ref: 'main', commit: BASE_COMMIT });
});

test('区分の無い材料（buildView）は、描き分けの欄を自分の欄として持たない（値が undefined の欄も持たない）', () => {
  const found: string[] = [];
  const walk = (value: unknown, path: string): void => {
    if (Array.isArray(value)) {
      value.forEach((v, i) => walk(v, `${path}[${i}]`));
    } else if (value !== null && typeof value === 'object') {
      for (const key of ['diff', 'changed', 'stateDiff', 'base']) if (Object.hasOwn(value, key)) found.push(`${path}.${key}`);
      for (const [key, v] of Object.entries(value)) walk(v, `${path}.${key}`);
    }
  };
  walk(buildView(sample), 'view');
  assert.deepEqual(found, []);
});

// ---- 描き分けの材料の、見本で通らない枝。件ごとに要るファイルだけを書いた小さな入力で見る ----

function diffViewOf(before: Sources, after: Sources): View {
  return buildDiffView('/unused', { ref: 'main', commit: BASE_COMMIT, sources: before }, after);
}

const SMALL_CREATE_UC = '- UC: 申請を作成する\n  説明: 空の申請を作る\n';

// 条件 金額の条件 を行の RDRA 欄から指す一式。listInUc なら UC の表もその条件を挙げる。
// 基準の版では条件が 金額の区分・旧区分 を持ち、作業ツリーでは 旧区分 をバリエーションの表ごと外す
function conditionInputs(listInUc: boolean): [Sources, Sources] {
  const ucs = listInUc ? `${SMALL_CREATE_UC}  条件: [金額の条件]\n` : SMALL_CREATE_UC;
  const requirement = [
    '# 要求票: 申請を作成する',
    '',
    '## 理由',
    '',
    '申請を先に作るため',
    '',
    '## 仕様',
    '',
    '1. 金額の条件を満たすとき、システムは申請を作る',
    '   - RDRA: 条件「金額の条件」',
    '   - 理由: なし',
    '',
  ].join('\n');
  const version = (variations: string[]) =>
    sourcesFromFiles({
      'docs/rdra/use-case.yaml': ucs,
      'docs/rdra/condition.yaml': `- 条件: 金額の条件\n  条件の説明: 金額で分ける\n  バリエーション: ${variations.join('、')}\n`,
      'docs/rdra/variation.yaml': variations.map((v) => `- バリエーション: ${v}\n  値: 甲、乙\n`).join(''),
      'docs/requirements/create.md': requirement,
    });
  return [version(['金額の区分', '旧区分']), version(['金額の区分'])];
}

function amountReference(uc: UseCaseView): ReferenceView {
  const ref = uc.requirements.flatMap((r) => r.lines.flatMap((l) => l.references)).find((r) => r.name === '金額の条件');
  assert.ok(ref?.definition, '行が 金額の条件 を指し、中身を持つ');
  return ref;
}

test('描き分けの材料: 行の RDRA 欄からだけ指す条件の中身に、表ごと外したバリエーションを区分 removed で後ろに足す', () => {
  const uc = useCase(diffViewOf(...conditionInputs(false)), '申請を作成する');
  assert.deepEqual(uc.conditions, [], 'UC の表は条件を挙げない');
  const ref = amountReference(uc);
  assert.equal(tag(ref), 'changed ["バリエーション"]');
  assert.deepEqual(marks(ref.definition!.variations), [
    ['金額の区分', ''],
    ['旧区分', 'removed'],
  ]);
});

test('描き分けの材料: UC の表が挙げる条件にも、表ごと外したバリエーションを区分 removed で後ろに足す', () => {
  const uc = useCase(diffViewOf(...conditionInputs(true)), '申請を作成する');
  assert.deepEqual(marks(uc.conditions), [['金額の条件', 'changed ["バリエーション"]']]);
  assert.deepEqual(marks(uc.conditions[0].variations), [
    ['金額の区分', ''],
    ['旧区分', 'removed'],
  ]);
  assert.deepEqual(marks(amountReference(uc).definition!.variations), [
    ['金額の区分', ''],
    ['旧区分', 'removed'],
  ]);
});

test('描き分けの材料: 作業ツリーの UC の遷移を外すと、外された遷移が戻り、その UC は重ね合わせた後の状態モデルを持つ', () => {
  const ucs = `${SMALL_CREATE_UC}- UC: 申請を取り下げる\n  説明: 作成中の申請を取り下げる\n`;
  const created = '- 状態モデル: 申請の状態\n  遷移UC: 申請を作成する\n  遷移先状態: 作成中\n';
  const withdrawn = '- 状態モデル: 申請の状態\n  状態: 作成中\n  遷移UC: 申請を取り下げる\n  遷移先状態: 取り下げ済み\n';
  const before = sourcesFromFiles({ 'docs/rdra/use-case.yaml': ucs, 'docs/rdra/state.yaml': created + withdrawn });
  const after = sourcesFromFiles({ 'docs/rdra/use-case.yaml': ucs, 'docs/rdra/state.yaml': created });
  // 作業ツリーだけで組んだ材料では、取り下げる UC はどの状態モデルとも結び付かない
  assert.deepEqual(useCase(buildView('/unused', after), '申請を取り下げる').stateModels, []);
  const uc = useCase(diffViewOf(before, after), '申請を取り下げる');
  assert.equal(tag(uc), '', 'UC 自身は変わっていない');
  assert.deepEqual(uc.stateModels, ['申請の状態']);
});

test('描き分けの材料: 行に結び付かないルールの外された例はそのルールの枠の後ろに在り、作業ツリーに無いルールは枠ごと加わる', () => {
  const draft = ['  ルール: 下書きを残す', '', '    シナリオ: 下書きが残る', '      もし 従業員Aが申請を作成する', '      ならば 下書きが残る', ''];
  const discard = ['    シナリオ: 下書きを消せる', '      もし 従業員Aが下書きを消す', '      ならば 下書きが無くなる', ''];
  const cleanup = ['  ルール: 古い下書きを片付ける', '', '    シナリオ: 古い下書きが消える', '      もし 30日が過ぎる', '      ならば 古い下書きが消える', ''];
  const feature = (body: string[]) =>
    sourcesFromFiles({
      'docs/rdra/use-case.yaml': SMALL_CREATE_UC,
      'docs/examples/create.feature': ['# language: ja', '機能: 申請を作成する', '', ...body].join('\n'),
    });
  const uc = useCase(diffViewOf(feature([...draft, ...discard, ...cleanup]), feature(draft)), '申請を作成する');
  assert.deepEqual(
    uc.unlinkedRules.map((r) => [r.name, marks(r.scenarios)]),
    [
      [
        '下書きを残す',
        [
          ['下書きが残る', ''],
          ['下書きを消せる', 'removed'],
        ],
      ],
      ['古い下書きを片付ける', [['古い下書きが消える', 'removed']]],
    ],
  );
});

test('描き分けの材料: ルールの外のシナリオは、ルールの外の位置で区分を持ち、外されたシナリオが後ろに在る', () => {
  const scenario = (name: string, steps: string[]) => [`  シナリオ: ${name}`, ...steps.map((s) => `    ${s}`), ''];
  const feature = (body: string[]) =>
    sourcesFromFiles({
      'docs/rdra/use-case.yaml': SMALL_CREATE_UC,
      'docs/examples/create.feature': ['# language: ja', '機能: 申請を作成する', '', ...body].join('\n'),
    });
  const before = feature([
    ...scenario('申請を作る', ['もし 従業員Aが申請を作成する', 'ならば 作成中の申請ができる']),
    ...scenario('申請を複製する', ['もし 従業員Aが申請を複製する', 'ならば 同じ中身の申請ができる']),
  ]);
  const after = feature([
    ...scenario('申請を作る', ['もし 従業員Aが申請を作成する', 'ならば 作成中の申請が1件できる']),
    ...scenario('申請を下書きから作る', ['もし 従業員Aが下書きから申請を作成する', 'ならば 作成中の申請ができる']),
  ]);
  const uc = useCase(diffViewOf(before, after), '申請を作成する');
  assert.deepEqual(uc.unlinkedRules, []);
  assert.deepEqual(marks(uc.looseScenarios), [
    ['申請を作る', 'changed ["手順"]'],
    ['申請を下書きから作る', 'added'],
    ['申請を複製する', 'removed'],
  ]);
});

// ---- 描き分けの HTML と図（html.ts の印、render.ts の書き出し）。材料は上の見本の2版から組む ----
// 印の文字列は仕様が固定する文言である（references/format.md の描き分けの節）。

const ADDED = '<span class="diff" data-diff="added">足された</span>';
const REMOVED = '<span class="diff" data-diff="removed">外された</span>';
const MARK = /<span class="diff" data-diff="([^"]*)">([^<]*)<\/span>/g;
// 縦串の図の強調と薄めの style（html.ts の HIGHLIGHT・DIMMED）と、仮説の辺の破線の指定
const HIGHLIGHT_STYLE = 'stroke:#d9480f,stroke-width:3px,color:#d9480f';
const DIMMED_STYLE = 'stroke:#adb5bd,color:#868e96';
const DASH = ',stroke-dasharray:5 5';

function changedMark(...fields: string[]): string {
  return `<span class="diff" data-diff="changed">変わった（${fields.join('・')}）</span>`;
}

function diffHtml(): string {
  return renderHtml(diffView(), new Date(0));
}

// 出現位置（要素自身の名前を持つセルか項）。入れ子で中に並ぶ子の項は含めず、子自身の出現位置として別に数える
interface Spot {
  at: string;
  html: string;
}

function spots(html: string): Spot[] {
  const out: Spot[] = [];
  const each = (at: string, re: RegExp, s: string) => {
    for (const m of s.matchAll(re)) out.push({ at, html: m[1] });
  };
  // 遷移の表の元の状態の欄・UC の一覧の UC 名の欄・情報と条件の表の名前の欄
  each('表の名前の欄', /<tr><td>(.*?)<\/td>/g, html);
  each('縦串の見出し', /<summary><h2>(.*?)<\/h2><\/summary>/g, html);
  for (const m of html.matchAll(/<h4>(?:アクター|外部システム)<\/h4><ul>(.*?)<\/ul>/g)) {
    each('アクター・外部システムの項', /<li>(.*?)<\/li>/g, m[1]);
  }
  for (const m of html.matchAll(/<th>バリエーション<\/th><\/tr><\/thead><tbody>(.*?)<\/tbody>/g)) {
    for (const row of m[1].matchAll(/<tr><td>.*?<\/td><td>.*?<\/td><td>(.*?)<\/td><\/tr>/g)) {
      each('条件のバリエーションの項', /<div>(.*?)<\/div>/g, row[1]);
    }
  }
  each('ファイル名の行', /<p class="file">(.*?)<\/p>/g, html);
  each('要求文の行', /<p class="sentence">(.*?)<\/p>/g, html);
  for (const m of html.matchAll(/<div class="defs" hidden><ul>(.*?)<\/ul><\/div>/g)) {
    for (const item of m[1].matchAll(/<li>(.*?)<\/li>/g)) {
      out.push({ at: '行の直下の中身の項', html: item[1].split('<div class="sub">')[0] });
      each('行の直下の中身の中の項', /<div class="sub">(.*?)<\/div>/g, item[1]);
    }
  }
  for (const m of html.matchAll(/<ul class="scenarios">(.*?)<\/ul>/g)) each('例の項', /<li>(.*?)<\/li>/g, m[1]);
  return out;
}

// 出現位置の印（無ければ ''）。2つ以上あれば落とす
function markOf(spot: string): string {
  const found = [...spot.matchAll(MARK)];
  assert.ok(found.length <= 1, `出現位置の印は1つまで: ${spot}`);
  return found.length === 0 ? '' : found[0][0];
}

// 出現位置の文字（印・種類の添え字・タグを除く）
function textOf(spot: string): string {
  return spot
    .replace(MARK, '')
    .replace(/<span class="kind">[^<]*<\/span>/g, '')
    .replace(/<[^>]*>/g, '');
}

// html の中の、種類が at で名前が name の出現位置の印。名前の直後は文字の終わりか区切り（空白・：・（）
function markAt(html: string, at: string, name: string): string {
  const all = spots(html).filter((s) => s.at === at);
  const hits = all.filter((s) => {
    const t = textOf(s.html);
    return t.startsWith(name) && (t.length === name.length || ' :（'.includes(t[name.length]));
  });
  assert.equal(hits.length, 1, `${at} に『${name}』が1つある\n${all.map((s) => textOf(s.html)).join('\n')}`);
  return markOf(hits[0].html);
}

// 縦串の中の、文が text の要求文の行（文の段落から次の行の手前まで。行の直下の中身と例を含む）
function lineBlock(slice: string, text: string): string {
  const starts = [...slice.matchAll(/<p class="sentence">(.*?)<\/p>/g)].filter((m) => textOf(m[1]) === text);
  assert.equal(starts.length, 1, `行『${text}』が1つある`);
  const rest = slice.slice(starts[0].index);
  const end = rest.search(/\n<li><p class="sentence">|<\/ol>/);
  return end < 0 ? rest : rest.slice(0, end);
}

// UC の一覧の、UC 名が name の行の欄
function indexRow(html: string, name: string): string[] {
  const rows = html.split('\n').filter((l) => l.includes('<tr><td><a href="#uc-') && l.includes(`">${name}</a>`));
  assert.equal(rows.length, 1, `UC の一覧に『${name}』の行が1つある`);
  return [...rows[0].matchAll(/<td>(.*?)<\/td>/g)].map((m) => m[1]);
}

// UC の材料の要求票の行数と例の件数（UC の一覧の数え方）
function countsOf(uc: UseCaseView): { lines: number; scenarios: number } {
  const lines = uc.requirements.flatMap((r) => r.lines);
  return {
    lines: lines.length,
    scenarios:
      lines.reduce((n, l) => n + l.scenarios.length, 0) +
      uc.unlinkedRules.reduce((n, r) => n + r.scenarios.length, 0) +
      uc.looseScenarios.length,
  };
}

// 出現位置に載る、区分のある材料の数。行の直下の中身は、中身を持つ参照の名前ごとに1つ（html.ts の definedReferences と同じ）
function expectedMarks(view: View): number {
  const n = (xs: Marked[]) => xs.filter((x) => x.diff !== undefined).length;
  let count = 0;
  for (const m of view.stateModels) count += n(m.transitions);
  for (const uc of view.useCases) {
    count += 2 * n([uc]) + n(uc.actors) + n(uc.externalSystems) + n(uc.information) + n(uc.conditions);
    count += n(uc.conditions.flatMap((c) => c.variations));
    for (const r of uc.requirements) {
      count += n([r]) + n(r.lines);
      for (const l of r.lines) {
        const refs = l.references.filter(
          (x, i, xs) =>
            x.definition !== null && x.name !== null && xs.findIndex((y) => y.name === x.name && y.definition !== null) === i,
        );
        count += n(refs) + n(refs.flatMap((x) => x.definition!.variations)) + n(l.scenarios);
      }
    }
    count += n(uc.unlinkedRules.flatMap((r) => r.scenarios)) + n(uc.looseScenarios);
  }
  return count;
}

// Mermaid の文字列の辺（定義の順。番号は linkStyle の辺の番号）
interface Edge {
  index: number;
  from: string;
  to: string;
  arrow: string;
  label: string;
}

function edgesOf(chart: string): Edge[] {
  return chart
    .split('\n')
    .filter((l) => /-\.?->/.test(l))
    .map((l, index) => {
      const m = l.match(/^\s*(\w+) (-\.?->)(?:\|"(.*)"\|)? (\w+)$/);
      assert.ok(m !== null, `辺の行: ${l}`);
      return { index, from: m[1], to: m[4], arrow: m[2], label: m[3] ?? '' };
    });
}

// 状態の節点の行と id。名札は区分の印（［…］ ）の後ろに状態の名前を持つ
function nodeOf(chart: string, state: string): { id: string; line: string } {
  const lines = chart.split('\n').filter((l) => new RegExp(`^\\s*s\\d+\\["(?:［[^］]*］ )?${state}"\\]`).test(l));
  assert.equal(lines.length, 1, `節点『${state}』が1つある\n${chart}`);
  return { id: lines[0].trim().split('[')[0], line: lines[0] };
}

// 遷移元・遷移先の節点の id（開始は start0、終端は end0）と、名札の末尾（遷移 UC）で辺を1本選ぶ
function edgeOf(chart: string, from: string, to: string, uc = ''): Edge {
  const hits = edgesOf(chart).filter((e) => e.from === from && e.to === to && e.label.endsWith(uc));
  assert.equal(hits.length, 1, `辺 ${from} → ${to}（${uc}）が1本ある\n${chart}`);
  return hits[0];
}

// 辺の番号 → その番号の linkStyle の style の並び
function linkStylesOf(chart: string): Map<number, string[]> {
  const out = new Map<number, string[]>();
  for (const l of chart.split('\n')) {
    const m = l.match(/^\s*linkStyle (\d+) (.*)$/);
    if (m === null) continue;
    const i = Number(m[1]);
    out.set(i, [...(out.get(i) ?? []), m[2]]);
  }
  return out;
}

test('描き分けの HTML: 見本の足された・外された要素が、各出現位置に区分の印を持つ', () => {
  const view = diffView();
  const html = renderHtml(view, new Date(0));
  const slice = (name: string) => sliceOf(html, useCase(view, name));
  const audit = slice('申請を監査する');
  const approve = slice('申請を承認する');
  const submit = slice(D_SUBMIT);
  const returned = slice('申請を差し戻す');

  // UC の一覧の UC 名の後ろと、縦串の見出しの UC 名の後ろ
  assert.equal(markAt(html, '表の名前の欄', '申請を監査する'), ADDED);
  assert.equal(markAt(html, '表の名前の欄', '申請を差し戻す'), REMOVED);
  assert.ok(html.includes(`<a href="#uc-4">申請を監査する</a>${ADDED}</td>`));
  assert.ok(audit.includes(`<summary><h2>申請を監査する${ADDED} </h2></summary>`), audit);
  assert.equal(markAt(returned, '縦串の見出し', '申請を差し戻す'), REMOVED);
  // 外された UC は UC の一覧に残り、作業ツリーの UC の後ろの続き番号のアンカーで縦串へ辿れる
  const headCount = buildView('/unused', diffHead).useCases.length;
  assert.equal(headCount, 4);
  assert.ok(indexRow(html, '申請を差し戻す')[0].startsWith(`<a href="#uc-${headCount + 1}">申請を差し戻す</a>`));
  assert.ok(html.includes(`<section class="slice" id="uc-${headCount + 1}">`));

  // 縦串のアクター・外部システムの各項
  assert.equal(markAt(audit, 'アクター・外部システムの項', '監査役'), ADDED);
  assert.equal(markAt(returned, 'アクター・外部システムの項', '経理'), REMOVED);
  assert.equal(markAt(approve, 'アクター・外部システムの項', '電子署名サービス'), ADDED);
  assert.equal(markAt(approve, 'アクター・外部システムの項', '通知サービス'), REMOVED);
  // 情報・条件の表の名前の欄と、条件のバリエーションの各項
  assert.equal(markAt(approve, '表の名前の欄', '承認の記録'), ADDED);
  assert.equal(markAt(approve, '表の名前の欄', '承認記録'), REMOVED);
  assert.equal(markAt(audit, '表の名前の欄', '監査記録'), ADDED);
  assert.equal(markAt(returned, '表の名前の欄', '旧台帳'), REMOVED);
  assert.equal(markAt(audit, '表の名前の欄', '監査できる条件'), ADDED);
  assert.equal(markAt(approve, '表の名前の欄', '期限の条件'), REMOVED);
  assert.equal(markAt(audit, '条件のバリエーションの項', '監査の区分'), ADDED);
  assert.equal(markAt(approve, '条件のバリエーションの項', '旧区分'), REMOVED);
  // 要求票のファイル名の行
  assert.equal(markAt(audit, 'ファイル名の行', 'docs/requirements/監査.md'), ADDED);
  assert.equal(markAt(returned, 'ファイル名の行', 'docs/requirements/差し戻し.md'), REMOVED);
  // 要求文の各行の先頭
  assert.equal(markAt(submit, '要求文の行', D_S3), ADDED);
  assert.equal(markAt(submit, '要求文の行', D_S2), REMOVED);
  assert.equal(markAt(audit, '要求文の行', D_AUDIT_LINE), ADDED);
  assert.equal(markAt(returned, '要求文の行', D_RETURN_LINE), REMOVED);
  assert.ok(audit.includes(`<p class="sentence">${ADDED}`), '印は行の先頭');
  // 行の直下に畳む中身の各項（条件・バリエーション・情報とその中のバリエーション）
  const auditLine = lineBlock(audit, D_AUDIT_LINE);
  assert.equal(markAt(auditLine, '行の直下の中身の項', '監査記録'), ADDED);
  assert.equal(markAt(auditLine, '行の直下の中身の項', '監査できる条件'), ADDED);
  assert.equal(markAt(auditLine, '行の直下の中身の項', '監査の区分'), ADDED);
  assert.equal(markAt(auditLine, '行の直下の中身の中の項', '監査の区分'), ADDED);
  assert.equal(markAt(lineBlock(returned, D_RETURN_LINE), '行の直下の中身の項', '旧台帳'), REMOVED);
  // 例の各項。同じシナリオ名でも、ルール（要求文）が違えば各々の区分を持つ
  const s1 = lineBlock(submit, D_S1);
  assert.equal(markAt(s1, '例の項', '金額の無い申請は出せない'), ADDED);
  assert.equal(markAt(s1, '例の項', '期限切れの申請は出せない'), REMOVED);
  assert.equal(markAt(lineBlock(submit, D_S3), '例の項', '提出すると提出済みになる'), ADDED);
  assert.equal(markAt(lineBlock(submit, D_S2), '例の項', '提出すると提出済みになる'), REMOVED);
  assert.equal(markAt(audit, '例の項', '承認済みの申請を監査する'), ADDED);
  assert.equal(markAt(returned, '例の項', '差し戻すと差し戻しになる'), REMOVED);
});

test('描き分けの HTML: 遷移の表の行は、元の状態の欄の先頭に区分の印を持つ', () => {
  const html = diffHtml();
  const states = html.slice(html.indexOf('<section id="states">'), html.indexOf('<section id="use-cases">'));
  const rows = [...states.matchAll(/<tr><td>(.*?)<\/td><td>(.*?)<\/td><td>(.*?)<\/td>/g)].map((m) => [
    textOf(m[1]),
    textOf(m[2]),
    textOf(m[3]),
    markOf(m[1]),
  ]);
  assert.deepEqual(rows, [
    ['（開始）', '作成中', '申請を作成する', ''],
    ['作成中', '提出済み', '申請を提出する', changedMark('状態モデル・状態の説明')],
    ['提出済み', '承認済み', '申請を承認する', ''],
    ['承認済み', '監査済み', '申請を監査する', ADDED],
    ['監査済み', '（終端）', '', ADDED],
    ['提出済み', '差し戻し', '申請を差し戻す', REMOVED],
    ['差し戻し', '（終端）', '', REMOVED],
    ['承認済み', '（終端）', '', REMOVED],
  ]);
  assert.ok(states.includes(`<tr><td>${REMOVED}差し戻し</td>`), '印は元の状態の欄の先頭');
});

test('描き分けの HTML: 変わった要素は、印の文言に変わった欄の名前を添える', () => {
  const view = diffView();
  const html = renderHtml(view, new Date(0));
  const submit = sliceOf(html, useCase(view, D_SUBMIT));
  const approve = sliceOf(html, useCase(view, '申請を承認する'));
  assert.equal(markAt(html, '表の名前の欄', D_SUBMIT), changedMark('アクター', '説明'));
  assert.equal(markAt(submit, '縦串の見出し', D_SUBMIT), changedMark('アクター', '説明'));
  assert.equal(markAt(html, '表の名前の欄', '申請を承認する'), changedMark('外部システム', '情報', '条件'));
  assert.equal(markAt(submit, 'アクター・外部システムの項', '従業員'), changedMark('役割'));
  assert.ok(submit.includes(`<li>従業員${changedMark('役割')}（申請を作り、種類と金額を入れて出す）</li>`), '印は名前の後ろ');
  assert.equal(markAt(approve, 'アクター・外部システムの項', '会計システム'), changedMark('役割'));
  assert.equal(markAt(submit, '表の名前の欄', '申請'), changedMark('属性'));
  assert.equal(markAt(submit, '表の名前の欄', '提出できる条件'), changedMark('条件の説明'));
  assert.equal(markAt(submit, '条件のバリエーションの項', '申請の種類'), changedMark('値'));
  assert.equal(markAt(submit, 'ファイル名の行', 'docs/requirements/submit.md'), changedMark('要求文'));
  assert.equal(markAt(submit, '要求文の行', D_S1), changedMark('理由'));
  const s1 = lineBlock(submit, D_S1);
  assert.equal(markAt(s1, '行の直下の中身の項', '提出できる条件'), changedMark('条件の説明'));
  assert.equal(markAt(s1, '行の直下の中身の中の項', '申請の種類'), changedMark('値'));
  assert.equal(markAt(s1, '行の直下の中身の項', '申請の種類'), changedMark('値'));
  assert.equal(markAt(s1, '例の項', '種類の無い申請は出せない'), changedMark('手順'));
});

test('描き分けの HTML: 変わった欄の名前（表の定義に無いキーを含む）と版の文字列を逃がす', () => {
  const ucs = '- UC: 申請を作成する\n  アクター: [従業員]\n  説明: 空の申請を作る\n';
  const actor = (note: string) => `- アクター: 従業員\n  役割: 申請を作る\n  社内外: 社内\n  備考<b>&: ${note}\n`;
  const version = (note: string) => sourcesFromFiles({ 'docs/rdra/use-case.yaml': ucs, 'docs/rdra/actor.yaml': actor(note) });
  const view = buildDiffView('/unused', { ref: 'a<b>&"', commit: BASE_COMMIT, sources: version('甲') }, version('乙'));
  const html = renderHtml(view, new Date(0));
  assert.equal(
    markAt(sliceOf(html, useCase(view, '申請を作成する')), 'アクター・外部システムの項', '従業員'),
    '<span class="diff" data-diff="changed">変わった（備考&lt;b&gt;&amp;）</span>',
  );
  assert.ok(html.includes('<p>基準の版: a&lt;b&gt;&amp;&quot;（0123456789ab）</p>'));
  assert.ok(!html.includes('備考<b>'));
});

test('描き分けの HTML: 容れ物から外れただけで表に残る要素と、変わっていない要素は印を持たない', () => {
  const view = diffView();
  const html = renderHtml(view, new Date(0));
  const submit = sliceOf(html, useCase(view, D_SUBMIT));
  const isBoss = (s: Spot) => s.at === 'アクター・外部システムの項' && textOf(s.html).startsWith('上長（');
  // 上長 は 申請を提出する の縦串に載らない
  assert.ok(!spots(submit).some(isBoss), '申請を提出する の縦串に 上長 の項が無い');
  // 上長 の項は、外された UC 申請を差し戻す の縦串を含め、どこにも印を持たない
  const boss = spots(html).filter(isBoss);
  assert.equal(boss.length, 2, '申請を承認する と 申請を差し戻す の縦串に 上長 の項がある');
  for (const s of boss) assert.equal(markOf(s.html), '', s.html);
  assert.equal(markAt(sliceOf(html, useCase(view, '申請を差し戻す')), 'アクター・外部システムの項', '上長'), '');
  // 金額の区分（値の順の入れ替えだけ）
  const amount = spots(html).filter((s) => textOf(s.html).startsWith('金額の区分'));
  assert.ok(amount.length > 0, '金額の区分 の出現位置がある');
  for (const s of amount) assert.equal(markOf(s.html), '', s.html);
  // 申請を作成する（行の順と例の順の入れ替えだけ）とその行・例
  const create = sliceOf(html, useCase(view, '申請を作成する'));
  assert.equal(markAt(html, '表の名前の欄', '申請を作成する'), '');
  assert.equal(markAt(create, '縦串の見出し', '申請を作成する'), '');
  assert.equal(markAt(create, 'ファイル名の行', 'docs/requirements/create.md'), '');
  const lines = useCase(view, '申請を作成する').requirements.flatMap((r) => r.lines.map((l) => l.text));
  assert.equal(lines.length, 2);
  for (const text of lines) assert.equal(markAt(create, '要求文の行', text), '');
  for (const name of ['空の申請を作る', '2件目の申請を作る']) assert.equal(markAt(create, '例の項', name), '');
});

test('描き分けの HTML: UC の一覧は、外された UC の行に基準の版での行数・件数を出し、残る UC の行は外された行・例を数えない', () => {
  const html = diffHtml();
  const returned = indexRow(html, '申請を差し戻す');
  const was = countsOf(useCase(buildView('/unused', diffBase), '申請を差し戻す'));
  assert.deepEqual(was, { lines: 1, scenarios: 1 });
  assert.ok(!returned.join('').includes('class="missing"'), returned.join(''));
  assert.equal(returned[3], `あり（${was.lines} 行）`);
  assert.equal(returned[4], `あり（${was.scenarios} シナリオ）`);
  const submit = indexRow(html, D_SUBMIT);
  const now = countsOf(useCase(buildView('/unused', diffHead), D_SUBMIT));
  // 描き分けの材料には外された行（S2）と例（期限切れ・S2 の例）も載るが、数えない
  assert.deepEqual(now, { lines: 2, scenarios: 3 });
  assert.deepEqual(countsOf(useCase(diffView(), D_SUBMIT)), { lines: 3, scenarios: 5 });
  assert.equal(submit[3], `あり（${now.lines} 行）`);
  assert.equal(submit[4], `あり（${now.scenarios} シナリオ）`);
});

test('描き分けの HTML: 区分ごとに印の文言と data-diff の値が違い、出現位置ごとに印は1つで、出現位置の外に印が無い', () => {
  const view = diffView();
  const html = renderHtml(view, new Date(0));
  const found = [...html.matchAll(MARK)];
  assert.deepEqual([...new Set(found.map((m) => m[1]))].sort(), ['added', 'changed', 'removed']);
  for (const [whole, status, text] of found) {
    if (status === 'added') assert.equal(text, '足された', whole);
    else if (status === 'removed') assert.equal(text, '外された', whole);
    else assert.match(text, /^変わった（[^（）]+）$/, whole);
  }
  // 各出現位置の印は1つまで（markOf が確かめる）。全ての印が出現位置の中にある
  // （UC の一覧のアクター名・RDRA 欄の文字列・ツールチップ・結び付かない枠には無い）
  const inSpots = spots(html).filter((s) => markOf(s.html) !== '').length;
  assert.equal(inSpots, found.length);
  // 印の数は、出現位置に載る区分のある材料の数と同じ
  assert.equal(found.length, expectedMarks(view));
});

test('基準の版なしの HTML と図には、描き分けの印・凡例・基準の版の行・描き分けの CSS・class が無い', () => {
  const view = buildView(sample);
  const html = renderHtml(view, new Date(0));
  const diff = diffHtml();
  // 描き分けの HTML には在る（否定が書式の食い違いで素通りしないよう、在る側も確かめる）
  for (const part of ['class="diff"', 'data-diff', '<p>基準の版: ', '<p class="note">基準の版との違い', 'span.diff']) {
    assert.ok(diff.includes(part), `描き分けの HTML に ${part} がある`);
    assert.ok(!html.includes(part), `基準の版なしの HTML に ${part} が無い`);
  }
  assert.ok(!html.includes('基準の版'));
  const charts = view.stateModels.flatMap((m) => [null, ...view.useCases.map((u) => u.name)].map((uc) => stateChart(m, uc)));
  const diffChart = stateChart(model(diffView()), null);
  for (const part of ['［足された］', '［外された］', '［変わった］', ':::added', ':::removed', 'classDef added', 'classDef removed']) {
    assert.ok(diffChart.includes(part), `描き分けの図に ${part} がある`);
    for (const chart of charts) assert.ok(!chart.includes(part), `基準の版なしの図に ${part} が無い\n${chart}`);
  }
  for (const chart of charts) assert.ok(!/:::changed|classDef changed/.test(chart), chart);
});

test('描き分けの HTML: ヘッダに基準の版とコミットの先頭12字の行を持ち、状態遷移図の凡例の後ろに区分の説明を足す', () => {
  const html = diffHtml();
  const header = html.slice(html.indexOf('<header>'), html.indexOf('</header>'));
  assert.ok(header.includes('<p>基準の版: main（0123456789ab）</p>'), header);
  const states = html.slice(html.indexOf('<section id="states">'), html.indexOf('<section id="use-cases">'));
  const legend = states.indexOf('実線は事実、破線は仮説の遷移');
  assert.ok(legend >= 0);
  assert.ok(states.indexOf('<p class="note">基準の版との違い') > legend, states);
});

test('描き分けの図: 全体図は、区分のある状態の節点に名札の印と class を、区分のある遷移の辺に名札の印と区分の linkStyle を付ける', () => {
  const chart = stateChart(model(diffView()), null);
  const audited = nodeOf(chart, '監査済み');
  assert.ok(audited.line.includes('["［足された］ 監査済み"]') && audited.line.endsWith(':::added'), audited.line);
  const gone = nodeOf(chart, '差し戻し');
  assert.ok(gone.line.includes('["［外された］ 差し戻し"]') && gone.line.endsWith(':::removed'), gone.line);
  const draft = nodeOf(chart, '作成中');
  assert.ok(!draft.line.includes('［') && !draft.line.includes(':::'), draft.line);

  const id = (s: string) => nodeOf(chart, s).id;
  const added = edgeOf(chart, id('承認済み'), id('監査済み'));
  const changed = edgeOf(chart, id('作成中'), id('提出済み'));
  const removed = edgeOf(chart, id('提出済み'), id('差し戻し'));
  assert.equal(added.label, '［足された］申請を監査する');
  assert.equal(changed.label, '［変わった］申請を提出する');
  assert.equal(removed.label, '［外された］申請を差し戻す');
  // 遷移 UC の無い辺も、印だけの名札を持つ
  assert.equal(edgeOf(chart, id('監査済み'), 'end0').label, '［足された］');
  assert.equal(edgeOf(chart, id('差し戻し'), 'end0').label, '［外された］');

  const styles = linkStylesOf(chart);
  for (const [i, ss] of styles) assert.equal(ss.length, 1, `辺 ${i} の linkStyle は1本`);
  const styleOf = (e: Edge) => styles.get(e.index)?.[0];
  const distinct = new Set([styleOf(added), styleOf(changed), styleOf(removed)]);
  assert.ok(!distinct.has(undefined), '区分のある辺は linkStyle を持つ');
  assert.equal(distinct.size, 3, `区分ごとに linkStyle が違う: ${[...distinct].join(' / ')}`);
  for (const s of distinct) assert.ok(!s!.includes('stroke-dasharray'), `仮説でない辺の区分の linkStyle は破線を持たない: ${s}`);
  // 区分の無い辺（（開始）→作成中、仮説の 提出済み→承認済み）は名札の印も linkStyle も持たない
  const start = edgeOf(chart, 'start0', id('作成中'));
  assert.equal(start.label, '申請を作成する');
  assert.ok(!styles.has(start.index));
  const approve = edgeOf(chart, id('提出済み'), id('承認済み'));
  assert.equal(approve.label, '申請を承認する');
  assert.equal(approve.arrow, '-.->');
  assert.ok(!styles.has(approve.index));
  assert.equal(styles.size, 6, '区分のある辺の数だけ');
  // 使った区分の classDef（状態の区分は足された・外されただけ）。色と太さで示し、破線を使わない
  const classDefs = chart.split('\n').filter((l) => /^\s*classDef (added|changed|removed) /.test(l));
  assert.deepEqual(
    classDefs.map((l) => l.trim().split(' ')[1]),
    ['added', 'removed'],
  );
  for (const l of classDefs) assert.ok(!l.includes('stroke-dasharray'), l);
});

test('描き分けの図: 同じ遷移元・遷移先に別の遷移 UC の仮説の記録を足すと、全体図では足した記録の辺だけが印と、破線を保つ区分の linkStyle を持つ', () => {
  const ucs = '- UC: 申請を提出する\n  説明: 作成中の申請を出す\n- UC: 申請を出し直す\n  説明: 作成中の申請をもう一度出す\n';
  const x = '- 状態モデル: 申請の状態\n  状態: 作成中\n  遷移UC: 申請を提出する\n  遷移先状態: 提出済み\n';
  const y = '- 状態モデル: 申請の状態\n  状態: 作成中\n  遷移UC: 申請を出し直す\n  遷移先状態: 提出済み\n  仮説: [P01-1]\n';
  const done = '- 状態モデル: 申請の状態\n  状態: 提出済み\n';
  const before = sourcesFromFiles({ 'docs/rdra/use-case.yaml': ucs, 'docs/rdra/state.yaml': x + done });
  const after = sourcesFromFiles({ 'docs/rdra/use-case.yaml': ucs, 'docs/rdra/state.yaml': x + y + done });
  const chart = stateChart(model(diffViewOf(before, after)), null);
  const from = nodeOf(chart, '作成中').id;
  const to = nodeOf(chart, '提出済み').id;
  const styles = linkStylesOf(chart);

  const added = edgeOf(chart, from, to, '申請を出し直す');
  assert.equal(added.label, '［足された］申請を出し直す');
  assert.equal(added.arrow, '-.->');
  // 区分の style（見本の足された辺と同じ）の後ろに、仮説の破線の指定が続く
  const sample = stateChart(model(diffView()), null);
  const sampleAdded = edgeOf(sample, nodeOf(sample, '承認済み').id, nodeOf(sample, '監査済み').id);
  const addedStyle = linkStylesOf(sample).get(sampleAdded.index)?.[0];
  assert.ok(addedStyle !== undefined);
  assert.deepEqual(styles.get(added.index), [`${addedStyle}${DASH}`]);
  // 元からある記録（遷移 UC は 申請を提出する）の辺は、名札の印も linkStyle も持たない
  const kept = edgeOf(chart, from, to, '申請を提出する');
  assert.equal(kept.label, '申請を提出する');
  assert.ok(!styles.has(kept.index));
});

test('描き分けの図: 縦串の図は強調・薄めの linkStyle だけを辺ごとに1本出し、区分は名札の印で示す', () => {
  const chart = stateChart(model(diffView()), D_SUBMIT);
  const edges = edgesOf(chart);
  const lines = chart
    .split('\n')
    .filter((l) => /^\s*linkStyle\s/.test(l))
    .map((l) => l.trim());
  const indices = lines.map((l) => Number(l.split(' ')[1]));
  assert.equal(new Set(indices).size, indices.length, `辺の番号が重複しない\n${chart}`);
  assert.deepEqual(
    [...indices].sort((a, b) => a - b),
    edges.map((e) => e.index),
    '辺ごとに1本',
  );
  for (const l of lines) {
    const m = l.match(/^linkStyle (\d+) (.*)$/);
    assert.ok(m !== null, l);
    const dash = edges[Number(m[1])].arrow === '-.->' ? DASH : '';
    assert.ok(m[2] === `${HIGHLIGHT_STYLE}${dash}` || m[2] === `${DIMMED_STYLE}${dash}`, `強調か薄めの style だけを持つ: ${l}`);
  }
  assert.equal(lines.filter((l) => l.includes('stroke-width:3px')).length, 1);
  const id = (s: string) => nodeOf(chart, s).id;
  const submit = edgeOf(chart, id('作成中'), id('提出済み'));
  assert.equal(submit.label, '［変わった］申請を提出する');
  assert.ok(lines.includes(`linkStyle ${submit.index} ${HIGHLIGHT_STYLE}`));
  // 状態の区分は縦串の図でも名札の印と class で示す
  assert.ok(nodeOf(chart, '監査済み').line.endsWith(':::added'));
  assert.match(chart, /^\s*classDef added /m);
});

test('描き分けの書き出し先: output の語幹に -diff を付け、拡張子を保つ', () => {
  assert.equal(diffOutputPath('.cache/living-spec/index.html'), '.cache/living-spec/index-diff.html');
  assert.equal(diffOutputPath('out/view'), 'out/view-diff');
});

test('描き分けの書き出し: 作業ツリーを読んで描き分けを別のファイルへ書き、output（index.html）には触れない', () => {
  const root = materialize(join(here, 'render', 'diff-head.txtar'));
  const out = writeDiffView(root, { ref: 'main', commit: BASE_COMMIT, sources: diffBase }, new Date(0));
  assert.equal(out, join(root, '.cache', 'living-spec', 'index-diff.html'));
  const html = readFileSync(out, 'utf8');
  assert.ok(html.includes('<p>基準の版: main（0123456789ab）</p>'));
  assert.ok(html.includes(`<a href="#uc-5">申請を差し戻す</a>${REMOVED}</td>`));
  assert.ok(!existsSync(join(root, '.cache', 'living-spec', 'index.html')));
});

// ---- 残る容れ物の件数・欠けの注記・警告の枠は外されていない子で、外された容れ物は全ての子で決める ----
// 件ごとに要るファイルだけを書いた小さな入力で見る。UC は SMALL_CREATE_UC の 申請を作成する

const CREATE_LINE = '従業員が申請を作成するとき、システムは作成中の申請を作る';
const CREATE_REQUIREMENT = [
  '# 要求票: 申請を作成する',
  '',
  '## 理由',
  '',
  '申請を先に作るため',
  '',
  '## 仕様',
  '',
  `1. ${CREATE_LINE}`,
  '   - RDRA: なし',
  '   - 理由: なし',
  '',
].join('\n');

// シナリオ1件の Gherkin の行。indent はシナリオの行の字下げ
function scenarioLines(name: string, indent: string): string[] {
  return [`${indent}シナリオ: ${name}`, `${indent}  もし 従業員Aが${name}`, `${indent}  ならば ${name}が済む`, ''];
}

function ruleLines(name: string, scenarios: string[]): string[] {
  return [`  ルール: ${name}`, '', ...scenarios.flatMap((s) => scenarioLines(s, '    '))];
}

// 申請を作成する の一式。body が null なら例のファイルを置かない
function createInputs(body: string[] | null, files: Record<string, string> = {}): Sources {
  return sourcesFromFiles({
    'docs/rdra/use-case.yaml': SMALL_CREATE_UC,
    ...(body === null ? {} : { 'docs/examples/create.feature': ['# language: ja', '機能: 申請を作成する', '', ...body].join('\n') }),
    ...files,
  });
}

test('描き分けの HTML: UC の一覧は、残る UC の結び付かないルールの外された例とルールの外の外された例を数えない', () => {
  const unlinked = diffViewOf(
    createInputs(ruleLines('下書きを残す', ['下書きが残る', '下書きを消せる'])),
    createInputs(ruleLines('下書きを残す', ['下書きが残る'])),
  );
  assert.equal(countsOf(useCase(unlinked, '申請を作成する')).scenarios, 2, '材料には外された例も載る');
  assert.equal(indexRow(renderHtml(unlinked, new Date(0)), '申請を作成する')[4], 'あり（1 シナリオ）');

  const loose = diffViewOf(
    createInputs([...scenarioLines('申請を作る', '  '), ...scenarioLines('申請を複製する', '  ')]),
    createInputs(scenarioLines('申請を作る', '  ')),
  );
  assert.equal(countsOf(useCase(loose, '申請を作成する')).scenarios, 2, '材料には外された例も載る');
  assert.equal(indexRow(renderHtml(loose, new Date(0)), '申請を作成する')[4], 'あり（1 シナリオ）');
});

test('描き分けの HTML: 票を全て外した残る UC の縦串は「要求票が無い」を出し、外された票を後ろに印付きで並べる。外された UC には出さない', () => {
  const view = diffViewOf(createInputs(null, { 'docs/requirements/create.md': CREATE_REQUIREMENT }), createInputs(null));
  const uc = useCase(view, '申請を作成する');
  assert.equal(tag(uc), '', 'UC は残る');
  const html = renderHtml(view, new Date(0));
  const slice = sliceOf(html, uc);
  const note = slice.indexOf('<p class="missing">要求票が無い</p>');
  const file = slice.indexOf(`<p class="file">docs/requirements/create.md${REMOVED}</p>`);
  assert.ok(note >= 0, slice);
  assert.ok(file > note, '外された票は注記の後ろに印付きで並ぶ');
  assert.equal(markAt(slice, '要求文の行', CREATE_LINE), REMOVED);
  assert.equal(indexRow(html, '申請を作成する')[3], '<span class="missing">無い</span>');

  // 外された容れ物（見本の 申請を差し戻す。票も外れている）は全ての子で決めるので、注記を出さない
  const sample = diffView();
  assert.ok(!sliceOf(renderHtml(sample, new Date(0)), useCase(sample, '申請を差し戻す')).includes('要求票が無い'));
});

test('描き分けの HTML: 例を全て外した残る行は「この行に結び付く例が無い」を出し、外された例を後ろに印付きで並べる。外された行には出さない', () => {
  const files = { 'docs/requirements/create.md': CREATE_REQUIREMENT };
  const view = diffViewOf(
    createInputs(ruleLines(CREATE_LINE, ['空の申請を作る']), files),
    createInputs(ruleLines(CREATE_LINE, []), files),
  );
  const uc = useCase(view, '申請を作成する');
  assert.equal(tag(lineOf(uc, CREATE_LINE)), '', '行は残る');
  const block = lineBlock(sliceOf(renderHtml(view, new Date(0)), uc), CREATE_LINE);
  const note = block.indexOf('<p class="missing">この行に結び付く例が無い</p>');
  assert.ok(note >= 0, block);
  assert.ok(block.indexOf('<ul class="scenarios">') > note, '外された例は注記の後ろに並ぶ');
  assert.equal(markAt(block, '例の項', '空の申請を作る'), REMOVED);

  // 外された行（見本の S2。例も外れている）は全ての子で決めるので、注記を出さない
  const sample = diffView();
  const submit = sliceOf(renderHtml(sample, new Date(0)), useCase(sample, D_SUBMIT));
  const gone = lineBlock(submit, D_S2);
  assert.ok(!gone.includes('この行に結び付く例が無い'), gone);
  assert.equal(markAt(gone, '例の項', '提出すると提出済みになる'), REMOVED);
});

test('描き分けの HTML: 外された例だけが残る結び付かない例の枠は警告の様式を付けずに出し、外されていない子がある枠と外された UC の枠は警告の様式を保つ', () => {
  const frame = (html: string) => html.match(/<div class="(unlinked[^"]*)"><h4>要求票の行に結び付かない例<\/h4>/)?.[1];

  // 残る UC で、結び付かないルールの例を全て外した（例のファイルは残る）
  const ruleGone = diffViewOf(createInputs(ruleLines('下書きを残す', ['下書きが残る'])), createInputs([]));
  const ruleSlice = sliceOf(renderHtml(ruleGone, new Date(0)), useCase(ruleGone, '申請を作成する'));
  assert.equal(frame(ruleSlice), 'unlinked-gone', ruleSlice);
  assert.equal(markAt(ruleSlice, '例の項', '下書きが残る'), REMOVED);
  assert.ok(ruleSlice.includes('<p class="file">docs/examples/create.feature</p>'));

  // 残る UC で、ルールの外の例を例のファイルごと外した。「例が無い」は作業ツリーの例のファイルで決まる
  const looseGone = diffViewOf(createInputs(scenarioLines('申請を作る', '  ')), createInputs(null));
  const looseHtml = renderHtml(looseGone, new Date(0));
  const looseSlice = sliceOf(looseHtml, useCase(looseGone, '申請を作成する'));
  assert.equal(frame(looseSlice), 'unlinked-gone', looseSlice);
  assert.equal(markAt(looseSlice, '例の項', '申請を作る'), REMOVED);
  assert.ok(looseSlice.includes('<p class="missing">例が無い</p>'));
  assert.equal(indexRow(looseHtml, '申請を作成する')[4], '<span class="missing">無い</span>');

  // 外されていない例が残る枠は警告の様式を保つ
  const partly = diffViewOf(
    createInputs(ruleLines('下書きを残す', ['下書きが残る', '下書きを消せる'])),
    createInputs(ruleLines('下書きを残す', ['下書きが残る'])),
  );
  assert.equal(frame(sliceOf(renderHtml(partly, new Date(0)), useCase(partly, '申請を作成する'))), 'unlinked');

  // 外された UC の枠は全ての子で決めるので、警告の様式を保つ
  const withdrawUc = '- UC: 申請を取り下げる\n  説明: 作成中の申請を取り下げる\n';
  const withdrawFeature = ['# language: ja', '機能: 申請を取り下げる', '', ...ruleLines('取り下げを残す', ['取り下げが残る'])].join('\n');
  const removedUc = diffViewOf(
    sourcesFromFiles({
      'docs/rdra/use-case.yaml': SMALL_CREATE_UC + withdrawUc,
      'docs/examples/withdraw.feature': withdrawFeature,
    }),
    sourcesFromFiles({ 'docs/rdra/use-case.yaml': SMALL_CREATE_UC }),
  );
  const withdraw = useCase(removedUc, '申請を取り下げる');
  assert.equal(tag(withdraw), 'removed');
  assert.equal(frame(sliceOf(renderHtml(removedUc, new Date(0)), withdraw)), 'unlinked');

  // 区分の無い材料で、例の無い結び付かないルールだけを持つ枠は今どおり警告の様式を持つ
  const empty = buildView('/unused', createInputs(ruleLines('下書きを残す', [])));
  assert.equal(frame(sliceOf(renderHtml(empty, new Date(0)), useCase(empty, '申請を作成する'))), 'unlinked');
});

test('描き分けの材料と図: __proto__ という名前の状態も、自分の欄として区分を持つ', () => {
  const ucs = `${SMALL_CREATE_UC}- UC: 申請を消す\n  説明: 作成中の申請を消す\n`;
  const created = '- 状態モデル: 申請の状態\n  遷移UC: 申請を作成する\n  遷移先状態: 作成中\n';
  const erased =
    '- 状態モデル: 申請の状態\n  状態: 作成中\n  遷移UC: 申請を消す\n  遷移先状態: __proto__\n- 状態モデル: 申請の状態\n  状態: __proto__\n';
  const m = model(
    diffViewOf(
      sourcesFromFiles({ 'docs/rdra/use-case.yaml': ucs, 'docs/rdra/state.yaml': created }),
      sourcesFromFiles({ 'docs/rdra/use-case.yaml': ucs, 'docs/rdra/state.yaml': created + erased }),
    ),
  );
  assert.ok(m.stateDiff !== undefined && Object.hasOwn(m.stateDiff, '__proto__'), '区分が自分の欄にある');
  assert.deepEqual(Object.entries(m.stateDiff), [['__proto__', 'added']]);
  const node = nodeOf(stateChart(m, null), '__proto__');
  assert.ok(node.line.includes('["［足された］ __proto__"]') && node.line.endsWith(':::added'), node.line);
});
