---
description: intake は複数の growth:promote 候補 Issue を1つの取り込み Issue へ束ね、人間が career を裁定する集約点を運用するスキル。候補の内容重複から既存の取り込み先を検出し（無ければ新規作成）、裁定対象と career 提案のサマリを提示して承認を得てから正式起票する。承認後、各候補を not planned ＋ リンクコメントで取り込み時クローズし inbox から外す。career 裁定・候補の取り込み・集約点運用に明示起動する（ADR-20260628-2 / Phase 2）。
allowed-tools:
  - Read
  - Write
  - AskUserQuestion
  - Bash(gh issue view*)
  - Bash(gh issue list*)
  - Bash(gh issue create*)
  - Bash(gh issue edit*)
  - Bash(gh issue close*)
  - Bash(gh issue comment*)
---

# intake

複数の `growth:promote` 候補 Issue を1つの**取り込み Issue** へ束ね、人間が career（昇格先キャリア）を裁定する集約点を運用する。承認後に各候補を取り込み時クローズして inbox から外す。学習ループ（`[Promote] → 取り込み（裁定） → [Distribute]`）の Promote と Distribute をつなぐトリアージ段。

## 目的・原則

- **目的**: promote がルーティング不可知に起票した候補（配送伝票）を集約点へ束ね、人間が career を締める。distill が運んだ仮説には拘束されず、参照したうえで裁定する（ADR-20260628-2 決定2・3）。
- **裁定は人間（明示ゲート）**: promote の「起票前ゲートなし」とは逆に、取り込みは career を確定する明示的な人間裁定ゲートである。スキルは裁定を**提案**し、承認を得てから正式起票する。確定を握り潰さない。
- **取り込み時クローズ**: cascade-close は GitHub 標準で表現できないため、束ねと同時に各候補を `not planned` ＋ リンクコメントで閉じる（ADR-20260628-2 決定4）。連鎖クローズ機構（GitHub Actions / Hook）は新設しない。
- **疎結合**: 起票・編集・クローズはすべて `gh` で直接行い、**dev-workflow スキル（create-issue 等）を直接呼び出さない**。取り込み Issue は通常の単一 Issue として既存ワークフロー（refine / plan / implementation / PR レビュー）に乗る。
- **集約先は固定しない**: 内容重複する既存取り込み先があれば合流し、無ければ新規作成する。「唯一の取り込み Issue」を前提にしない（不変条件。intake-issue-spec.md）。

## 手順

判定基準・コマンド・本文書式の詳細は `${CLAUDE_SKILL_DIR}/references/intake-procedure.md` を、worked example は `${CLAUDE_SKILL_DIR}/references/intake-examples.md` を参照する（手順本文を SKILL.md に二重化しない）。取り込み Issue の構造・裁定結果の記録形式・不変条件は `${CLAUDE_PLUGIN_ROOT}/references/intake-issue-spec.md` を参照する。

1. **取り込み対象の特定（AC2）**: 引数で候補 Issue 番号が渡ればそれを対象にする。無ければ `gh issue list --label growth:promote --state open` で inbox を列挙し、対象を人間に選ばせる。各候補を `gh issue view` で読む（career 提案と裁定サマリの材料。procedure §1）。
2. **既存取り込み先の検出（不変条件・AC5）**: `gh issue list --label growth:intake --state open` で既存の取り込み Issue を列挙し、各候補の内容と意味的に照合する。重複する取り込み先があれば「既存 #X へ合流」、無ければ「新規作成」を束ね先として決める（procedure §2）。
3. **裁定提案の生成**: 各候補本文の振る舞い差分（と存在すれば distill の career 仮説・scope 仮説）を材料に、候補ごとの career（#349 D1 の4分類）と公開可否（scope を公開ゲートに流用）を**提案**する。確証ではない（procedure §3）。
4. **裁定サマリの提示と承認（AskUserQuestion）**: 裁定対象（候補リスト）＋裁定結果の提案（候補ごとの career・公開可否）＋束ね先（既存 #X / 新規）を提示し、承認を得る。人間は career・公開可否を編集でき、public への昇格を拒否できる。承認されるまで起票・クローズへ進めない（procedure §4）。
5. **正式起票／追記（AC1）**: 承認された裁定で、新規なら取り込み Issue を起票（`gh issue create`、`growth` ＋ `growth:intake` ラベル）、既存なら追記（`gh issue edit`）する。本文に「取り込んだ候補」「裁定結果」テーブル・「成果物」task list を含める。複数行本文は Write で一時ファイルへ書き出し `--body-file` で渡す（procedure §5）。
6. **取り込み時クローズ（AC2・AC3）**: 各候補に対し、取り込み Issue へのリンクコメント（`gh issue comment`）→ `not planned` クローズ（`gh issue close --reason "not planned"`）を**この順**で行う。クローズ後 `is:open label:growth:promote` から外れることを確認する（procedure §6）。

## 完了報告

取り込み対象の候補件数・束ね先（新規起票した取り込み Issue 番号/URL、または合流した既存 #X）・各候補の裁定結果（career）・取り込み時クローズした候補件数を報告する。

```
候補3件を取り込みました。
- 束ね先: 新規取り込み Issue #420
- 裁定結果: #401 → learnings.md（パブリック） / #402 → ADR 差分（閉じた） / #403 → 強キャリア（パブリック）
- 取り込み時クローズ: 候補3件（not planned ＋ リンクコメント）
inbox 確認: is:open label:growth:promote から3件が外れました。
```

承認が得られなかった候補・クローズに失敗した候補は `open` のまま inbox に残り、再実行可能な状態を保つ。

## 関連

- `${CLAUDE_SKILL_DIR}/references/intake-procedure.md` — 各段の判定基準（対象特定・重複検出・裁定提案・承認ゲート・起票/追記・取り込み時クローズ・エラー処理）の単一出典
- `${CLAUDE_SKILL_DIR}/references/intake-examples.md` — worked example（新規起票／既存合流／承認却下／クローズ失敗時の inbox 維持）
- `${CLAUDE_PLUGIN_ROOT}/references/intake-issue-spec.md` — 取り込み Issue の構造・裁定結果の記録形式・取り込み時クローズ規約・集約トポロジの不変条件・`growth:intake` ラベル
- `${CLAUDE_PLUGIN_ROOT}/references/promotion-issue-spec.md` — 入力源 `growth:promote` 候補 Issue のテンプレート（#382 で再定義予定）
- `${CLAUDE_PLUGIN_ROOT}/DESIGN.md` — 設計母艦（学習ループ・二段ゲート・共有境界軸）
