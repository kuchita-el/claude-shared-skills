// RDRA の表・要求票・例から、状態遷移図と UC ごとの縦串を1つの HTML（<根>/<LAYOUT.output>）へ描く。
// 違反があっても描く（検査は check.ts）。
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { renderHtml } from './html.ts';
import { LAYOUT } from './schema.ts';
import { buildView } from './view.ts';

// 描いて書き出し、書き出した場所を返す
export function writeView(root: string, now: Date = new Date()): string {
  const out = join(root, LAYOUT.output);
  const html = renderHtml(buildView(root), now);
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, html);
  return out;
}
