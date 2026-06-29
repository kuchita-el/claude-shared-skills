# 取り込み Issue 規約

growth プラグインの学習ループにおいて、複数の `growth:promote` 候補 Issue を1つの**取り込み Issue** へ束ね、人間が career（昇格先キャリア）を裁定する集約点の規約を定義する。many-to-one の束ね方・裁定結果の記録形式・取り込み時クローズの手順・集約トポロジの不変条件を、`intake` スキル（取り込みスキル）の実行を含めて単一出典として定める。

## 位置づけ

本規約は ADR-20260628-2（career 決定モデルの再設計）の実装である。career の裁定を「promote 起票時・候補単位の確定」から「集約点での人間裁定」へ移したことに伴い、その集約点となる取り込み Issue の構造と、候補を取り込み時に閉じる手続きを定める。

- **学習ループ上の位置**: `[Capture] → [Distill] → [Route] → [Promote] → [Distribute]` のうち、Promote（`promote` が起票した `growth:promote` 候補 Issue）と Distribute（成果物としての実体化）の**あいだに立つトリアージ点**。promote はルーティング不可知に候補を起票するだけで career を確定しない（ADR-20260628-2 決定2）。取り込み Issue が、複数候補を束ねて career を締める裁定の場になる。
- **promote 候補 Issue は配送伝票**: `growth:promote` 候補 Issue は耐久的な作業単位ではなく、検証通過候補を inbox へ届ける配送伝票である。取り込み Issue へ吸収された時点でトリアージ完了＝inbox 処理完了として閉じる（ADR-20260628-2 決定4。「取り込み時クローズ」）。
- **取り込み Issue は通常の単一 Issue**: 束ね・裁定を終えた取り込み Issue は、通常の単一 Issue として既存ワークフロー（`refine-issue` → `plan-issue` → `implementation` → PR レビュー）を流れ、成果物 PR の closing keyword または手動で閉じる。連鎖クローズの機構は新設しない（後述「取り込み Issue 自身のクローズ」）。
- **関連仕様との関係**:
  - [`promotion-issue-spec.md`](promotion-issue-spec.md) — 入力源となる `growth:promote` 候補 Issue のテンプレートを定義する（ADR-20260628-2 に合わせ #382 で再定義予定）。本規約はその候補 Issue を**入力として束ねる**側であり、候補テンプレート自体は再定義しない。
  - [`learning-promotion-spec.md`](learning-promotion-spec.md) — learnings.md 行きと裁定された成果を1欄エントリへ翻訳する変換規約（#383）。本規約の**裁定結果を将来の入力境界**として受ける（ラベル filter 依存から裁定結果依存への改訂は #383 側で行う。本規約はその入力となりうる形式を提供する）。
  - [`DESIGN.md`](../DESIGN.md) — 設計母艦（学習ループ・学びの2系統・共有境界軸・二段ゲート）。

## 取り込み Issue の構造

取り込み Issue は、束ねた候補・裁定結果・成果物追跡の3要素を本文に持つ。`intake` スキルがプログラム生成し、人間が裁定欄を確定する。

### 本文構造

| セクション | 役割 | 記法 |
|---|---|---|
| **取り込んだ候補** | 束ねた `growth:promote` 候補 Issue の provenance 記録（many-to-one の束ね） | `- #候補番号` の参照リスト（1行1候補。カンマ区切り1行にしない）。候補は取り込み時にクローズ済みのため、進捗追跡用の checkbox は持たない |
| **裁定結果** | 候補ごとに人間が確定した career と公開可否（後述「裁定結果の記録形式」） | テーブル1行＝1候補 |
| **成果物** | 裁定結果を実体化する成果物の追跡（task list） | `- [ ] <成果物の説明>（#候補番号 由来）` |

「取り込んだ候補」が many-to-one の束ね構造を、「成果物」の task list が career の結果（実際の成果物）の追跡を担う（ADR-20260628-2 決定5「career の結果は実際の成果物として実現し、取り込み Issue の task list が追跡する」）。

### 裁定結果の記録形式

裁定は**人間が集約点で行う**（ADR-20260628-2 決定3）。distill が候補本文に運んだ仮説（career 仮説・scope 仮説）には拘束されず、参照したうえで確定する。裁定結果は候補ごとに次のテーブルへ記録する。

