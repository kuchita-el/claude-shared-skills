// RDRA の表・要求票・例から、状態遷移図と UC ごとの縦串を1つの HTML（<根>/<LAYOUT.output>）へ描く。
// 違反があっても描く（検査は check.ts）。
// 基準の版との描き分け（writeDiffView）は、output の語幹に -diff を付けた別のファイルへ書き、output には触れない。
// フックが描き直すのは output だけなので、描き分けの HTML はフックの描き直しで上書きされない。
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, extname, join } from 'node:path';
import type { BaseVersion } from './base.ts';
import { buildDiffView } from './diffview.ts';
import { renderHtml } from './html.ts';
import { LAYOUT } from './schema.ts';
import { readSources } from './sources.ts';
import { buildView } from './view.ts';

// 描いて書き出し、書き出した場所を返す
export function writeView(root: string, now: Date = new Date()): string {
  const out = join(root, LAYOUT.output);
  const html = renderHtml(buildView(root), now);
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, html);
  return out;
}

// 描き分けの書き出し先（根からの相対）。output の語幹に -diff を付け、拡張子を保つ
// （.cache/living-spec/index.html → .cache/living-spec/index-diff.html、拡張子の無い out/view → out/view-diff）
export function diffOutputPath(output: string): string {
  const ext = extname(output);
  return `${output.slice(0, output.length - ext.length)}-diff${ext}`;
}

// 作業ツリー（コミット前の変更を含む）を基準の版と比べて描き分け、diffOutputPath(LAYOUT.output) へ書き出し、
// 書き出した場所を返す
export function writeDiffView(root: string, base: BaseVersion, now: Date = new Date()): string {
  const out = join(root, diffOutputPath(LAYOUT.output));
  const html = renderHtml(buildDiffView(root, base, readSources(root)), now);
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, html);
  return out;
}
