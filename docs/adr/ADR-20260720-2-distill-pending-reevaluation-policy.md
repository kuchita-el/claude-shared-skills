---
status: 承認済み
validity: 有効
---

# ADR-20260720-2: distill の pending 候補再評価ポリシー

## Context

本 ADR は ADR-20260629-distill-input-contract-and-ledger-matching（以下、原 ADR）の分割により生じた後継のひとつである。決定内容は原 ADR で承認済みのものを逐語 restate したものであり、内容の再決定ではない。

### 分割の経緯

原 ADR は4つの決定を束ねる多決定 ADR だった。そのうち決定1「入力の種別分離（処理源 / 参照源）」の処理源 facet が ADR-20260713-captures-stateless-candidate-side-state 決定3 により上書きされた。ADR-20260711-3 決定3 が定める多決定 ADR の部分 core 反転手続き（ADR分割）に従い、原 ADR の生存決定を独立に反転しうる core ごとの後継へ逐語 restate し、原 ADR を `上書き済み` へ退役させた。

後継は3本である。本 ADR は原 ADR の**決定3（pending 候補の再評価ポリシー）**を担う。決定2（入力定義の拡張と時間不変性の意図的放棄）および決定1 の参照源 facet は ADR-20260720-distill-ledger-as-explicit-input が、決定4（責務境界の確認）は ADR-20260720-3-distill-ledger-matching-responsibility-boundary が担う。原 ADR の Consequences 5項は3後継へ配分した。本 ADR は共同帰結である「得られる利益」（再発知見への変換に関する記述）と、「本 ADR に含めない範囲」のうち出力スキーマの具体を保持する。

### 原 ADR からの改変箇所と理由（開示）

ADR-20260711-3 決定3 の開示義務に従い、逐語 restate に際して生じた改変を列挙する。

1. **見出しの先頭番号の振り直し**: 原 ADR `### 3. pending 候補の再評価ポリシー（毎回再評価）` を本 ADR では `### 1.` とした。番号は原 ADR 内での決定の並び順を示すものであり、後継では自身の決定集合における位置へ振り直す。見出しタイトルは変更していない。
2. **リード文の書き換え**: 原 ADR の `## Decision` 冒頭「以下の4点を決定する。」を、本 ADR の決定数に合わせ「以下の1点を決定する。」とした。
3. **`## Consequences` の調整**: 原 ADR の Consequences 5項を後継3本へ配分した。本 ADR は「得られる利益」（決定2 と決定3 の共同帰結。既知ルールの再発見を「N 回再発」知見へ変換する部分が決定3 に対応する）と、「本 ADR に含めない範囲」のうち出力スキーマの具体（再発回数を専用フィールドにするか本文記述にするか）を保持する。「受容したコスト」「自己参照の留保」「将来の留保事項」は決定2 に対応するため ADR-20260720 が保持する。原 ADR に存在しない記述の新規追加は行っていない。

### 参照の時点固定

原 ADR の Context は当時の store 仕様文書を現在形で参照していた。ADR-20260719 決定4（記録の参照原則）に従い、本 ADR ではこれらの可変文書を現在の参照先として指さない。本決定の背景は #417 にあり、既知ルールの単純な再発見で `candidates.md` が希釈される問題への対処として、pending 候補を実行時の台帳で再評価し最新化する方針を採ったものである。

## Decision

以下の1点を決定する。

### 1. pending 候補の再評価ポリシー（毎回再評価）

- pending 候補は distill 実行時の台帳で再評価し最新化する。既存ルールと一致すれば「ルール追加候補」から「既存ルール X が N 回再発」知見へ upsert で置換する。
- `promoted` / `rejected` の候補は**不可侵**とする。distill は再評価でこれらを覆さない（特に promote が `rejected` にした候補を再生成・pending 復活させない）。
- 再評価は同一 provenance での内容置換＝既存 upsert の範囲内で行い、新たな削除操作や `status` 反転を導入しない。

## Consequences

- **得られる利益**: 既知ルールの単純な再発見を新規候補にせず「既存ルールが機能していない（N 回再発）」知見へ変換することで、本当に学びとなる判断誤りが埋もれない。
- **本 ADR に含めない範囲（実装 Issue 側で詰める）**: 出力スキーマの具体（再発回数を専用フィールドにするか本文記述にするか）。

## 関連ADR

- Supersedes: ADR-20260629-distill-input-contract-and-ledger-matching（ADR分割〔ADR-20260711-3 決定3〕により、原 ADR の決定3 を逐語 restate で re-home。原 ADR の決定2＋参照源 facet は ADR-20260720、決定4 は ADR-20260720-3 が担い、決定1 の処理源 facet は ADR-20260713 が上書きした。原 ADR の `superseded-by` はこれら4本の後継を列挙する）
- Related: ADR-20260713-captures-stateless-candidate-side-state（`rejected` / `promoted` 不可侵を共有する。同 ADR 決定2 が候補側 `candidate-status` へ状態を集約し、同 ADR 決定3 は `pending` 観測を本 ADR の pending 再評価で再考する前提で処理源から除外する）
- 関連Issue: #417, #416, #525（ADR分割による re-home）