| 列 | 内容 | 取りうる値 |
|---|---|---|
| **候補** | 束ねた候補 Issue 番号 | `#候補番号` |
| **career** | #349 D1 の昇格先キャリア（4分類）のいずれか1つ | learnings.md / ADR 差分 / 改善還元 Issue（任意プラグイン・コミュニティ）/ 強キャリア（skill / hook / lint / test） |
| **公開可否** | 公開ゲートの裁定結果（後述「不変条件」） | パブリック / 閉じた |
| **備考** | distill 仮説の転記や裁定理由（任意） | 自由記述 |

- **career 軸**: #349 D1 の4分類。行2（dev-workflow スキル改善）は ADR-20260628-2 決定6 により「任意のプラグイン／コミュニティの改善還元 → 当該 repo へ Issue」へ一般化されている。なお `promotion-issue-spec.md`（#382 で再定義予定）が現状まだ行2 を旧表記「dev-workflow への Issue / PR」のまま持つため、#382 再定義前に起票された候補本文の career 仮説欄には旧表記が残りうる。裁定結果テーブルには上記の新分類名（改善還元 Issue）で記録してよい（候補側の旧表記に引きずられない）。
- **宛先 repo は記録しない**: 当面は単一 repo 配線であり、候補 Issue は既に宛先 repo（取り込み Issue が置かれた repo）へ届いている前提に立つ。career を実体化する成果物も同 repo 内に生む。よって裁定結果に宛先 repo 欄は持たせない。集約先が複数になる将来の multi-repo 配線（後述「不変条件」）で再導入余地を残すが、現時点では YAGNI として持たない。
- **将来の入力境界**: この裁定結果テーブルは、#383（learnings.md 昇格ハンドラ）・#384（残りキャリア）が「ラベル filter 依存」から「取り込み Issue の裁定結果依存」へ改訂される際の入力となる。career 列でハンドラが対象候補を仕分けられるよう、値は4分類の名称をそのまま記す。

## 取り込み時クローズ

候補 Issue は取り込み Issue へ吸収された時点で閉じる（ADR-20260628-2 決定4）。cascade-close（親クローズで子を連鎖クローズ）は GitHub 標準機能で表現できないため、束ねと同時にスキルが各候補を閉じる「取り込み時クローズ」で代替する。

各候補に対し、次を**この順**で行う。

1. **リンクコメント**: 取り込み Issue へのリンクを含むコメントを候補 Issue へ付与する（`gh issue comment`）。どの取り込み Issue へ吸収されたかを候補側に残し、追跡可能にする。
2. **not planned クローズ**: 候補 Issue を `not planned`（作業放棄ではなく「配送完了によりトリアージ済み」）として閉じる（`gh issue close --reason "not planned"`）。

クローズ後、`is:open label:growth:promote` の検索結果に取り込み済み候補が現れない（inbox から外れる）ことを確認する。これが取り込みが inbox 処理として完了したことの観測点である。

## 取り込み Issue 自身のクローズ（cascade-close を新設しない）

取り込み Issue 用の**新規連鎖クローズ機構（GitHub Actions / Hook 等）は追加しない**（ADR-20260628-2 決定・却下案「GHA による cascade-close」）。理由は配布プラグインの携帯性原則——各 consuming リポジトリへ per-repo インフラ（Actions / Hook）の設置を要求すると、どの repo にもコピーして使えるという原則に反する。

- 取り込み Issue は通常の単一 Issue として、**成果物 PR の closing keyword（`Closes #取り込み番号`）または手動クローズ**で閉じる。標準の GitHub 機能の範囲で完結する。
- 候補 Issue のクローズは前述「取り込み時クローズ」がスキル実行時に同期的に行う。イベント駆動の連鎖は存在しない。
- 本 PR ではいかなる GitHub Actions ワークフロー・Hook も追加しない。本規約に準拠する実装が cascade-close 機構を持たないことは、`.github/workflows/` 配下に取り込み連動の追加が無いことで確認できる。

## 不変条件（単一 repo 配線でも破らない）

当面の配線は単一 repo（取り込み Issue・候補・成果物がすべて同一 repo）だが、ADR-20260628-2 決定7 の集約トポロジ不変条件を破らない。単一 repo 実装が「公開のみ」を暗黙に焼き込むことを防ぐため、規約として次を明記する。

