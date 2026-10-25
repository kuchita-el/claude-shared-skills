import { t } from './case.ts';
import type { Case } from './case.ts';

const S1 = '従業員が経費申請を取り下げるとき、システムは経費申請を作成中へ戻し、前回提出した内容を残さない';
const S2 = '取り下げられる条件を満たさないならば、システムは取り下げを受け付けない';

const ACTOR = {
  'docs/rdra/actor.yaml': t`
    - アクター: 従業員
      役割: 経費を申請する
      社内外: 社内
  `,
};
const CONDITION = {
  'docs/rdra/condition.yaml': t`
    - 条件: 取り下げられる条件
      条件の説明: 経費申請が提出済みのときだけ取り下げられる
      状態モデル: 経費申請の状態
  `,
};
// 取り下げる UC が「作成中」を遷移先にする
const STATE = {
  'docs/rdra/state.yaml': t`
    - 状態モデル: 経費申請の状態
      状態: 提出済み
      遷移UC: 経費申請を取り下げる
      遷移先状態: 作成中
    - 状態モデル: 経費申請の状態
      状態: 作成中
  `,
};
const WITHDRAW_UC = t`
  - UC: 経費申請を取り下げる
    アクター:
      - 従業員
    条件:
      - 取り下げられる条件
`;
// 票の行ごとに、同じ名前のルールを持つ機能（書き漏らしの検査で example-missing を出さないため）
const FEATURE = {
  'docs/examples/withdraw.feature': t`
    # language: ja
    機能: 経費申請を取り下げる

      ルール: ${S1}

      ルール: ${S2}
  `,
};
const TITLE = '# 要求票: 経費申請を取り下げる\n\n## 仕様\n\n';
const line = (n: number, sentence: string, rdra: string) => `${n}. ${sentence}\n   - RDRA: ${rdra}\n   - 理由: なし\n`;

export const cases: Case[] = [
  // UC の条件と遷移先状態が、どちらかの行の RDRA 欄に挙がっている
  {
    name: 'pass-condition-and-next-state-listed',
    files: {
      ...ACTOR,
      ...CONDITION,
      ...STATE,
      ...FEATURE,
      'docs/rdra/use-case.yaml': WITHDRAW_UC,
      'docs/requirements/withdraw.md':
        TITLE + line(1, S1, 'アクター「従業員」、状態「経費申請の状態/作成中」') + line(2, S2, '条件「取り下げられる条件」'),
    },
    expected: [],
  },
  // 『仮説』キーのある UC は、条件と遷移先状態を挙げていなくても検査しない（仕様の行が0件でも出ない）
  {
    name: 'pass-hypothesis-uc-not-checked',
    files: {
      ...CONDITION,
      ...STATE,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を取り下げる
          条件:
            - 取り下げられる条件
          仮説:
            - P01-1
      `,
      'docs/requirements/withdraw.md': TITLE,
    },
    expected: [],
  },
  // 別の UC（仮説キーあり）が遷移先にする状態は、この UC の票に挙げなくてよい
  {
    name: 'pass-other-uc-transition-not-required',
    files: {
      ...ACTOR,
      ...CONDITION,
      ...FEATURE,
      'docs/rdra/state.yaml': t`
        - 状態モデル: 経費申請の状態
          状態: 提出済み
          遷移UC: 経費申請を取り下げる
          遷移先状態: 作成中
        - 状態モデル: 経費申請の状態
          状態: 作成中
          遷移UC: 経費申請を提出する
          遷移先状態: 提出済み
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を取り下げる
          アクター:
            - 従業員
          条件:
            - 取り下げられる条件
        - UC: 経費申請を提出する
          仮説:
            - P01-1
      `,
      'docs/requirements/withdraw.md':
        TITLE + line(1, S1, 'アクター「従業員」、状態「経費申請の状態/作成中」') + line(2, S2, '条件「取り下げられる条件」'),
    },
    expected: [],
  },
  // UC の条件がどの行の RDRA 欄にも挙がっていない（条件の行の RDRA 欄が「なし」）
  {
    name: 'fail-condition-not-listed',
    files: {
      ...ACTOR,
      ...CONDITION,
      ...STATE,
      ...FEATURE,
      'docs/rdra/use-case.yaml': WITHDRAW_UC,
      'docs/requirements/withdraw.md':
        TITLE + line(1, S1, 'アクター「従業員」、状態「経費申請の状態/作成中」') + line(2, S2, 'なし'),
    },
    expected: [{ rule: 'requirement-coverage', file: 'docs/requirements/withdraw.md', target: '条件:取り下げられる条件' }],
  },
  // UC が遷移先にする状態がどの行の RDRA 欄にも挙がっていない
  {
    name: 'fail-next-state-not-listed',
    files: {
      ...ACTOR,
      ...CONDITION,
      ...STATE,
      ...FEATURE,
      'docs/rdra/use-case.yaml': WITHDRAW_UC,
      'docs/requirements/withdraw.md':
        TITLE + line(1, S1, 'アクター「従業員」') + line(2, S2, '条件「取り下げられる条件」'),
    },
    expected: [{ rule: 'requirement-coverage', file: 'docs/requirements/withdraw.md', target: '状態:経費申請の状態／作成中' }],
  },
  // 仕様の行が0件の票は、条件も遷移先状態も挙げていないので、両方が出る
  {
    name: 'fail-no-spec-lines',
    files: {
      ...CONDITION,
      ...STATE,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を取り下げる
          条件:
            - 取り下げられる条件
      `,
      'docs/requirements/withdraw.md': TITLE,
    },
    expected: [
      { rule: 'requirement-coverage', file: 'docs/requirements/withdraw.md', target: '条件:取り下げられる条件' },
      { rule: 'requirement-coverage', file: 'docs/requirements/withdraw.md', target: '状態:経費申請の状態／作成中' },
    ],
  },
];
