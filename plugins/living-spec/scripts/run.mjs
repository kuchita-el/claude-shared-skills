// living-spec の検査器を探して呼ぶ中継。依存を持たない。検査器そのものはプラグインに含めず、利用者がソースからビルドして入れる。
// 使い方: node run.mjs check [--doc-missing] [根] | node run.mjs render [根] | node run.mjs hook
// 検査器を探す順:
//   1. 環境変数 LIVING_SPEC_BIN（ビルドした dist/living-spec.mjs のパス）
//   2. 根から解決できるパッケージ @kuchita-el/living-spec（利用者のリポジトリへ npm i -D で入れたもの）の bin
// 根は hook なら CLAUDE_PROJECT_DIR（無ければ今の作業ディレクトリ）、それ以外は今の作業ディレクトリ。
// 見つかれば引数と標準入力をそのまま渡し、検査器の終了コードで終わる。
// 見つからなければ、hook は何もせず終了コード 0（検査器を入れていないリポジトリの編集を止めない）。
// それ以外は導入の手順を標準エラーへ出して終了コード 2。
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';

const PACKAGE = '@kuchita-el/living-spec';

const INSTALL = `living-spec の検査器が見つからない。次のどちらかで入れる:
  1. claude-shared-skills の tools/living-spec で pnpm install && pnpm build し、このリポジトリで npm i -D <claude-shared-skills>/tools/living-spec
  2. 環境変数 LIVING_SPEC_BIN に、ビルドした <claude-shared-skills>/tools/living-spec/dist/living-spec.mjs のパスを入れる`;

function findChecker(root) {
  const fromEnv = process.env.LIVING_SPEC_BIN;
  if (fromEnv) return existsSync(fromEnv) ? resolve(fromEnv) : null;
  try {
    const manifest = createRequire(join(root, 'package.json')).resolve(`${PACKAGE}/package.json`);
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
const root = resolve(isHook ? process.env.CLAUDE_PROJECT_DIR || process.cwd() : process.cwd());
const checker = findChecker(root);
if (checker === null) {
  if (isHook) process.exit(0);
  process.stderr.write(`${INSTALL}\n`);
  process.exit(2);
}
const result = spawnSync(process.execPath, [checker, ...args], { stdio: 'inherit' });
if (result.error) {
  process.stderr.write(`living-spec の検査器を起動できない（${result.error.message}）\n`);
  process.exit(2);
}
process.exit(result.status ?? 2);
