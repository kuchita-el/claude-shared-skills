import { t } from './case.ts';
import type { Case } from './case.ts';

const rule1 = '従業員が経費申請を取り下げるとき、システムは経費申請を作成中へ戻し、前回提出した内容を残さない';
const rule2 = '取り下げられる条件を満たさないならば、システムは取り下げを受け付けない';

const ucTable = '- UC: 経費申請を取り下げる\n';

const requirement = (...rules: string[]) =>
  '# 要求票: 経費申請を取り下げる\n\n## 仕様\n\n' +
  rules.map((r, i) => `${i + 1}. ${r}\n   - RDRA: なし\n   - 理由: なし\n`).join('');

// ルール1つ分の機能。scenarios は字下げを除いて書いたシナリオ群（ルールの下の字下げ4字はここで足す）
const oneRule = (scenarios: string) => ({
  'docs/rdra/use-case.yaml': ucTable,
  'docs/requirements/withdraw.md': requirement(rule1),
  'docs/examples/withdraw.feature': `# language: ja\n機能: 経費申請を取り下げる\n\n  ルール: ${rule1}\n\n${scenarios.replace(/^(?=.)/gm, '    ')}`,
});

const target = (name: string) => [
  { rule: 'example-duplicate', file: 'docs/examples/withdraw.feature', target: `シナリオ:${name}` },
];


export const cases: Case[] = [
  // 接続詞（もし／かつ／ならば）だけが違い、手順の文の並びが同じなら重複になる
  {
    name: 'fail-only-keywords-differ',
    files: oneRule(t`
          シナリオ: 取り下げる
            前提 経費申請が提出済みである
            もし 従業員が経費申請を取り下げる
            ならば 経費申請は作成中に戻る

          シナリオ: 接続詞だけ違う
            前提 経費申請が提出済みである
            もし 従業員が経費申請を取り下げる
            かつ 経費申請は作成中に戻る
    `),
    expected: target('接続詞だけ違う'),
  },
  // アウトラインの行がシナリオと同じ手順に展開されると、アウトラインの行（#1）が重複になる
  {
    name: 'fail-outline-row-same-as-scenario',
    files: oneRule(t`
          シナリオ: 取り下げる
            前提 経費申請が提出済みで内容が1件である
            もし 従業員が経費申請を取り下げる
            ならば 経費申請は作成中に戻り内容が1件残らない

          シナリオアウトライン: 取り下げの例
            前提 経費申請が提出済みで内容が<件数>件である
            もし 従業員が経費申請を取り下げる
            ならば 経費申請は作成中に戻り内容が<件数>件残らない

            例:
              | 件数 | 備考 |
              | 1 | a |
              | 2 | b |
    `),
    expected: target('取り下げの例#1'),
  },
  // アウトラインの2行が同じ手順に展開されると、2行目（#2）が重複になる
  {
    name: 'fail-outline-rows-expand-same',
    files: oneRule(t`
          シナリオアウトライン: 取り下げの例
            前提 経費申請が提出済みで内容が<件数>件である
            もし 従業員が経費申請を取り下げる
            ならば 経費申請は作成中に戻り内容が<件数>件残らない

            例:
              | 件数 | 備考 |
              | 1 | a |
              | 1 | b |
    `),
    expected: target('取り下げの例#2'),
  },
  // 別のルールのシナリオと手順が同じでも、同じ機能の中なので重複になる
  {
    name: 'fail-same-steps-across-rules',
    files: {
      'docs/rdra/use-case.yaml': ucTable,
      'docs/requirements/withdraw.md': requirement(rule1, rule2),
      'docs/examples/withdraw.feature': t`
        # language: ja
        機能: 経費申請を取り下げる

          ルール: ${rule1}

            シナリオ: 取り下げる
              前提 経費申請が提出済みである
              もし 従業員が経費申請を取り下げる
              ならば 経費申請は作成中に戻る

          ルール: ${rule2}

            シナリオ: 別のルールで取り下げる
              前提 経費申請が提出済みである
              もし 従業員が経費申請を取り下げる
              ならば 経費申請は作成中に戻る
      `,
    },
    expected: target('別のルールで取り下げる'),
  },
  // 1つのルールの中で、手順が同じシナリオが2つあると、2つ目が重複になる
  {
    name: 'fail-same-steps-in-one-rule',
    files: oneRule(t`
          シナリオ: 取り下げる
            前提 経費申請が提出済みである
            もし 従業員が経費申請を取り下げる
            ならば 経費申請は作成中に戻る

          シナリオ: もう一度取り下げる
            前提 経費申請が提出済みである
            もし 従業員が経費申請を取り下げる
            ならば 経費申請は作成中に戻る
    `),
    expected: target('もう一度取り下げる'),
  },
  // 手順の文が同じでも並びが違えば重複としない
  {
    name: 'pass-order-of-steps-differs',
    files: oneRule(t`
          シナリオ: 取り下げる
            前提 経費申請が提出済みである
            もし 従業員が経費申請を取り下げる
            ならば 経費申請は作成中に戻る

          シナリオ: 順序の違う例
            もし 従業員が経費申請を取り下げる
            前提 経費申請が提出済みである
            ならば 経費申請は作成中に戻る
    `),
    expected: [],
  },
  // アウトラインの行が展開後に異なる手順になれば（備考列だけ同じでも）重複としない
  {
    name: 'pass-outline-rows-differ',
    files: oneRule(t`
          シナリオアウトライン: 取り下げの例
            前提 経費申請が提出済みで内容が<件数>件である
            もし 従業員が経費申請を取り下げる
            ならば 経費申請は作成中に戻り内容が<件数>件残らない

            例:
              | 件数 | 備考 |
              | 1 | a |
              | 2 | a |
    `),
    expected: [],
  },
];
