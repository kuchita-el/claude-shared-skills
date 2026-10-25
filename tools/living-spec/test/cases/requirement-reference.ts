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
  // 9種すべての種類（アクター・外部システム・情報・状態モデル・状態・UC・条件・バリエーション・アーキテクチャ特性）を1つの行に挙げ、すべて表にあり、名前が要求文に現れる
  {
    name: 'pass-all-nine-kinds',
    files: {
      'docs/rdra/actor.yaml': t`
        - アクター: 従業員
          役割: 経費を申請する
          社内外: 社内
        - アクター: 上司
          役割: 申請を受け取る
          社内外: 社内
      `,
      'docs/rdra/architecture-characteristic.yaml': t`
        - アーキテクチャ特性: 監査可能性
          分類: 運用
          説明: 操作を追跡できる
          検証方法: 履歴の照合
      `,
      'docs/rdra/condition.yaml': t`
        - 条件: 提出可能
          条件の説明: 経費が1件以上ある
          バリエーション: 費目
          状態モデル: 経費申請の状態
      `,
      'docs/rdra/external-system.yaml': t`
        - 外部システム: 会計システム
          役割: 仕訳を受け取る
      `,
      'docs/rdra/information.yaml': t`
        - 情報: 経費申請
          属性: 申請日、合計額
          関連情報: 経費
          状態モデル: 経費申請の状態
          バリエーション: 費目
        - 情報: 経費
          属性: 金額、支払日
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
          情報:
            - 経費申請
            - 経費
          条件:
            - 提出可能
          仮説:
            - P01-1
        - UC: 経費申請を提出する
          アクター:
            - 従業員
            - 上司
          外部システム:
            - 会計システム
          情報:
            - 経費申請
      `,
      'docs/rdra/variation.yaml': t`
        - バリエーション: 費目
          値: 交通費、宿泊費
      `,
      'docs/requirements/submit.md': t`
        # 要求票: 経費申請を提出する

        ## 理由

        従業員が提出を誤ったとき、提出先が処理を始める前なら出し直せるようにする。

        ## 仕様

        1. 経費申請を作成するの後に、従業員が経費申請を提出するとき、システムは経費申請の状態を提出済にし、会計システムへ費目ごとの仕訳を渡し、提出可能を確かめ、監査可能性を保つ
           - RDRA: アクター「従業員」、外部システム「会計システム」、情報「経費申請」、状態モデル「経費申請の状態」、状態「経費申請の状態/提出済」、UC「経費申請を作成する」、条件「提出可能」、バリエーション「費目」、アーキテクチャ特性「監査可能性」
           - 理由: なし
      `,
    },
    expected: [],
  },
  // RDRA 欄が「なし」の行と、RDRA 欄そのものが無い行は、参照なしとして扱い違反にしない
  {
    name: 'pass-no-reference-or-no-field',
    files: {
      ...TABLES,
      'docs/requirements/withdraw.md':
        withdrawMd(null, null) +
        t`
          3. システムは取り下げを記録する
             - RDRA: なし
             - 理由: なし
          4. システムは取り下げの履歴を残す
        `,
    },
    expected: [],
  },
  // RDRA 欄の末尾が「、」で終わり、空の要素がある
  {
    name: 'fail-element-empty',
    files: { ...TABLES, 'docs/requirements/withdraw.md': withdrawMd(`システムは従業員の取り下げを記録する`, `アクター「従業員」、`) },
    expected: [{ rule: 'requirement-reference', file: 'docs/requirements/withdraw.md', target: '仕様:3' }],
  },
  // RDRA 欄の要素が 種類「名前」の形で読めない（「」が無い）
  {
    name: 'fail-element-unreadable',
    files: { ...TABLES, 'docs/requirements/withdraw.md': withdrawMd(`システムは従業員の取り下げを記録する`, `アクター従業員`) },
    expected: [{ rule: 'requirement-reference', file: 'docs/requirements/withdraw.md', target: '仕様:3' }],
  },
  // 種類が語彙に無く、名前も要求文に現れない参照は、requirement-reference だけが出る（名前の出現は問わない）
  {
    name: 'fail-kind-not-in-vocabulary-name-absent',
    files: { ...TABLES, 'docs/requirements/withdraw.md': withdrawMd(`経費申請を取り下げる前に、システムは確認を求める`, `ユースケース「申請を差し戻す」`) },
    expected: [{ rule: 'requirement-reference', file: 'docs/requirements/withdraw.md', target: '仕様:3' }],
  },
  // RDRA 欄の種類が語彙に無い（「UC」でなく「ユースケース」）
  {
    name: 'fail-kind-not-in-vocabulary',
    files: { ...TABLES, 'docs/requirements/withdraw.md': withdrawMd(`経費申請を取り下げる前に、システムは確認を求める`, `ユースケース「経費申請を取り下げる」`) },
    expected: [{ rule: 'requirement-reference', file: 'docs/requirements/withdraw.md', target: '仕様:3' }],
  },
  // 状態「<状態モデル>/<状態>」の状態モデルが状態の表に無い
  {
    name: 'fail-state-model-not-in-table',
    files: { ...TABLES, 'docs/requirements/withdraw.md': withdrawMd(`システムは取り下げられた経費申請を作成中として扱う`, `状態「在庫の状態/作成中」`) },
    expected: [{ rule: 'requirement-reference', file: 'docs/requirements/withdraw.md', target: '仕様:3' }],
  },
  // 状態モデルの参照の名前が状態の表に無い
  {
    name: 'fail-state-model-undefined',
    files: { ...TABLES, 'docs/requirements/withdraw.md': withdrawMd(`システムは在庫の状態を変えない`, `状態モデル「在庫の状態」`) },
    expected: [{ rule: 'requirement-reference', file: 'docs/requirements/withdraw.md', target: '仕様:3' }],
  },
  // 状態が状態モデルの「状態」「遷移先状態」のどちらにも無い
  {
    name: 'fail-state-not-in-model',
    files: { ...TABLES, 'docs/requirements/withdraw.md': withdrawMd(`システムは取り下げられた経費申請を承認済みとして扱う`, `状態「経費申請の状態/承認済み」`) },
    expected: [{ rule: 'requirement-reference', file: 'docs/requirements/withdraw.md', target: '仕様:3' }],
  },
  // 状態の区切りが全角「／」で、半角「/」の形で書かれていない
  {
    name: 'fail-state-separator-fullwidth',
    files: { ...TABLES, 'docs/requirements/withdraw.md': withdrawMd(`システムは取り下げられた経費申請を作成中として扱う`, `状態「経費申請の状態／作成中」`) },
    expected: [{ rule: 'requirement-reference', file: 'docs/requirements/withdraw.md', target: '仕様:3' }],
  },
  // 参照先の種類の表のファイル（外部システム）が無ければ、名前は表に無い
  {
    name: 'fail-table-file-missing',
    files: { ...TABLES, 'docs/requirements/withdraw.md': withdrawMd(`システムは会計システムへ取り下げを伝える`, `外部システム「会計システム」`) },
    expected: [{ rule: 'requirement-reference', file: 'docs/requirements/withdraw.md', target: '仕様:3' }],
  },
  // アクターの表に無い名前を参照している
  {
    name: 'fail-undefined-actor',
    files: { ...TABLES, 'docs/requirements/withdraw.md': withdrawMd(`承認者が経費申請を見るとき、システムは内容を表示する`, `アクター「承認者」`) },
    expected: [{ rule: 'requirement-reference', file: 'docs/requirements/withdraw.md', target: '仕様:3' }],
  },
];
