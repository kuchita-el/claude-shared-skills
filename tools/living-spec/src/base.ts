// 基準の版（git の版）から正本の中身を読む。render --base が、作業ツリーとの描き分けの入力にする。
// このモジュール自身は描画のモジュール（view.ts・diffview.ts・html.ts・render.ts）に依存しない。基準の版との差分の一覧が
// このモジュールと diff.ts を使うとき、描き分けの材料と HTML を組む側（diffview.ts・html.ts・render.ts）が付いてこないようにするため。
// ただし diff.ts は表の値の読み方（str・list）と区分の型を view.ts と共用するので、view.ts は付いてくる。
//
// 読み方: git の CLI を子プロセスで呼ぶ（rev-parse・ls-tree・cat-file）。git が要るのは --base を付けたときだけ。却下した案:
//   - git を読む npm の依存を足す: 検査器の実行時依存と同梱の量が増える（基準の版との差分の一覧が負う「実行時依存を増やさない」にも反する）
//   - 一時の worktree を作って読む: リポジトリの .git に worktree の登録が残り、異常終了で後始末が漏れる
//   - git archive を展開する: tar の展開を Node の標準だけでは持てない
// ADR にしない: 粒度判定で当たるのは、後戻りのコスト（配布済みの検査器の利用者に git が要る）と自動強制が無いことの2点に留まる。
//   適用先は検査器の1つの実行可能単位に閉じ、理由はこの冒頭と format.md に規範と同居できる。
//
// 基準の版の根は、作業ツリーと同じ目印の規則（root.ts の isMarkerBy）で、同じ起点から基準の版の木を上へ辿って決め、
// 作業ツリーの根と位置が違えば止める。置き場は基準の版の .living-spec.json で読む（取り組みの中で表の置き場を移しても比べられる）。
// 木に渡すパスは全て git の作業ツリーの根からの相対。ls-tree は <path> を今いるディレクトリからの相対で読むので --full-tree を付け、
// 日本語のファイル名が引用されないよう -z で NUL 区切りに読む。cat-file は <コミット>:<パス> で渡す（パスを ./ で始めない）。
// 木（tree）をディレクトリ、それ以外の項（通常のファイル・シンボリックリンク・submodule の参照）をファイルとして扱い、リンク先を辿らない。
// 読む位置の項が通常のファイル（ディレクトリ）でないか、読む位置の途中の祖先が木でないか、読む位置が git の作業ツリーの根の外を
// 指せば、黙って「無い」にせず止める。
import { spawnSync } from 'node:child_process';
import { posix, relative, sep } from 'node:path';
import { isMarkerBy } from './root.ts';
import { CONFIG_FILE, parseLayout } from './schema.ts';
import { type SourceReader, type Sources, readSourcesFrom } from './sources.ts';

export interface BaseVersion {
  // 利用者が指定した版の文字列
  ref: string;
  // 版が指すコミット
  commit: string;
  // 基準の版の木から、その版の置き場の設定どおりに読んだ表・要求票・例
  sources: Sources;
}

// 基準の版を読めないときの誤り。入口がこの型だけを捕えて終了コード 2 で止める
export class BaseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'BaseError';
  }
}

// 木の一覧と表・要求票・例の中身が収まる大きさ
const MAX_BUFFER = 256 * 1024 * 1024;
const TREE_MODE = '040000';
const REGULAR_MODES = ['100644', '100755'];

interface GitResult {
  status: number | null;
  stdout: string;
  stderr: string;
}

// git を -C <根> で起動する。起動できなければ BaseError。
// --literal-pathspecs: : で始まる名前を pathspec の魔法として読ませず、パスを字面どおりに渡す
function runGit(root: string, args: string[]): GitResult {
  const result = spawnSync('git', ['--literal-pathspecs', '-C', root, ...args], { encoding: 'utf8', maxBuffer: MAX_BUFFER });
  if (result.error !== undefined) {
    const code = (result.error as NodeJS.ErrnoException).code;
    throw new BaseError(`基準の版を読めない: git を実行できない（${typeof code === 'string' ? code : result.error.message}）`);
  }
  return { status: result.status, stdout: result.stdout, stderr: result.stderr };
}

// 終了コードが 0 でなければ例外（読み出しの段で BaseError に包む）
function gitOut(root: string, args: string[]): string {
  const result = runGit(root, args);
  if (result.status !== 0) throw new Error(`git ${args[0]} が失敗した（${result.stderr.trim() || `終了コード ${result.status}`}）`);
  return result.stdout;
}

