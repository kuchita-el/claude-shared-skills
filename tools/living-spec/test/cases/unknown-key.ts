import { t } from './case.ts';
import type { Case } from './case.ts';

export const cases: Case[] = [
  {
    name: 'pass-all-allowed-keys',
    files: {
      'docs/rdra/actor.yaml': t`
        - アクター: 従業員
          役割: 経費を申請する
          社内外: 社内
          仮説:
            - P01-2
      `,
      'docs/rdra/architecture-characteristic.yaml': t`
        - アーキテクチャ特性: 監査可能性
          分類: 運用
          説明: 操作を追跡できる
          検証方法: 履歴の照合
          仮説:
            - P01-2
      `,
      'docs/rdra/condition.yaml': t`
        - 条件: 提出可能
          条件の説明: 経費が1件以上ある
          バリエーション: 費目
          状態モデル: 経費申請の状態
          仮説:
            - P01-2
      `,
      'docs/rdra/external-system.yaml': t`
        - 外部システム: 会計システム
          役割: 仕訳を受け取る
          仮説:
            - P01-2
      `,
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
          属性: 申請日
          状態モデル: 経費申請の状態
          バリエーション: 費目
          説明: 申請の単位
          仮説:
            - P01-2
      `,
      'docs/rdra/state.yaml': t`
        - 状態モデル: 経費申請の状態
          遷移UC: 経費申請を作成する
          遷移先状態: 作成中
          状態モデル・状態の説明: 作成すると作成中になる
          仮説:
            - P01-2
        - 状態モデル: 経費申請の状態
          状態: 作成中
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          アクター:
            - 従業員
          外部システム:
            - 会計システム
          情報:
            - 経費申請
          条件:
            - 提出可能
          説明: 申請を作る
          仮説:
            - P01-2
      `,
      'docs/rdra/variation.yaml': t`
        - バリエーション: 費目
          値: 交通費、宿泊費
          説明: 経費の分類
          仮説:
            - P01-2
      `,
    },
    expected: [],
  },
  {
    name: 'fail-actor-extra-key',
    files: {
      'docs/rdra/actor.yaml': t`
        - アクター: 従業員
          役割: 経費を申請する
          メモ: 許されないキー
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          アクター:
            - 従業員
      `,
    },
    expected: [{ rule: 'unknown-key', file: 'docs/rdra/actor.yaml', target: 'アクター:従業員' }],
  },
  // 別の表のキー（情報の 属性）をバリエーションに書くと落ちる
  {
    name: 'fail-key-of-other-table',
    files: {
      'docs/rdra/variation.yaml': t`
        - バリエーション: 費目
          値: 交通費、宿泊費
          属性: 費目の属性
      `,
    },
    expected: [{ rule: 'unknown-key', file: 'docs/rdra/variation.yaml', target: 'バリエーション:費目' }],
  },
  // 状態の行に許されないキーがあると落ちる
  {
    name: 'fail-state-extra-key',
    files: {
      'docs/rdra/state.yaml': t`
        - 状態モデル: 経費申請の状態
          状態: 作成中
          備考: x
      `,
    },
    expected: [{ rule: 'unknown-key', file: 'docs/rdra/state.yaml', target: '状態:経費申請の状態／作成中' }],
  },
  // UC に許されないキーがあると落ちる
  {
    name: 'fail-use-case-extra-key',
    files: {
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を提出する
          優先度: 高
      `,
    },
    expected: [{ rule: 'unknown-key', file: 'docs/rdra/use-case.yaml', target: 'UC:経費申請を提出する' }],
  },
  // UC に画面要求のキーを書くと落ちる（UC の表のキーではない）
  {
    name: 'fail-use-case-screen-requirement',
    files: {
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を提出する
          画面要求: 申請の入力画面
      `,
    },
    expected: [{ rule: 'unknown-key', file: 'docs/rdra/use-case.yaml', target: 'UC:経費申請を提出する' }],
  },
];
