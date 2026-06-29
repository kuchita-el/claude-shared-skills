# career 昇格手順（ADR 差分・改善還元 Issue）仕様

growth プラグインの学習ループ（`[Capture] → [Distill] → [Route] → [Promote] → [Distribute]`）の Distribute 段のうち、取り込み Issue で career＝**ADR 差分** または **改善還元 Issue** と裁定された候補を、それぞれ ADR 運用ルールに沿った ADR 差分・宛先 repo への疎結合な Issue として昇格する**移送規約**を定義する。learnings.md 行きは姉妹規約 [`learning-promotion-spec.md`](learning-promotion-spec.md)（#383）が、強キャリア（skill / hook / lint / test）行きは本規約の対象外（通常の実装ワークフローへ振り分け）。本規約と #383 を合わせ、#349 D1 の全キャリアを Phase 2 でカバーする。

## 位置づけ

- 本仕様は `DESIGN.md` 学習ループの **Distribute 段**（検証済みの学びを配布物・成果物として届ける段）の、ADR 差分（`docs/adr/`）および改善還元 Issue（宛先 repo）への materialization 手続きを定義する。career の裁定（昇格先キャリアの確定）は集約点＝取り込み Issue で人間が行う（ADR-20260628-2 決定3）。本規約はその裁定を**再実装せず、確定済みの裁定結果を信頼**して、ADR 差分・宛先 repo 起票へ着地させる手続きに徹する。
- **新規スキルを設けない**（#349 D2）。本仕様は参照ドキュメントであり、昇格の実行主体は既存ワークフローである。
  - **ADR 差分** → 既存の implementation → PR ワークフロー（`docs/adr/` への ADR 起票・改訂を PR で提出する）。
  - **改善還元 Issue** → `gh issue create` による宛先 repo への疎結合な起票（起票後は宛先 repo 側の既存ワークフロー＝ refine / DoR / plan / implementation / PR レビューが消費する）。
- **出口ゲートは既存の ADR 運用ルールと宛先 repo の受け入れに委ねる**。ADR 差分は [`docs/adr/README.md`](../../../docs/adr/README.md) の粒度判定（4項目）・Superseded / Amended 手続きへ照合し、本規約はこれらを再定義しない。改善還元 Issue は宛先 repo の refine / DoR / レビューが受け入れ可否を締める。
- 姉妹規約 [`learning-promotion-spec.md`](learning-promotion-spec.md)（#383）が learnings.md（パブリック / グローバル空間）行きの変換4手順を担うのに対し、本規約は残る2キャリア（ADR 差分・改善還元 Issue）への昇格と、強キャリアの振り分け確認を担う。

## 入力境界

本規約は、**取り込み Issue（[`intake-issue-spec.md`](intake-issue-spec.md)）の裁定結果テーブルで career 列＝`ADR 差分` または `改善還元 Issue` と裁定された候補**のみを入力に取る。career の確定（裁定）は集約点で人間が行う（ADR-20260628-2 決定3）。本規約はその裁定を再実装せず、確定済みの裁定結果を信頼する。

- **入力識別の拘束キーは裁定結果テーブルの `career` 列**（[`intake-issue-spec.md`](intake-issue-spec.md)「裁定結果の記録形式」）。候補本文の `## キャリア仮説` は distill 由来の**非拘束な仮説**であり、入力識別の拘束キーではない（ADR-20260628-2 決定3。裁定が binding、候補本文は参照されるが拘束しない）。`promotion-issue-spec.md`（#382）再定義前に起票された候補本文には旧表記「dev-workflow への Issue / PR」が残りうるが、裁定結果テーブルの新分類名（`改善還元 Issue`）に従う（候補側の旧表記に引きずられない）。
- `growth:promote` ラベルは候補が inbox へ流入した経緯を示す識別子として存続するが（ADR-20260628-2 決定5）、入力の絞り込みには用いない（絞り込みは裁定結果テーブルの career 列が担う）。
- 昇格手順の一次ソース（候補の `## 振る舞い差分` 等）は、`#候補番号` 参照経由で**取り込み時にクローズ済みの候補 Issue 本文**を読む。取り込み Issue は候補を `- #候補番号` の参照リストで保持し本文を転記しないため（[`intake-issue-spec.md`](intake-issue-spec.md)「本文構造」）、候補本文が一次ソースとなる。

