import { t } from './case.ts';
import type { Case } from './case.ts';

const rule1 = '従業員が経費申請を取り下げるとき、システムは経費申請を作成中へ戻し、前回提出した内容を残さない';
const rule2 = '取り下げられる条件を満たさないならば、システムは取り下げを受け付けない';

const ucTable = t`
  - UC: 経費申請を取り下げる
`;

const twoRulesFeature = t`
  # language: ja
  機能: 経費申請を取り下げる

    ルール: ${rule1}

      シナリオ: 提出済みの経費申請を取り下げる
        前提 経費申請が提出済みである
        もし 従業員が経費申請を取り下げる
        ならば 経費申請は作成中に戻る

    ルール: ${rule2}

      シナリオ: 作成中の経費申請は取り下げられない
        前提 経費申請が作成中である
        もし 従業員が経費申請を取り下げる
        ならば 取り下げは受け付けられない
`;

const twoLinesRequirement = t`
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

export const cases: Case[] = [
  // 要求票の UC に対応する機能が例に無く、要求文に対応するルールが無い
  {
    name: 'fail-feature-missing-for-requirement',
    files: {
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を提出する
      `,
      'docs/requirements/submit.md': t`
        # 要求票: 経費申請を提出する

        ## 理由

        なし

        ## 仕様

        1. 従業員が経費申請を提出するとき、システムは提出先へ出す
           - RDRA: なし
           - 理由: なし
      `,
    },
    expected: [{ rule: 'example-missing', file: 'docs/requirements/submit.md', target: '仕様:1' }],
  },
  // 同じ UC の機能に、要求票の3行目の要求文と同じ名前のルールが無い
  {
    name: 'fail-requirement-line-without-rule',
    files: {
      'docs/rdra/use-case.yaml': ucTable,
      'docs/requirements/withdraw.md': t`
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
        3. システムは取り下げを記録する
           - RDRA: なし
           - 理由: なし
      `,
      'docs/examples/withdraw.feature': twoRulesFeature,
    },
    expected: [{ rule: 'example-missing', file: 'docs/requirements/withdraw.md', target: '仕様:3' }],
  },
  // 要求票の全行に同じ名前のルールがあれば通る
  {
    name: 'pass-every-line-has-rule',
    files: {
      'docs/rdra/use-case.yaml': ucTable,
      'docs/requirements/withdraw.md': twoLinesRequirement,
      'docs/examples/withdraw.feature': twoRulesFeature,
    },
    expected: [],
  },
];
