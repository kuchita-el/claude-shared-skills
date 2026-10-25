import { t } from './case.ts';
import type { Case } from './case.ts';

const ucTable = t`
  - UC: 経費申請を取り下げる
`;

const withdrawRule =
  '従業員が経費申請を取り下げるとき、システムは経費申請を作成中へ戻し、前回提出した内容を残さない';

const withdrawRequirement = t`
  # 要求票: 経費申請を取り下げる

  ## 理由

  なし

  ## 仕様

  1. ${withdrawRule}
     - RDRA: なし
     - 理由: なし
`;

const duplicateFeature = t`
  # language: ja
  機能: 経費申請を取り下げる
`;

export const cases: Case[] = [
  // 同じ UC の機能が2つのファイルにあると、両方のファイルが重複として出る
  {
    name: 'fail-duplicate-feature-across-files',
    files: {
      'docs/rdra/use-case.yaml': ucTable,
      'docs/examples/withdraw.feature': duplicateFeature,
      'docs/examples/withdraw-copy.feature': duplicateFeature,
    },
    expected: [
      { rule: 'example-feature', file: 'docs/examples/withdraw.feature', target: '機能:経費申請を取り下げる' },
      { rule: 'example-feature', file: 'docs/examples/withdraw-copy.feature', target: '機能:経費申請を取り下げる' },
    ],
  },
  // 機能の名前が空で、中にルールとルール外のシナリオがあっても、機能名の空だけが出る
  {
    name: 'fail-name-empty-with-rules',
    files: {
      'docs/examples/other.feature': t`
        # language: ja
        機能:

          ルール: 名前の無い機能の中のルール

            シナリオ: 名前の無い機能の中の例
              前提 何かがある
              もし 何かをする
              ならば 何かが起きる

          シナリオ: ルールの外の例
            前提 何かがある
            もし 別の何かをする
            ならば 別の何かが起きる
      `,
    },
    expected: [{ rule: 'example-feature', file: 'docs/examples/other.feature', target: '機能:（名前なし）' }],
  },
  // 機能の名前が空
  {
    name: 'fail-name-empty',
    files: {
      'docs/examples/other.feature': t`
        # language: ja
        機能:
      `,
    },
    expected: [{ rule: 'example-feature', file: 'docs/examples/other.feature', target: '機能:（名前なし）' }],
  },
  // 機能名が UC の表に無い
  {
    name: 'fail-name-not-in-uc-table',
    files: {
      'docs/rdra/use-case.yaml': ucTable,
      'docs/examples/other.feature': t`
        # language: ja
        機能: 経費申請を削除する
      `,
    },
    expected: [{ rule: 'example-feature', file: 'docs/examples/other.feature', target: '機能:経費申請を削除する' }],
  },
  // 注記だけで機能が無いファイルは、機能が無いことが出る
  {
    name: 'fail-no-feature',
    files: {
      'docs/examples/empty.feature': '# 注記だけで機能が無い\n',
    },
    expected: [{ rule: 'example-feature', file: 'docs/examples/empty.feature', target: '機能' }],
  },
  // 例のファイル名が要求票のファイル名と違っても、機能名が UC に対応していれば通る
  {
    name: 'pass-file-name-differs-from-requirement',
    files: {
      'docs/rdra/use-case.yaml': ucTable,
      'docs/requirements/withdraw.md': withdrawRequirement,
      'docs/examples/anything.feature': t`
        # language: ja
        機能: 経費申請を取り下げる

          ルール: ${withdrawRule}

            シナリオ: 提出済みの経費申請を取り下げる
              前提 経費申請が提出済みである
              もし 従業員が経費申請を取り下げる
              ならば 経費申請は作成中に戻る
      `,
    },
    expected: [],
  },
];
