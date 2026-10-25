import { t } from './case.ts';
import type { Case } from './case.ts';

const rule1 = '従業員が経費申請を取り下げるとき、システムは経費申請を作成中へ戻し、前回提出した内容を残さない';

const files = (rules: string) => ({
  'docs/rdra/use-case.yaml': '- UC: 経費申請を取り下げる\n',
  'docs/requirements/withdraw.md': t`
    # 要求票: 経費申請を取り下げる

    ## 仕様

    1. ${rule1}
       - RDRA: なし
       - 理由: なし
  `,
  'docs/examples/withdraw.feature': `# language: ja\n機能: 経費申請を取り下げる\n\n  ルール: ${rule1}\n\n${rules}`,
});

const scenarios = (from: number, to: number): string => {
  let s = '';
  for (let n = from; n <= to; n++) {
    s += t`
          シナリオ: 提出済みの経費申請を取り下げる例${n}
            前提 経費申請が提出済みで内容が${n}件である
            もし 従業員が経費申請を取り下げる
            ならば 経費申請は作成中に戻り内容が${n}件残らない
    `.replace(/^/gm, '    ');
    s += '\n';
  }
  return s;
};

const outline = (rows: number[]): string =>
  t`
    シナリオアウトライン: 取り下げの例
      前提 経費申請が提出済みで内容が<件数>件である
      もし 従業員が経費申請を取り下げる
      ならば 経費申請は作成中に戻り内容が<件数>件残らない

      例:
        | 件数 | 備考 |
  `
    .replace(/^(?=.)/gm, '    ') +
  rows.map((n, i) => `        | ${n} | ${'abcd'[i]} |\n`).join('');

const target = { rule: 'example-limit', file: 'docs/examples/withdraw.feature', target: `ルール:${rule1}` };

export const cases: Case[] = [
  // シナリオが4件あると、1つのルールの例が上限（3件）を超える
  { name: 'fail-four-scenarios', files: files(scenarios(1, 4)), expected: [target] },
  // アウトラインの例の表の本体が4行あると、4件に数えて上限を超える
  { name: 'fail-outline-four-rows', files: files(outline([1, 2, 3, 4])), expected: [target] },
  // シナリオ1件とアウトライン3行を合わせた4件が、ルール内の合計として上限を超える
  {
    name: 'fail-scenario-and-outline-total',
    files: files(scenarios(1, 1) + '\n' + outline([2, 3, 4])),
    expected: [target],
  },
  // アウトラインの例の表の本体が3行なら、上限ちょうどで通る
  { name: 'pass-outline-three-rows', files: files(outline([1, 2, 3])), expected: [] },
  // シナリオが3件なら、上限ちょうどで通る
  { name: 'pass-three-scenarios', files: files(scenarios(1, 3)), expected: [] },
];
