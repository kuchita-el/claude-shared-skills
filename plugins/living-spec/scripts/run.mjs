// living-spec の検査器を探して呼ぶ中継。依存を持たない。検査器そのものはプラグインに含めず、利用者が GitHub Release の添付物を取って入れる。
// 使い方: node run.mjs check [--doc-missing | --open] [起点] | node run.mjs render [--base <版>] [起点] | node run.mjs diff --base <版> [起点] | node run.mjs hook
// 検査器を探す順:
//   1. 環境変数 LIVING_SPEC_BIN（取った living-spec-<SHA>.mjs のパス）
//   2. 解決の起点から解決できるパッケージ @kuchita-el/living-spec（開発者がリポジトリへ npm i -D で入れたもの）の bin
// 解決の起点は hook なら CLAUDE_PROJECT_DIR（無ければ今の作業ディレクトリ）、それ以外は今の作業ディレクトリ。
// 正本の根（検査器が起点から決める）とは別のもの。
// 見つかれば引数と標準入力をそのまま渡し、検査器の終了コードで終わる（前提より古い検査器の扱いは下）。
// 見つからなければ、hook は何もせず終了コード 0（検査器を入れていないリポジトリの編集を止めない）。
// それ以外は導入の手順を標準エラーへ出して終了コード 2。
// 見つかった検査器がプラグインの前提より古いか（下の REQUIRED_COMPAT）を、呼ぶ前に `compat` で問う。
// 世代を持たない版の検査器も古いものとして扱う（checkerCompat）。古ければ:
//   hook 以外: 検査器の出力より前に staleNotice の1行を標準エラーへ出し、検査器を呼んだうえで、その終了コードによらず終了コード 2。
//     古い検査器は新しい必須の検査を見ないので、違反が0件でも合格とみなさない。
//   hook: 検査器のフックが検査したとき（範囲内の編集。印は hookProbe）か、検査器が 0 以外で終わったときだけ、staleNotice の1行を出して終了コード 2。
//     検査せず 0 で終わるとき（範囲外の編集・表の置き場が無い・hook が false 等）は、出力も終了コードも検査器のまま。範囲の判定は検査器が持ち、中継は写さない。
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const PACKAGE = '@kuchita-el/living-spec';

// プラグインの手順・書式が前提とする検査器の互換の世代。検査器が `compat` で答える値がこれより小さければ古い。
// 検査器の側の世代と同じ値に保つ。版番号ではない（版はコミット SHA が担う）
const REQUIRED_COMPAT = 5;

const INSTALL = `living-spec の検査器が見つからない。次の2段で入れる:
  1. 使う版のコミット SHA（40桁）を https://github.com/kuchita-el/claude-shared-skills/releases から選び、添付物を取る:
     curl -fsSL --create-dirs -o ~/.local/share/living-spec/living-spec-<SHA>.mjs https://github.com/kuchita-el/claude-shared-skills/releases/download/living-spec-<SHA>/living-spec-<SHA>.mjs
  2. エージェント（Claude Code・Codex 等）を起動するシェルで、環境変数 LIVING_SPEC_BIN に取ったファイルのパスを入れる`;

// 利用者が開く導入の節。配布元での置き場と、入れたプラグインでの実際の置き場を並べる
const README = join(dirname(fileURLToPath(import.meta.url)), '..', 'README.md');

function staleNotice(actual) {
  return `living-spec の検査器が、このプラグインの前提より古い（検査器の互換の世代: ${actual ?? 'なし'}、前提: ${REQUIRED_COMPAT}）。古い規則による結果なので合格とみなさない。plugins/living-spec/README.md（このプラグインでは ${README}）の「検査器の導入」の節に従い、検査器を最新の Release へ上げる`;
}

