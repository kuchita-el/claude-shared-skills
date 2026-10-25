import { t } from './case.ts';
import type { Case } from './case.ts';

// 票の判定に行は要らないので、仕様節は空にする（行があると対応する例のルールまで要る）
const WITHDRAW_MD = t`
  # 要求票: 経費申請を取り下げる

  ## 理由

  なし

  ## 仕様
`;

export const cases: Case[] = [
  // 仮説キーの無い UC の要求票が、すべての UC について揃っている
  {
    name: 'pass-every-uc-has-requirement',
    files: {
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を取り下げる
      `,
      'docs/requirements/withdraw.md': WITHDRAW_MD,
    },
    expected: [],
  },
  // 『仮説』キーのある UC は、要求票が無くても免除される
  {
    name: 'pass-hypothesis-key-exempt',
    files: {
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を取り下げる
        - UC: 経費申請を提出する
          仮説:
            - P01-1
      `,
      'docs/requirements/withdraw.md': WITHDRAW_MD,
    },
    expected: [],
  },
  // 要求票の置き場に .md が1つも無ければ（.md でないメモだけなら）、票の有無は検査しない
  {
    name: 'pass-no-md-in-requirements-dir',
    files: {
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を取り下げる
      `,
      'docs/requirements/notes.txt': t`
        要求票のメモ（.md ではない）
      `,
    },
    expected: [],
  },
  // 仮説キーの無い UC に要求票が無ければ、UC の表の側に出る（別の UC の票があっても免れない）
  {
    name: 'fail-uc-without-requirement',
    files: {
      'docs/rdra/use-case.yaml': t`
        - UC: 経費申請を取り下げる
        - UC: 経費申請を提出する
      `,
      'docs/requirements/withdraw.md': WITHDRAW_MD,
    },
    expected: [{ rule: 'requirement-missing', file: 'docs/rdra/use-case.yaml', target: 'UC:経費申請を提出する' }],
  },
];
