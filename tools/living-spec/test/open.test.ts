// 未決の印（表の『未決』キー）の読み取り・一覧・描画を確かめる。
// 見本は examples/invalid-shape の pass-open-marked（印あり）・pass-open-unmarked（印なし）・fail-open-malformed（印の書式誤り）。
// 3つの見本の検査の結果そのものは examples.test.ts が見る。ここでは、印の有無で他の規則の判定が変わらないこと、
// 一覧の中身と所在、印を外すと一覧が空になること、書式誤りの文面、描画の印を見る。入口（check --open）は cli.test.ts が見る。
import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { isMap, isSeq, parseDocument } from 'yaml';
import { checkDocMissingSources, checkSources, collectOpenSources, formatOpen, formatViolation } from '../src/check.ts';
import { diffSources } from '../src/diff.ts';
import { renderHtml } from '../src/html.ts';
import { OPEN, TABLES } from '../src/schema.ts';
import { sourcesFromFiles } from '../src/sources.ts';
import { buildView } from '../src/view.ts';
import { parseTxtar } from './fixture.ts';

const examplesDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'examples');

function filesOf(path: string): Record<string, string> {
  const files: Record<string, string> = {};
  for (const { path: p, data } of parseTxtar(readFileSync(path, 'utf8'))) if (p !== 'expected.yaml') files[p] = data;
  return files;
}

const marked = filesOf(join(examplesDir, 'invalid-shape', 'pass-open-marked.txtar'));
const unmarked = filesOf(join(examplesDir, 'invalid-shape', 'pass-open-unmarked.txtar'));
const malformed = filesOf(join(examplesDir, 'invalid-shape', 'fail-open-malformed.txtar'));

function allViolations(files: Record<string, string>): string[] {
  const sources = sourcesFromFiles(files);
  return [...checkSources(sources), ...checkDocMissingSources(sources)].map(formatViolation).sort();
}

// 表のレコードから『未決』キーを外す（YAML として読み直して書く。読めない表と並びでない表はそのまま）
function strip(files: Record<string, string>): Record<string, string> {
  return Object.fromEntries(
    Object.entries(files).map(([path, text]) => {
      if (!path.endsWith('.yaml')) return [path, text];
      const doc = parseDocument(text);
      if (doc.errors.length > 0 || !isSeq(doc.contents)) return [path, text];
      for (const item of doc.contents.items) if (isMap(item)) item.delete(OPEN);
      return [path, String(doc)];
    }),
  );
}

// 表の各レコードへ、表の文で書く欄の1つに書式どおりの未決の項目を足す。already の要素は足さない
function inject(files: Record<string, string>): Record<string, string> {
  return Object.fromEntries(
    Object.entries(files).map(([path, text]) => {
      const def = TABLES.find((d) => path === d.file);
      const doc = parseDocument(text);
      if (def === undefined || doc.errors.length > 0 || !isSeq(doc.contents)) return [path, text];
      for (const item of doc.contents.items) {
        if (isMap(item) && !item.has(OPEN)) item.set(OPEN, [{ [def.textKeys[0]]: '試験で足した未決' }]);
      }
      return [path, String(doc)];
    }),
  );
}

// 同じ表を YAML として読み直して書いたもの（inject と書式の揺れを揃えて比べるため）
function reformat(files: Record<string, string>): Record<string, string> {
  return Object.fromEntries(
    Object.entries(files).map(([path, text]) => {
      const doc = parseDocument(text);
      if (!TABLES.some((d) => path === d.file) || doc.errors.length > 0 || !isSeq(doc.contents)) return [path, text];
      return [path, String(doc)];
    }),
  );
}

test('印ありの見本から『未決』キーを外すと、印なしの見本と同じ表になる（印を除いた以外は同じ入力）', () => {
  assert.deepEqual(strip(marked), strip(unmarked));
  assert.notDeepEqual(strip(marked), marked, '外す前と同じなら印が無い');
});

test('印ありの見本と印なしの見本は、どの規則でも同じ判定になる（どちらも違反0）', () => {
  assert.deepEqual(allViolations(marked), []);
  assert.deepEqual(allViolations(marked), allViolations(unmarked));
});

test('規則ごとの全ての見本で、各レコードへ書式どおりの未決の印を足しても、検査の結果は変わらない', () => {
  let touched = 0;
  for (const rule of readdirSync(examplesDir).filter((n) => statSync(join(examplesDir, n)).isDirectory())) {
    for (const name of readdirSync(join(examplesDir, rule)).filter((n) => n.endsWith('.txtar'))) {
      const files = filesOf(join(examplesDir, rule, name));
      const before = reformat(files);
      const after = inject(files);
      if (JSON.stringify(before) !== JSON.stringify(after)) touched++;
      assert.deepEqual(allViolations(after), allViolations(before), `${rule}/${name}`);
    }
  }
  assert.ok(touched > 20, `印を足せた見本が少ない（${touched} 件）`);
});

