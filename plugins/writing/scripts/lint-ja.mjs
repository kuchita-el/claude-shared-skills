// 一文の長さを、文書種別ごとの上限で検査する。
// 数え方の正本は references/japanese-writing.md 第5条の補則であり、ここはその規則に従って数える実装である。
// 規則の本文はここへ写さない。数え方を変えるときは、補則を先に改める。
//
// 使い方は USAGE を見る。違反は「パス:行:一文長: N字（上限M）」の形で標準出力へ出す。
//
// Markdown の構造は、同梱の解析器 vendor/markdown-it.mjs（CommonMark に GFM の表を足した設定）で読む。
// 解析器は静的な import でなく、処理の全体を包む try/catch の中の動的な import() で読む。
// 静的な import の失敗と未捕捉の例外を、Node は違反ありと同じ終了コード 1 で終えるためである。
import { Buffer } from 'node:buffer';
import { spawnSync } from 'node:child_process';
import { readFileSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const USAGE = `usage: lint-ja.mjs [--type TYPE] --file PATH | [--type TYPE] --diff BASE -- PATH...
  TYPE: 文書種別。省略時は「汎用」。上限はプロジェクト固有のプロファイルの TYPE の行、無ければ同梱の既定の「汎用」の行から採る。
  PATH: Markdown として扱う拡張子 .md・.markdown（大文字小文字を問わない）のファイルに限る。
  終了コード: 0 違反なし、1 一文長の違反あり、2 引数の誤りか検査できない入力。`;

const PARSER = new URL('./vendor/markdown-it.mjs', import.meta.url).href;
const BUNDLED_PROFILE = fileURLToPath(new URL('../references/document-type-profiles.md', import.meta.url));
const DEFAULT_TYPE = '汎用';
// どのプロファイルからも上限を読めないときに採る、補則の既定値。
const DEFAULT_LIMIT = 100;
const TERMINATORS = new Set(['。', '！', '？', '!', '?']);
const BLANK = /^[ \t]*$/;
const FRONT_MATTER_FENCE = /^---[ \t]*$/;
const MARKDOWN_EXTENSION = /\.(md|markdown)$/i;
const LIMIT_CELL = /^([0-9]+)\s*(字)?$/;
// 新側の開始行と件数だけを読む。見出しの文脈部にある + を拾わないよう、旧側（-a,b）を飛ばして最初の + で止める。
const HUNK_HEADER = /^@@ [^+]*\+([0-9]+)(?:,([0-9]+))?/;

/**
 * 解析器（markdown-it）のうち、この検査器が使う面。
 * @typedef {{ type: string, map: [number, number] | null, content: string }} Token
 * @typedef {{ parse(src: string, env: object): Token[] }} MarkdownParser
 */
/**
 * 行の種類。skip は文として数えない行（front-matter・フェンスで囲んだコードブロック・表）。
 * itemStarts は箇条書きの項目の最初の行の添字（0始まり）の集合。
 * @typedef {'skip' | 'heading' | 'text'} LineKind
 * @typedef {{ kinds: LineKind[], itemStarts: Set<number> }} LineStructure
 */
/**
 * 検査の対象の印。all は全ての行を対象にする。changed は変えた行、joined は削除で次の行と隣り合った行（どちらも1始まり）。
 * @typedef {{ all: boolean, changed: Set<number>, joined: Set<number> }} Marks
 */
/** @typedef {{ line: number, length: number }} Report */

/** @returns {Marks} */
function everyLine() {
  return { all: true, changed: new Set(), joined: new Set() };
}

/**
 * 各行の種類と、箇条書きの項目の始まりの行を決める。
 * 種類の優先は skip、heading、text の順。項目の始まりは、種類と別に持つ。
 * @param {string[]} lines 行末の \r を落とした行（0始まり）
 * @param {MarkdownParser} md
 * @returns {LineStructure}
 */
function lineKinds(lines, md) {
  /** @type {LineKind[]} */
  const kinds = lines.map(() => 'text');
  const itemStarts = new Set();
  // front-matter は解析器に読ませず、ここで照合する。閉じの行が無ければ front-matter と見ない。
  let frontMatterEnd = -1;
  if (lines.length > 0 && FRONT_MATTER_FENCE.test(lines[0])) {
    frontMatterEnd = lines.findIndex((line, i) => i > 0 && FRONT_MATTER_FENCE.test(line));
  }
  for (let i = 0; i <= frontMatterEnd; i++) kinds[i] = 'skip';
  // 解析器の返す行の範囲を元の行に当てるため、行の数と並びを保って渡す。
  // front-matter の行は空の行にし、行の中に残る \r は半角空白にする（解析器は単独の \r も改行と見なす）。
  const src = lines.map((line, i) => (i <= frontMatterEnd ? '' : line.replaceAll('\r', ' '))).join('\n');
  const rank = { text: 0, heading: 1, skip: 2 };
  /**
   * @param {[number, number]} range 解析器の返す行の範囲（終わりを含まない）
   * @param {LineKind} kind
   */
  const assign = ([from, to], kind) => {
    for (let i = from; i < Math.min(to, lines.length); i++) {
      if (rank[kind] > rank[kinds[i]]) kinds[i] = kind;
    }
  };
  for (const token of md.parse(src, {})) {
    if (!token.map) continue;
    if (token.type === 'fence' || token.type === 'table_open') assign(token.map, 'skip');
    else if (token.type === 'heading_open') assign(token.map, 'heading');
    else if (token.type === 'list_item_open') itemStarts.add(token.map[0]);
  }
  return { kinds, itemStarts };
}

/**
 * 文書の GFM の表の行（見出しの行を含む）ごとに、欄の文字列の配列を返す。
 * @param {string} text
 * @param {MarkdownParser} md
 * @returns {string[][]}
 */
function parseTables(text, md) {
  /** @type {string[][]} */
  const rows = [];
  /** @type {string[] | null} */
  let row = null;
  for (const token of md.parse(text, {})) {
    if (token.type === 'tr_open') row = [];
    else if (token.type === 'tr_close' && row) {
      rows.push(row);
      row = null;
    } else if (token.type === 'inline' && row) row.push(token.content);
  }
  return rows;
}

/**
 * 上限を超え、印のある字を1つでも含む文を、報告の順に返す。
 * @param {string[]} lines 行末の \r を落とした行（0始まり）
 * @param {LineStructure} structure
 * @param {Marks} marks
 * @param {number} limit
 * @returns {Report[]}
 */
function longSentences(lines, { kinds, itemStarts }, marks, limit) {
  /** @type {Report[]} */
  const reports = [];
  let length = 0;
  let start = 0;
  let target = marks.all;
  let joinPending = false;
  const finish = () => {
    if (length > limit && target) reports.push({ line: start, length });
    length = 0;
    target = marks.all;
    joinPending = false;
  };
  lines.forEach((raw, i) => {
    const lineNo = i + 1;
    const kind = kinds[i];
    // 文ではない行は一文に足さず、そこで前の文を区切る。
    if (kind === 'skip') {
      finish();
      return;
    }
    // 空白だけの空行は、字の無い空行と同じに扱う。空白を次の文の字として持ち越さない。
    const blank = kind === 'text' && BLANK.test(raw);
    const line = blank ? '' : raw;
    // 見出しと項目の始まりは前の文を区切る。見出しはそれ自体で1つの単位として閉じる。
    if (kind === 'heading' || itemStarts.has(i)) finish();
    const lineMarked = marks.all || marks.changed.has(lineNo);
    if (lineMarked) target = true;
    // 印は字の単位で立てる。変えた行の字か、削除でつながった境目の後ろの字を1字でも含む文を検査する。
    // 文の始まりの行は、文の最初の字を足すときに決める。行の途中で始まる文も、その行で報告する。
    for (const ch of line) {
      if (length === 0) start = lineNo;
      length++;
      if (lineMarked || joinPending) target = true;
      if (TERMINATORS.has(ch)) finish();
    }
    if (kind === 'heading' || (blank && length > 0)) finish();
    // 削除で次の行と隣り合った行の終わりで文が続いていれば、次の行の字でその文に印を立てる。
    if (marks.joined.has(lineNo) && length > 0) joinPending = true;
  });
  finish();
  return reports;
}

/**
 * git を起動する。起動できなければ例外を投げる。
 * @param {string[]} args
 */
function git(args) {
  const result = spawnSync('git', args, { encoding: 'utf8', maxBuffer: Infinity });
  if (result.error) throw result.error;
  return result;
}

/**
 * 基点からの差分で、パスの印を作る。変えた行も境目も無ければ null を返す。
 * @param {string} base
 * @param {string} path
 * @returns {Marks | null}
 */
function diffMarks(base, path) {
  // 新しく書いた文書はまだ git の差分に現れないので、ファイル全体を差分とみなす。
  if (git(['ls-files', '--error-unmatch', '--', path]).status !== 0) return everyLine();
  const diff = git(['diff', '--no-ext-diff', '--no-textconv', '--unified=0', '--no-color', base, '--', path]);
  if (diff.status !== 0) throw new Error(`git diff が終了コード ${diff.status} で失敗した: ${diff.stderr.trim()}`);
  const changed = new Set();
  const joined = new Set();
  // 最初のハンク見出しより前の行だけをファイルの見出しとして読む。
  // ハンクの中では、中身が ++ で始まる追加行（+++ で始まる差分の行）も追加行として数える。
  let inHunk = false;
  let next = 0;
  for (const line of diff.stdout.split('\n')) {
    if (line.startsWith('@@')) {
      const range = HUNK_HEADER.exec(line);
      if (!range) throw new Error(`差分のハンク見出しを読めない: ${line}`);
      next = Number(range[1]);
      // 削除だけのハンク（+c,0）は、新側の c 行と c+1 行を隣り合わせる。その境目をまたぐ文を検査できるよう印を残す。
      if (range[2] === '0') joined.add(next);
      inHunk = true;
    } else if (inHunk && line.startsWith('+')) {
      changed.add(next);
      next++;
    }
  }
  if (changed.size === 0 && joined.size === 0) return null;
  return { all: false, changed, joined };
}

/**
 * 上限を、プロジェクト固有のプロファイルの種別の行、同梱の既定の「汎用」の行、補則の既定値の順に採る。
 * 読めないプロファイルと、種別の行の無いプロファイルは飛ばす。行の欄を数値として読めなければ error を返す。
 * @param {{ type: string, projectDir: string | undefined, bundledProfile: string, md: MarkdownParser }} options
 * @returns {{ limit: number } | { error: string }}
 */
function resolveLimit({ type, projectDir, bundledProfile, md }) {
  /** @type {Array<[string, string]>} */
  const sources = [];
  if (projectDir) sources.push([`${projectDir}/.claude/writing/type-profiles.md`, type]);
  sources.push([bundledProfile, DEFAULT_TYPE]);
  for (const [path, name] of sources) {
    let text;
    try {
      text = readFileSync(path, 'utf8');
    } catch {
      continue;
    }
    // 先頭の欄が種別と一致する最初の行の、4つ目の欄（一文長の上限）を読む。
    const row = parseTables(text, md).find((cells) => cells[0] === name);
    if (!row) continue;
    const cell = row[3] ?? '';
    const value = LIMIT_CELL.exec(cell);
    if (value) return { limit: Number(value[1]) };
    return { error: `プロファイルの種別「${name}」の一文長の上限を数値として読めない: ${path}: ${cell}` };
  }
  return { limit: DEFAULT_LIMIT };
}

/**
 * 検査できない入力なら理由を返し、検査できれば null を返す。
 * @param {string} path
 * @returns {string | null}
 */
function inputProblem(path) {
  let isFile = false;
  try {
    isFile = statSync(path).isFile();
  } catch {
    isFile = false;
  }
  if (!isFile) return `入力ファイルが無い: ${path}`;
  if (!MARKDOWN_EXTENSION.test(path)) return `Markdown として扱えない（拡張子が .md・.markdown でない）: ${path}`;
  return null;
}

/**
 * パスをコードポイントの順に並べる比較。UTF-8 のバイト順はコードポイントの順と一致する。
 * @param {string} a
 * @param {string} b
 */
function byCodePoint(a, b) {
  return Buffer.compare(Buffer.from(a, 'utf8'), Buffer.from(b, 'utf8'));
}

/**
 * 引数を解釈して検査し、終了コード（0 違反なし、1 違反あり、2 引数の誤りか検査できない入力）を返す。
 * @param {string[]} argv
 * @returns {Promise<number>}
 */
async function main(argv) {
  /** @param {string} message */
  const fail = (message) => {
    process.stderr.write(`${message}\n`);
    return 2;
  };
  try {
    // 引数の誤りは、解析器を読み込む前に判定する。
    let mode = '';
    let file = '';
    let base = '';
    let type = '';
    let typeGiven = false;
    /** @type {string[]} */
    let paths = [];
    for (let i = 0; i < argv.length; ) {
      const arg = argv[i];
      const hasValue = i + 1 < argv.length;
      if (arg === '--type') {
        if (typeGiven || !hasValue || argv[i + 1] === '') return fail(USAGE);
        type = argv[i + 1];
        typeGiven = true;
        i += 2;
      } else if (arg === '--file') {
        if (mode !== '' || !hasValue) return fail(USAGE);
        mode = 'file';
        file = argv[i + 1];
        i += 2;
      } else if (arg === '--diff') {
        if (mode !== '' || !hasValue) return fail(USAGE);
        mode = 'diff';
        base = argv[i + 1];
        i += 2;
      } else if (arg === '--') {
        if (mode !== 'diff' || !hasValue) return fail(USAGE);
        paths = argv.slice(i + 1);
        break;
      } else {
        return fail(USAGE);
      }
    }
    if (mode === '' || (mode === 'diff' && paths.length === 0)) return fail(USAGE);

    const { default: MarkdownIt } = await import(PARSER);
    /** @type {MarkdownParser} */
    const md = new MarkdownIt('commonmark').enable('table');

    /** @type {Map<string, Marks>} */
    const targets = new Map();
    if (mode === 'file') {
      const problem = inputProblem(file);
      if (problem) return fail(problem);
      targets.set(file, everyLine());
    } else {
      if (git(['rev-parse', '--verify', '--quiet', `${base}^{commit}`]).status !== 0) {
        return fail(`差分の基点が commit を指さない: ${base}`);
      }
      for (const path of paths) {
        const problem = inputProblem(path);
        if (problem) return fail(problem);
        if (targets.has(path)) continue;
        const marks = diffMarks(base, path);
        if (marks) targets.set(path, marks);
      }
    }

    const resolved = resolveLimit({
      type: type || DEFAULT_TYPE,
      projectDir: process.env.CLAUDE_PROJECT_DIR,
      bundledProfile: BUNDLED_PROFILE,
      md,
    });
    if ('error' in resolved) return fail(resolved.error);
    const { limit } = resolved;

    let status = 0;
    for (const [path, marks] of [...targets].sort(([a], [b]) => byCodePoint(a, b))) {
      const text = readFileSync(path, 'utf8');
      const rows = text.split('\n');
      if (text.endsWith('\n')) rows.pop();
      const lines = rows.map((row) => row.replace(/\r$/, ''));
      const reports = longSentences(lines, lineKinds(lines, md), marks, limit);
      if (reports.length === 0) continue;
      status = 1;
      process.stdout.write(reports.map(({ line, length }) => `${path}:${line}:一文長: ${length}字（上限${limit}）\n`).join(''));
    }
    return status;
  } catch (error) {
    // 解析器の読み込みの失敗と予期しない失敗（読み取り・git の起動等）は、違反の有無と区別して 2 で返す。
    return fail(error instanceof Error ? error.message : String(error));
  }
}

process.exitCode = await main(process.argv.slice(2));
