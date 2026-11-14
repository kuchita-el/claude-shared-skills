import { t } from './case.ts';
import type { Case } from './case.ts';

const INFO = 'docs/rdra/information.yaml';
const cyc = (...names: string[]) => names.map((n) => ({ rule: 'aggregate-cycle', file: INFO, target: `情報:${n}` }));

// 循環の件では、循環の上の情報を UC から直接参照し、unconnected が混ざらない入力にする
export const cases: Case[] = [
  // 親・子・孫と辿って、集約の親を持たない情報で終われば通る
  {
    name: 'pass-chain-ends-at-root',
    files: {
      [INFO]: t`
        - 情報: 経費申請
        - 情報: 経費明細
          集約の親: 経費申請
        - 情報: 領収書の画像
          集約の親: 経費明細
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          情報:
            - 経費申請
      `,
    },
    expected: [],
  },
  // 1つの親に子が複数あっても循環ではない
  {
    name: 'pass-siblings',
    files: {
      [INFO]: t`
        - 情報: 経費申請
        - 情報: 経費明細
          集約の親: 経費申請
        - 情報: 申請の添付
          集約の親: 経費申請
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          情報:
            - 経費申請
      `,
    },
    expected: [],
  },
  // 親が自身なら落ちる
  {
    name: 'fail-self-parent',
    files: {
      [INFO]: t`
        - 情報: 経費明細
          集約の親: 経費明細
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費明細を直す
          情報:
            - 経費明細
      `,
    },
    expected: cyc('経費明細'),
  },
  // 2つの情報が互いを親に挙げると、両方が落ちる
  {
    name: 'fail-two-cycle',
    files: {
      [INFO]: t`
        - 情報: 経費申請
          集約の親: 経費明細
        - 情報: 経費明細
          集約の親: 経費申請
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          情報:
            - 経費申請
            - 経費明細
      `,
    },
    expected: cyc('経費申請', '経費明細'),
  },
  // 3つの循環へ入るだけの情報（循環の上に無い）は出さず、循環の上の3つだけが1件ずつ落ちる
  {
    name: 'fail-three-cycle-with-tail',
    files: {
      [INFO]: t`
        - 情報: 甲
          集約の親: 乙
        - 情報: 乙
          集約の親: 丙
        - 情報: 丙
          集約の親: 甲
        - 情報: 丁
          集約の親: 甲
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 甲を扱う
          情報:
            - 甲
            - 乙
            - 丙
            - 丁
      `,
    },
    expected: cyc('甲', '乙', '丙'),
    counts: { '情報:甲': 1, '情報:乙': 1, '情報:丙': 1 },
  },
];