test('未決の一覧は、要素の名前・欄・未決の内容・所在（ファイル:行）を、表の順・レコードの順・項目の順に持つ', () => {
  const { entries, blocking } = collectOpenSources(sourcesFromFiles(marked));
  assert.deepEqual(blocking, []);
  assert.deepEqual(entries.map(formatOpen), [
    '[未決] docs/rdra/actor.yaml:8 アクター:上司 役割: 代理の承認者を 含むかが決まっていない',
    '[未決] docs/rdra/state.yaml:10 状態:経費申請の状態／作成中 状態モデル・状態の説明: 提出の後に取り下げられるかが決まっていない',
    '[未決] docs/rdra/condition.yaml:6 条件:提出可能 条件の説明: 上限の境目（上限ちょうどを含むか）が出典で揃っていない',
    '[未決] docs/rdra/condition.yaml:7 条件:提出可能 条件の説明: 上限の額が決まっていない',
    '[未決] docs/rdra/variation.yaml:5 バリエーション:費目 説明: 交通費と宿泊費のほかの費目を含めるかが決まっていない',
    '[未決] docs/rdra/architecture-characteristic.yaml:7 アーキテクチャ特性:監査可能性 説明: 操作の記録を残す期間が決まっていない',
  ]);
  // 所在の行は、表のファイルでその項目が書かれた行である
  for (const e of entries) {
    const line = marked[e.file].split('\n')[e.line - 1];
    assert.match(line, new RegExp(`^\\s*- ${e.key}: `), `${e.file}:${e.line}`);
  }
});

test('印を外すと、未決の一覧は空になる', () => {
  assert.deepEqual(collectOpenSources(sourcesFromFiles(unmarked)), { entries: [], blocking: [] });
  assert.deepEqual(collectOpenSources(sourcesFromFiles(strip(marked))), { entries: [], blocking: [] });
});

test('印の書式誤りは invalid-shape で落ち、誤りの種類ごとの文面を持ち、一覧を出させない', () => {
  const sources = sourcesFromFiles(malformed);
  const details = checkSources(sources)
    .filter((v) => v.rule === 'invalid-shape')
    .map((v) => `${v.target} ${v.detail}`)
    .sort();
  assert.deepEqual(details, [
    'アクター:上司 キー『未決』の1番目の項目の未決の内容が空、または文字列でない',
    'アーキテクチャ特性:監査可能性 キー『未決』の値が項目の並びになっていない（各項目は「<欄>: <未決の内容>」の1組。欄は 『説明』）',
    'バリエーション:費目 キー『未決』に項目が無い（決まったらキーごと外す）',
    '条件:提出可能 キー『未決』の1番目の項目の欄『条件』は未決の印を付けられる欄でない（付けられる欄は 『条件の説明』）',
    '状態:経費申請の状態／作成中 キー『未決』の1番目の項目が「<欄>: <未決の内容>」の1組になっていない（欄は 『状態モデル・状態の説明』）',
  ]);
  const { entries, blocking } = collectOpenSources(sources);
  assert.equal(entries.length, 0);
  assert.equal(blocking.length, 5);
});

test('書式誤りの残りの形: 2組の項目・null・文字列でない内容・検証方法への印', () => {
  const ac = 'docs/rdra/architecture-characteristic.yaml';
  const shapes = [
    '  未決:\n    - 説明: 一つ目\n      検証方法: 二つ目\n',
    '  未決:\n',
    '  未決:\n    - 説明: 3\n',
    '  未決:\n    - 説明:\n        - 並び\n',
    '  未決:\n    - 検証方法: 閾値が決まっていない\n',
  ];
  for (const shape of shapes) {
    const files = { [ac]: `- アーキテクチャ特性: 監査可能性\n  説明: 操作を追跡できる\n${shape}` };
    const found = checkSources(sourcesFromFiles(files)).filter((v) => v.rule === 'invalid-shape');
    // 3 は YAML では数として読まれるので、文字列でない内容として落ちる
    assert.equal(found.length, 1, shape);
  }
});

