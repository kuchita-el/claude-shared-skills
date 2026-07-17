---
status: 承認済み
validity: 有効
---

# ADR-20260628-2: career 決定モデルの再設計（distill 仮説 ＋ 集約点裁定）

## Context

growth Phase 2 は #349 D1 で career（学びの活用先の4分類: `learnings.md` / ADR 差分 / dev-workflow 転送 / 強キャリア）を定め、#382（`promotion-issue-spec.md`）はこれを **promote 起票時・候補単位**の決定表で一意出力する規約とした。#384 のプラン検討中に、この設計に2つの問題が判明した。

1. **未配線ギャップ**: 現行の promote は空間軸 `scope-hypothesis` の本文注記のみを実装し、career の Route 判定実行・キャリアラベル付与は未実装（`promote-procedure.md` §5「ラベル付与は任意」）。`promote:*` ラベルの実体作成も #385 へ委譲され未作成。career ラベルで Issue を絞り込む後段ハンドラ（#383 / #384）の入力前提が成立していない。

2. **設計上の不整合**: career を promote が候補単位で決めることが、フリート学習（DESIGN.md 原理6「一人の N セッションより、M 人の集合ログの方が豊か」）と噛み合わない。`promote` は構造上、1人・1プロジェクトの個人ローカル store（`~/.claude/projects/<project-id>/growth/candidates.md`、`personal-store-spec.md`）しか参照できない。career をここで縛ると、フリート視界ゼロの単独判定が下流ルーティングを確定させてしまう。

なお、DESIGN.md 決定事項8 が「仮説のまま終点・最終裁定は人間」と規定するのは**空間軸（scope: `project-local` / `universal`）**についてであり、career 軸には全面的な「仮説どまり」規定は無かった。career だけが起票時に決定表で縛られる非対称な設計になっていた。

## Decision

career の決定を「promote 起票時・候補単位の確定」から外し、以下のモデルへ再設計する。

1. **career 仮説の生成は distill の責務とする**。`distill` が候補ごとに `career-hypothesis`（＋宛先 repo 仮説）を `candidates.md` へ出力する。scope 仮説（`scope-hypothesis`）と対称・直交な2つのメタ欄として持つ。これは DESIGN.md 決定事項8「Route を distill へ統合する」を、scope だけでなく career についても完成させる変更にあたる。

2. **promote はルーティング不可知とする**。promote は決定表を持たず、distill が出した `career-hypothesis` と `scope-hypothesis` を昇格 Issue 本文に注記として運ぶだけにする。career の確定（裁定）は行わない。

3. **career の裁定は集約点（取り込み Issue）へ移す**。複数の `growth:promote` 候補 Issue を束ねる「取り込み Issue」を裁定の場とし、人間（取り込み Issue が置かれた repo の維持者）が career と宛先を締める。distill の仮説には拘束されない。集約点は scope と career が噛み合う地点である——scope が「どの repo（境界）で裁定するか」を、career が「その repo で何の成果物に落とすか」を決める。

4. **取り込み Issue のクローズは「取り込み時クローズ」とする**。promote 候補 Issue は取り込み Issue へ吸収された時点で `close as not planned ＋ 取り込み Issue へのリンクコメント`により閉じる（スキルが実行）。promote 候補 Issue は耐久的な作業単位ではなく配送伝票であり、トリアージ完了＝inbox 処理完了として閉じる。これにより cascade-close イベント自体が存在しなくなる。取り込み Issue は通常の単一 Issue として refine → plan → implementation → PR を流れ、標準機能（成果物 PR の closing keyword か手動）で閉じる。

5. **`promote:*` の4 career ラベルを廃止する**。career の裁定が人間による集約点トリアージへ移り、1つの取り込み Issue が複数候補を異種 career へ裁定しうるため、1-Issue-1-career-label のルーティング機構は意味を失う。career の結果は実際の成果物（ADR PR / プラグイン Issue / `learnings.md` PR / 強キャリア Issue）として実現し、取り込み Issue の task list が追跡する。inbox 識別子 `growth:promote`（＋既存 `growth`）のみ残す。4 career ラベルは #385 で未作成のため、これは「作らない」決定であり teardown コストはゼロ。

6. **career 行2 を一般化する**。決定表 行2「dev-workflow スキル自体の改善 → dev-workflow への Issue」を、「任意のプラグイン／コミュニティの改善還元 → 当該 repo へ Issue（`gh` 経由）」へ拡張する。知識の集約単位は global / 組織 / チームと様々ありうるため、宛先 repo は固定しない。ただし宛先 repo は distill 時点では仮説であり、最終宛先は集約点（所属コミュニティ境界を知る側）が確定する。

