// 対象が根の範囲の内か外かの判定と、範囲外の注記。フックと CLI が同じ関数で判定する。
// 範囲内: 対象がディレクトリとして在れば、いずれかの置き場が対象の中にあるとき（対象が置き場そのものか、それを含むとき）。
//   そうでなければ、対象の親がいずれかの置き場と一致するか、対象が根の .living-spec.json と一致するとき。
// 候補: 起動した場所が根の下にあり（根と同じでない）、対象が起動した場所の中にあり、どの置き場も起動した場所の中に無く、
//   起動した場所がどの置き場の中にも無いとき、起動した場所を、対象の領域を独立した正本にするときの根の候補とする。
// パスは絶対化したものを字面のまま比べる。置き場の絶対パスは join(根, 値)。
import { dirname, join } from 'node:path';
import { PLACEMENT_KEYS, type PlacementKey, isWithin, statIfExists } from './root.ts';
import { CONFIG_FILE, DEFAULT_LAYOUT, type Layout } from './schema.ts';

export type Scope =
  // 対象が無い（CLI の引数なし）
  | { kind: 'none' }
  | { kind: 'in' }
  // candidate は候補の絶対パス。候補が無ければ null
  | { kind: 'out'; candidate: string | null };

// root・launch（起動した場所）・target は絶対パスで渡す。target がディレクトリとして在るかはここで見る。
// 読み取りの失敗は RootSearchError を投げる
export function classifyTarget(
  root: string,
  layout: Pick<Layout, PlacementKey>,
  launch: string,
  target: string | undefined,
): Scope {
  if (target === undefined) return { kind: 'none' };
  const placements = PLACEMENT_KEYS.map((key) => join(root, layout[key]));
  const inScope =
    statIfExists(target)?.isDirectory() === true
      ? placements.some((p) => isWithin(p, target))
      : placements.includes(dirname(target)) || target === join(root, CONFIG_FILE);
  if (inScope) return { kind: 'in' };
  const candidate =
    launch !== root &&
    isWithin(launch, root) &&
    isWithin(target, launch) &&
    !placements.some((p) => isWithin(p, launch)) &&
    !placements.some((p) => isWithin(launch, p))
      ? launch
      : null;
  return { kind: 'out', candidate };
}

export function formatScopeNote(
  root: string,
  layout: Pick<Layout, PlacementKey>,
  target: string,
  candidate: string | null,
): string {
  const values = PLACEMENT_KEYS.map((key) => layout[key]).join('・');
  const second =
    candidate === null
      ? '根にするディレクトリは決められない。どこを根にするかを決める'
      : `候補: ${candidate}。ここに ${CONFIG_FILE} を置くか ${DEFAULT_LAYOUT.tables} を作る`;
  return [
    `注記: ${target} は根 ${root} の置き場（${values}）の外にある。検査は根 ${root} に掛けた。扱いは次の2つ:`,
    `  1. ${target} を根の置き場へ移す`,
    `  2. ${target} の領域を独立した正本にする（${second}）`,
  ].join('\n');
}