1. **集約先は複数ありうる**: 取り込み Issue（集約点）は1つに固定されない。内容の異なる学びは別々の集約点へ束ねられてよく、本規約・スキルは「唯一の取り込み Issue」を前提にしない（`intake` スキルは内容重複する既存取り込み先を検出して合流させ、無ければ新規作成する）。将来 multi-repo 配線では集約先が他 repo にもなりうる。
2. **public への昇格を拒否できる**: 公開可否はゲートであり、裁定で「閉じた」と締めれば public（パブリック/グローバル空間 = `learnings.md` 相当）への昇格を拒否できる。すべての候補が自動で public へ向かうことはない。
3. **当面は scope を公開ゲートに流用する**: 公開可否の専用 privacy 軸は新設せず、当面は scope 軸（`project-local` ＝公開しない / `universal` ＝公開しうる）を公開ゲートに流用する（ADR-20260628-2 決定7・留保「公開可否（広さ ≠ permission）」）。裁定結果テーブルの「公開可否」列は scope 由来の値（パブリック ← `universal` / 閉じた ← `project-local`）として記録する。privacy ゲートが別途必要になれば別 Issue で扱う。

## `growth:intake` ラベル

取り込み Issue を機械的に識別・列挙できるよう、識別ラベル `growth:intake` を定義する。`intake` スキルが既存の取り込み先（内容重複する取り込み Issue）を検出する際にこのラベルで列挙する。

| ラベル | 役割 | hex | 根拠 |
|---|---|---|---|
| `growth:intake` | 識別（取り込み Issue 全体） | `#1D76DB` | 集約点を示す青系。inbox 識別子 `growth:promote`（濃緑）と視認上区別する |

- 取り込み Issue は既存 `growth` ラベルと**併用**する（`growth` ＋ `growth:intake`）。`growth` は growth ドメイン全体の識別、`growth:intake` は集約点のサブ識別。
- **ラベル実体の作成は本 PR では実行しない**。マージ前のリポジトリにラベルを作ると状態を汚すため、実作成は #385（承認フロー配線）またはセットアップ手順の実行時に委譲する（`promotion-issue-spec.md` のラベル方針と同一）。

```bash
# ラベル実体の作成（本 PR では実行しない。セットアップ時に実行する）
gh label create growth:intake --color 1D76DB --description "取り込み Issue（career 裁定の集約点・識別）"
```

## スコープ境界

| 本規約が定義する（IN） | 本規約が定義しない（OUT） |
|---|---|
| 取り込み Issue の本文構造（束ね・裁定結果・成果物 task list） | distill / promote の career 仮説（`career-hypothesis`）配線（別 Issue。career の決定責務を distill へ移す実装） |
| 裁定結果の記録形式（career・公開可否のテーブル。宛先 repo を持たない） | 候補 Issue（`growth:promote`）のテンプレート自体（`promotion-issue-spec.md` #382 が担う） |
| 取り込み時クローズの手順（リンクコメント ＋ not planned） | 各 career への実書き込み手順（learnings.md 変換 #383 / 残りキャリア #384 / 成果物 PR の作成） |
| 集約トポロジの不変条件（集約先複数・public 拒否・scope 流用） | privacy ゲートの新設（公開可否 ≠ 広さ。留保。別 Issue） |
| `growth:intake` 識別ラベルの定義 | ラベル実体の作成（`gh label create` の実行。#385 / セットアップへ委譲） |
| cascade-close を新設しない方針の明記 | フリート fan-in の供給（Phase 3） |

## 関連

- [`../skills/intake/SKILL.md`](../skills/intake/SKILL.md) — 本規約を実行する取り込みスキル（候補の束ね・裁定提示・取り込み時クローズ）
- [`promotion-issue-spec.md`](promotion-issue-spec.md) — 入力源 `growth:promote` 候補 Issue のテンプレート（#382 で本決定に合わせ再定義予定）
- [`learning-promotion-spec.md`](learning-promotion-spec.md) — 裁定結果を将来の入力境界とする learnings.md 変換規約（#383）
- [`DESIGN.md`](../DESIGN.md) — 設計母艦（学習ループ・二段ゲート・共有境界軸）
- ADR-20260628-2 — career 決定モデルの再設計（distill 仮説 ＋ 集約点裁定）。本規約の決定根拠
