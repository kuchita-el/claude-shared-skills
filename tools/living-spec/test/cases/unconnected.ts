import { t } from './case.ts';
import type { Case } from './case.ts';

const un = (file: string, target: string) => [{ rule: 'unconnected', file, target }];

export const cases: Case[] = [
  // アクター・条件・外部システム・情報がどれも UC から参照されていれば通る
  {
    name: 'pass-all-connected',
    files: {
      'docs/rdra/actor.yaml': t`
        - アクター: 従業員
      `,
      'docs/rdra/condition.yaml': t`
        - 条件: 提出可能
      `,
      'docs/rdra/external-system.yaml': t`
        - 外部システム: 会計システム
      `,
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
          関連情報: 経費
        - 情報: 経費
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          アクター:
            - 従業員
          外部システム:
            - 会計システム
          情報:
            - 経費申請
            - 経費
          条件:
            - 提出可能
      `,
    },
    expected: [],
  },
  // どの UC にも参照されないアクターは落ちる
  {
    name: 'fail-actor',
    files: {
      'docs/rdra/actor.yaml': t`
        - アクター: 孤立したアクター
      `,
    },
    expected: un('docs/rdra/actor.yaml', 'アクター:孤立したアクター'),
  },
  // どの UC にも参照されない条件は落ちる
  {
    name: 'fail-condition',
    files: {
      'docs/rdra/condition.yaml': t`
        - 条件: 孤立した条件
      `,
    },
    expected: un('docs/rdra/condition.yaml', '条件:孤立した条件'),
  },
  // どの UC にも参照されない外部システムは落ちる
  {
    name: 'fail-external-system',
    files: {
      'docs/rdra/external-system.yaml': t`
        - 外部システム: 孤立した外部システム
      `,
    },
    expected: un('docs/rdra/external-system.yaml', '外部システム:孤立した外部システム'),
  },
  // 関連情報として他の情報から参照されるだけで UC から参照されない情報は落ちる
  {
    name: 'fail-information-only-via-related',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
          関連情報: 経費
        - 情報: 経費
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          情報:
            - 経費申請
      `,
    },
    expected: un('docs/rdra/information.yaml', '情報:経費'),
  },
  // どの UC にも参照されない情報は落ちる
  {
    name: 'fail-information',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 孤立した情報
      `,
    },
    expected: un('docs/rdra/information.yaml', '情報:孤立した情報'),
  },
];