裁定結果テーブルで career 列＝`learnings.md`（→ #383）・`強キャリア`（→「強キャリアの振り分け」節）の候補は、それぞれのハンドラへ委ね、本規約では昇格しない。career 列が単一値（#349 D1 の4分類のいずれか1つ）であることが、1候補が複数ハンドラへ二重に流れないことを保証する（「重複出現の防止」節）。

`空間` 列（パブリック / 閉じた）は本規約の入力絞り込みには用いない。ADR 差分は当該 repo の `docs/adr/` に閉じた設計記録であり、改善還元 Issue の公開可否は宛先 repo の選択と宛先 repo 側のゲートが担うため、いずれも career 列の裁定のみで昇格対象が定まる。

## ADR 差分への昇格

取り込み Issue で career＝`ADR 差分` と裁定された候補を、ADR として `docs/adr/` へ昇格する。

1. **粒度判定**: [`docs/adr/README.md`](../../../docs/adr/README.md)「粒度判定基準」の4項目チェックリストへ照合し、ADR 化要否を判定する。
   1. 後戻りコストが高い
   2. 複数モジュール・複数開発者に波及する
   3. 採用理由が時間経過で揮発しやすい
   4. ツールで自動強制できない

   判定ルール（同 README）: **3点以上→ ADR 化推奨 / 2点以下→ ADR 化しない / 迷ったら ADR 化しない**（境界では「書かない」を優先）。
2. **既存 ADR との関係を確認**: 既存 ADR と矛盾する決定なら Superseded（全体上書き）、一部 facet のみ改訂なら Amended、後継なし廃止なら Deprecated の手続きを [`docs/adr/README.md`](../../../docs/adr/README.md)「廃止・上書き手順」に従って踏む。新規の独立した決定なら新規 ADR を採番方式で起票する。
3. **昇格**: ADR 化推奨と判定した候補のみ、`docs/adr/` への新規 ADR 追加または既存 ADR 改訂を、既存の implementation → PR ワークフローで提出する。ADR 化しないと判定した候補は ADR ファイルに反映しない（差し戻しの扱いは「裁定外候補の非反映と確認」節）。

ADR 化要否の判定例は「入出力例」節に示す（ADR 化する例・しない例の双方）。

## 改善還元 Issue への昇格

取り込み Issue で career＝`改善還元 Issue` と裁定された候補を、宛先 repo への疎結合な Issue として転送する。

- **宛先 repo の決定責務は本ハンドラ（Issue 作成側）が持つ**。裁定結果テーブルは宛先 repo 列を持たない（[`intake-issue-spec.md`](intake-issue-spec.md)「裁定結果の記録形式」。取り込み側は既に存在する候補を取り込むか否かを判断するのみで、宛先 repo を記録しない）。宛先 repo は **dev-workflow 固定ではない**（ADR-20260628-2 決定6＝決定表行2の一般化「任意のプラグイン／コミュニティの改善還元 → 当該 repo へ Issue」）。
- **当面は単一 repo 配線**であり、宛先 repo の既定は取り込み Issue が置かれた repo（同 repo）とする。将来の multi-repo 配線では本ハンドラが宛先 repo を選択し `gh issue create --repo <宛先 repo>` で他 repo を指定できる（集約先は複数ありうる＝[`intake-issue-spec.md`](intake-issue-spec.md)「不変条件」）。
- **疎結合（gh 経由・スキルを直接呼ばない）**: 転送は `gh issue create`（複数行本文は Write で一時ファイルへ書き出し `--body-file` で渡す）で行い、宛先プラグインのスキル（`create-issue` 等）を直接呼び出さない（#349 D2）。起票された Issue は宛先 repo の既存ワークフロー（refine / DoR / plan / implementation / PR レビュー）に自然に乗る。
- **承認ゲートを追加しない**: 起票前に追加の人間承認ゲートを置かない。承認は宛先 repo の PR マージの人間ゲート（#349 D2）が担う（「裁定外候補の非反映と確認」節）。

## 強キャリアの振り分け

取り込み Issue で career＝`強キャリア`（skill / hook / lint / test）と裁定された候補は、**本規約の昇格対象外**である。強キャリアは「構造変換可能」と裁定されており、専用の移送手順を持たず通常の実装ワークフロー（既存の implementation → PR）へ帰着する（#384 スコープ OUT）。

本規約が担うのは**振り分けの確認のみ**——career 列＝`強キャリア` の候補を ADR 差分・改善還元 Issue のいずれにも反映せず、通常実装ワークフローへ送ったことを確認する。専用ハンドラを新設しない。

## 重複出現の防止（同一候補 ID の単一出力先）