7. **集約トポロジは当面単一配線でよいが、設計不変条件を保持する**。「集約先は複数ありうる／public への昇格を拒否できる」を不変条件として記録し、単一 repo 実装が「公開のみ」を暗黙に焼き込むことを防ぐ。当面は scope 軸（`project-local` ＝公開しない）を公開ゲートに流用する。

## Consequences

### 後続再スコープ（実装は本決定の対象外。別 Issue で実施）

| 対象 | 判定 | 内容 |
|---|---|---|
| #382 `promotion-issue-spec.md` | 再定義 | 決定表を distill 側仕様へ移設。`promote:*` 4 career ラベル体系を削除。career を binding label → 本文注記の仮説へ。行2 を「任意プラグイン／コミュニティ改善還元」へ一般化。 |
| #383 `learning-promotion-spec.md`（マージ済） | 再訪 | 入力前提を「`promote:learnings` ラベルで絞った Issue」→「取り込み Issue の裁定結果」へ改訂。ラベル filter 依存を除去。 |
| #384 `career-promotion-spec.md`（pause 中・未作成） | 再定義 | career ラベルベースのハンドラ入力前提が失効。入力を取り込み Issue の裁定結果へ。#405 確定後に再定義して再開。 |
| #349 D1 | 改訂 | career の適用タイミングを「promote 起票時・候補単位で確定」→「career 仮説は distill が出し、裁定は集約点」へ。行2 一般化を反映。 |
| #348 `promote-procedure.md` | 改訂 | §5 の Route 注記／career 決定表を除去し、distill 由来の `career-hypothesis` を運ぶ注記に変更。promote をルーティング不可知に。 |
| #385 | 縮小 | ラベル作成スコープを inbox 識別子 `growth:promote`（＋ `growth`）のみに縮小。4 career ラベルは作らない。 |

### 新規実装 Issue（別 Issue で起票）

- `distill`: `career-hypothesis`（＋宛先 repo 仮説）生成ロジック（決定表の移設先）。
- `candidates.md` スキーマ: `career-hypothesis` 欄追加（`personal-store-spec.md`）。
- 取り込み Issue 規約 ＋ 取り込みスキル（取り込み時クローズの実行主体）。

### 留保（開いた検討事項）

- **公開可否（広さ ≠ permission）**: scope（generalization の広さ）と公開可否（permission）は本来別軸であり、「普遍的に有用だが公開したくない」ナレッジは scope 一軸では表現できない。当面は scope を公開ゲートに流用するが、privacy ゲートが必要になれば別 Issue で扱う。
- **「career の宛先 repo」と「scope の裁定境界 repo」の関係**: career 行2 の宛先 repo（改善フィードバックを送る当該プラグインの repo）と、scope が指す裁定境界 repo（取り込み Issue が置かれる repo）は別概念だが、両者がどう連動するか（例: 普遍候補をグローバル境界で裁定したうえで特定プラグイン repo へ送る経路）は本決定では確定しない。#382 の再定義で整理する。
- **フリート fan-in（他者→自分の供給）は Phase 3** の別機構が担う。#160（nightly-grooming）は Issue の DoR 自動化であり本モデルとは無関係（取り込み Issue も一般の Issue として #160 の DoR バッチが触れうる、という以上の接続はない）。

### 却下案

- **A（現行 #382: per-candidate 確定）**: career を promote 起票時・候補単位で確定。promote の単独視界がフリート学習と不整合・未配線。
- **GHA による cascade-close**: PR マージ・Issue クローズを契機に GitHub Actions で連鎖クローズ。各 consuming リポジトリへ per-repo インフラ設置が必要で、配布プラグインの携帯性原則（どの repo にもコピーして使える）に反する。スキル（取り込み時クローズ）を採用。
- **トポロジ固定（単一 repo を運用形として確定）**: 集約基盤の実装は #405 の射程外であり、Phase 3 / fan-in の設計自由度を先食いするため不採用。原理＋不変条件の記録に留めた。
- **公開可否を scope と別ゲートとして新設**: 表現力は上がるが軸が増える。当面 YAGNI とし、scope 流用＋開いた検討事項として保持。

## 関連ADR

Related: [ADR-20260626-growth-plugin-separation](./ADR-20260626-growth-plugin-separation.md)

関連Issue: #405（本決定の spike）, #349（Phase 2 エピック / D1）, #382, #383, #384, #348, #385, #160