test('render: 未決の印を持つ箇所に、仮説の印と別の「未決」の印を付け、未決の内容を出す。縦串に現れない要素の未決は未決の一覧の節に出る', () => {
  const html = renderHtml(buildView('/unused', sourcesFromFiles(marked)), new Date());
  // 条件の表の説明の欄（縦串）
  assert.match(
    html,
    /経費が1件以上あり、合計額が上限以下である<span class="open">未決（条件の説明）: 上限の境目（上限ちょうどを含むか）が出典で揃っていない<\/span><span class="open">未決（条件の説明）: 上限の額が決まっていない<\/span>/,
  );
  // 遷移の表の説明の欄・アクターの役割
  assert.match(html, /作成中の申請を提出すると提出済になる<span class="open">未決（状態モデル・状態の説明）: 提出の後に取り下げられるかが決まっていない<\/span>/);
  assert.match(html, /（申請を受け取る）<span class="open">未決（役割）: 代理の承認者を 含むかが決まっていない<\/span>/);
  // 仮説の印（黄色のバッジ）とは別の class で、実線の枠で描く
  assert.doesNotMatch(html, /class="badge"[^>]*>未決/);
  assert.match(html, /\.open \{[^}]*border:1px solid/);
  // 縦串に現れないアーキテクチャ特性の未決は、未決の一覧の節に所在とともに出る
  const section = html.slice(html.indexOf('<section id="open">'), html.indexOf('</section>', html.indexOf('<section id="open">')));
  assert.ok(section.startsWith('<section id="open"><h2>未決の一覧</h2>'), '未決の一覧の節が無い');
  assert.match(section, /アーキテクチャ特性:監査可能性<\/td><td>説明<\/td><td><span class="open">未決: 操作の記録を残す期間が決まっていない<\/span><\/td><td class="file">docs\/rdra\/architecture-characteristic.yaml:7<\/td>/);
  assert.equal(section.match(/<tr><td>/g)?.length, 6);
  assert.match(html, /<a href="#open">未決の一覧<\/a>/);
});

test('render: 印の無い入力には未決の印も未決の一覧の節も出さない', () => {
  const html = renderHtml(buildView('/unused', sourcesFromFiles(unmarked)), new Date());
  assert.doesNotMatch(html, /<span class="open">/);
  assert.doesNotMatch(html, /id="open"|href="#open"/);
});

test('diff: 未決の項目を外すと、その要素は「変わった（未決）」になる', () => {
  const d = diffSources(sourcesFromFiles(marked), sourcesFromFiles(unmarked));
  const changed = d.elements.map((e) => `${e.kind} ${e.name} ${e.status} ${e.changed.join('・')}`).sort();
  assert.deepEqual(changed, [
    'アクター 上司 changed 未決',
    'バリエーション 費目 changed 未決',
    '条件 提出可能 changed 未決',
    '遷移 経費申請の状態/作成中→提出済（経費申請を提出する） changed 未決',
  ]);
});

// 表の未決の節（render）。表の形の違反があれば、印が0件でも節を残し、欠けうることを示す
function openSection(files: Record<string, string>): string {
  const html = renderHtml(buildView('/unused', sourcesFromFiles(files)), new Date());
  const start = html.indexOf('<section id="open">');
  return start < 0 ? '' : html.slice(start, html.indexOf('</section>', start));
}

test('render: 表の形の違反があり印が0件でも、未決の一覧の節を残し、欠けうることを示す', () => {
  // 印は名前の無いレコードにだけあり、一覧には入らない
  const files = {
    ...unmarked,
    'docs/rdra/variation.yaml': '- 値: 交通費、宿泊費\n  未決:\n    - 説明: 費目の分け方が決まっていない\n',
  };
  const section = openSection(files);
  assert.ok(section !== '', '違反があるのに節が消えた');
  assert.match(section, /表の形の違反 1 件のため、この一覧は欠けうる/);
  assert.doesNotMatch(section, /<span class="open">/);
});

test('render: 表の形の違反があり印もあるとき、読めた印を並べ、欠けうることを示す', () => {
  const files = { ...marked, 'docs/rdra/external-system.yaml': '- 外部システム: [壊れた\n' };
  const section = openSection(files);
  assert.match(section, /表の形の違反 1 件のため、この一覧は欠けうる/);
  assert.equal(section.match(/<tr><td>/g)?.length, 6);
  // 違反の無い入力には注記を出さない
  assert.doesNotMatch(openSection(marked), /欠けうる/);
});

test('未決の値が別名（*a）でも、所在は項目の行を指す', () => {
  const files = {
    'docs/rdra/condition.yaml':
      '- 条件: 提出可能\n  条件の説明: 経費が1件以上ある\n  未決: &shared\n    - 条件の説明: 金額が0円の経費を数えるかが決まっていない\n' +
      '- 条件: 承認可能\n  条件の説明: 提出済である\n  未決: *shared\n',
  };
  const { entries, blocking } = collectOpenSources(sourcesFromFiles(files));
  assert.deepEqual(blocking, []);
  assert.deepEqual(
    entries.map((e) => `${e.target} ${e.line}`),
    ['条件:提出可能 4', '条件:承認可能 4'],
  );
});
