import { t } from './case.ts';
import type { Case } from './case.ts';

const AC = 'docs/rdra/architecture-characteristic.yaml';
const bad = (file: string, target: string) => [{ rule: 'invalid-shape', file, target }];

export const cases: Case[] = [
  // 表のファイルが空でも通る
  {
    name: 'pass-empty-file',
    files: { [AC]: '' },
    expected: [],
  },
  // 表のファイルが1つだけでも（他の表が無くても）通る
  {
    name: 'pass-only-one-table-file',
    files: {
      'docs/rdra/variation.yaml': t`
        - バリエーション: 費目
          値: 交通費、宿泊費
      `,
    },
    expected: [],
  },
  // 状態・遷移UC が空文字、遷移先状態が null でも（値が空なだけで）通る
  {
    name: 'pass-state-empty-values',
    files: {
      'docs/rdra/state.yaml': t`
        - 状態モデル: 経費申請の状態
          遷移UC: 経費申請を作成する
          遷移先状態: 作成中
          状態: ""
        - 状態モデル: 経費申請の状態
          状態: 作成中
          遷移UC: 経費申請を提出する
          遷移先状態: 提出済
        - 状態モデル: 経費申請の状態
          状態: 提出済
          遷移UC: ""
          遷移先状態: null
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
        - UC: 経費申請を提出する
      `,
    },
    expected: [],
  },
  // 仮説が配列でなく文字列だと落ちる
  {
    name: 'fail-hypothesis-not-list',
    files: {
      [AC]: t`
        - アーキテクチャ特性: 監査可能性
          仮説: P01-2
      `,
    },
    expected: bad(AC, 'アーキテクチャ特性:監査可能性'),
  },
  // 配列のキー（UC のアクター）が文字列だと落ちる
  {
    name: 'fail-list-key-got-string',
    files: {
      'docs/rdra/actor.yaml': t`
        - アクター: 従業員
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          アクター: 従業員
      `,
    },
    expected: bad('docs/rdra/use-case.yaml', 'UC:経費申請を作成する'),
  },
  // 配列に文字列でない要素（数値 5）があると落ちる
  {
    name: 'fail-list-with-non-string-item',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
        - 情報: 経費
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          情報:
            - 経費申請
            - 経費
            - 5
      `,
    },
    expected: bad('docs/rdra/use-case.yaml', 'UC:経費申請を作成する'),
  },
  // 名前が空文字だと落ちる（名前の代わりに行番号 #1 で指す）
  {
    name: 'fail-name-empty',
    files: {
      [AC]: t`
        - アーキテクチャ特性: ""
          分類: 運用
      `,
    },
    expected: bad(AC, 'アーキテクチャ特性:#1'),
  },
  // 名前のキーが無い行は落ちる
  {
    name: 'fail-name-missing',
    files: {
      [AC]: t`
        - 分類: 運用
      `,
    },
    expected: bad(AC, 'アーキテクチャ特性:#1'),
  },
  // 名前が文字列でなく数値だと落ちる
  {
    name: 'fail-name-not-string',
    files: {
      [AC]: t`
        - アーキテクチャ特性: 123
      `,
    },
    expected: bad(AC, 'アーキテクチャ特性:#1'),
  },
  // 値が null だと落ちる
  {
    name: 'fail-null-value',
    files: {
      [AC]: t`
        - アーキテクチャ特性: 監査可能性
          分類: null
          説明: 操作を追跡できる
          検証方法: 履歴の照合
      `,
    },
    expected: bad(AC, 'アーキテクチャ特性:監査可能性'),
  },
  // 行がマップでなく文字列だと落ちる
  {
    name: 'fail-record-not-map',
    files: {
      [AC]: t`
        - 監査可能性
      `,
    },
    expected: bad(AC, 'アーキテクチャ特性:#1'),
  },
  // 、区切りの文字列のキー（関連情報）が配列だと落ちる
  {
    name: 'fail-split-key-got-list',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
          関連情報:
            - 経費
        - 情報: 経費
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          情報:
            - 経費申請
            - 経費
      `,
    },
    expected: bad('docs/rdra/information.yaml', '情報:経費申請'),
  },
  // 状態の表で状態モデルのキーが無い行は落ちる（行番号 #4 で指す）
  {
    name: 'fail-state-name-missing',
    files: {
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
        - 状態: 作成中
          遷移UC: 経費申請を提出する
          遷移先状態: 提出済
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
        - UC: 経費申請を提出する
      `,
    },
    expected: bad('docs/rdra/state.yaml', '状態:#4'),
  },
  // 文字列のキー（分類）が配列だと落ちる
  {
    name: 'fail-string-key-got-list',
    files: {
      [AC]: t`
        - アーキテクチャ特性: 監査可能性
          分類:
            - 運用
            - 保守
          説明: 操作を追跡できる
          検証方法: 履歴の照合
      `,
    },
    expected: bad(AC, 'アーキテクチャ特性:監査可能性'),
  },
  // 文字列のキー（説明）が数値だと落ちる
  {
    name: 'fail-string-key-got-number',
    files: {
      [AC]: t`
        - アーキテクチャ特性: 監査可能性
          分類: 運用
          説明: 100
          検証方法: 履歴の照合
      `,
    },
    expected: bad(AC, 'アーキテクチャ特性:監査可能性'),
  },
  // 表のトップが配列でなくマップだと落ちる（表全体を指す）
  {
    name: 'fail-top-level-not-sequence',
    files: { [AC]: 'アーキテクチャ特性: 監査可能性\n' },
    expected: bad(AC, '表:architecture-characteristic.yaml'),
  },
  // YAML の構文誤りがあると落ちる（表全体を指す）
  {
    name: 'fail-yaml-syntax',
    files: { [AC]: '- アーキテクチャ特性: 監査可能性\n  分類: [運用\n' },
    expected: bad(AC, '表:architecture-characteristic.yaml'),
  },
];
