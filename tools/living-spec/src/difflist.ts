// 差分（diff.ts の SpecDiff）の要素を、種類・区分の語・同一性の値のタブ区切りの1行にして返す。
// 行の形の正本は references/format.md の「一覧の行の形」で、ここはそれを実装する。比べ方・区分・並びは diff.ts が持ち、
// 一覧はその結果を読むだけである（要素の並びも diff.elements のまま）。
// 変わった欄の名前は出さない。一覧は「どの要素に印が付いたか」を示すもので、欄の違いは描き分け（render --base）が示す。
// 名前に含まれるタブ・改行は逃がさず、そのまま出す（決定論点）。逃がし方を決めると利用者が読み戻す手順が増えるのに、
// 名前にタブ・改行を含む要素は表・要求票・例の書式の上でまれなためである。
import type { SpecDiff } from './diff.ts';
import type { DiffStatus } from './view.ts';

const STATUS_WORD: Record<DiffStatus, string> = {
  added: '足された',
  changed: '変わった',
  removed: '外された',
};

// 無い値（初期遷移の元・終端の先・遷移 UC の無い記録・ルールの外）を表す語。列の数を保つために空にしない
const NONE = 'なし';

export function diffListLines(diff: SpecDiff): string[] {
  return diff.elements.map((e) => [e.kind, STATUS_WORD[e.status], ...e.identity.map((v) => v ?? NONE)].join('\t'));
}
