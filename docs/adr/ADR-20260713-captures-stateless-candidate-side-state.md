---
status: 承認済み
validity: 有効
---

# ADR-20260713: 個人 store 状態モデル — captures 無状態化と状態の候補側集約

## Status（承認軸／有効性軸）

- **承認軸**（`status`）: `承認済み`（不変）。本 ADR の決定1〜3 は ADR-20260711-store-state-model-captures-stateless で承認済みの決定を、ADR分割（ADR-20260711-3 決定3）により逐語 restate で re-home したものであり、内容の再決定ではない。
- **有効性軸**（`validity`）: `有効`。
- 状態の権威は本ファイル冒頭の front-matter。分割の経緯・スキーマの正本は ADR-20260711-3、上書き・廃止の遷移規定は同 ADR 決定2 を参照。

## Context

growth 学習ループの「distill の再走査抑止」責務が、候補の帰結によって2つのファイル・フィールドに分裂していた（#455）。

- 昇格時: `promote` が `captures.md` の `status` を `unprocessed → promoted` へ反転し、distill が再走査しない。
- 棄却時: `promote` は `captures.status` を反転せず、由来エントリは `unprocessed` のまま残る。再提示抑止は `candidates.md` の `candidate-status: rejected` が担う。

結果、「再走査抑止フラグ」の所在が帰結で非対称になり、単一の locus を持たなかった。PR #454 で stateDiagram に追加した「`status`＝再走査抑止フラグ」注記も promoted 側しか射程に入れられなかった。

#455 の検討で、この非対称は次の理由により「locus を統一する／現状を正当化する」の二択ではなく、captures 側の状態フィールドそのものを廃止する第3の道へ収束した。

1. **別軸である**: `captures.status`（観測の処理状態）と `candidate-status`（候補の検証結果）は別軸。棄却は候補＝仮説への裁定であって観測への裁定ではない。1 観測は 1 仮説が棄却されても別の仮説を生みうる。
2. **distiller 相対である**: 観測棄却（distill が「有効な観測でない」と見る）も候補形成も、いずれも現在の distill による判断で、より賢い distiller により改訂されうる。ゆえに観測の側に「処理済み」の終端状態を置くのは、進化途上の distill v1 の判断への不可逆コミットになる。
3. **陳腐化ゆえ有界でよい**: 観測は時間とともに陳腐化するため、改善された distiller による再検討を全コーパスに毎回かける必要はない。recency 窓で有界化すれば足りる。
4. **promote の裁定だけは下流 commitment**: `rejected` / `promoted` は distiller 相対でなく、配布経路（Issue）への commitment。ここは明示状態として残す必要がある（ADR-20260629 決定3「rejected/promoted 不可侵」に一致）。

## Decision

個人 store の状態モデルを以下へ改める。実装（spec/DESIGN/スキル本体の書換）は本 ADR に含めず follow-up 実装 Issue で扱う。

1. **`captures.md` は無状態の append-only 観測コーパスとする**。`status` フィールドを廃止する。観測の側に「処理済み」終端状態を持たせない（根拠2）。

2. **ループの状態は候補側 `candidate-status`（pending / rejected / promoted）に集約する**。`rejected` / `promoted` は promote の commitment ゆえ導出でなく明示状態として残す（根拠4。ADR-20260629 決定3 に依拠し、distill は再導出でこれらを覆さない）。

3. **distill の処理源選択を「`status: unprocessed` の走査」から「provenance 導出 ＋ recency 窓」へ改める**。観測は、その timestamp が **`promoted` または `pending` の候補**の provenance に現れれば「処理済み」と導出し、処理源から除外する。一方、**`rejected` 候補しか持たない観測、および候補を持たない観測（未 distill／観測棄却）は処理源に残す（再走査に開く）**。これにより賢い distiller が rejected 観測から別の仮説を立てる余地を保つ（Consequence (c)）。rejected された同一仮説の復活は候補層（distill が `candidate-status: rejected` を尊重）が抑止し、現行「冪等性」節の層分離（観測は再走査に開き、同一仮説の再提示だけを候補層で止める）を踏襲する。`pending` 観測は ADR-20260629 決定3 の pending 候補再評価で別途再考されるため処理源からは除外する。観測棄却の再走査は無音（候補を生まない）で、改善された distiller が回った時のみ新たにシグナルを拾う。全再導出でなく recency 窓で有界化する（窓のサイズ・述語は実装 Issue で具体化）。

