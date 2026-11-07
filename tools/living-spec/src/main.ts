// 使い方:
//   living-spec check [--doc-missing] [起点]   全体検査。--doc-missing は書き漏らしの向き（UC に要求票が無い・票が条件や遷移先状態を挙げない・票の行にルールが無い）だけを検査する
//   living-spec render [起点]                  設計の可視化（状態遷移図と UC ごとの縦串）を1つの HTML へ描き、書き出した場所を出す
//   living-spec hook                           Claude Code の PostToolUse フック（標準入力の JSON を読む）
// 根は起点（check・render は引数か作業ディレクトリ、hook は編集したファイル）から上へ辿って最も近い目印で決まる。
// 根・置き場・範囲の規則の正本は plugins/living-spec/references/format.md の「置き場の設定」。CLI とフックは同じ関数でそれを適用する。
// check は1行目に「根: <絶対パス>」を出し、違反があれば終了コード 1、無ければ 0。引数で渡した起点が範囲外なら、扱いを示す注記を標準エラーへ出す。
// 終了コード 2: 引数の誤り・起点が無い・正本が見つからない・根の探索を続けられない・設定を読めない・根に属さない置き場・表の置き場が無い。
// hook: 根の範囲内の編集で根を全体検査して描き直す。CLAUDE_PROJECT_DIR は根にしない。
//   終了コード 2 で止める: 違反・検査器が動かない・設定を読めない（範囲によらない）・根に属さない置き場・根が決まった後の探索を続けられない。
//   止めるときは標準エラーが AI へ返る。設定の誤りと読み取りの失敗の文面は CLI と同じ。描画の失敗では編集を止めない。
//   何もせず終了コード 0: 正本が見つからない・根が決まる前の探索を続けられない・hook が false・範囲外の編集・表の置き場が無い。
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { checkDocMissing, checkRepo, formatViolation } from './check.ts';
import { writeView } from './render.ts';
import {
  type RootSearch,
  SearchError,
  findMisplacements,
  findRoot,
  formatMisplacements,
  formatNoRoot,
  statIfExists,
} from './root.ts';
import { classifyTarget, formatScopeNote } from './scope.ts';
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

// 根の .living-spec.json を読めないときの文面（CLI とフックで同じ。どちらも loadConfig を通る）
function configError(root: string, e: unknown): string {
  return `${CONFIG_FILE} を読めない（根: ${root}）: ${(e as Error).message}`;
}

// 根の .living-spec.json を読み込む。読めなければ止める
function loadConfig(root: string): void {
  try {
    configureLayout(root);
  } catch (e) {
    die(configError(root, e));
  }
}

// 探索（起点の判定・根の探索・置き場の検証・範囲の判定）を続けられなければ止める。
// 根が決まった後なら root を渡し、文面に根を添える（文面は CLI とフックで同じ）。フックの根が決まる前は runHook が扱う
function withSearch<T>(f: () => T, root?: string): T {
  try {
    return f();
  } catch (e) {
    if (e instanceof SearchError) die(root === undefined ? e.message : `${e.message}（根: ${root}）`);
    throw e;
  }
}

// 根に属さない置き場は別の正本の表を読み込むため止める（文面は CLI とフックで同じ）
function checkPlacements(root: string): void {
  const misplaced = withSearch(() => findMisplacements(root, LAYOUT), root);
  if (misplaced.length > 0) die(formatMisplacements(root, misplaced));
}

function tablesIsDir(root: string): boolean {
  return withSearch(() => statIfExists(join(root, LAYOUT.tables))?.isDirectory() === true, root);
}

// 起点から根を決め、置き場を読み込んで検証する。announce なら根が決まった直後（設定を読む前）に標準出力の1行目へ根を出す。
// 根を誤ると表を1つも読まずに「違反なし」と出て黙って通るため、表の置き場が無ければ止める。
// 返す target は引数を絶対化した対象（引数が無ければ undefined）
function prepare(arg: string | undefined, announce: boolean): { root: string; target: string | undefined } {
  const target = arg === undefined ? undefined : resolve(arg);
  let start = process.cwd();
  if (target !== undefined) {
    const stat = withSearch(() => statIfExists(target));
    if (stat === undefined) die(`起点が見つからない: ${target}`);
    start = stat.isDirectory() ? target : dirname(target);
  }
  const search = withSearch(() => findRoot(start));
  if (!search.found) die(formatNoRoot(search));
  const root = search.root;
  if (announce) console.log(`根: ${root}`);
  loadConfig(root);
  checkPlacements(root);
  if (!tablesIsDir(root)) {
    die(`表の置き場が見つからない: ${join(root, LAYOUT.tables)}（根: ${root}。置き場は ${CONFIG_FILE} の tables）`);
  }
  return { root, target };
}

// 対象が範囲外なら、検査か描画へ進む前に注記を標準エラーへ出す。起動した場所は作業ディレクトリ。終了コードは変えない
function noteScope(root: string, target: string | undefined): void {
  const scope = withSearch(() => classifyTarget(root, LAYOUT, process.cwd(), target), root);
  if (scope.kind === 'out' && target !== undefined) {
    process.stderr.write(`${formatScopeNote(root, LAYOUT, target, scope.candidate)}\n`);
  }
}

function runCheck(args: string[]): never {
  const docMissing = args.includes('--doc-missing');
  const rest = args.filter((a) => a !== '--doc-missing');
  if (rest.length > 1 || rest.some((a) => a.startsWith('--'))) usage();
  const { root, target } = prepare(rest[0], true);
  noteScope(root, target);
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
  const { root, target } = prepare(args[0], false);
  noteScope(root, target);
  console.log(writeView(root));
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
  // 基点は相対の file_path の絶対化と、範囲の判定の起動した場所にだけ使い、根にはしない
  const launch = resolve(process.env.CLAUDE_PROJECT_DIR || (typeof obj.cwd === 'string' ? obj.cwd : process.cwd()));
  const target = resolve(launch, filePath);
  // 根が決まる前に探索を続けられなければ、どの根の編集かが分からないので何もしない
  let search: RootSearch;
  try {
    search = findRoot(statIfExists(target)?.isDirectory() === true ? target : dirname(target));
  } catch (e) {
    if (e instanceof SearchError) process.exit(0);
    throw e;
  }
  if (!search.found) process.exit(0);
  const root = search.root;
  // 設定を読めないときは範囲によらず止める。範囲の判定に置き場の値が要るため
  loadConfig(root);
  if (!LAYOUT.hook) process.exit(0);
  if (withSearch(() => classifyTarget(root, LAYOUT, launch, target), root).kind !== 'in') process.exit(0);
  // 置き場の検証は表の置き場の有無より先。外れた置き場は存在しなくても止める
  checkPlacements(root);
  if (!tablesIsDir(root)) process.exit(0);
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
  die(`RDRA の検査で違反が ${violations.length} 件ある（根: ${root}。${target} の編集後）。直すこと。\n${violations.map(formatViolation).join('\n')}`);
}

const [command, ...args] = process.argv.slice(2);
if (command === 'check') runCheck(args);
if (command === 'render') runRender(args);
if (command === 'hook' && args.length === 0) runHook();
usage();
