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
  // 未決の印は、どの表でも文で書く欄（役割・説明・条件の説明・状態モデル・状態の説明）に付けられる
  {
    name: 'pass-open-on-every-text-key',
    files: {
      'docs/rdra/actor.yaml': t`
        - アクター: 従業員
          役割: 経費を申請する
          未決:
            - 役割: 派遣の社員を含むかが決まっていない
      `,
      'docs/rdra/external-system.yaml': t`
        - 外部システム: 会計システム
          未決:
            - 役割: 仕訳を受け取る時刻が決まっていない
      `,
      'docs/rdra/information.yaml': t`
        - 情報: 経費
          説明: 立て替えた費用
          未決:
            - 説明: 立て替えでない費用を含むかが決まっていない
      `,
      'docs/rdra/state.yaml': t`
        - 状態モデル: 経費申請の状態
          遷移UC: 経費申請を作成する
          遷移先状態: 作成中
          未決:
            - 状態モデル・状態の説明: 下書きを状態に数えるかが決まっていない
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
            - 経費
          条件:
            - 提出可能
          説明: 経費をまとめて申請にする
          未決:
            - 説明: 1件の申請に入れられる経費の数が決まっていない
      `,
      'docs/rdra/condition.yaml': t`
        - 条件: 提出可能
          条件の説明: 経費が1件以上ある
          未決:
            - 条件の説明: 金額が0円の経費を数えるかが決まっていない
      `,
      'docs/rdra/variation.yaml': t`
        - バリエーション: 費目
          値: 交通費、宿泊費
          未決:
            - 説明: 費目の分け方が決まっていない
      `,
      'docs/rdra/architecture-characteristic.yaml': t`
        - アーキテクチャ特性: 監査可能性
          説明: 操作を追跡できる
          未決:
            - 説明: 記録を残す期間が決まっていない
      `,
    },
    expected: [],
  },
  // 未決の印は、名前キー・参照のキー・検証方法には付けられない（表ごとの文で書く欄に限る）
  {
    name: 'fail-open-on-non-text-key',
    files: {
      'docs/rdra/actor.yaml': t`
        - アクター: 従業員
          未決:
            - 社内外: 派遣の社員の扱いが決まっていない
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を作成する
          アクター:
            - 従業員
          未決:
            - UC: 名前が決まっていない
      `,
      [AC]: t`
        - アーキテクチャ特性: 監査可能性
          検証方法: 履歴の照合
          未決:
            - 検証方法: 照合の範囲が決まっていない
      `,
    },
    expected: [
      ...bad('docs/rdra/actor.yaml', 'アクター:従業員'),
      ...bad('docs/rdra/use-case.yaml', 'UC:経費申請を作成する'),
      ...bad(AC, 'アーキテクチャ特性:監査可能性'),
    ],
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
          分類体系: ソフトウェアアーキテクチャの基礎
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
          分類体系: ソフトウェアアーキテクチャの基礎
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
  // 集約の親は情報の名前1つの文字列で書く。並びで複数の親を書くと落ちる
  {
    name: 'fail-aggregate-parent-got-list',
    files: {
      'docs/rdra/information.yaml': t`
        - 情報: 経費明細
          集約の親:
            - 経費申請
            - 出張申請
        - 情報: 経費申請
        - 情報: 出張申請
      `,
      'docs/rdra/use-case.yaml': t`
        - UC: 申請を作成する
          情報:
            - 経費申請
            - 出張申請
            - 経費明細
      `,
    },
    expected: bad('docs/rdra/information.yaml', '情報:経費明細'),
  },
  // 文字列のキー（説明）が数値だと落ちる
  {
    name: 'fail-string-key-got-number',
    files: {
      [AC]: t`
        - アーキテクチャ特性: 監査可能性
          分類: 運用
          分類体系: ソフトウェアアーキテクチャの基礎
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
  // 分類に値があるのに分類体系が無いレコードだけが落ちる
  {
    name: 'fail-classification-system-missing',
    files: {
      [AC]: t`
        - アーキテクチャ特性: 監査可能性
          分類: 運用
          分類体系: ソフトウェアアーキテクチャの基礎
        - アーキテクチャ特性: 可用性
          分類: 運用
      `,
    },
    expected: bad(AC, 'アーキテクチャ特性:可用性'),
  },
  // 分類体系が空文字・空白だけのレコードも、無いものとして落ちる
  {
    name: 'fail-classification-system-blank',
    files: {
      [AC]: t`
        - アーキテクチャ特性: 監査可能性
          分類: 運用
          分類体系: ""
        - アーキテクチャ特性: 可用性
          分類: 運用
          分類体系: " "
      `,
    },
    expected: [...bad(AC, 'アーキテクチャ特性:監査可能性'), ...bad(AC, 'アーキテクチャ特性:可用性')],
  },
  // 名前の無いレコードにも掛かり、名前の欠けと同じ対象に重ねて出る（集合では見えないので件数で見る）
  {
    name: 'fail-classification-system-nameless',
    files: {
      [AC]: t`
        - 分類: 運用
          説明: 操作を追跡できる
      `,
    },
    expected: bad(AC, 'アーキテクチャ特性:#1'),
    counts: { 'アーキテクチャ特性:#1': 2 },
  },
  // 分類体系の値が文字列でないときは型の誤りだけが出て、必須の検査は重ならない
  {
    name: 'fail-classification-system-not-string',
    files: {
      [AC]: t`
        - アーキテクチャ特性: 監査可能性
          分類: 運用
          分類体系: 123
        - アーキテクチャ特性: 可用性
          分類: 運用
          分類体系: null
      `,
    },
    expected: [...bad(AC, 'アーキテクチャ特性:監査可能性'), ...bad(AC, 'アーキテクチャ特性:可用性')],
    counts: { 'アーキテクチャ特性:監査可能性': 1, 'アーキテクチャ特性:可用性': 1 },
  },
  // 分類の値が文字列でないときは型の誤りだけが出て、必須の検査は重ならない
  {
    name: 'fail-classification-not-string',
    files: {
      [AC]: t`
        - アーキテクチャ特性: 監査可能性
          分類: 123
      `,
    },
    expected: bad(AC, 'アーキテクチャ特性:監査可能性'),
    counts: { 'アーキテクチャ特性:監査可能性': 1 },
  },
  // 分類と分類体系が揃っていれば通る
  {
    name: 'pass-classification-with-system',
    files: {
      [AC]: t`
        - アーキテクチャ特性: 保守性
          分類: 保守性
          分類体系: ISO/IEC 25010
      `,
    },
    expected: [],
  },
  // 体系が分からないときは「不明」と書けば通る（値の中身は問わない）
  {
    name: 'pass-classification-system-unknown',
    files: {
      [AC]: t`
        - アーキテクチャ特性: 監査可能性
          分類: 運用
          分類体系: 不明
      `,
    },
    expected: [],
  },
  // 分類の無いレコードは分類体系を問われない
  {
    name: 'pass-no-classification',
    files: {
      [AC]: t`
        - アーキテクチャ特性: 監査可能性
          説明: 操作を追跡できる
      `,
    },
    expected: [],
  },
  // 分類が空文字・空白だけなら値が無いものとして、分類体系を問われない
  {
    name: 'pass-classification-blank',
    files: {
      [AC]: t`
        - アーキテクチャ特性: 監査可能性
          分類: ""
        - アーキテクチャ特性: 可用性
          分類: " "
      `,
    },
    expected: [],
  },
  // レコードごとに分類体系が違っても通る（体系の一致は求めない）
  {
    name: 'pass-classification-systems-differ',
    files: {
      [AC]: t`
        - アーキテクチャ特性: 監査可能性
          分類: 運用
          分類体系: ソフトウェアアーキテクチャの基礎
        - アーキテクチャ特性: 保守性
          分類: 保守性
          分類体系: ISO/IEC 25010
      `,
    },
    expected: [],
  },
];
