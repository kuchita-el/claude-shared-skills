---
status: 承認済み
validity: 有効
---

# ADR-20260712: 生観測の有界保持（経年削除）と work-queue／retention の2軸分離

## Context

growth の生観測 store（`captures.md`）は capture が全観測を単一ファイルへ append する設計で、各観測を `## <timestamp>` 見出しで記録する。この単一ファイル方針の根拠は DESIGN.md 原理5（足場を痩せさせる＝肥大の可視化）とされてきたが、原理5 の「単一の人間可読ファイル」は本来 **学び置き場 `learnings.md`（配布物）** 向けの定義（DESIGN.md L133／L233）であり、生観測 store 固有の要請ではない。単一ファイル方針そのものを主題化した ADR は存在しなかった。

### 顕在化したスケール限界

`captures.md` は append-only ゆえ無界に伸びる。distill は処理源選択の際にこのファイルを **まるごと Read** してからカーソルで絞る（`personal-store-spec.md`「distill 処理源選択」）。したがってファイル肥大は、稀な巻き戻しだけでなく **毎回のルーチン distill** で Read トークン天井に近づく形で効く。運用実績として、第1世代 `captures.md` が約1ヶ月で数百エントリ規模に達し Read が truncate される事象が観測され、手動アーカイブで応急対処された経緯がある（Issue #451 の背景）。

### 問題の本質は store 構造でなく retention ポリシー

対処を「store をどう分割・退避・ページングするか」（店構造）として立てると、分割時のカーソル・provenance 横断や持ち越しページングといった複雑性を抱える。しかし問題の本質は、**そもそも生観測を無限に保持し続けるべきか**という retention ポリシーにある。

生観測を保持する唯一の根拠は「改善された distiller が過去観測から新シグナルを再導出できる」こと（ADR-20260711 決定4）。だが観測は特定時点の摩擦・誤りの生記録であり、コードベース・ワークフロー・ツールの変化で価値を失う。ADR-20260711 決定3 根拠3 自身が「観測は時間とともに陳腐化する」と明記している。

- **保持価値は陳腐化で減衰する**: 半年前の、もう存在しないワークフローの摩擦信号を再蒸留して有用な振る舞い差分が出る確率はほぼゼロ。
- **保持費用は単調増加する**: store 肥大・毎回の Read コスト・上記スケール限界。

価値→0／費用→∞ という非対称の正解は **有界保持＋経年削除** であり、無限保持ではない。加えて growth 自身の背骨（原理5「忘却・圧縮を検証と同格に」、原理7 via negativa）は忘却を一級市民に置く。より低価値密度の生観測 store を無限保持しつつ、精製済みの `learnings.md` に積極忘却（物理除去）を課すのは一貫性を欠く。

### recency 窓の失敗を繰り返さないための2軸分離

ADR-20260711-2 は「直近 N の recency 窓」で処理源を有界化する機構を廃した。理由は、未 distill 観測が窓外へ **無音で脱落**して coverage 欠損を生むことだった。この失敗は「window で work-queue を切った」ことに起因する。retention の有界化はこれと **別軸**として設計できる。

- **work-queue 軸（distill カーソル）**: どの観測を distill するか。カーソルより新しい観測を処理し、各観測を最低1回は処理する（guarantee-once）。
- **retention 軸（保持期間）**: どの観測を store に残すか。改善 distiller の巻き戻し再導出のために直近 horizon 分を保持する。

ADR-20260711-2 は「work-queue に窓を置かない」を「無限保持」まで延長したが、両者は分離できる。retention horizon は **既に distill 済み（カーソル通過済み）でシグナルを候補へ吐き終えた観測だけ**を経年削除の対象にするため、recency 窓の coverage 欠損（未 distill 観測の脱落）は構造的に起きない。

### ADR 化要否（ADR-20260719 決定1 の粒度判定4項目）

| # | 項目 | 該当 |
|---|---|---|
| 1 | 後戻りコストが高い | ○（retention 反転は store・distill 契約・巻き戻し射程に波及） |
| 2 | 複数モジュールに波及 | ○（capture・distill・spec） |
| 3 | 採用理由が揮発しやすい | ○（陳腐化・2軸分離・原理整合という選定理由は記録なしに揮発） |
| 4 | ツールで自動強制できない | ○（保持ポリシーはドキュメント規約） |

4/4 該当につき ADR 化する。

## Decision

### 1. 生観測の保持を「無限保持」から「有界保持＋経年削除」へ改める

生観測を無限に保持しない。work-queue 軸と retention 軸を分離し、後者に有界 retention horizon を導入する。

- **work-queue 軸（維持）**: distill 処理済みカーソルによる guarantee-once を維持する（ADR-20260711-2 決定2）。未 distill の観測は horizon に関わらず **絶対に削除しない**。
- **retention 軸（新設）**: **既に distill 済み（カーソル通過済み）** の観測のうち、retention horizon より古いものを物理削除（忘却）する。削除対象は「カーソル通過済み かつ horizon 超」の積集合に限る。

これにより ADR-20260711 決定4 の「観測は削除しない」を改訂する（→ 有界保持）。retention の目的（改善 distiller による再導出）は維持しつつ、その射程を horizon で有界化する。

### 2. ADR-20260711-2 を上書きし、カーソル機構を引き継いだ上で retention 射程を改訂する

新 ADR 運用フロー（ADR-20260711-3：Amend 廃止、core 変更＝新規 ADR＋旧 ADR を上書き済み＋不変部分を restate）に従い、retention 射程の現行権威である ADR-20260711-2 を上書きする。ADR-20260711-2 のカーソル機構のうち有効な決定を以下に restate し、retention 射程に関わる決定4・5 のみを改訂する。

