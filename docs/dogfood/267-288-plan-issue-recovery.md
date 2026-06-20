# ドッグフード観察ログ: #288 plan-issue: 却下後のリカバリパス（再生成/手動修正）を定義する

#267（再配線後スキルの実Issueドッグフード検証）の観察記録。

## メタ

- 対象リポ: kuchita-el/claude-shared-skills
- 対象Issue: https://github.com/kuchita-el/claude-shared-skills/issues/288
- 実施日: 2026-06-20（着手）
- 担当: kuchita-el + Claude (model: claude-opus-4-7)
- 使用フロー: plan-issue → dev-loop（再配線後）
- 開始ブランチ: `feature/288-plan-issue-rejection-recovery`
- 開始コミット: afc5450 (Merge PR #306, v0.4.1 bump)
- 想定観察制約:
  - 本Issueは SKILL.md 編集が主体でテストコードを書く対象がない
  - → S4（test-driven-development）の委譲挙動・テスト網羅性後退は観察対象外
  - 観察可能: 計画品質・writing-plans 委譲・レビュー指摘・往復回数・人間介入頻度・finishing/verification 委譲

## 実行記録

### Phase 1: plan-issue

- 起動コマンド: `/dev-workflow:plan-issue 288`（スキル経由）
- 計画生成エージェント: `dev-workflow:plan`（custom agent、ID: a4930d268dcce5f12）
- writing-plans preload 結果: **成功**（エージェントが `<command-name>writing-plans</command-name>` `<skill-format>true</skill-format>` および skill 本体の preload を確認、フォールバック未使用）
- 計画生成所要: 203秒 / 111k tokens / 17 tool uses
- レビュー結果: **PASS（1周収束、指摘なし）** / レビュアーID: ae7ca754d0df0de43 / 64k tokens / 15 tool uses / 92秒
- 観察:
  - [x] writing-plans の preload 警告の有無 → 警告なし、preload 成功
  - [x] 計画品質 → タスク分解3件・AC↔テストケース対応表10件・判断依頼4件（判断待ち2＋前提確認2）。レビュー1周PASS
  - [x] 接続契約の保持確認 → 検証方針・判断依頼セクションともに dev-workflow plan-output-format に従って生成。writing-plans 委譲下でも dev-workflow 接続契約が機能している
- 自由記述:
  - 引数解析〜Issue情報取得まではメインループで実行（特に詰まりなし）
  - エージェントには Issue #97 と event-storming.md の確認も指示済み → 一次情報で実在確認の上で参照
  - writing-plans のメソドロジー（bite-sized 粒度・ファイル構造事前マッピング）と dev-workflow の出力形式が干渉なく両立。委譲の構造設計が機能している
  - 判断依頼 4 件（判断待ち2 + 前提確認2）。判断待ち2件は AskUserQuestion で1回のみで確定（推奨案2件採用）。前提確認2件はそのまま採用

### Phase 2: dev-loop

- 起動コマンド: `/dev-workflow:dev-loop 288`（スキル経由）
- worktree: **不使用**（通常のブランチで作業。CLAUDE.md「ブランチ運用」に従う）
- 委譲対象スキル稼働状況:
  - [x] test-driven-development（S4） — **N/A**（Markdown のみの変更、テスト対象コードなし）
  - [x] verification-before-completion（S5） — **スキップ**（test/lint フレームワーク不在のため。dev-loop SKILL.md 仕様で許容）
  - [x] finishing-a-development-branch（S6） — Phase 4 で起動予定
  - [x] requesting-code-review（S7） — **起動成功**、レビュアーエージェント完了（abb2b6910843b457b、56k tokens、98秒、12 tool uses）
  - [x] using-git-worktrees — **未起動**（worktree 不使用のため）
- フェーズ別所感:
  - 計画適用: 計画ファイルから3タスク（追記/注記/検証）を直接消化。subagent-driven-development 委譲は不要（単一ファイル小規模）
  - 実装: Edit で SKILL.md に49行追記。Markdown のみで TDD 不適用
  - 検証ゲート: S5 スキップ。AC1〜AC4 を手動チェックリストで確認、wc -l で 183行確認（170超過13行、計画予測範囲内）
  - PR化: **完了** — PR #307 (https://github.com/kuchita-el/claude-shared-skills/pull/307)、finishing-a-development-branch 委譲下で Ready 状態作成
  - レビュー反映: 本PR上で対応予定
- 自由記述:
  - レビュアーは Ready to merge: Yes、Critical/Important 0件、Minor 3件
  - **誤検知1件**: Minor 1/2「末尾改行欠落」は実測で全ファイル `\n` 終端を確認、誤検知
  - 深刻度調整は不要（ブロッカー0件、誤検知格下げ対象は Minor のため対象外）
  - dev-loop の周回統治撤去の影響なし（1周収束のため発動条件未満）

### Phase 3: 判定

- ブロッカー: 0件 → Phase 4 へ進む
- 改善提案: 3件（Minor）+ 2件（Recommendations）。PR本文に記載
  - Minor 3「ステップ7再起動の曖昧さ」: 別 Issue で改善検討
  - Recommendation 1「dogfood Phase 2 空欄」: 本コミットで解消
  - Recommendation 2「#97 完了後アクションの追跡」: PR 本文で言及

### Phase 5 サマリ（レビューサイクル定量集計）

| 項目 | 値 |
|---|---|
| レビュー周回数 | 3周（11:13 / 11:26 / 11:37、UTC） |
| 指摘件数 | 5件（Blocker候補2: C1/C4、Major3: C2/C3/C5） |
| 全周収束所要 | 約25分（11:13:36 → 11:38 頃、各周内のメインループ修正含む） |
| レビュー応答コード修正コミット | 3件（3bb5cdd: C1/C2、e5544f4: C4、0a56e46: C5） |
| レビュー応答 dogfood/PR更新コミット | 2件（a84c2f1: Phase 5 観察、c097437: 用語訂正） |
| 非コミット対応 | 1件（C3 = #97 へのコメント投稿） |
| セルフレビュー誤検知 | 1件（末尾改行欠落、別件） |

### Phase 5: 別セッション Claude Code レビュー対応（PR #307 レビュー指摘）

セルフレビュー（同一セッション内の reviewer subagent）では検出されなかった以下の指摘が、**別セッション Claude Code** のレビューで検出された:

| # | 重大度 | 指摘 | 検出可否（同一セッション内 subagent） |
|---|---|---|---|
| C1 | Blocker候補 | ステップ6本文に衝突回避メカニズム未定義、リカバリ手順L170の連番付与指示が宙に浮く | **未検出**（セルフレビューはAC直接対応のみ確認、ステップ間整合は確認漏れ） |
| C2 | Major | 再生成手順の「却下理由の渡し方」が未定義（コマンド形式の明示なし） | **未検出**（プロセス手順の具体性チェックが甘い） |
| C3 | Major | #97 完了後リンク更新の追跡手段が未設置（PR本文の「要検討」止まり） | **部分検出**（改善提案として認識したが追跡手段確立まで踏み込まず） |

**修正方針確定**（ユーザー承認、推奨案採用）:
- C1: 案A（ステップ6本文に衝突回避を全モードへ展開）
- C2: コマンド形式 `/dev-workflow:plan-issue {番号} "{補足}"` を手順に明記
- C3: 案A（本PRマージ前に #97 へフォローコメント投稿）

**観察（同一セッション subagent vs 別セッション Claude Code の検出範囲差）**:
- 同一セッション内 reviewer subagent（`superpowers:requesting-code-review` 経由 general-purpose）はメインループから渡されたレビュー契約（AC由来12項目）に縛られ、契約内項目には強いが、AC外の懸念（ステップ間整合性・プロセス手順の具体性・運用上の追跡可能性）は構造的に対象外
- 別セッション Claude Code はプロンプト由来の契約に縛られず、コード本体を自由に読んで運用観点の問題を発見
- これは「contractual review（契約レビュー）vs free review（自由レビュー）」の差異であり、撤去機構の影響ではない
- **dev-workflow 接続契約への示唆**: レビュー契約を AC由来のみで構成すると検出範囲が限定される。「ステップ間整合性」「プロセス手順の具体性」「運用追跡可能性」を契約に追加するか、reviewer subagent へ「契約外の懸念も自由に指摘してよい」と明示する改善余地あり

**派生発見（dev-loop UXギャップ）**: C1 (a) 適用に伴い、dev-loop が `docs/plans/issue-{番号}.md` 固定で参照する仕様と、再生成時に新規plan が `issue-{番号}-2.md` などになる挙動の間にギャップあり。当初は「別Issue化候補」として記録したが、別セッション Claude Code の再レビュー（C4）で「本PR導入のリカバリパスが本PRで動かない latent bug」と再評価された。

**C4 対応**: 案 (a)（本PR scope に含める）を採用。`plugins/dev-workflow/skills/dev-loop/references/phase0-input-detection.md` L32 の plan 探索を「`docs/plans/` から `issue-{番号}.md` および `issue-{番号}-{連番}.md` を Glob で列挙 → 連番最大を選択」へ拡張。4シナリオ目視で動作確認済（通常初回・1〜2回リカバリ後・計画ファイルなし）。

**観察3点目（dogfood で latent bug を別Issue化と楽観視）**: 私（メインループ）が dogfood で「別Issue化候補」とした判断は、レビュアー視点では「本PRで対応すべき Blocker」だった。**dogfood 観察時の重大度評価**にも構造的バイアス（自分が書いた仕様に対し甘い評価をする傾向）がある可能性。dev-workflow への示唆: dogfood 観察の重大度評価も別セッション Claude Code レビューに通すか、明示的なチェックリストで補強する余地あり。

### Phase 5（続）: C5 対応（C4 修正の仕様精度不足）

C4 修正の3周目レビューで C5（Major）を受領:
- **問題1**: Glob パターン「`issue-{番号}.md` および `issue-{番号}-{連番}.md`」だけでは実装者が `issue-{番号}*.md` 単一パターンで組む可能性を排除できず、桁またぎ Issue（#12 vs #123）で誤マッチ
- **問題2**: 「連番が最大のもの」だけでは数値/文字列ソート方法が未指定で、文字列ソートだと `-10 < -2 < -9` でリカバリ10回到達時に誤動作

**修正**（コミット追加予定）: phase0-input-detection.md L32 を「2 パターンを別 Glob で照合（単一パターンは使わない）」「整数として比較（文字列比較は使わない）」と明文化。**否定形（〜は使わない）を仕様に含める**ことで、実装者の安易な解釈を構造的に排除。

**観察4点目（LLM 向けスキル仕様の精度要件）**: 自然言語スキル仕様は LLM が解釈するため、肯定形（「正しいやり方」）だけでなく**否定形（「やってはいけないやり方」と発動条件）を明示**する必要がある。「Glob で列挙」「最大」のような自然な表現は、複数の正当な実装を許容してしまい latent bug を残す。dev-workflow への示唆: スキル定義のレビュー観点に「LLM 解釈の曖昧性チェック（仕様文の複数の正当解釈に複数の正答があるか）」を追加する余地。

**dev-loop SKILL.md への発見**: Phase 5（レビュー対応サイクル）は dev-loop SKILL.md に明示されていない（Phase 4 = PR作成で文書化が終わっている）が、今回の実施で実体として存在することが観察された。Phase 5 の接続契約（スレッド返信・修正コミット・PR本文更新）を SKILL.md に明文化する改修候補あり。

**観察5点目（修正カスケードと独立視点の検出能力）**:

修正連鎖が発生:

```
C1（ステップ6に衝突回避追加）
  ↓ 副作用（dev-loop が連番ファイルを拾えない）
C4（リカバリパス実行直後の latent bug）
  ↓ 副作用（仕様文の曖昧さ）
C5（Glob/ソート仕様の latent bug）
  ↓ 終止
```

- 同一実装者は自身の修正が次の問題を生むことを構造的に予測しにくい（実装直後はその修正が「正しい」と認識しているため副作用検出のメンタルモデルが立ち上がらない）
- セルフレビュー（reviewer subagent）は「実装 ↔ レビュー契約」の対応検証で、「**修正コミットの副作用**」検証は契約に含まれない
- 独立視点（別セッション Claude Code）は前修正の副作用を検出可能。実際 C4 は C1 を、C5 は C4 を起点に発見された
- **dev-workflow への示唆**: 修正コミット後の差分も自動で別セッション CC レビューに通すか、最低限「直前修正が新たな破綻を生まないか」をセルフレビュー契約に含める余地。dev-loop Phase 2 の「セルフレビュー」を「初回実装レビュー」と「修正後レビュー」に分けて契約を差別化することも候補

**観察6点目（判断依頼の発生パターン）**:

| 指摘 | 重大度 | 判断依頼 | 結果 |
|---|---|---|---|
| C1 | Blocker候補 | あり（案A/B） | 案A採用 |
| C2 | Major | なし（即修正） | コマンド形式明文化 |
| C3 | Major | あり（案A/B/C） | 案A採用 |
| C4 | Blocker候補 | あり（案A/B/C） | 案A採用 |
| C5 | Major | なし（即修正） | 仕様文に否定形含めて明文化 |

- AskUserQuestion 発生率 60%（3/5）。修正方針が複数あり PR scope への影響が異なる場合は判断依頼、明確な仕様明文化のみの場合は即修正
- 判断依頼で常に「Recommended」が採用された（5/5中3件＝判断依頼分）。**推奨案の妥当性が高い** or **ユーザーが推奨を尊重する傾向**のいずれか。後者の場合、推奨案の品質が事実上のレビュー品質を決める。dev-workflow への示唆: 推奨案を提示する前に複数案の検討痕跡（pros/cons）を観察ログに残すこと
- 判断依頼を経た指摘は全て案A（最も保守的・安全側の案）が選ばれた。リスク回避志向が観察される

## 追加メタ観察

**観察7点目（dev-loop Phase 構造とドキュメント構造のズレ）**: 本ログは Phase 3 の直後に Phase 5 と飛んでおり、Phase 4（PR化）は Phase 2 内の「フェーズ別所感 > PR化」欄に埋め込まれた状態になっている。これは dev-loop SKILL.md の Phase 構造（Phase 4 = PR作成）と、本ログの観察構造（Phase 別記述）が一致していないため発生したズレ。

- 原因: dev-loop SKILL.md の Phase 2 が「セルフレビュー」、Phase 4 が「PR作成 + 完了報告」だが、本ログのドッグフード観察テンプレ（`_template.md`）は「Phase 1: plan-issue / Phase 2: dev-loop / 結論」の3区分のみで、dev-loop 内の Phase 0〜4 のサブ区分を持たない。観察記述時にどこに何を書くか迷い、結果として PR化 を「Phase 2: dev-loop」の中に押し込んだ
- dev-workflow への示唆: ドッグフード観察ログのテンプレを dev-loop の Phase 構造（Phase 0〜5）に整合させる改修候補あり。または、観察ログを dev-loop SKILL.md の Phase 構造に依存させず「実施記録 / 観察 / 結論」のような分類で組み直す案もあり。テンプレ改修は #267 のクローズ判断後の別 Issue 化が候補

## 撤去機構の影響評価

| 機構 | 後退兆候の観点 | 観測事象 | 評価 |
|---|---|---|---|
| 独立 test-spec 検証撤去 | テスト観点漏れが review/runtime で初検出されたか | N/A（テスト対象コードなし） | N/A |
| リトライ統治撤去 | 失敗ループ・暴走・人間介入頻度 | plan-issue/dev-loop 双方とも1周収束、人間介入は判断依頼2件のみ。失敗ループ・暴走の発生なし | 後退なし（本Issue規模では発動条件未満、観察対象事象なし） |
| 振動検知撤去 | 同一箇所の往復編集 | 初回実装フェーズでは同一箇所の往復編集なし（追記のみ、修正なし）。ただし**レビュー往復軸**では同一ファイル `plugins/dev-workflow/skills/dev-loop/references/phase0-input-detection.md` を C4→C5 で連続修正（修正→指摘→再修正）の振動が発生。「振動」の定義により評価が分岐する | 初回実装フェーズ: 後退なし / レビュー往復軸: 軽度の振動あり（実害なし、3周で収束）。撤去機構（自前 Phase 1c の交互破壊検知）はそもそも実装フェーズ内のループを対象としており、レビュー往復は対象外。本観察は **dev-workflow に「レビュー往復振動」軸の検知が必要かどうかを問う**追加発見 |
| レビュー契約（保持） | requesting-code-review が blocker を実際に検出したか | Critical/Important 0件、Minor 3件のみ（うち2件は誤検知）。レビュー契約12項目は全項目PASS。レビュアーは AC↔実装の対応・event-storming 整合性・前方互換性を一次情報で検証 | 機能した（false-positive 1件 = 末尾改行欠落の誤検知あり、ただし計画リスクには影響なし） |

## 結論

- **品質後退: なし**（本Issue規模・性質では撤去機構の発動条件に達する事象が発生せず、レビュー契約は機能した）
- 詳細:
  - writing-plans 委譲は preload 成功、dev-workflow plan-output-format と干渉なく両立
  - requesting-code-review 委譲は機能し、AC網羅性・整合性・前方互換性の検証で具体的な確認を実施
  - 接続契約（レビュー契約・判断依頼・検証方針）は委譲下でも保持
  - レビュアー1件の誤検知（末尾改行）はメインループ側で `od -An -c` 実測により即座に判定可能、深刻度調整機構は機能
- 別Issue化が必要な事項:
  - Minor 3「ステップ7再起動の任意性が読み手判断に委ねられる」→ 軽微、将来改修候補
  - Recommendation 2「#97 完了後の SKILL.md L183 リンク更新の追跡」→ #97 へフォローコメント投稿で対応済（[issuecomment-4757523062](https://github.com/kuchita-el/claude-shared-skills/issues/97#issuecomment-4757523062)）
  - ~~**dev-loop の plan 探索ロジック拡張**（#288 派生）: 再生成後の連番付きplan を見つけるロジックが必要。別Issue化候補~~ → **本PRで対応済**（C4 指摘経由、`phase0-input-detection.md` L32 修正）
  - **dev-workflow 接続契約改善**（観察1から）: レビュー契約の AC由来限定問題、「ステップ間整合性」「プロセス手順の具体性」「運用追跡可能性」の追加検討
  - **dev-loop SKILL.md への Phase 5 明文化**（観察「dev-loop SKILL.md への発見」から）: レビュー対応サイクルの接続契約明文化
  - **修正コミット後セルフレビュー契約の差別化**（観察5点目から）: 「初回実装レビュー」と「修正後レビュー」で契約を変える設計検討
  - **推奨案提示時の pros/cons 痕跡記録**（観察6点目から）: dogfood/レビュー応答時の推奨案根拠を観察ログに残す改善
  - **「レビュー往復振動」軸の検知**（撤去機構評価表 振動検知行から）: dev-workflow に新軸の検知メカニズムが必要かの設計検討
  - **dogfood テンプレと dev-loop Phase 構造の整合**（観察7点目から）: テンプレを dev-loop Phase 0〜5 に整合させる改修
- 観察制約:
  - TDD/テスト網羅性軸は本Issueでは観察不可（Markdown のみ）。当軸の観察は別Issue（実コードを含むリポでの追加観察）が必要
  - リトライ統治・振動検知の撤去影響は「発動条件未満で観察対象事象なし」止まり。撤去後退の有無を判定するには、レビュー往復が発生する規模・性質のIssueでの追加観察が必要