裁定結果テーブルの career 列は候補ごとに単一値（#349 D1 の4分類のいずれか1つ）を取る（[`intake-issue-spec.md`](intake-issue-spec.md)「裁定結果の記録形式」）。これにより、1候補は1キャリア＝1出力先にのみ着地する。

- learnings.md 行き（#383）・ADR 差分行き・改善還元 Issue 行き・強キャリア（通常実装）の各ハンドラは、自分の career 値の行のみを入力に取る（「入力境界」節）。
- したがって同一候補 ID が `learnings.md`・ADR ファイル diff・プラグイン起票 Issue・強キャリア実装の複数の出力に重複出現しない。重複出現が観測された場合は、裁定結果テーブルで同一候補に複数 career が付与された規約違反（[`intake-issue-spec.md`](intake-issue-spec.md) 違反）であり、集約点で裁定をやり直す。

## 裁定外候補の非反映と確認

当該 career と裁定された候補のみが成果物に出現し、裁定されていない候補が反映されないことを保証する。

- **ADR 差分**: career 列＝`ADR 差分` かつ ADR 化推奨と判定した候補のみを `docs/adr/` の diff に含める。career 列が他の値の候補・ADR 化しないと判定した候補を ADR ファイルに含めない。確認は PR の diff（反映前後の `docs/adr/` の比較）で目視する。
- **改善還元 Issue**: career 列＝`改善還元 Issue` の候補のみを起票 Issue 本文に含める。起票前に `--body-file` に渡す本文をドライラン（内容確認）し、裁定外候補が混入しないことを確認する。
- **承認は PR マージの人間ゲート**（#349 D2）。ADR 差分は本 repo の PR マージ、改善還元 Issue は宛先 repo の後続 PR マージが配布反映の関門となる。起票・PR 提出前に追加の承認ゲートを設けない。
- ADR 化しないと判定した候補・出口で受け入れられなかった候補は、成果物へ反映せず、裁定点である取り込み Issue で再裁定するか別 Issue で追跡する（候補 Issue は取り込み時に `not planned` でクローズ済みのため差し戻し先にしない＝[`intake-issue-spec.md`](intake-issue-spec.md)「取り込み時クローズ」）。

## 入出力例（worked example）

### ADR 差分: ADR 化する判定例

取り込み Issue の裁定結果テーブルで career＝`ADR 差分` と裁定された候補（`#候補番号` 参照で読む取り込み時クローズ済みの候補本文）:

```markdown
## 振る舞い差分
### 共有参照ファイルの配置を references/ 配下へ統一する
複数スキルが参照する DoR デフォルト定義を、各スキル配下に重複コピーするのをやめ、
プラグインルートの references/ に単一出典として置き ${CLAUDE_PLUGIN_ROOT} で参照する
べきだった。重複コピーは更新漏れと不整合を生む。
```

粒度判定（4項目チェックリスト）の適用:

| 項目 | 該当 | 理由 |
|---|---|---|
| 1. 後戻りコストが高い | ○ | 配置を後から変えると全参照元の書き換えが要る |
| 2. 複数モジュール・複数開発者に波及する | ○ | 複数スキルが同一ファイルを参照する横断事項 |
| 3. 採用理由が時間経過で揮発しやすい | ○ | 「なぜ単一出典か」は記録しないと忘れられる |
| 4. ツールで自動強制できない | ○ | 配置規約は Linter では強制できない |

→ 4点（3点以上）＝ **ADR 化推奨**。既存 ADR と矛盾しなければ新規 ADR を採番方式で起票し、矛盾するなら Superseded 手続きを踏む。implementation → PR ワークフローで `docs/adr/` への追加を提出する。

### ADR 差分: ADR 化しない判定例

```markdown
## 振る舞い差分
### Markdown の箇条書きはハイフンで揃える
ドキュメント内の箇条書きマーカーが `-` と `*` で混在していたので `-` に統一すべきだった。
```

粒度判定:

| 項目 | 該当 | 理由 |
|---|---|---|
| 1. 後戻りコストが高い | × | 局所的・機械置換で戻せる |
| 2. 複数モジュール・複数開発者に波及する | × | 書式の局所事項 |
| 3. 採用理由が時間経過で揮発しやすい | × | 自明な書式統一 |
| 4. ツールで自動強制できない | × | Linter / フォーマッタで強制できる（書式的命名規約） |

