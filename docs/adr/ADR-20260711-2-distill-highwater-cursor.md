---
status: 承認済み
validity: 上書き済み
superseded-by: ADR-20260712-captures-bounded-retention-aging
---

# ADR-20260711-2: distill 処理源の有界化を recency 窓から処理済みカーソル（high-water mark）へ

## Status

<!-- 状態系は front-matter を正とする（ADR-20260711-3）。以下は過渡期の可読表示。 -->
承認済み（validity: 上書き済み — Superseded by: ADR-20260712-captures-bounded-retention-aging。retention 射程 facet を上書き、カーソル機構は同 ADR に restate）

## Context

ADR-20260711 決定3 は distill の処理源選択を「provenance 導出 ＋ recency 窓」と定め、窓のサイズ・選択述語の具体化を follow-up 実装 Issue（#459）へ委ねた。#459 の実装計画中、窓のサイズ（直近 N セッション／N 日）を決める段で、recency 窓という機構そのものの妥当性を再検討した。

distill が provenance 導出後に処理源へ残す観測は3種に分かれる:

1. **未 distill 観測（1a）**: 一度も走査されていない。
2. **走査済みノイズ（1b）**: distill が走査したが候補を生まなかった。
3. **rejected 観測（2）**: `rejected` 候補しか持たない。

核心の困難は、distill が provenance では **1a と 1b を区別できない**ことにある（どちらも promoted/pending 候補の provenance に現れない）。recency 窓はこの区別不能を「直近 N だけ走査し、古いものは処理源から落とす」で回避するが、1a と 1b が求める扱いは正反対である:

| 種別 | 望ましい扱い | recency 窓の実挙動 |
|---|---|---|
| 1a 未 distill | 齢に関係なく最低1回は走査（落とすと無音の欠損） | N より古いと処理源から**無音で脱落**（coverage 欠損） |
| 1b 走査済みノイズ | distiller 改善時のみ再走査 | 毎回 N 個を再走査（無駄＋LLM 非決定性による偽候補 churn）。N より古い分は改善しても**到達不能** |

窓のサイズをどう選んでも、この 1a／1b の要求衝突は解けない。窓を大きくすれば 1b の毎回 churn とコストが増え、小さくすれば 1a の欠損リスクと改善 distiller の到達射程が痩せる。両立点は存在しない。したがって「窓のサイズをいくつにするか」ではなく、機構そのものを差し替える。

## Decision

distill の処理源有界化を **recency 窓から「distill 処理済みカーソル（high-water mark）」へ置換する**。

1. **store レベルに単一の「最終処理 timestamp（カーソル）」を持つ**。captures エントリ単位の状態は導入しない（ADR-20260711 決定1 の captures 無状態を維持）。カーソルは distill のみが前進させ、`promote` は触らない（旧 `status` のようなスキル間反転結合を生まない）。

2. **ルーチン distill はカーソルより新しい観測のみを処理源とし、処理後カーソルを最新へ前進させる**。これにより 1a（未 distill 観測）は、distill 実行までのラグに関係なく必ず1回は処理され、齢による無音の coverage 欠損が消える。1b（走査済みノイズ）の毎回再走査と非決定性 churn も消える。

3. **provenance 導出は維持する**。カーソルより新しいスライス内でも、既に `promoted` または `pending` 候補を持つ観測は provenance で処理源から除外する（重複候補生成の防止）。有界化（カーソル）と重複排除（provenance）は役割が異なり、両者は合成される。なお `rejected` 候補しか持たない観測・候補を持たない観測（Context の分類2・1a）は provenance では除外されないが、有界化（項2）によりルーチン distill で処理されるのは各観測につき1回のみで、処理後はカーソル前進とともに 1b（走査済みノイズ）と同様に処理源から外れる。これらの以降の再走査は巻き戻し（項4）でのみ開く。

4. **distiller 改善時は、カーソルを意図的に巻き戻して1回だけ再導出する**。巻き戻し範囲の観測を再走査し、provenance が live 候補（promoted/pending）の重複を止め、`rejected` 不可侵（ADR-20260629 決定3）が棄却済み同一仮説の復活を止める。再導出後カーソルを最新へ戻す。全履歴に到達でき、有限窓のような射程制限を持たない。

5. **`candidates.md` 消失時はカーソルを先頭へ巻き戻し、`captures.md` 全体から再導出する**（ADR-20260711 Consequence (b) の「再生成可能」をカーソル巻き戻しとして具体化）。

6. **カーソル欠損時は「先頭」を既定とする**。一度だけ全走査して安全に劣化する（データ損失を招かない）。

カーソルは append-only な `captures.md` の `## <timestamp>`（ISO 8601）見出しと同じキー空間で比較する。観測は capture 時刻の単調増加 timestamp を持つため「カーソルより新しい」は一意に定まる。

## Consequences

- **得られる利益**:
  - coverage 欠損の除去: 未 distill 観測が齢で無音脱落しない。ユーザーの distill 起動ラグに対して頑健。
  - churn の除去: 走査済みノイズをルーチンで再走査しないため、LLM 非決定性による偽候補の反復生成が起きない。
  - 改善 distiller の全履歴到達: 巻き戻しにより有限窓の射程制限がなくなる。
  - magic number の排除: 窓サイズ N も「セッション単位 vs 日数単位」の選択も不要になる。
- **ADR-20260711 との差分（Amended facet）**: 決定3 の有界化機構「recency 窓」を「処理済みカーソル」へ改訂する。決定3 の provenance 導出、および決定1（captures 無状態）・決定2（状態は候補側 `candidate-status`）・決定4（再導出のため保持）は不変。決定4 の retention 目的は「窓内再導出」→「カーソル巻き戻しによる再導出」へ文言のみ調整する（削除せず保持し続ける核は不変）。ADR-20260711 Consequence (a)（処理源選択への時間依存の追加）はカーソルでも成立するが、再現性は窓境界でなくカーソル位置の記録で担保する。同 (b)（`candidates.md` 消失時の再導出）は「窓内の観測」→「カーソル先頭巻き戻しで全体」に読み替える。
- **受容したコスト**:
  - store に「カーソル」という process bookkeeping を1つ追加する。ただしこれは domain state（候補の検証結果＝`candidate-status`）とは別カテゴリの、batch 処理の進捗マーカーであり、mental model の状態軸は候補側 1 本のまま保たれる。
  - distiller 改善時のカーソル巻き戻しは手動の明示操作とする（「改善されたか」を自動判定しない）。改善を入れた開発者が巻き戻しを行う。
- **ADR-20260629 との整合**: 決定2（台帳突合）・決定3（rejected/promoted 不可侵、pending 候補再評価）・決定4（責務境界）はいずれも不変。pending 候補を持つ観測はカーソル以下（処理済み）かつ provenance でも除外され、pending 再評価は決定3 の経路が担う。

## 関連ADR

- Superseded by: ADR-20260712-captures-bounded-retention-aging（retention 射程 facet ＝ 全履歴到達 → 有界 retention horizon。生観測に経年削除を導入。カーソル機構〔guarantee-once・provenance 重複排除・欠損時既定〕は同 ADR に restate して存続）
- Related: ADR-20260629-distill-input-contract-and-ledger-matching（決定3 rejected/promoted 不可侵。カーソル巻き戻し時の同一仮説復活抑止として依拠）
- 関連Issue: #455, #459