## Consequences

- **得られる利益**:
  - 再走査抑止の非対称が消滅する。captures 側に状態を持たないため、`candidate-status` と非対称になる相手が存在しなくなる。
  - promote の `captures.status` 反転責務（#348）が消え、promote が簡素化する。
  - 状態軸が候補側 1 本になり、mental model が単純化する。retention の目的が「再導出」へ明確化する。
- **moot 化する先行決定**（follow-up 実装 Issue で記述を書き換える）:
  - #348: promote が `captures.status` を反転する決定。反転対象が消えるため moot。
  - `references/personal-store-spec.md`「状態管理」節: `status` 2値とインライン反転の監査保持機構。
  - `DESIGN.md` stateDiagram の `captures.md（status）` 状態、および PR #454 が追加した「`status`＝再走査抑止フラグ」注記。
- **受容したコスト**:
  - (a) recency 窓は処理源選択に時間依存を追加し、ADR-20260629 決定2 が既に受容した時間不変性の放棄へ上乗せする。再現性は窓境界の固定・記録で担保する（ADR-20260629 の将来留保事項と同系の扱い）。
  - (b) `candidates.md` 消失時は窓内の観測を再導出する（#455 の検討で受容。`captures.md` を保持するため再生成は可能）。
  - (c) `rejected` / `promoted` は導出でなく明示状態として残す必要がある。賢い distiller が rejected 観測から**別の**仮説を立てるのは可だが、rejected された**同じ**仮説を蘇らせてはならない（ADR-20260629 決定3 に依拠）。この「別の仮説を立てる余地」は決定3が rejected 候補しか持たない観測を処理源に残すことで担保し、同一仮説の復活抑止は候補層（`candidate-status: rejected` の尊重）が担う。
- **改訂範囲（Amended の facet）**: ADR-20260629 の決定1（処理源＝`captures.md`、`status: unprocessed` 選択、status 軸の再走査抑止）の facet のみを改訂する。同 ADR の台帳突合（決定2）・rejected/promoted 不可侵（決定3）・責務境界（決定4）は存続する。
- **本 ADR に含めない範囲（実装 Issue で詰める）**: spec/DESIGN/スキル本体の書換、recency 窓の具体（サイズ・選択述語）、provenance 導出の実装と収束条件。

## 関連ADR

- Supersedes: ADR-20260711-store-state-model-captures-stateless（ADR分割〔ADR-20260711-3 決定3〕により、原 ADR の生存決定1〜3 を逐語 restate で re-home。原 ADR の決定4〔retention 姿勢〕は ADR-20260712 が担い、原 ADR の `superseded-by` は本 ADR と ADR-20260712 の両後継を列挙する）
- Supersedes: ADR-20260629-distill-input-contract-and-ledger-matching（決定1 の処理源 facet ＝ work-queue 選択〔status 軸の再走査抑止〕を provenance ＋ recency 導出へ上書き。原 ADR-20260711-store が持っていた Amend 関係を ADR分割〔ADR-20260711-3 決定3〕で本 ADR の supersede 連鎖へ吸収し、#525 で 629 退役に伴い Amends から Supersedes へ格上げした。本 ADR は 711-store と 629 の2本を Supersede する）
- Related: ADR-20260720-distill-ledger-as-explicit-input（本 ADR が改訂しなかった 629 決定1 の参照源 facet〔1b＝既存ルール台帳〕を引き取った後継。本 ADR が上書きするのは決定1 の処理源 facet のみで、参照源 facet は同後継へ生存 re-home された。処理源／参照源で対をなす）
- Related: ADR-20260712-captures-bounded-retention-aging（本 ADR 決定3 の有界化機構 facet〔recency 窓〕は ADR-20260711-2-distill-highwater-cursor で処理済みカーソルへ改訂され、さらに同 ADR-20260712 で retention 射程が改訂されている。この facet の後続改訂を指していた歴史的相互参照が持っていた固有情報を、ADR-20260711-3 決定3 の移設に従い生存語彙へ移した）
- 関連Issue: #455（決定1〜3 の起票元）, #488（ADR分割による re-home）
