import { t } from './case.ts';
import type { Case } from './case.ts';

const ucTable = t`
  - UC: 経費申請を取り下げる
`;

const rule1 = '従業員が経費申請を取り下げるとき、システムは経費申請を作成中へ戻し、前回提出した内容を残さない';
const rule2 = '取り下げられる条件を満たさないならば、システムは取り下げを受け付けない';

const requirement1 = t`
  # 要求票: 経費申請を取り下げる

  ## 理由

  なし

  ## 仕様

  1. ${rule1}
     - RDRA: なし
     - 理由: なし
`;

const requirement2 = t`
  # 要求票: 経費申請を取り下げる

  ## 理由

  なし

  ## 仕様

  1. ${rule1}
     - RDRA: なし
     - 理由: なし
  2. ${rule2}
     - RDRA: なし
     - 理由: なし
`;

// ルールの下に置く2つのシナリオ（ルール1・ルール2のそれぞれ用）
const scenario1 = t`
  シナリオ: 提出済みの経費申請を取り下げる
    前提 経費申請が提出済みである
    もし 従業員が経費申請を取り下げる
    ならば 経費申請は作成中に戻る
`;

const scenario2 = t`
  シナリオ: 作成中の経費申請は取り下げられない
    前提 経費申請が作成中である
    もし 従業員が経費申請を取り下げる
    ならば 取り下げは受け付けられない
`;

// ルール1つ分（ルール行と、その下に字下げしたシナリオ）
const ruleBlock = (name: string, scenario: string) =>
  `  ルール: ${name}\n\n` +
  scenario
    .split('\n')
    .map((l) => (l === '' ? l : `    ${l}`))
    .join('\n');

const header = '# language: ja\n機能: 経費申請を取り下げる\n\n';

export const cases: Case[] = [
  // 要求票が無い UC の機能にルールがあると、対応する要求文が無いことが出る
  {
    name: 'fail-requirement-missing-for-feature',
    files: {
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を提出する
      `,
      'docs/examples/submit.feature': t`
        # language: ja
        機能: 経費申請を提出する

          ルール: 従業員が経費申請を提出するとき、システムは提出先へ出す

            シナリオ: 提出する
              前提 経費申請が作成中である
              もし 従業員が経費申請を提出する
              ならば 経費申請は提出済みになる
      `,
    },
    expected: [
      {
        rule: 'example-rule-mismatch',
        file: 'docs/examples/submit.feature',
        target: 'ルール:従業員が経費申請を提出するとき、システムは提出先へ出す',
      },
    ],
  },
  // ルールの名前が要求文を言い換えていると、一致しないルールが出る
  {
    name: 'fail-rule-name-reworded',
    files: {
      'docs/rdra/use-case.yaml': ucTable,
      'docs/requirements/withdraw.md': requirement2,
      'docs/examples/withdraw.feature':
        header + ruleBlock(rule1, scenario1) + '\n' + ruleBlock('取り下げられる条件を満たさないとき、システムは取り下げを受け付けない', scenario2),
    },
    expected: [
      {
        rule: 'example-rule-mismatch',
        file: 'docs/examples/withdraw.feature',
        target: 'ルール:取り下げられる条件を満たさないとき、システムは取り下げを受け付けない',
      },
    ],
  },
  // 要求票に対応する行が無いルールが、余分なルールとして出る
  {
    name: 'fail-rule-without-requirement-line',
    files: {
      'docs/rdra/use-case.yaml': ucTable,
      'docs/requirements/withdraw.md': requirement2,
      'docs/examples/withdraw.feature':
        header +
        ruleBlock(rule1, scenario1) +
        '\n' +
        ruleBlock(rule2, scenario2) +
        '\n' +
        ruleBlock(
          'システムは取り下げを記録する',
          t`
            シナリオ: 記録する
              前提 経費申請が提出済みである
              もし 従業員が取り下げの記録を見る
              ならば 記録が残っている
          `,
        ),
    },
    expected: [
      {
        rule: 'example-rule-mismatch',
        file: 'docs/examples/withdraw.feature',
        target: 'ルール:システムは取り下げを記録する',
      },
    ],
  },
  // ルールの外（機能の直下）に置いたシナリオが出る
  {
    name: 'fail-scenario-outside-rule',
    files: {
      'docs/rdra/use-case.yaml': ucTable,
      'docs/requirements/withdraw.md': requirement1,
      'docs/examples/withdraw.feature':
        header +
        t`
          シナリオ: ルールの外の例
            前提 経費申請が提出済みである
            もし 従業員が取り下げの画面を開く
            ならば 取り下げの確認が出る
        `.replace(/^/gm, '  ') +
        '\n' +
        ruleBlock(rule1, scenario1),
    },
    expected: [
      { rule: 'example-rule-mismatch', file: 'docs/examples/withdraw.feature', target: 'シナリオ:ルールの外の例' },
    ],
  },
  // ルールの並びが要求票の行の並びと違っても、名前が一致すれば通る
  {
    name: 'pass-rule-order-differs',
    files: {
      'docs/rdra/use-case.yaml': ucTable,
      'docs/requirements/withdraw.md': requirement2,
      'docs/examples/withdraw.feature': header + ruleBlock(rule2, scenario2) + '\n' + ruleBlock(rule1, scenario1),
    },
    expected: [],
  },
];
