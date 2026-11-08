// git を使う CLI 試験の共用部。一時ディレクトリに本物の git のリポジトリを作り、基準の版をコミットする。
// git と検査器には、手元の利用者の設定（署名・既定のブランチ名・リポジトリを指す GIT_ の環境変数）に結果が左右されない環境を渡す。
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, realpathSync } from 'node:fs';
import { devNull, tmpdir } from 'node:os';
import { join } from 'node:path';

export const gitEnv: NodeJS.ProcessEnv = {
  ...Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('GIT_'))),
  GIT_CONFIG_GLOBAL: devNull,
  GIT_CONFIG_NOSYSTEM: '1',
  GIT_AUTHOR_NAME: 'living-spec',
  GIT_AUTHOR_EMAIL: 'living-spec@example.invalid',
  GIT_COMMITTER_NAME: 'living-spec',
  GIT_COMMITTER_EMAIL: 'living-spec@example.invalid',
};

// git を起動して標準出力を返す。失敗したら落とす
export function git(dir: string, ...args: string[]): string {
  const result = spawnSync('git', args, { cwd: dir, env: gitEnv, encoding: 'utf8' });
  assert.equal(result.status, 0, `git ${args.join(' ')}: ${result.error?.message ?? result.stderr}`);
  return result.stdout;
}

// シンボリックリンクを解いた一時ディレクトリに、git のリポジトリを作る
export function gitRepo(): string {
  const dir = realpathSync(mkdtempSync(join(tmpdir(), 'living-spec-base-')));
  git(dir, 'init', '-q', '-b', 'main');
  return dir;
}

// 作業ツリーの全てを基準の版としてコミットする
export function commitAll(dir: string): void {
  git(dir, 'add', '-A');
  git(dir, '-c', 'commit.gpgsign=false', 'commit', '-q', '-m', 'base');
}
