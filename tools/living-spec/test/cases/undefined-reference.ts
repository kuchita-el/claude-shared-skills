import { t } from './case.ts';
import type { Case } from './case.ts';

const ref = (file: string, target: string) => [{ rule: 'undefined-reference', file, target }];

export const cases: Case[] = [
  // 参照がすべて表に定義されていれば通る
  {
    name: 'pass-all-resolved',
    files: {
      'docs/rdra/actor.yaml': t`
        - アクター: 従業員
      `,
      'docs/rdra/condition.yaml': t`
        - 条件: 提出可能
          バリエーション: 費目
          状態モデル: 経費申請の状態
      `,
      'docs/rdra/external-system.yaml': t`
        - 外部システム: 会計システム
      `,
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
          関連情報: 経費
          状態モデル: 経費申請の状態
          バリエーション: 費目
        - 情報: 経費
      `,
      'docs/rdra/state.yaml': t`
        - 状態モデル: 経費申請の状態
          遷移UC: 経費申請を作成する
          遷移先状態: 作成中
        - 状態モデル: 経費申請の状態
          状態: 作成中
          遷移UC: 経費申請を提出する
          遷移先状態: 提出済
        - 状態モデル: 経費申請の状態
          状態: 提出済
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
        - UC: 経費申請を提出する
      `,
      'docs/rdra/variation.yaml': t`
        - バリエーション: 費目
          値: 交通費、宿泊費
      `,
    },
    expected: [],
  },
  // 、区切りの複数の値（バリエーション・関連情報）がすべて定義されていれば通る
  {
    name: 'pass-comma-separated-multi-valued',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
          関連情報: 経費、部門
          バリエーション: 費目、消費税の区分
        - 情報: 経費
        - 情報: 部門
      `,
      'docs/rdra/variation.yaml': t`
        - バリエーション: 費目
          値: 交通費、宿泊費
        - バリエーション: 消費税の区分
          値: 課税、非課税
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          情報:
            - 経費申請
            - 経費
            - 部門
      `,
    },
    expected: [],
  },
  // 他の状態モデルに同じ名前の状態があっても、遷移先状態は自分の状態モデル内で解決され通る
  {
    name: 'pass-state-in-other-model-same-name',
    files: {
      'docs/rdra/state.yaml': t`
        - 状態モデル: 経費申請の状態
          状態: 作成中
          遷移UC: 経費申請を提出する
          遷移先状態: 提出済
        - 状態モデル: 経費申請の状態
          状態: 提出済
        - 状態モデル: 取り下げの状態
          状態: 作成中
          遷移UC: 経費申請を提出する
          遷移先状態: 取り下げ済
        - 状態モデル: 取り下げの状態
          状態: 取り下げ済
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を提出する
      `,
    },
    expected: [],
  },
  // 条件の状態モデルに、定義の無い状態モデルを書くと落ちる
  {
    name: 'fail-condition-state-model',
    files: {
      'docs/rdra/condition.yaml': t`
        - 条件: 提出可能
          状態モデル: 経費申請の状態、存在しない状態モデル
      `,
      'docs/rdra/state.yaml': t`
        - 状態モデル: 経費申請の状態
          状態: 作成中
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          条件:
            - 提出可能
      `,
    },
    expected: ref('docs/rdra/condition.yaml', '条件:提出可能'),
  },
  // 条件のバリエーションに、定義の無いバリエーションを書くと落ちる
  {
    name: 'fail-condition-variation',
    files: {
      'docs/rdra/condition.yaml': t`
        - 条件: 提出可能
          バリエーション: 費目、存在しないバリエーション
      `,
      'docs/rdra/variation.yaml': t`
        - バリエーション: 費目
          値: 交通費、宿泊費
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          条件:
            - 提出可能
      `,
    },
    expected: ref('docs/rdra/condition.yaml', '条件:提出可能'),
  },
  // 情報の関連情報に、定義の無い情報を書くと落ちる
  {
    name: 'fail-information-related',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
          関連情報: 経費、存在しない情報
        - 情報: 経費
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          情報:
            - 経費申請
            - 経費
      `,
    },
    expected: ref('docs/rdra/information.yaml', '情報:経費申請'),
  },
  // 情報の状態モデルに、定義の無い状態モデルを書くと落ちる
  {
    name: 'fail-information-state-model',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
          状態モデル: 経費申請の状態、存在しない状態モデル
      `,
      'docs/rdra/state.yaml': t`
        - 状態モデル: 経費申請の状態
          状態: 作成中
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          情報:
            - 経費申請
      `,
    },
    expected: ref('docs/rdra/information.yaml', '情報:経費申請'),
  },
  // 情報のバリエーションに、定義の無いバリエーションを書くと落ちる
  {
    name: 'fail-information-variation',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
          バリエーション: 費目、存在しないバリエーション
      `,
      'docs/rdra/variation.yaml': t`
        - バリエーション: 費目
          値: 交通費、宿泊費
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          情報:
            - 経費申請
      `,
    },
    expected: ref('docs/rdra/information.yaml', '情報:経費申請'),
  },
  // 遷移先状態が、別の状態モデルにだけ定義されている状態だと落ちる（自分の状態モデル内で解決されない）
  {
    name: 'fail-state-next-state-in-other-model',
    files: {
      'docs/rdra/state.yaml': t`
        - 状態モデル: 経費申請の状態
          状態: 作成中
          遷移UC: 経費申請を提出する
          遷移先状態: 取り下げ済
        - 状態モデル: 取り下げの状態
          状態: 取り下げ済
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を提出する
      `,
    },
    expected: ref('docs/rdra/state.yaml', '状態:経費申請の状態／作成中'),
  },
  // 遷移先状態が、どの状態モデルにも定義の無い状態だと落ちる
  {
    name: 'fail-state-next-state',
    files: {
      'docs/rdra/state.yaml': t`
        - 状態モデル: 経費申請の状態
          状態: 作成中
          遷移UC: 経費申請を提出する
          遷移先状態: 存在しない状態
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を提出する
      `,
    },
    expected: ref('docs/rdra/state.yaml', '状態:経費申請の状態／作成中'),
  },
  // 遷移UC に、定義の無い UC を書くと落ちる
  {
    name: 'fail-state-transition-uc',
    files: {
      'docs/rdra/state.yaml': t`
        - 状態モデル: 経費申請の状態
          状態: 作成中
          遷移UC: 存在しないUC
          遷移先状態: 作成中
      `,
    },
    expected: ref('docs/rdra/state.yaml', '状態:経費申請の状態／作成中'),
  },
  // UC のアクターに、定義の無いアクターを書くと落ちる
  {
    name: 'fail-uc-actor',
    files: {
      'docs/rdra/actor.yaml': t`
        - アクター: 従業員
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          アクター:
            - 従業員
            - 存在しないアクター
      `,
    },
    expected: ref('docs/rdra/use-case.yaml', 'UC:経費申請を作成する'),
  },
  // UC の条件に、定義の無い条件を書くと落ちる
  {
    name: 'fail-uc-condition',
    files: {
      'docs/rdra/condition.yaml': t`
        - 条件: 提出可能
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          条件:
            - 提出可能
            - 存在しない条件
      `,
    },
    expected: ref('docs/rdra/use-case.yaml', 'UC:経費申請を作成する'),
  },
  // UC の外部システムに、定義の無い外部システムを書くと落ちる
  {
    name: 'fail-uc-external-system',
    files: {
      'docs/rdra/external-system.yaml': t`
        - 外部システム: 会計システム
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を提出する
          外部システム:
            - 会計システム
            - 存在しない外部システム
      `,
    },
    expected: ref('docs/rdra/use-case.yaml', 'UC:経費申請を提出する'),
  },
  // UC の情報に、定義の無い情報を書くと落ちる
  {
    name: 'fail-uc-information',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          情報:
            - 経費申請
            - 存在しない情報
      `,
    },
    expected: ref('docs/rdra/use-case.yaml', 'UC:経費申請を作成する'),
  },
];