**restate（不変で引き継ぐ）**:

- store レベルに単一の distill 処理済みカーソル（high-water mark）を持つ。captures はエントリ単位の状態を持たない無状態のまま（ADR-20260711 決定1）。カーソルは distill のみが前進させ、promote は触らない。
- ルーチン distill はカーソルより新しい観測のみを処理源とし、処理後カーソルを最新へ前進させる（guarantee-once：各観測は齢に関係なく最低1回は処理される）。
- provenance 導出を維持する。カーソルより新しいスライス内でも、既に `promoted`／`pending` 候補を持つ観測は provenance で処理源から除外する（重複候補生成の防止）。有界化（カーソル）と重複排除（provenance）は合成される。
- カーソル欠損時は「先頭」を既定とし、一度だけ全走査して安全に劣化する。

**改訂（retention 射程）**:

- **決定4 の改訂**: distiller 改善時のカーソル巻き戻し再導出の到達射程を「全履歴」から「**retention horizon 先頭まで**」へ改める。horizon より古い観測は経年削除済みゆえ再導出の対象外。これは陳腐化を受け入れる意図的なトレードオフである。
- **決定5 の読み替え**: `candidates.md` 消失時の再導出は「カーソルを先頭へ巻き戻し `captures.md` 全体から」を「**retention horizon 先頭まで巻き戻して**」へ読み替える。horizon 外の観測からは候補を再生成しない。

### 3. spec の retention 条項の改訂方針

`personal-store-spec.md`「retention の目的」節（「観測は削除しない」）の改訂方針を「無限保持 → 有界 horizon ＋ 経年削除」と定める。「削除しない」核（再導出可能性）は horizon 内で維持する。**本 ADR は方針決定までとし、spec の実改訂・distill／capture スキルへの反映は後続の実装 Issue に委ねる。**

### 4. 実装形は後続 Issue の裁量

retention horizon の単位（直近 N セッション／M 日）・サイズ、および経年削除の実装形（store を時刻セグメントに分割して horizon 超セグメントを丸ごと drop するか、単一ファイル内で古いエントリを削除するか）は本 ADR で確定しない。設計原理は「guarantee-once ＋ 有界 retention horizon」までとし、パラメータと機構は実装 Issue で詰める。

## Consequences

**得られる利益**:

- スケール限界が根本から解消する。store は概ね horizon サイズで有界化し、単一 captures.md のまるごと Read も cold path（巻き戻し）も horizon で有界化する。店構造の分割・退避・持ち越しページングによる緩和が不要になる。
- captures と learnings が「忘却を持つ」点で一貫する（captures：陳腐な生シグナルを経年削除／learnings：効かない規範を忘却＋畳み込み）。段階が違うだけで、原理5・原理7 に整合する。
- guarantee-once（未 distill 観測を落とさない）を維持するため、recency 窓が抱えた coverage 欠損を再発しない。

**受容したトレードオフ**:

- retention horizon より古い観測からの再発掘能力を失う。改善 distiller が年単位の古い摩擦を遡って再蒸留することはできなくなる。だが陳腐化ゆえその価値はほぼ無く、単独利用者で監査要件も無い（spec 明記「監査保持は単独利用者ゆえ不要」）ため妥当な放棄とする。
- ADR-20260711-2 のカーソル機構を本 ADR へ restate する冗長が生じる。これは Amend を廃した新運用フロー（ADR-20260711-3）が「自己完結原則の対価」として受容済みの形である。

**将来の留保事項（本 ADR のスコープ外＝後続実装 Issue）**:

- `personal-store-spec.md` retention 条項の実改訂、distill の guarantee-once ＋ horizon ロジック、capture のローテーション／経年削除機構の実装。
- retention horizon の単位・サイズの確定、および経年削除の実装形（セグメント分割 vs 単一ファイル内削除）の選定。
- spec・DESIGN.md・distill-procedure 等が参照する `ADR-20260711-2` を本 ADR へ張り替える参照整合作業。
- `docs/adr/index.md` 生成・`scripts/lint-adr.sh` drift-lint は Issue #463 フェーズ3 に委ねる（本 ADR は front-matter を持つが index 未整備）。

## 関連ADR

- Supersedes: ADR-20260711-2-distill-highwater-cursor（retention 射程を「全履歴到達」から「有界 retention horizon」へ改め、生観測に経年削除を導入。カーソル機構〔guarantee-once・provenance 重複排除・欠損時既定〕は本 ADR に restate して引き継ぐ）
- Supersedes: ADR-20260711-store-state-model-captures-stateless（決定4「観測は削除しない／retention＝再導出のため保持」を本 ADR で改訂〔有界保持＋経年削除へ〕。ADR分割〔ADR-20260711-3 決定3〕により本 ADR は原 ADR の決定4 facet を担う後継として `Supersedes` を宣言し、原 ADR の `superseded-by` に列挙される。決定1〜3〔captures 無状態・状態の候補側集約・処理源選択〕は ADR-20260713-captures-stateless-candidate-side-state へ re-home され不変で存続）
- Related: ADR-20260713-captures-stateless-candidate-side-state（入力契約の処理源 facet〔work-queue 選択〕の後継。629 決定1 の処理源を provenance＋recency 導出へ上書き）、ADR-20260720-distill-ledger-as-explicit-input（入力契約の参照源 facet〔既存ルール台帳〕の後継。629 決定1b・決定2 を引き取る）。処理源／参照源の2分は本決定で反転せず不変（分割以前は退役した ADR-20260629-distill-input-contract-and-ledger-matching を指していた）
- 関連Issue: #451（本決定）, #434（論点3 の独立元）, #463（ADR 運用2軸モデル）