// 木の中の項の在り方。blocked は途中の祖先 at が木でない（mode はその祖先の mode）。リンク先を辿らないので、その下は読めない
type Lookup = { kind: 'found'; mode: string } | { kind: 'absent' } | { kind: 'blocked'; at: string; mode: string };

// 基準の版の木。パスは git の作業ツリーの根からの相対で、最上段は ''
interface Tree {
  lookup(path: string): Lookup;
  // 項の mode。無ければ（途中が木でないときも）undefined。目印の判定と表の置き場の有無に使う
  modeAt(path: string): string | undefined;
  // 木 dir の直下の項の名前 → mode
  children(dir: string): Map<string, string>;
}

function treeOf(root: string, commit: string): Tree {
  const listings = new Map<string, Map<string, string>>();
  const children = (dir: string): Map<string, string> => {
    const cached = listings.get(dir);
    if (cached !== undefined) return cached;
    const head = dir === '' ? '' : `${dir}/`;
    const out = gitOut(root, ['ls-tree', '--full-tree', '-z', commit, ...(dir === '' ? [] : ['--', head])]);
    const items = new Map<string, string>();
    for (const record of out.split('\0')) {
      if (record === '') continue;
      // <mode> SP <type> SP <object> TAB <パス>。-z ではパスを引用しない
      const m = /^(\d{6}) [^ ]+ [0-9a-f]+\t(.+)$/s.exec(record);
      const name = m === null || !m[2].startsWith(head) ? '' : m[2].slice(head.length);
      if (m === null || name === '' || name.includes('/')) throw new Error(`git ls-tree の出力を読めない: ${JSON.stringify(record)}`);
      items.set(name, m[1]);
    }
    listings.set(dir, items);
    return items;
  };
  const lookup = (path: string): Lookup => {
    if (path === '') return { kind: 'found', mode: TREE_MODE };
    const slash = path.lastIndexOf('/');
    const parent = slash < 0 ? '' : path.slice(0, slash);
    const up = lookup(parent);
    if (up.kind !== 'found') return up;
    if (up.mode !== TREE_MODE) return { kind: 'blocked', at: parent, mode: up.mode };
    const mode = children(parent).get(path.slice(slash + 1));
    return mode === undefined ? { kind: 'absent' } : { kind: 'found', mode };
  };
  const modeAt = (path: string): string | undefined => {
    const found = lookup(path);
    return found.kind === 'found' ? found.mode : undefined;
  };
  return { lookup, modeAt, children };
}

// git の作業ツリーの根からの相対へ直す（最上段は ''）。prefix は根の位置、rel は根からの相対。
// 作業ツリーの側の join(根, 値) と同じく、値の先頭の / は根からの相対として読む。git の作業ツリーの根の外へ出れば '..' で始まる
function treePath(prefix: string, rel: string): string {
  const path = posix.join(prefix === '' ? '.' : prefix, rel).replace(/\/+$/, '');
  return path === '.' ? '' : path;
}

function isOutside(path: string): boolean {
  return path === '..' || path.startsWith('../');
}

function shown(path: string): string {
  return path === '' ? '.' : path;
}

// 起点 from（git の作業ツリーの根からの相対）から、基準の版の木を git の作業ツリーの根まで上へ辿り、最も近い目印の位置を返す
function findBaseRoot(tree: Tree, from: string): string | undefined {
  let dir = from;
  for (;;) {
    const base = dir;
    const marker = isMarkerBy((segments) => {
      const mode = tree.modeAt([base, ...segments].filter((s) => s !== '').join('/'));
      return mode === undefined ? undefined : mode === TREE_MODE ? 'dir' : 'file';
    });
    if (marker) return dir;
    if (dir === '') return undefined;
    const slash = dir.lastIndexOf('/');
    dir = slash < 0 ? '' : dir.slice(0, slash);
  }
}

