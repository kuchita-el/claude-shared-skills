// 使い方:
//   living-spec check [--doc-missing] [起点]   全体検査。--doc-missing は書き漏らしの向き（UC に要求票が無い・票が条件や遷移先状態を挙げない・票の行にルールが無い）だけを検査する
//   living-spec render [起点]                  設計の可視化（状態遷移図と UC ごとの縦串）を1つの HTML へ描き、書き出した場所を出す
//   living-spec hook                           Claude Code の PostToolUse フック（標準入力の JSON を読む）
// 起点（ファイルならそのディレクトリ、省略時は今の作業ディレクトリ）から上へ辿り、最も近い目印のディレクトリを根にする（root.ts）。
// 各層の置き場は根の .living-spec.json で変えられる（schema.ts の Layout）。
// check: 1行目に「根: <絶対パス>」を出す。違反があれば一覧を標準出力へ出して終了コード 1、無ければ 0。
// 引数の誤り・起点が無い・正本が見つからない・.living-spec.json の誤り・根に属さない置き場がある・根に表の置き場がディレクトリとして無いときは終了コード 2。
// hook: 編集したファイルが表・要求票・例の置き場か .living-spec.json なら全体検査し、合否に関わらず描き直す。
//   違反、または検査器が動かないときは標準エラーへ出して終了コード 2（PostToolUse の終了コード 2 は標準エラーを AI へ返す）。
//   表の置き場が無いリポジトリ、.living-spec.json の hook が false のとき、範囲外のファイルでは何もせず終了コード 0。描画の失敗では編集を止めない。
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { checkDocMissing, checkRepo, formatViolation } from './check.ts';
import { writeView } from './render.ts';
import {
  RootSearchError,
  findMisplacements,
  findRoot,
  formatMisplacements,
  formatNoRoot,
  statIfExists,
} from './root.ts';
import { CONFIG_FILE, LAYOUT, configureLayout } from './schema.ts';

const USAGE = '使い方: living-spec check [--doc-missing] [起点] | living-spec render [起点] | living-spec hook';

function usage(): never {
  console.error(USAGE);
  process.exit(2);
}

function die(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(2);
}

// 根の .living-spec.json を読めないときの文面（CLI とフックで同じ）
function configError(root: string, e: unknown): string {
  return `${CONFIG_FILE} を読めない（根: ${root}）: ${(e as Error).message}`;
}

// 起点から根を決め、置き場を読み込んで検証する。announce なら根が決まった直後（設定を読む前）に標準出力の1行目へ根を出す。
// 根に属さない置き場は別の正本の表を読み込むため止める。根を誤ると表を1つも読まずに「違反なし」と出て黙って通るため、表の置き場が無ければ止める
function prepare(arg: string | undefined, announce: boolean): string {
  let search: ReturnType<typeof findRoot>;
  try {
    let start = process.cwd();
    if (arg !== undefined) {
      const target = resolve(arg);
      const stat = statIfExists(target);
      if (stat === undefined) die(`起点が見つからない: ${target}`);
      start = stat.isDirectory() ? target : dirname(target);
    }
    search = findRoot(start);
  } catch (e) {
    if (e instanceof RootSearchError) die(e.message);
    throw e;
  }
  if (!search.found) die(formatNoRoot(search));
  const root = search.root;
  if (announce) console.log(`根: ${root}`);
  try {
    configureLayout(root);
  } catch (e) {
    die(configError(root, e));
  }
  const tables = join(root, LAYOUT.tables);
  let tablesIsDir: boolean;
  try {
    const misplaced = findMisplacements(root, LAYOUT);
    if (misplaced.length > 0) die(formatMisplacements(root, misplaced));
    tablesIsDir = statIfExists(tables)?.isDirectory() === true;
  } catch (e) {
    if (e instanceof RootSearchError) die(`${e.message}（根: ${root}）`);
    throw e;
  }
  if (!tablesIsDir) die(`表の置き場が見つからない: ${tables}（根: ${root}。置き場は ${CONFIG_FILE} の tables）`);
  return root;
}

function runCheck(args: string[]): never {
  const docMissing = args.includes('--doc-missing');
  const rest = args.filter((a) => a !== '--doc-missing');
  if (rest.length > 1 || rest.some((a) => a.startsWith('--'))) usage();
  const root = prepare(rest[0], true);
  const label = docMissing ? '要求票・例の書き漏らしの検査' : 'RDRA の検査';
  const violations = docMissing ? checkDocMissing(root) : checkRepo(root);
  if (violations.length === 0) {
    console.log(`${label}: 違反なし`);
    process.exit(0);
  }
  for (const v of violations) console.log(formatViolation(v));
  console.log(`${label}: 違反 ${violations.length} 件`);
  process.exit(1);
}

function runRender(args: string[]): never {
  if (args.length > 1 || args.some((a) => a.startsWith('--'))) usage();
  console.log(writeView(prepare(args[0], false)));
  process.exit(0);
}

function runHook(): never {
  let input: unknown;
  try {
    input = JSON.parse(readFileSync(0, 'utf8'));
  } catch (e) {
    die(`living-spec フック: 標準入力の JSON を読めない（${(e as Error).message}）`);
  }
  const obj = (typeof input === 'object' && input !== null ? input : {}) as {
    cwd?: unknown;
    tool_input?: { file_path?: unknown };
  };
  const filePath = obj.tool_input?.file_path;
  if (typeof filePath !== 'string' || filePath === '') process.exit(0);
  const root = resolve(process.env.CLAUDE_PROJECT_DIR || (typeof obj.cwd === 'string' ? obj.cwd : process.cwd()));
  const rel = relative(root, resolve(root, filePath)).split('\\').join('/');
  const configExists = existsSync(join(root, CONFIG_FILE));
  try {
    configureLayout(root);
  } catch (e) {
    die(`living-spec フック: ${CONFIG_FILE} を読めない（${(e as Error).message}）`);
  }
  if (!LAYOUT.hook || !existsSync(join(root, LAYOUT.tables))) process.exit(0);
  const inScope =
    (configExists && rel === CONFIG_FILE) ||
    [LAYOUT.tables, LAYOUT.requirements, LAYOUT.examples].some((d) => rel.startsWith(`${d}/`));
  if (!inScope) process.exit(0);
  let violations;
  try {
    violations = checkRepo(root);
  } catch (e) {
    die(`living-spec フック: 検査器を実行できない（${(e as Error).message}）`);
  }
  try {
    writeView(root);
  } catch (e) {
    process.stderr.write(`living-spec フック: 設計の可視化を描けない（${(e as Error).message}）\n`);
  }
  if (violations.length === 0) process.exit(0);
  die(`RDRA の検査で違反が ${violations.length} 件ある（${rel} の編集後）。直すこと。\n${violations.map(formatViolation).join('\n')}`);
}

const [command, ...args] = process.argv.slice(2);
if (command === 'check') runCheck(args);
if (command === 'render') runRender(args);
if (command === 'hook' && args.length === 0) runHook();
usage();
