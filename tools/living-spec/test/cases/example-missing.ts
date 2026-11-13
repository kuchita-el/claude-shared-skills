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

// 2行目の要求文を、RDRA 欄だけ替えて置く。1行目は同名のルールを持つ。2行目のルールは置かない
const listRule = '従業員が経費申請の一覧を開くとき、システムはその従業員の経費申請だけを表示する';
const listFiles = (rdra: string) => ({
  'docs/rdra/actor.yaml': t`
    - アクター: 従業員
  `,
  'docs/rdra/information.yaml': t`
    - 情報: 経費申請
  `,
  'docs/rdra/architecture-characteristic.yaml': t`
    - アーキテクチャ特性: 応答性
      検証方法: 1万件の経費申請を置いた負荷試験で、一覧表示の95パーセンタイルが2秒以内であることを測る
    - アーキテクチャ特性: 可用性
      検証方法: 業務時間中の停止時間を月ごとに測る
  `,
  'docs/rdra/use-case.yaml': t`
    - UC: 経費申請の一覧を見る
      アクター:
        - 従業員
      情報:
        - 経費申請
  `,
  'docs/requirements/list.md': t`
    # 要求票: 経費申請の一覧を見る

    ## 理由

    なし

    ## 仕様

    1. ${listRule}
       - RDRA: アクター「従業員」、情報「経費申請」
       - 理由: なし
    2. システムは常に経費申請の一覧を2秒以内に表示する
       - RDRA: ${rdra}
       - 理由: なし
  `,
  'docs/examples/list.feature': t`
    # language: ja
    機能: 経費申請の一覧を見る

      ルール: ${listRule}

        シナリオ: 他の従業員の経費申請は一覧に出ない
          前提 従業員Aの経費申請と従業員Bの経費申請がある
          もし 従業員Aが経費申請の一覧を開く
          ならば 従業員Aの経費申請だけが表示される
  `,
});
const missingLine2 = [{ rule: 'example-missing', file: 'docs/requirements/list.md', target: '仕様:2' }];

export const cases: Case[] = [
  // RDRA 欄がアーキテクチャ特性だけの行は、ルールが無くても通る（合否は特性の『検証方法』が持つ）
  {
    name: 'pass-characteristic-only-line',
    files: listFiles('アーキテクチャ特性「応答性」'),
    expected: [],
  },
  // アーキテクチャ特性を2つ挙げても、特性だけなら通る
  {
    name: 'pass-characteristics-only-line',
    files: listFiles('アーキテクチャ特性「応答性」、アーキテクチャ特性「可用性」'),
    expected: [],
  },
  // 特性と他の要素を併せて挙げる行は、振る舞いを含むので落ちる
  {
    name: 'fail-characteristic-with-other-element',
    files: listFiles('アーキテクチャ特性「応答性」、情報「経費申請」'),
    expected: missingLine2,
  },
  // RDRA 欄が『なし』の行は落ちる
  {
    name: 'fail-no-reference-line',
    files: listFiles('なし'),
    expected: missingLine2,
  },
  // 特性だけを挙げる行から特性を外し、情報に替えた行は落ちる
  {
    name: 'fail-characteristic-replaced-with-information',
    files: listFiles('情報「経費申請」'),
    expected: missingLine2,
  },
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