// 基準の版の根（git の作業ツリーの根からの位置 prefix）の読み手。パスは根からの相対で受ける（SourceReader の約束）。
// 通常のファイルでない項を読む位置、途中の祖先が木でない位置、git の作業ツリーの根の外を指す位置では例外を投げ、
// 黙って「無い」にしない（票・例の置き場が黙って空になると、作業ツリーの全ての票・例に「足された」が付く）。
// 根の外は、表の置き場と同じく木を読めない位置として止める。根の中で項が無いだけなら「無い」とする
function treeReader(tree: Tree, root: string, commit: string, prefix: string): SourceReader {
  // 読む位置の項の mode。無ければ undefined。what は、理由の文面で読む位置を呼ぶ語
  const modeToRead = (path: string, what: string): string | undefined => {
    if (isOutside(path)) throw new Error(`git の作業ツリーの根の外を指す${what}: ${path}`);
    const found = tree.lookup(path);
    if (found.kind === 'blocked') throw new Error(`途中が木でない位置: ${shown(path)}（${found.at} は mode ${found.mode}）`);
    return found.kind === 'found' ? found.mode : undefined;
  };
  return {
    readFile: (rel) => {
      const path = treePath(prefix, rel);
      const mode = modeToRead(path, '位置');
      if (mode === undefined) return undefined;
      if (!REGULAR_MODES.includes(mode)) throw new Error(`通常のファイルでない項: ${shown(path)}（mode ${mode}）`);
      return gitOut(root, ['cat-file', 'blob', `${commit}:${path}`]);
    },
    listFiles: (relDir) => {
      const path = treePath(prefix, relDir);
      const mode = modeToRead(path, '置き場');
      if (mode === undefined) return [];
      if (mode !== TREE_MODE) throw new Error(`ディレクトリでない項: ${shown(path)}（mode ${mode}）`);
      return [...tree.children(path)].filter(([, m]) => m !== TREE_MODE).map(([name]) => name);
    },
  };
}

// f が投げた BaseError 以外の例外を、message の文面の BaseError に包む
function guard<T>(f: () => T, message: (reason: string) => string): T {
  try {
    return f();
  } catch (e) {
    if (e instanceof BaseError) throw e;
    throw new BaseError(message((e as Error).message));
  }
}

// root は作業ツリーで決まった正本の根、start はその根を決めた探索の起点のディレクトリ（どちらも絶対パス）。
// 基準の版を読めなければ BaseError を投げる
export function readBase(root: string, start: string, ref: string): BaseVersion {
  const top = runGit(root, ['rev-parse', '--show-prefix']);
  if (top.status !== 0) {
    // git の標準エラーの1行目を理由として添える（safe.directory の所有者の不一致や壊れたリポジトリを、管理下に無いことと見分ける）
    const reason = top.stderr.split('\n')[0].trim();
    throw new BaseError(`基準の版を読めない: 根が git の作業ツリーの中に無い（根: ${root}）${reason === '' ? '' : `: ${reason}`}`);
  }
  // git の作業ツリーの根から見た根の位置。起点の相対は、これと字面の relative(根, 起点) から組む
  // （git が返す絶対パスはシンボリックリンクを解いているので、字面の根と混ぜない）
  const prefix = top.stdout.replace(/\n$/, '').replace(/\/+$/, '');
  const resolved = runGit(root, ['rev-parse', '--verify', '--quiet', `${ref}^{commit}`]);
  if (resolved.status !== 0) throw new BaseError(`基準の版が見つからない: ${ref}（根: ${root}）`);
  const commit = resolved.stdout.trim();
  const tree = treeOf(root, commit);
  const unreadable = (reason: string) => `基準の版 ${ref} の正本を読めない（根: ${root}）: ${reason}`;

  const from = treePath(prefix, relative(root, start).split(sep).join('/'));
  const found = guard(() => findBaseRoot(tree, from), unreadable);
  if (found === undefined) throw new BaseError(`基準の版 ${ref} に正本の根が無い（起点: ${shown(from)}。根: ${root}）`);
  if (found !== prefix) {
    throw new BaseError(
      `基準の版 ${ref} と作業ツリーで正本の根の置き場が異なる（作業ツリー: ${shown(prefix)}、基準の版: ${shown(found)}。根: ${root}）`,
    );
  }

  const reader = treeReader(tree, root, commit, prefix);
  const layout = guard(
    () => parseLayout(reader.readFile(CONFIG_FILE)),
    (reason) => `基準の版 ${ref} の ${CONFIG_FILE} を読めない（根: ${root}）: ${reason}`,
  );
  const tables = treePath(prefix, layout.tables);
  if (isOutside(tables) || guard(() => tree.modeAt(tables), unreadable) !== TREE_MODE) {
    throw new BaseError(`基準の版 ${ref} に表の置き場が無い: ${shown(tables)}（根: ${root}）`);
  }
  const sources = guard(() => readSourcesFrom(reader, layout), unreadable);
  return { ref, commit, sources };
}