// 検査器の互換の世代。世代を持たない版（compat を知らず、使い方を出して終了コード 2）と、答えが非負の整数の1行でない検査器は null。
// compat を起動できない・使い方を出さずに失敗した検査器は undefined。古いとは判定せず、そのまま呼んで本来の失敗を見せる
// （取り損ねたファイル等を「古い」と誤って示し、最新の Release を入れた利用者に更新を迫らないため）
function checkerCompat(checker) {
  const r = spawnSync(process.execPath, [checker, 'compat'], { stdio: ['ignore', 'pipe', 'pipe'], encoding: 'utf8' });
  if (r.error || r.signal) return undefined;
  if (r.status === 0) {
    const m = /^(\d+)\n?$/.exec(r.stdout);
    return m ? Number(m[1]) : null;
  }
  if (r.status === 2 && r.stderr.includes('使い方: living-spec')) return null;
  return undefined;
}

// 古い検査器のフックへ先に読み込ませるモジュールの URL。フックが検査した印を次の3つとする。
//   描き直しのファイルの書き込み（mkdirSync・writeFileSync）。範囲内の編集で検査したフックは、合否によらず描き直す
//   描き直しの失敗の文面（RENDER_FAILED）。描き直しは書き込みの前に失敗しうる
//   0 以外の終了コード。古い検査器が止めた理由（知らない設定のキー等）は、古いこと自体でありうる
// 印を見た時点で notice を標準エラーへ出し、終わるときの終了コードを 2 にする。印が無ければ出力も終了コードも検査器のまま
const RENDER_FAILED = '設計の可視化を描けない';
function hookProbe(notice) {
  const code = `import fs from 'node:fs';
import { syncBuiltinESMExports } from 'node:module';
const notice = ${JSON.stringify(`${notice}\n`)};
const write = process.stderr.write.bind(process.stderr);
let seen = false;
const mark = () => {
  if (seen) return;
  seen = true;
  write(notice);
};
for (const name of ['mkdirSync', 'writeFileSync']) {
  const original = fs[name];
  fs[name] = (...a) => { mark(); return original(...a); };
}
syncBuiltinESMExports();
process.stderr.write = (chunk, ...rest) => {
  if (String(chunk).includes(${JSON.stringify(RENDER_FAILED)})) mark();
  return write(chunk, ...rest);
};
process.on('exit', (code) => {
  if (code !== 0) mark();
  if (seen) process.exitCode = 2;
});
`;
  return `data:text/javascript,${encodeURIComponent(code)}`;
}

function findChecker(searchFrom) {
  const fromEnv = process.env.LIVING_SPEC_BIN;
  if (fromEnv) return existsSync(fromEnv) ? resolve(fromEnv) : null;
  try {
    const manifest = createRequire(join(searchFrom, 'package.json')).resolve(`${PACKAGE}/package.json`);
    const { bin } = JSON.parse(readFileSync(manifest, 'utf8'));
    const rel = typeof bin === 'string' ? bin : bin?.['living-spec'];
    if (typeof rel !== 'string') return null;
    const path = join(dirname(manifest), rel);
    return existsSync(path) ? path : null;
  } catch {
    return null;
  }
}

const args = process.argv.slice(2);
const isHook = args[0] === 'hook';
const searchFrom = resolve(isHook ? process.env.CLAUDE_PROJECT_DIR || process.cwd() : process.cwd());
const checker = findChecker(searchFrom);
if (checker === null) {
  if (isHook) process.exit(0);
  process.stderr.write(`${INSTALL}\n`);
  process.exit(2);
}
const compat = checkerCompat(checker);
const stale = compat === null || (compat !== undefined && compat < REQUIRED_COMPAT);
const nodeArgs = stale && isHook ? ['--import', hookProbe(staleNotice(compat))] : [];
if (stale && !isHook) process.stderr.write(`${staleNotice(compat)}\n`);
const result = spawnSync(process.execPath, [...nodeArgs, checker, ...args], { stdio: 'inherit' });
if (result.error) {
  process.stderr.write(`living-spec の検査器を起動できない（${result.error.message}）\n`);
  process.exit(2);
}
process.exit(stale && !isHook ? 2 : (result.status ?? 2));