→ 0点（2点以下）＝ **ADR 化しない**（[`docs/adr/README.md`](../../../docs/adr/README.md)「命名規約のADR化基準」の書式的規約に該当）。ADR ファイルに反映しない。learnings.md 行き等として再裁定するか、Linter / フォーマッタ規約として扱う。

### 改善還元 Issue: 起票例

取り込み Issue の裁定結果テーブルで career＝`改善還元 Issue` と裁定された候補:

```markdown
## 振る舞い差分
### refine-issue の出力量を Issue の状態に応じて抑制する
小さな Issue に対して refine-issue が過剰な指摘を返すので、Issue の規模・状態に
応じて出力量を段階制御すべきだった。
```

転送（本ハンドラ＝ Issue 作成側が宛先 repo を決定。dev-workflow 固定ではない。当面は単一 repo 配線で宛先＝取り込み Issue が置かれた repo）:

```bash
# 本文を Write で一時ファイルへ書き出し（複数行を CLI に直接渡さない）してから起票する。
# 宛先 repo は本ハンドラが決定する。将来の multi-repo 配線では --repo <宛先 repo> で他 repo を指定できる
# （単一 repo 配線では同 repo＝省略可）。宛先プラグインのスキルは直接呼ばず gh 経由で疎結合に接続する。
gh issue create \
  --title "refine-issue の出力量を Issue 状態に応じて抑制する" \
  --body-file /tmp/improvement-issue-{timestamp}.md
```

起票された Issue は宛先 repo の既存ワークフロー（refine / DoR / plan / implementation / PR レビュー）に乗る。承認は宛先 repo の PR マージの人間ゲート（#349 D2）が担い、起票前に追加の承認ゲートは置かない。

## スコープ境界

| 本仕様が定義する（IN） | 本仕様が定義しない（OUT） |
|---|---|
| ADR 差分行き候補の `docs/adr/` 昇格手順（粒度判定4項目の適用・Superseded / Amended 手続きへの照合・ADR 化要否の判定例） | 粒度判定基準・Superseded 手続き自体の定義（[`docs/adr/README.md`](../../../docs/adr/README.md) が担う） |
| 改善還元 Issue 行き候補の宛先 repo への `gh` 経由の疎結合転送手順（宛先 repo は Issue 作成側が決定・dev-workflow 固定でなく可変） | career / 空間の裁定（集約点＝取り込み Issue が担う＝[`intake-issue-spec.md`](intake-issue-spec.md)）・裁定結果テーブルへの宛先 repo 列追加 |
| 強キャリア候補の通常実装ワークフローへの振り分け確認（専用ハンドラを設けない） | 強キャリア（skill / hook / lint / test）への構造変換そのもの（通常の implementation → PR） |
| 同一候補 ID の単一出力先保証（重複出現の防止）・裁定外候補の非反映の確認 | learnings.md 行きの変換（[`learning-promotion-spec.md`](learning-promotion-spec.md) #383） |
| 既存ワークフロー（implementation → PR / `gh issue create`）での昇格と PR マージ人間ゲート | 承認フロー配線・越境ゲートの新設（既存の PR マージゲートを再利用。#385） |

## 関連

- [`intake-issue-spec.md`](intake-issue-spec.md) — 入力源（#412）。裁定結果の記録形式（career / 空間 / 備考テーブル）の出典であり、本規約の入力境界が参照する裁定結果テーブルを提供する。宛先 repo 列を持たない単一 repo 配線・集約トポロジの不変条件もここで確定
- [`learning-promotion-spec.md`](learning-promotion-spec.md) — 姉妹規約（#383）。learnings.md 行きの変換4手順。本規約と合わせ #349 D1 の全キャリアを Phase 2 でカバーする
- [`docs/adr/README.md`](../../../docs/adr/README.md) — ADR 差分の出口ゲート。粒度判定基準（4項目）・Superseded / Deprecated / Amended 手続き・命名規約の ADR 化基準
- [`promotion-issue-spec.md`](promotion-issue-spec.md) — 候補 Issue（`growth:promote`）のテンプレート（#382。昇格先キャリアの判定＝Route は distill へ移設＝ADR-20260628-2）
- [`DESIGN.md`](../DESIGN.md) — 設計母艦（学習ループ・Distribute 段・学びの2系統・二段ゲート）
- ADR-20260628-2 — career 決定モデルの再設計（distill 仮説 ＋ 集約点裁定・決定表行2の一般化）。本規約の決定根拠
- #349 — 親エピック。D1（career 4分類）・D2（新規スキルなし・既存ワークフロー再利用・疎結合）
