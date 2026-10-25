import { t } from './case.ts';
import type { Case } from './case.ts';

const UC = { 'docs/rdra/use-case.yaml': t`
  - UC: 経費申請を取り下げる
` };
const FILE = 'docs/requirements/withdraw.md';
const fail = (target: string) => ({ rule: 'requirement-structure', file: FILE, target });

export const cases: Case[] = [
  {
    // 雛形どおりの票（コメント・空行・番号の付け方の違い・全角のコロン・* の箇条書きを含む）は通る
    name: 'pass-template-structure',
    files: {
      ...UC,
      [FILE]: t`
        # 要求票: 経費申請を取り下げる

        <!-- 見出しは固定 -->

        ## 理由

        提出を誤ったときに出し直せるようにする。

        ## 仕様

        <!--
        複数行のコメント
        -->
        1. 従業員が経費申請を取り下げるとき、システムは経費申請を作成中へ戻す
           - RDRA： なし
           * 理由: なし

        3. 取り下げた経費申請を、システムは提出先に見せない
           - RDRA: なし
           - 理由: なし
      `,
    },
    expected: [],
  },
  {
    // 「## 理由」「## 仕様」の見出しが無い
    name: 'fail-heading-missing',
    files: {
      ...UC,
      [FILE]: t`
        # 要求票: 経費申請を取り下げる

        提出を誤ったときに出し直せるようにする。
      `,
    },
    expected: [fail('見出し:理由'), fail('見出し:仕様')],
  },
  {
    // 雛形に無い見出しと、2回目の見出し
    name: 'fail-heading-unknown-or-repeated',
    files: {
      ...UC,
      [FILE]: t`
        # 要求票: 経費申請を取り下げる

        ## 理由

        なし

        ## 背景

        前の版の経緯。

        ## 仕様

        1. 従業員が経費申請を取り下げるとき、システムは経費申請を作成中へ戻す
           - RDRA: なし
           - 理由: なし

        ## 仕様

        2. 取り下げた経費申請を、システムは提出先に見せない
           - RDRA: なし
           - 理由: なし
      `,
    },
    expected: [fail('見出し:背景'), fail('見出し:仕様')],
  },
  {
    // 仕様の行に「- RDRA: 」「- 理由: 」の欄が無い（欄が無い行を参照なしとして黙って読まない）
    name: 'fail-field-missing',
    files: {
      ...UC,
      [FILE]: t`
        # 要求票: 経費申請を取り下げる

        ## 理由

        なし

        ## 仕様

        1. 従業員が経費申請を取り下げるとき、システムは経費申請を作成中へ戻す
           - 理由: なし
        2. 取り下げた経費申請を、システムは提出先に見せない
           - RDRA: なし
      `,
    },
    expected: [fail('仕様:1'), fail('仕様:2')],
  },
  {
    // 同じ欄が2回ある（2回目は読まれない）
    name: 'fail-field-repeated',
    files: {
      ...UC,
      [FILE]: t`
        # 要求票: 経費申請を取り下げる

        ## 理由

        なし

        ## 仕様

        1. 従業員が経費申請を取り下げるとき、システムは経費申請を作成中へ戻す
           - RDRA: なし
           - RDRA: なし
           - 理由: なし
      `,
    },
    expected: [fail('仕様:1')],
  },
  {
    // 仕様の節の読めない行: 字下げの無い欄、知らない欄、番号の前の欄、番号でない本文。行番号で示す
    name: 'fail-unreadable-line',
    files: {
      ...UC,
      [FILE]: t`
        # 要求票: 経費申請を取り下げる

        ## 理由

        なし

        ## 仕様

           - RDRA: なし
        1. 従業員が経費申請を取り下げるとき、システムは経費申請を作成中へ戻す
        - RDRA: なし
           - RDRA: なし
           - 理由: なし
           - 例: 提出済みの申請
        取り下げは提出先が処理する前に限る
      `,
    },
    expected: [fail('行:9'), fail('行:11'), fail('行:14'), fail('行:15')],
  },
  {
    // 要求文が空の番号つきの行
    name: 'fail-sentence-empty',
    files: {
      ...UC,
      [FILE]: t`
        # 要求票: 経費申請を取り下げる

        ## 理由

        なし

        ## 仕様

        1.
           - RDRA: なし
           - 理由: なし
      `,
    },
    expected: [fail('仕様:1')],
  },
];
