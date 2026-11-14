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
  // 『仮説』キーを持つレコードは、どの UC からも参照されなくても判定しない（4種とも）。キーの値が空でも仮説として扱う
  {
    name: 'pass-hypothesis-records',
    files: {
      'docs/rdra/actor.yaml': t`
        - アクター: 監査人
          仮説:
            - H1
      `,
      'docs/rdra/condition.yaml': t`
        - 条件: 監査できる
          仮説: []
      `,
      'docs/rdra/external-system.yaml': t`
        - 外部システム: 監査システム
          仮説:
            - H1
      `,
      'docs/rdra/information.yaml': t`
        - 情報: 監査記録
          仮説:
            - H1
      `,
    },
    expected: [],
  },
  // 上の件のレコードから『仮説』キーを外すと、4種とも落ちる
  {
    name: 'fail-hypothesis-key-removed',
    files: {
      'docs/rdra/actor.yaml': t`
        - アクター: 監査人
      `,
      'docs/rdra/condition.yaml': t`
        - 条件: 監査できる
      `,
      'docs/rdra/external-system.yaml': t`
        - 外部システム: 監査システム
      `,
      'docs/rdra/information.yaml': t`
        - 情報: 監査記録
      `,
    },
    expected: [
      ...un('docs/rdra/actor.yaml', 'アクター:監査人'),
      ...un('docs/rdra/condition.yaml', '条件:監査できる'),
      ...un('docs/rdra/external-system.yaml', '外部システム:監査システム'),
      ...un('docs/rdra/information.yaml', '情報:監査記録'),
    ],
  },
  // 仮説のレコードを外すのはそのレコードだけで、同じ表の事実のレコードの未接続は従来どおり落ちる
  {
    name: 'fail-fact-beside-hypothesis',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 監査記録
          仮説:
            - H1
        - 情報: 孤立した情報
      `,
    },
    expected: un('docs/rdra/information.yaml', '情報:孤立した情報'),
  },
  // 仮説の UC からだけ参照される事実のレコードは、参照されているとして通る（仮説の UC からの参照も参照に数える）
  {
    name: 'pass-fact-referenced-only-by-hypothesis-uc',
    files: {
      'docs/rdra/actor.yaml': t`
        - アクター: 従業員
      `,
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を一括で取り込む
          仮説:
            - H2
          アクター:
            - 従業員
          情報:
            - 経費申請
      `,
    },
    expected: [],
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
  // 集約の子は、どの UC からも直接参照されなくても、親が UC から参照されていれば通る（孫も親を辿って同じく）
  {
    name: 'pass-aggregate-child-via-parent',
    files: {
      'docs/rdra/information.yaml': t`
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
  // 孫を子より前に、子を親より前に並べても通る（接続は表の並び順によらず、親を辿り切って決める）
  {
    name: 'pass-aggregate-child-before-parent',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 領収書の画像
          集約の親: 経費明細
        - 情報: 経費明細
          集約の親: 経費申請
        - 情報: 経費申請
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          情報:
            - 経費申請
      `,
    },
    expected: [],
  },
  // 子を UC に併せて挙げても通る（親と子の両方を書いた形）
  {
    name: 'pass-aggregate-child-also-on-uc',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
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
    expected: [],
  },
  // 親が仮説のレコードでも、UC から参照されていれば子は接続している
  {
    name: 'pass-aggregate-parent-hypothesis-on-uc',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
          仮説:
            - H1
        - 情報: 経費明細
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
  // 仮説の情報が間に入っても、その親が UC から参照されていれば、仮説の情報を通して孫は接続している
  {
    name: 'pass-aggregate-hypothesis-between',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
        - 情報: 経費明細
          集約の親: 経費申請
          仮説:
            - H1
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
  // 上の件から根の UC からの参照を外すと、仮説の情報は判定しないが、事実の根と孫は落ちる
  {
    name: 'fail-aggregate-hypothesis-between-unconnected',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
        - 情報: 経費明細
          集約の親: 経費申請
          仮説:
            - H1
        - 情報: 領収書の画像
          集約の親: 経費明細
        - 情報: 従業員
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 従業員を登録する
          情報:
            - 従業員
      `,
    },
    expected: [...un('docs/rdra/information.yaml', '情報:経費申請'), ...un('docs/rdra/information.yaml', '情報:領収書の画像')],
  },
  // 空白だけの集約の親は書いていないものとみなし、独立した情報として UC からの参照を求める
  {
    name: 'fail-aggregate-parent-blank',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
        - 情報: 経費明細
          集約の親: "  "
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          情報:
            - 経費申請
      `,
    },
    expected: un('docs/rdra/information.yaml', '情報:経費明細'),
  },
  // 親がどの UC からも参照されなければ、親と子（孫も）の両方が落ちる
  {
    name: 'fail-aggregate-parent-unconnected',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
        - 情報: 経費明細
          集約の親: 経費申請
        - 情報: 領収書の画像
          集約の親: 経費明細
        - 情報: 従業員
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 従業員を登録する
          情報:
            - 従業員
      `,
    },
    expected: [
      ...un('docs/rdra/information.yaml', '情報:経費申請'),
      ...un('docs/rdra/information.yaml', '情報:経費明細'),
      ...un('docs/rdra/information.yaml', '情報:領収書の画像'),
    ],
  },
  // 子が UC から参照されていても、親は子から接続しない（接続は親から子への向きだけ）。孫は子を辿って接続する
  {
    name: 'fail-aggregate-parent-not-connected-by-child',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
        - 情報: 経費明細
          集約の親: 経費申請
        - 情報: 領収書の画像
          集約の親: 経費明細
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費明細を直す
          情報:
            - 経費明細
      `,
    },
    expected: un('docs/rdra/information.yaml', '情報:経費申請'),
  },
  // 仮説の親がどの UC からも参照されなければ、親は判定しないが、事実の子は落ちる
  {
    name: 'fail-aggregate-parent-hypothesis-unconnected',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
          仮説:
            - H1
        - 情報: 経費明細
          集約の親: 経費申請
      `,
    },
    expected: un('docs/rdra/information.yaml', '情報:経費明細'),
  },
  // 集約の子が関連情報で指すだけの、集約の子でない情報は落ちる（関連情報では接続しない）
  {
    name: 'fail-related-of-aggregate-child',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
        - 情報: 経費明細
          集約の親: 経費申請
          関連情報: 費目
        - 情報: 費目
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          情報:
            - 経費申請
      `,
    },
    expected: un('docs/rdra/information.yaml', '情報:費目'),
  },
];
