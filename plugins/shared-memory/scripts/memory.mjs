// 共有の記憶（Shared Memory）の検査器。記録と採用の台帳の形式を検査し、索引を生成する。
// 記録の版を返し、採用した記録の変化を報告する。Task Memory の残留を検出する。
// 形式の正本は references/format.md であり、ここはその規則に従う実装である。
// 規則を変えるときは、format.md を先に改める。
//
// 使い方は USAGE を見る。違反は「パス:規則: 説明」の形で標準出力へ出す。
import { spawnSync } from 'node:child_process';
import { existsSync, lstatSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const USAGE = `usage: memory.mjs check ROOT [--no-task-memory]
       memory.mjs index ROOT [--write]
       memory.mjs version ROOT ID [--ref REF]
       memory.mjs adopted ROOT GLOBAL_ROOT [--ref REF]
  ROOT: 記憶の根。records/ を直下に持つディレクトリ。index.md と adopted/（採用の台帳）も直下に置く。
  check: 記録と採用の台帳の形式と、index.md が記録と一致することを検査する。
  --no-task-memory: ROOT/tasks/ の直下に何か在れば違反にする。既定のブランチへ入るツリーに使う。
  index: 索引を標準出力へ出す。--write を付けると ROOT/index.md へ書く。
  version: 記録 ID の版を「ID@コミットの省略形」で標準出力へ出す。版は、REF でその記録を最後に変えたコミット。
  adopted: ROOT の台帳の1件ごとに、GLOBAL_ROOT の REF と比べた結果を「パス:結果: 説明」で標準出力へ出す。
           結果は unchanged / changed / superseded / moved / missing。
  --ref REF: 版を数える起点。省くと refs/remotes/origin/HEAD。作業中の HEAD は使わない。
           remote 追跡の ref（省いたときの既定を含む）と FETCH_HEAD は、最後に取り直した結果（FETCH_HEAD）と照合する。
  version と adopted は git を要する。fetch のようにネットワークへ出る git のコマンドは呼ばない。
  履歴の浅い checkout と、起点が最後に取り直した結果と食い違う checkout では、exit 2 で止まる。
  終了コード:
    check / index: 0 違反なし、1 違反あり、2 引数の誤りか検査できない入力。
    version: 0 版を返した、1 REF にその記録が1件に決まらない、2 引数の誤りか版を決められない状態。
    adopted: 0 missing も台帳の違反も無い、1 missing か台帳の違反が在る、2 引数の誤りか検査できない状態。`;

const ID = /^MEM-[0-9]{12}-[0-9]{2}$/;
const FILE_NAME = /^(MEM-[0-9]{12}-[0-9]{2})-[a-z0-9]+(?:-[a-z0-9]+)*\.md$/;
const DATE = /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/;
const COMMIT = /^[0-9a-f]{7,64}$/;
const ADOPTED_DIR = 'adopted';
const ADOPTED_FILE = /^(MEM-[0-9]{12}-[0-9]{2})\.md$/;
const DEFAULT_REF = 'refs/remotes/origin/HEAD';
const FETCH_HEAD = 'FETCH_HEAD';
const TRACKING = 'refs/remotes/';
// FETCH_HEAD の、枝を取り直した行。2列目は、空か not-for-merge である。3列目の URL は照合に使わない。
const FETCHED_BRANCH = /^([0-9a-f]{40,64})\t(?:not-for-merge)?\tbranch '(.*)' of /;
// git へ渡さない環境変数。継承すると -C より優先され、根とは別のリポジトリを読む。git のフックの中では、これらが立っている。
const INHERITED_GIT = ['GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE'];
const GIT_ENV = Object.fromEntries(Object.entries(process.env).filter(([name]) => !INHERITED_GIT.includes(name)));
// キーは、コロンを含まず、空白・#・- で始まらない文字の並び。日本語や空白を含むキーも読み飛ばせるようにする。
const KEY_LINE = /^([^\s#:-][^:]*):(?:[ \t]+(.*))?$/;
const ITEM_LINE = /^[ \t]*-[ \t]+(.*)$/;
const ENUMS = {
  type: ['knowledge', 'experience', 'belief', 'decision', 'evolution'],
  author: ['human', 'ai', 'joint'],
  verification: ['verified', 'unverified'],
  confidence: ['high', 'medium', 'low'],
};
const SCALARS = ['id', 'type', 'title', 'author', 'verification', 'confidence', 'applies-when', 'created', 'updated'];
const OPTIONAL_SCALARS = ['superseded-by', 'moved-to'];
const LISTS = ['sources', 'from', 'to'];
const RECORD_KEYS = { scalars: [...SCALARS, ...OPTIONAL_SCALARS], lists: LISTS };
const ADOPTED_SCALARS = ['record', 'version', 'adopted'];
const ADOPTED_KEYS = { scalars: ADOPTED_SCALARS, lists: ['decisions'] };
const INDEX_HEADER = [
  '# 索引',
  '',
  '<!-- 検査器が生成する。手で編集しない。作り直すには index --write を使う。 -->',
  '',
  '| 識別子 | 種類 | 主張 | 当てはまる条件 | 検証 |',
  '|---|---|---|---|---|',
];

class Unreadable extends Error {}
// 検査できない状態。main の外で受け、説明を標準エラーへ出して exit 2 にする。
class Unusable extends Error {}

/**
 * 値を1つ読む。引用符で囲んだ値は中身を返す。囲まない値は、YAML として別の意味になる形を拒む。
 * @param {string} raw
 * @returns {string}
 */
function scalar(raw) {
  const text = raw.trim();
  const quoted = text.match(/^"(.*)"$/) ?? text.match(/^'(.*)'$/);
  if (quoted) return quoted[1];
  // YAML が値の先頭で別の意味に読む記号。- ? : は、後ろが空白か行末のときだけ別の意味になる。
  const indicator = /^[\[\]{},#&*!|>'"%@`]/.test(text) || /^[-?:]([ \t]|$)/.test(text);
  if (indicator || text.includes(': ') || text.includes(' #') || text.endsWith(':')) {
    throw new Unreadable(`値を引用符で囲む: ${text}`);
  }
  return text;
}

/**
 * front-matter を読む。知っているキーだけを厳密に読み、知らないキーは値ごと読み飛ばす。
 * @param {string} source
 * @param {{ scalars: string[], lists: string[] }} keys 知っているキー
 * @returns {{ fields: Map<string, string | string[]>, body: string }}
 */
function frontMatter(source, keys) {
  const lines = source.split('\n').map((line) => line.replace(/\r$/, ''));
  if (lines[0] !== '---') throw new Unreadable('1行目が --- でない');
  const end = lines.indexOf('---', 1);
  if (end === -1) throw new Unreadable('front-matter を閉じる --- が無い');
  const fields = new Map();
  let index = 1;
  while (index < end) {
    const line = lines[index];
    index += 1;
    if (line.trim() === '' || line.startsWith('#')) continue;
    const matched = line.match(KEY_LINE);
    if (!matched) throw new Unreadable(`読めない行: ${line}`);
    const [, key, rest] = matched;
    const nested = [];
    while (index < end && (/^([ \t]|-[ \t])/.test(lines[index]) || lines[index].trim() === '')) {
      if (lines[index].trim() !== '') nested.push(lines[index]);
      index += 1;
    }
    const isList = keys.lists.includes(key);
    if (!isList && !keys.scalars.includes(key)) continue;
    if (fields.has(key)) throw new Unreadable(`キーが重複している: ${key}`);
    if (isList) {
      if (rest !== undefined && rest.trim() !== '') throw new Unreadable(`${key} は「- 値」の行で書く`);
      fields.set(key, nested.map((item) => {
        const itemMatched = item.match(ITEM_LINE);
        if (!itemMatched) throw new Unreadable(`${key} の読めない行: ${item.trim()}`);
        return scalar(itemMatched[1]);
      }));
    } else {
      if (nested.length > 0 || rest === undefined) throw new Unreadable(`${key} は1行の値で書く`);
      fields.set(key, scalar(rest));
    }
  }
  return { fields, body: lines.slice(end + 1).join('\n') };
}

/**
 * 記録を1件ずつ読み、1件の中で決まる違反を集める。
 * @param {string} root
 * @returns {{ records: { path: string, file: string, fields: Map<string, string | string[]> }[], violations: string[] }}
 */
function load(root) {
  const dir = join(root, 'records');
  const violations = [];
  const records = [];
  for (const file of readdirSync(dir).filter((name) => name.endsWith('.md')).sort()) {
    const path = `records/${file}`;
    const report = (rule, message) => violations.push(`${path}:${rule}: ${message}`);
    let fields;
    try {
      ({ fields } = frontMatter(readFileSync(join(dir, file), 'utf8'), RECORD_KEYS));
    } catch (error) {
      if (!(error instanceof Unreadable)) throw error;
      report('front-matter', error.message);
      continue;
    }
    for (const key of [...SCALARS, 'sources']) {
      const value = fields.get(key);
      if (value === undefined || value.length === 0) report('required', `${key} が無い`);
    }
    for (const [key, allowed] of Object.entries(ENUMS)) {
      const value = fields.get(key);
      if (value !== undefined && !allowed.includes(value)) report('value', `${key} は ${allowed.join(' / ')} のいずれか: ${value}`);
    }
    for (const key of ['created', 'updated']) {
      const value = fields.get(key);
      if (value !== undefined && !DATE.test(value)) report('value', `${key} は YYYY-MM-DD の形で書く: ${value}`);
    }
    const id = fields.get('id');
    if (id !== undefined && !ID.test(id)) report('value', `id は MEM-<12桁>-<2桁> の形で書く: ${id}`);
    const named = file.match(FILE_NAME);
    if (!named) report('filename', 'ファイル名は <id>-<英小文字と数字をハイフンでつないだ名前>.md の形にする');
    else if (id !== undefined && named[1] !== id) report('filename', `ファイル名の識別子が id と一致しない: ${id}`);
    if (fields.has('superseded-by') && fields.has('moved-to')) report('value', 'superseded-by と moved-to は同時に書かない');
    if (fields.get('type') === 'belief' && fields.get('author') === 'joint') {
      report('value', 'belief の author は human か ai のどちらかにする');
    }
    const isEvolution = fields.get('type') === 'evolution';
    for (const key of ['from', 'to']) {
      const listed = fields.get(key) ?? [];
      if (isEvolution && listed.length === 0) report('evolution', `evolution は ${key} に記録を1件以上書く`);
      if (!isEvolution && fields.has(key)) report('evolution', `${key} は evolution だけが持つ`);
    }
    records.push({ path, file, fields });
  }
  return { records, violations };
}

/**
 * 採用の台帳を1件ずつ読み、1件の中で決まる違反を集める。adopted/ が無ければ0件である。
 * @param {string} root
 * @returns {{ path: string, fields: Map<string, string | string[]>, violations: string[] }[]}
 */
function loadAdopted(root) {
  const dir = join(root, ADOPTED_DIR);
  if (!existsSync(dir)) return [];
  if (!statSync(dir).isDirectory()) throw new Unusable(`${ADOPTED_DIR} がディレクトリでない: ${dir}`);
  return readdirSync(dir).filter((name) => name.endsWith('.md')).sort().map((file) => {
    const path = `${ADOPTED_DIR}/${file}`;
    const violations = [];
    const report = (rule, message) => violations.push(`${path}:${rule}: ${message}`);
    let fields = new Map();
    let body = '';
    try {
      ({ fields, body } = frontMatter(readFileSync(join(dir, file), 'utf8'), ADOPTED_KEYS));
    } catch (error) {
      if (!(error instanceof Unreadable)) throw error;
      report('front-matter', error.message);
      return { path, fields, violations };
    }
    for (const key of [...ADOPTED_SCALARS, 'decisions']) {
      const value = fields.get(key);
      if (value === undefined || value.length === 0) report('required', `${key} が無い`);
    }
    if (body.trim() === '') report('required', '本文が無い。採用の理由を書く');
    const record = fields.get('record');
    if (record !== undefined && !ID.test(record)) report('value', `record は MEM-<12桁>-<2桁> の形で書く: ${record}`);
    const version = fields.get('version');
    if (version !== undefined && !COMMIT.test(version)) report('value', `version は 7〜64桁の16進の小文字で書く: ${version}`);
    const adopted = fields.get('adopted');
    if (adopted !== undefined && !DATE.test(adopted)) report('value', `adopted は YYYY-MM-DD の形で書く: ${adopted}`);
    const named = file.match(ADOPTED_FILE);
    if (!named) report('filename', 'ファイル名は <record>.md の形にする');
    else if (record !== undefined && named[1] !== record) report('filename', `ファイル名の識別子が record と一致しない: ${record}`);
    return { path, fields, violations };
  });
}

/**
 * git を、シェルを介さずに記憶の根で実行する。パスの指定は文字どおりに解釈させる。
 * @param {string} root
 * @param {string[]} args
 * @returns {{ status: number, stdout: string, stderr: string }}
 */
function git(root, args) {
  const result = spawnSync('git', ['--literal-pathspecs', '-C', root, ...args], { encoding: 'utf8', env: GIT_ENV, maxBuffer: 64 * 1024 * 1024 });
  if (result.error) throw new Unusable(`git を実行できない: ${result.error.message}`);
  if (result.status === null) throw new Unusable(`git ${args[0]} が中断された: ${result.signal}`);
  return { status: result.status, stdout: result.stdout, stderr: result.stderr };
}

/**
 * git を実行し、成功したときの標準出力を返す。失敗は、検査できない状態として扱う。
 * @param {string} root
 * @param {string[]} args
 * @returns {string}
 */
function gitOutput(root, args) {
  const { status, stdout, stderr } = git(root, args);
  if (status !== 0) throw new Unusable(`git ${args[0]} が失敗した（exit ${status}）: ${stderr.trim()}`);
  return stdout;
}

/**
 * 最後に取り直した結果（その worktree の FETCH_HEAD）から、枝を取り直した行を読む。
 * @param {string} root
 * @returns {{ commit: string, branch: string }[]} FETCH_HEAD が無いときは空
 */
function fetchedBranches(root) {
  const path = resolve(root, gitOutput(root, ['rev-parse', '--git-path', FETCH_HEAD]).trim());
  if (!existsSync(path)) return [];
  return readFileSync(path, 'utf8').split('\n').map((line) => line.match(FETCHED_BRANCH)).filter((matched) => matched !== null)
    .map(([, commit, branch]) => ({ commit, branch }));
}

/**
 * remote 追跡の ref の完全な名前を、remote と枝に分ける。remote の名前は、設定に在る remote のうち最も長く一致するものとする。
 * @param {string} root
 * @param {string} fullName refs/remotes/ で始まる名前
 * @returns {{ remote: string, branch: string }}
 */
function trackedBranch(root, fullName) {
  const rest = fullName.slice(TRACKING.length);
  const remotes = gitOutput(root, ['remote']).split('\n').filter((name) => name !== '' && rest.startsWith(`${name}/`));
  const remote = remotes.sort((a, b) => b.length - a.length)[0] ?? rest.split('/')[0];
  return { remote, branch: rest.slice(remote.length + 1) };
}

/**
 * 起点が、最後に取り直した結果と食い違わないことを確かめる。照合するのは、remote 追跡の ref と FETCH_HEAD だけである。
 * ローカルのブランチ・タグ・コミットは、照合しない。URL は照合しない。クラウドの checkout では、取り直した URL が remote の URL と違うことがある。
 * @param {string} root
 * @param {string} name 渡された起点
 * @param {{ remote: string, branch: string } | undefined} tracked 起点が remote 追跡の ref なら、その remote と枝
 * @param {string} commit 起点のコミット
 */
function requireFetched(root, name, tracked, commit) {
  if (tracked !== undefined) {
    const { remote, branch } = tracked;
    const fetch = `git fetch ${remote} ${branch} で取り直してから実行する`;
    const lines = fetchedBranches(root).filter((line) => line.branch === branch);
    if (lines.length === 0) throw new Unusable(`起点 ${name} の枝 ${branch} を取り直した記録が、FETCH_HEAD に無い。${fetch}`);
    if (!lines.some((line) => line.commit === commit)) {
      throw new Unusable(`起点 ${name} が、最後に取り直した結果（FETCH_HEAD）と食い違う。${fetch}`);
    }
    return;
  }
  if (name !== FETCH_HEAD) return;
  const lines = fetchedBranches(root);
  const fetch = '既定のブランチだけを git fetch <remote> <既定のブランチ> で取り直してから実行する';
  if (lines.length !== 1) throw new Unusable(`FETCH_HEAD が、枝を取り直した行を1つに決められない（${lines.length}行）。${fetch}`);
  if (lines[0].commit !== commit) throw new Unusable(`FETCH_HEAD の先頭が、枝を取り直した行と違う。${fetch}`);
}

/**
 * 履歴が揃っていることを確かめ、起点の ref をコミットへ解決する。git を使う最初の手順である。
 * 起点が remote 追跡の ref か FETCH_HEAD なら、最後に取り直した結果と照合する（requireFetched）。
 * @param {string} root
 * @param {string | undefined} ref
 * @returns {string} 起点のコミット
 */
function startingCommit(root, ref) {
  const probe = git(root, ['rev-parse', '--is-shallow-repository']);
  if (probe.status !== 0) throw new Unusable(`git の作業ツリーの中に無い: ${root}\n${probe.stderr.trim()}`);
  const shallow = probe.stdout.trim();
  const name = ref ?? DEFAULT_REF;
  const symbolic = git(root, ['rev-parse', '--symbolic-full-name', name]);
  const fullName = symbolic.status === 0 ? symbolic.stdout.trim() : '';
  const tracked = fullName.startsWith(TRACKING) ? trackedBranch(root, fullName) : undefined;
  if (shallow === 'true') {
    const target = tracked === undefined ? 'origin <既定のブランチ>' : `${tracked.remote} ${tracked.branch}`;
    throw new Unusable(`履歴が浅く、版を決められない。git fetch --deepen=1000 ${target} で履歴を取り直す。まだ浅ければ、深さを増やす: ${root}`);
  }
  if (shallow !== 'false') throw new Unusable(`履歴が浅いかどうかを git が答えない。git を新しくする: ${shallow}`);
  const resolved = git(root, ['rev-parse', '--verify', '--quiet', `${name}^{commit}`]);
  if (resolved.status !== 0) {
    if (ref === undefined) throw new Unusable(`既定のブランチを決められない（${DEFAULT_REF} が無い）。--ref で起点を指すか、git remote set-head origin <既定のブランチ> で作る`);
    throw new Unusable(`起点の ref を解決できない: ${ref}`);
  }
  const commit = resolved.stdout.trim();
  requireFetched(root, name, tracked, commit);
  return commit;
}

/**
 * あるコミットでの、識別子に当たる記録を探す。records/ の直下のファイルだけを見る。
 * @param {string} root
 * @param {string} commit
 * @param {string} id
 * @returns {{ path: string, blob: string }[]} ちょうど1件のときだけ、記録が在る
 */
function recordsAt(root, commit, id) {
  return gitOutput(root, ['ls-tree', '-z', commit, 'records/']).split('\0').filter((entry) => entry !== '').map((entry) => {
    const tab = entry.indexOf('\t');
    const [, type, blob] = entry.slice(0, tab).split(' ');
    return { type, blob, path: entry.slice(tab + 1) };
  }).filter((entry) => entry.type === 'blob' && entry.path.startsWith(`records/${id}-`) && entry.path.endsWith('.md'));
}

/**
 * 記録の版を「識別子@コミットの省略形」で返す。版は、起点でその記録を最後に変えたコミットである。
 * @param {string} root
 * @param {string} commit 起点のコミット
 * @param {string} id
 * @param {string} path
 * @returns {string}
 */
function versionAt(root, commit, id, path) {
  const last = gitOutput(root, ['rev-list', '-1', commit, '--', path]).trim();
  if (last === '') throw new Unusable(`記録を最後に変えたコミットが見つからない: ${path}`);
  return `${id}@${gitOutput(root, ['rev-parse', '--short=7', last]).trim()}`;
}

/**
 * version コマンド。
 * @returns {number} 終了コード
 */
function version(root, id, ref) {
  const start = startingCommit(root, ref);
  const found = recordsAt(root, start, id);
  if (found.length !== 1) {
    console.error(`memory: ${ref ?? DEFAULT_REF} に、${id} の記録が${found.length === 0 ? '無い' : '複数在る'}`);
    return 1;
  }
  const [{ path, blob }] = found;
  const result = versionAt(root, start, id, path);
  const file = join(root, path);
  const same = existsSync(file) && statSync(file).isFile() && gitOutput(root, ['hash-object', '--', path]).trim() === blob;
  console.log(result);
  if (!same) console.error(`memory: 作業ツリーの記録は、この版と内容が違う: ${path}`);
  return 0;
}

/**
 * 台帳の1件を、Global Memory の起点と比べる。
 * @returns {{ result: string, detail: string }}
 */
function compare(globalRoot, start, id, pinned) {
  const cited = `${id}@${pinned}`;
  const stale = '。Global Memory の履歴が古い場合にも起きる';
  const resolved = git(globalRoot, ['rev-parse', '--verify', '--quiet', `${pinned}^{commit}`]);
  if (resolved.status !== 0) return { result: 'missing', detail: `${cited} 版のコミットが無い${stale}` };
  const commit = resolved.stdout.trim();
  // 16進だけの名前の ref が在ると、git はコミットの省略形より先に ref を解決する。それを版として扱わない。
  if (!commit.startsWith(pinned)) return { result: 'missing', detail: `${cited} 版のコミットが無い。同じ名前の ref は、版として扱わない` };
  const ancestor = git(globalRoot, ['merge-base', '--is-ancestor', commit, start]);
  if (ancestor.status === 1) return { result: 'missing', detail: `${cited} 版が起点の履歴に無い${stale}` };
  if (ancestor.status !== 0) throw new Unusable(`git merge-base が失敗した（exit ${ancestor.status}）: ${ancestor.stderr.trim()}`);
  const before = recordsAt(globalRoot, commit, id);
  if (before.length !== 1) return { result: 'missing', detail: `${cited} 版に記録が${before.length === 0 ? '無い' : '複数在る'}` };
  const after = recordsAt(globalRoot, start, id);
  if (after.length !== 1) return { result: 'missing', detail: `${cited} 起点に記録が${after.length === 0 ? '無い' : '複数在る'}` };
  const current = versionAt(globalRoot, start, id, after[0].path);
  let fields = new Map();
  let note = '';
  try {
    ({ fields } = frontMatter(gitOutput(globalRoot, ['cat-file', 'blob', after[0].blob]), RECORD_KEYS));
  } catch (error) {
    if (!(error instanceof Unreadable)) throw error;
    note = '（起点の記録の front-matter を読めない）';
  }
  if (fields.has('superseded-by')) return { result: 'superseded', detail: `${cited} -> ${current} superseded-by ${fields.get('superseded-by')}` };
  if (fields.has('moved-to')) return { result: 'moved', detail: `${cited} -> ${current} moved-to ${fields.get('moved-to')}` };
  if (before[0].blob !== after[0].blob) return { result: 'changed', detail: `${cited} -> ${current}${note}` };
  return { result: 'unchanged', detail: `${cited}${note}` };
}

/**
 * adopted コマンド。台帳は作業ツリーから、Global Memory は起点のコミットの木から読む。
 * @returns {number} 終了コード
 */
function adopted(root, globalRoot, ref) {
  const entries = loadAdopted(root);
  const start = startingCommit(globalRoot, ref);
  const lines = [];
  let failed = false;
  for (const entry of entries) {
    if (entry.violations.length > 0) {
      lines.push(...entry.violations);
      failed = true;
      continue;
    }
    const { result, detail } = compare(globalRoot, start, entry.fields.get('record'), entry.fields.get('version'));
    if (result === 'missing') failed = true;
    lines.push(`${entry.path}:${result}: ${detail}`);
  }
  for (const line of lines) console.log(line);
  return failed ? 1 : 0;
}

/**
 * 記録どうしの関係で決まる違反を集める。
 * @param {ReturnType<typeof load>['records']} records
 * @returns {string[]}
 */
function relations(records) {
  const violations = [];
  const byId = new Map();
  for (const record of records) {
    const id = record.fields.get('id');
    if (id === undefined) continue;
    if (byId.has(id)) violations.push(`${record.path}:duplicate-id: ${id} は ${byId.get(id).path} と重複している`);
    else byId.set(id, record);
  }
  const evolutions = records.filter((record) => record.fields.get('type') === 'evolution');
  for (const record of records) {
    const refer = (key, target) => {
      if (!byId.has(target)) violations.push(`${record.path}:dangling: ${key} が指す記録が無い: ${target}`);
    };
    const next = record.fields.get('superseded-by');
    if (next !== undefined) {
      refer('superseded-by', next);
      const id = record.fields.get('id');
      const explained = evolutions.some((evolution) => (evolution.fields.get('from') ?? []).includes(id)
        && (evolution.fields.get('to') ?? []).includes(next));
      if (!explained) violations.push(`${record.path}:replacement: ${next} への置き換えを説明する evolution が無い`);
    }
    for (const key of ['from', 'to']) for (const target of record.fields.get(key) ?? []) refer(key, target);
    const seen = new Set();
    for (let at = record.fields.get('id'); at !== undefined; at = byId.get(at)?.fields.get('superseded-by')) {
      if (seen.has(at)) {
        violations.push(`${record.path}:replacement: 置き換えが循環している: ${at}`);
        break;
      }
      seen.add(at);
    }
  }
  for (const evolution of evolutions) {
    const to = evolution.fields.get('to') ?? [];
    for (const old of evolution.fields.get('from') ?? []) {
      const next = byId.get(old)?.fields.get('superseded-by');
      if (byId.has(old) && !to.includes(next)) {
        violations.push(`${evolution.path}:replacement: from の ${old} が、to の記録を superseded-by で指していない`);
      }
    }
  }
  return violations;
}

/** @param {string} text */
function cell(text) {
  return text.replaceAll('|', '\\|');
}

/**
 * 索引の本文を作る。置き換え済みの記録と、記憶の外へ移した記録は載せない。
 * @param {ReturnType<typeof load>['records']} records
 * @returns {string}
 */
function renderIndex(records) {
  const rows = records
    .filter((record) => !record.fields.has('superseded-by') && !record.fields.has('moved-to'))
    .filter((record) => ['id', 'type', 'title', 'applies-when', 'verification'].every((key) => record.fields.has(key)))
    .sort((a, b) => (a.fields.get('id') < b.fields.get('id') ? -1 : 1))
    .map((record) => {
      const field = (key) => cell(record.fields.get(key));
      return `| [${field('id')}](${record.path}) | ${field('type')} | ${field('title')} | ${field('applies-when')} | ${field('verification')} |`;
    });
  return [...INDEX_HEADER, ...rows, ''].join('\n');
}

/**
 * Task Memory の残留を集める。tasks の直下に在るものを、1件につき1行の違反にする。
 * tasks がリンクのときは辿らない。辿ると、切れたリンクと、空のディレクトリを指すリンクが、残留なしに見える。
 * @param {string} root
 * @returns {string[]}
 */
function taskMemory(root) {
  const dir = join(root, 'tasks');
  const found = lstatSync(dir, { throwIfNoEntry: false });
  if (found === undefined) return [];
  if (!found.isDirectory()) return ['tasks:task-memory: tasks がディレクトリでない。リンクは辿らない。既定のブランチへ入れる前に取り除く'];
  return readdirSync(dir).sort().map((name) => `tasks/${name}:task-memory: Task Memory が残っている。既定のブランチへ入れる前に取り除く`);
}

/**
 * 記憶の根であることを確かめる。
 * @param {string} root
 */
function requireRoot(root) {
  if (!existsSync(root) || !statSync(root).isDirectory()) throw new Unusable(`記憶の根がディレクトリでない: ${root}`);
  const recordsDir = join(root, 'records');
  if (!existsSync(recordsDir) || !statSync(recordsDir).isDirectory()) throw new Unusable(`記憶の根に records/ が無い: ${root}`);
}

// コマンドごとの、位置で決まる引数の数。
const POSITIONALS = { check: 1, index: 1, version: 2, adopted: 2 };

function main(argv) {
  const [command, ...rest] = argv;
  const count = Object.hasOwn(POSITIONALS, command ?? '') ? POSITIONALS[command] : 0;
  const positionals = rest.slice(0, count);
  const options = rest.slice(count);
  const write = command === 'index' && options.length === 1 && options[0] === '--write';
  const noTaskMemory = command === 'check' && options.length === 1 && options[0] === '--no-task-memory';
  const takesRef = command === 'version' || command === 'adopted';
  const ref = takesRef && options.length === 2 && options[0] === '--ref' && options[1] !== '' && !options[1].startsWith('-') ? options[1] : undefined;
  if (count === 0 || positionals.length !== count || !(options.length === 0 || write || noTaskMemory || ref !== undefined)) {
    console.error(USAGE);
    return 2;
  }
  const [root, second] = positionals;
  requireRoot(root);
  if (command === 'version') {
    if (!ID.test(second)) throw new Unusable(`識別子は MEM-<12桁>-<2桁> の形で書く: ${second}`);
    return version(root, second, ref);
  }
  if (command === 'adopted') {
    requireRoot(second);
    return adopted(root, second, ref);
  }
  const { records, violations } = load(root);
  const indexPath = join(root, 'index.md');
  if (command === 'index') {
    if (write) writeFileSync(indexPath, renderIndex(records));
    else process.stdout.write(renderIndex(records));
    return 0;
  }
  violations.push(...relations(records));
  const ledger = loadAdopted(root);
  const hasIndex = existsSync(indexPath);
  if (records.length > 0 || hasIndex) {
    if (!hasIndex) violations.push('index.md:index: 索引が無い。index --write で作る');
    else if (readFileSync(indexPath, 'utf8').replaceAll('\r\n', '\n') !== renderIndex(records)) {
      violations.push('index.md:index: 索引が記録と一致しない。index --write で作り直す');
    }
  }
  for (const entry of ledger) violations.push(...entry.violations);
  if (noTaskMemory) violations.push(...taskMemory(root));
  for (const violation of violations) console.log(violation);
  return violations.length === 0 ? 0 : 1;
}

try {
  process.exitCode = main(process.argv.slice(2));
} catch (error) {
  if (error instanceof Unusable) console.error(`memory: ${error.message}`);
  else console.error(`memory: 検査できない: ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 2;
}
