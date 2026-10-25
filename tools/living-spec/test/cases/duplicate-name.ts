import { t } from './case.ts';
import type { Case } from './case.ts';

const dup = (file: string, target: string) => [{ rule: 'duplicate-name', file, target }];

export const cases: Case[] = [
  // 別の表なら同じ名前（条件とバリエーションの 提出可能）でも通る
  {
    name: 'pass-same-name-different-tables',
    files: {
      'docs/rdra/condition.yaml': t`
        - 条件: 提出可能
      `,
      'docs/rdra/variation.yaml': t`
        - バリエーション: 提出可能
          値: 可、不可
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          条件:
            - 提出可能
      `,
    },
    expected: [],
  },
  // 同じ状態モデル・状態でも、遷移UC が違う行どうしなら重複にならず通る
  {
    name: 'pass-state-same-pair-different-uc',
    files: {
      'docs/rdra/state.yaml': t`
        - 状態モデル: 経費申請の状態
          状態: 作成中
          遷移UC: 経費申請を提出する
          遷移先状態: 提出済
        - 状態モデル: 経費申請の状態
          状態: 作成中
          遷移UC: 経費申請を破棄する
          遷移先状態: 破棄済
        - 状態モデル: 経費申請の状態
          状態: 提出済
        - 状態モデル: 経費申請の状態
          状態: 破棄済
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を提出する
        - UC: 経費申請を破棄する
      `,
    },
    expected: [],
  },
  // 同じ名前のアクターが2行あると落ちる
  {
    name: 'fail-actor',
    files: {
      'docs/rdra/actor.yaml': t`
        - アクター: 従業員
        - アクター: 従業員
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          アクター:
            - 従業員
      `,
    },
    expected: dup('docs/rdra/actor.yaml', 'アクター:従業員'),
  },
  // 同じ名前のアーキテクチャ特性が2行あると落ちる
  {
    name: 'fail-architecture-characteristic',
    files: {
      'docs/rdra/architecture-characteristic.yaml': t`
        - アーキテクチャ特性: 監査可能性
        - アーキテクチャ特性: 監査可能性
      `,
    },
    expected: dup('docs/rdra/architecture-characteristic.yaml', 'アーキテクチャ特性:監査可能性'),
  },
  // 同じ名前の条件が2行あると落ちる
  {
    name: 'fail-condition',
    files: {
      'docs/rdra/condition.yaml': t`
        - 条件: 提出可能
        - 条件: 提出可能
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          条件:
            - 提出可能
      `,
    },
    expected: dup('docs/rdra/condition.yaml', '条件:提出可能'),
  },
  // 同じ名前の外部システムが2行あると落ちる
  {
    name: 'fail-external-system',
    files: {
      'docs/rdra/external-system.yaml': t`
        - 外部システム: 会計システム
        - 外部システム: 会計システム
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          外部システム:
            - 会計システム
      `,
    },
    expected: dup('docs/rdra/external-system.yaml', '外部システム:会計システム'),
  },
  // 同じ名前の情報が2行あると落ちる
  {
    name: 'fail-information',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費
        - 情報: 経費
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          情報:
            - 経費
      `,
    },
    expected: dup('docs/rdra/information.yaml', '情報:経費'),
  },
  // 同じ状態モデルの終端の状態（遷移UC なし）が2行あると落ちる
  {
    name: 'fail-state-terminal',
    files: {
      'docs/rdra/state.yaml': t`
        - 状態モデル: 経費申請の状態
          状態: 提出済
        - 状態モデル: 経費申請の状態
          状態: 提出済
      `,
    },
    expected: dup('docs/rdra/state.yaml', '状態:経費申請の状態／提出済'),
  },
  // 状態モデル・状態・遷移UC・遷移先状態が全て同じ行が2つあると落ちる
  {
    name: 'fail-state-triple',
    files: {
      'docs/rdra/state.yaml': t`
        - 状態モデル: 経費申請の状態
          状態: 作成中
          遷移UC: 経費申請を提出する
          遷移先状態: 提出済
        - 状態モデル: 経費申請の状態
          状態: 作成中
          遷移UC: 経費申請を提出する
          遷移先状態: 提出済
        - 状態モデル: 経費申請の状態
          状態: 提出済
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を提出する
      `,
    },
    expected: dup('docs/rdra/state.yaml', '状態:経費申請の状態／作成中'),
  },
  // 同じ名前の UC が2行あると落ちる
  {
    name: 'fail-use-case',
    files: {
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を提出する
        - UC: 経費申請を提出する
      `,
    },
    expected: dup('docs/rdra/use-case.yaml', 'UC:経費申請を提出する'),
  },
  // 同じ名前のバリエーションが2行あると落ちる
  {
    name: 'fail-variation',
    files: {
      'docs/rdra/variation.yaml': t`
        - バリエーション: 費目
          値: 交通費、宿泊費
        - バリエーション: 費目
          値: 交通費、宿泊費
      `,
    },
    expected: dup('docs/rdra/variation.yaml', 'バリエーション:費目'),
  },
];
