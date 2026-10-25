import { t } from './case.ts';
import type { Case } from './case.ts';

// 仕様の行1・2が参照する先（アクター・条件・状態）と、票の UC
const TABLES = {
  'docs/rdra/actor.yaml': t`
    - アクター: 従業員
      役割: 経費を申請する
      社内外: 社内
  `,
  'docs/rdra/condition.yaml': t`
    - 条件: 取り下げられる条件
      条件の説明: 経費申請が提出済みのときだけ取り下げられる
      状態モデル: 経費申請の状態
  `,
  'docs/rdra/state.yaml': t`
    - 状態モデル: 経費申請の状態
      状態: 提出済み
      遷移UC: 経費申請を取り下げる
      遷移先状態: 作成中
    - 状態モデル: 経費申請の状態
      状態: 作成中
  `,
  'docs/rdra/use-case.yaml': t`
    - UC: 経費申請を取り下げる
      アクター:
        - 従業員
      条件:
        - 取り下げられる条件
  `,
};

// 仕様の行1・2は表と整合した通常の行。行3だけを件ごとに変える（行3の RDRA 欄が null のときは欄ごと書かない）
function withdrawMd(sentence3: string | null, rdra3: string | null): string {
  const head = t`
    # 要求票: 経費申請を取り下げる

    ## 理由

    従業員が提出を誤ったとき、提出先が処理を始める前なら出し直せるようにする。

    ## 仕様

    1. 従業員が経費申請を取り下げるとき、システムは経費申請を作成中へ戻し、前回提出した内容を残さない
       - RDRA: アクター「従業員」、状態「経費申請の状態/作成中」
       - 理由: なし
    2. 取り下げられる条件を満たさないならば、システムは取り下げを受け付けない
       - RDRA: 条件「取り下げられる条件」
       - 理由: なし
  `;
  if (sentence3 === null) return head;
  return head + `3. ${sentence3}\n` + (rdra3 === null ? '' : `   - RDRA: ${rdra3}\n   - 理由: なし\n`);
}

export const cases: Case[] = [
  // 状態の参照で要求文に現れるべきは状態名の部分だけ（行1は状態モデル名「経費申請の状態」が要求文に無くても、状態名「作成中」があれば通る）
  {
    name: 'pass-state-checks-state-part-only',
    files: { ...TABLES, 'docs/requirements/withdraw.md': withdrawMd(null, null) },
    expected: [],
  },
  // アクターの名前が要求文に現れない
  {
    name: 'fail-actor-absent-from-sentence',
    files: { ...TABLES, 'docs/requirements/withdraw.md': withdrawMd(`システムは取り下げを記録する`, `アクター「従業員」`) },
    expected: [{ rule: 'requirement-name-absent', file: 'docs/requirements/withdraw.md', target: '仕様:3' }],
  },
  // 条件の名前が要求文に現れない
  {
    name: 'fail-condition-absent',
    files: { ...TABLES, 'docs/requirements/withdraw.md': withdrawMd(`システムは取り下げを記録する`, `条件「取り下げられる条件」`) },
    expected: [{ rule: 'requirement-name-absent', file: 'docs/requirements/withdraw.md', target: '仕様:3' }],
  },
  // 状態の参照は、状態モデル名が要求文にあっても状態名（作成中）が無ければ出る
  {
    name: 'fail-state-absent-model-name-present',
    files: { ...TABLES, 'docs/requirements/withdraw.md': withdrawMd(`システムは経費申請の状態を確認する`, `状態「経費申請の状態/作成中」`) },
    expected: [{ rule: 'requirement-name-absent', file: 'docs/requirements/withdraw.md', target: '仕様:3' }],
  },
  // 状態モデルの名前が要求文に現れない
  {
    name: 'fail-state-model-absent',
    files: { ...TABLES, 'docs/requirements/withdraw.md': withdrawMd(`システムは取り下げを記録する`, `状態モデル「経費申請の状態」`) },
    expected: [{ rule: 'requirement-name-absent', file: 'docs/requirements/withdraw.md', target: '仕様:3' }],
  },
];
