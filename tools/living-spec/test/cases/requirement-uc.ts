import { t } from './case.ts';
import type { Case } from './case.ts';

const UC_TABLE = {
  'docs/rdra/use-case.yaml': t`
    - UC: 経費申請を取り下げる
  `,
};

// 表題の UC 名が要求票ごとに表から引ける通常の票が1件。表題の判定に行は要らないので、仕様節は空にする
const TITLE_ONLY = t`
  # 要求票: 経費申請を取り下げる

  ## 仕様
`;

export const cases: Case[] = [
  // 表題の UC 名が UC の表にあれば通る
  {
    name: 'pass-title-in-uc-table',
    files: { ...UC_TABLE, 'docs/requirements/withdraw.md': TITLE_ONLY },
    expected: [],
  },
  // HTML コメントの中の偽の表題・偽の仕様の行は読まない（コメントの後ろの本物の表題・行は読む）
  {
    name: 'pass-html-comment-ignored',
    files: {
      'docs/rdra/actor.yaml': t`
        - アクター: 従業員
          役割: 経費を申請する
          社内外: 社内
      `,
      'docs/rdra/condition.yaml': t`
        - 条件: 取り下げられる条件
          条件の説明: 経費申請が提出済みのときだけ取り下げられる
          状態モデル: 経費申請の状態
      `,
      'docs/rdra/state.yaml': t`
        - 状態モデル: 経費申請の状態
          状態: 提出済み
          遷移UC: 経費申請を取り下げる
          遷移先状態: 作成中
        - 状態モデル: 経費申請の状態
          状態: 作成中
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を取り下げる
          アクター:
            - 従業員
          条件:
            - 取り下げられる条件
      `,
      'docs/requirements/withdraw.md': t`
        <!-- # 要求票: 存在しない UC -->
        # 要求票: 経費申請を取り下げる

        ## 理由

        従業員が提出を誤ったとき、提出先が処理を始める前なら出し直せるようにする。

        ## 仕様

        <!-- 注記。コメントの中は読まない
             1. 偽の仕様の行
                - RDRA: 条件「存在しない条件」
        -->

        1. 従業員が経費申請を取り下げるとき、システムは経費申請を作成中へ戻し、前回提出した内容を残さない
           - RDRA: アクター「従業員」、状態「経費申請の状態/作成中」
           - 理由: なし
        2. 取り下げられる条件を満たさないならば、システムは取り下げを受け付けない
           - RDRA: 条件「取り下げられる条件」
           - 理由: なし
      `,
    },
    expected: [],
  },
  // 同じ UC の要求票が2つあれば、両方の票に出る
  {
    name: 'fail-duplicate-uc',
    files: {
      ...UC_TABLE,
      'docs/requirements/withdraw.md': TITLE_ONLY,
      'docs/requirements/withdraw-copy.md': TITLE_ONLY,
    },
    expected: [
      { rule: 'requirement-uc', file: 'docs/requirements/withdraw.md', target: 'UC:経費申請を取り下げる' },
      { rule: 'requirement-uc', file: 'docs/requirements/withdraw-copy.md', target: 'UC:経費申請を取り下げる' },
    ],
  },
  // 表題「# 要求票:」の後ろの UC 名が空なら、UC 名を取れない
  {
    name: 'fail-title-uc-name-empty',
    files: {
      ...UC_TABLE,
      'docs/requirements/untitled.md': t`
        # 要求票:

        ## 仕様
      `,
    },
    expected: [{ rule: 'requirement-uc', file: 'docs/requirements/untitled.md', target: '表題' }],
  },
  // 表題に「要求票:」のラベルが無ければ、UC 名を取れない
  {
    name: 'fail-title-without-label',
    files: {
      ...UC_TABLE,
      'docs/requirements/untitled.md': t`
        # 経費申請を取り下げる

        ## 仕様
      `,
    },
    expected: [{ rule: 'requirement-uc', file: 'docs/requirements/untitled.md', target: '表題' }],
  },
  // 表題の UC 名が UC の表に無ければ出る
  {
    name: 'fail-uc-not-in-table',
    files: {
      ...UC_TABLE,
      'docs/requirements/other.md': t`
        # 要求票: 経費申請を削除する

        ## 仕様
      `,
    },
    expected: [{ rule: 'requirement-uc', file: 'docs/requirements/other.md', target: 'UC:経費申請を削除する' }],
  },
];
