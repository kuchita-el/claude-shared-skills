import { t } from './case.ts';
import type { Case } from './case.ts';

const rule1 = '従業員が経費申請を取り下げるとき、システムは経費申請を作成中へ戻し、前回提出した内容を残さない';

const target = { rule: 'example-syntax', file: 'docs/examples/withdraw.feature', target: '構文' };

export const cases: Case[] = [
  // 例の表の行ごとに列の数が違うと、Gherkin として読めない
  {
    name: 'fail-inconsistent-table-cells',
    files: {
      'docs/examples/withdraw.feature': t`
        # language: ja
        機能: 経費申請を取り下げる

          ルール: ${rule1}

            シナリオアウトライン: 取り下げの例
              前提 経費申請が提出済みで内容が<件数>件である
              もし 従業員が経費申請を取り下げる
              ならば 経費申請は作成中に戻り内容が<件数>件残らない

              例:
                | 件数 | 備考 |
                | 1 | a |
                | 2 |
      `,
    },
    expected: [target],
  },
  // 先頭に「# language: ja」が無いと、日本語のキーワードを読めない
  {
    name: 'fail-no-language-header',
    files: {
      'docs/examples/withdraw.feature': t`
        機能: 経費申請を取り下げる

          ルール: ${rule1}

            シナリオ: 提出済みの経費申請を取り下げる
              前提 経費申請が提出済みである
              もし 従業員が経費申請を取り下げる
              ならば 経費申請は作成中に戻る
      `,
    },
    expected: [target],
  },
  // 「# language: ja」の下で、日本語のキーワード（機能・ルール・シナリオ・前提・もし・ならば）が読めれば通る
  {
    name: 'pass-japanese-keywords',
    files: {
      'docs/rdra/use-case.yaml': '- UC: 経費申請を取り下げる\n',
      'docs/requirements/withdraw.md': t`
        # 要求票: 経費申請を取り下げる

        ## 理由

        なし

        ## 仕様

        1. ${rule1}
           - RDRA: なし
           - 理由: なし
      `,
      'docs/examples/withdraw.feature': t`
        # language: ja
        機能: 経費申請を取り下げる

          ルール: ${rule1}

            シナリオ: 提出済みの経費申請を取り下げる
              前提 経費申請が提出済みである
              もし 従業員が経費申請を取り下げる
              ならば 経費申請は作成中に戻る
      `,
    },
    expected: [],
  },
];
