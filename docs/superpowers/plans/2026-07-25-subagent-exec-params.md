# サブエージェント実行パラメータの統制 実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `dev-workflow` プラグインの全サブエージェントに `model` と `effort` を明示し、配布先の親セッション設定に依存せず役割ごとに定めた水準で動くようにする。

**Architecture:** サブエージェント定義の frontmatter を実行パラメータの単一の統制点とする。値は役割ごとの必要最小水準として選び、量が出る Issue 精査のみ許容最大水準として扱う。Agent tool に `effort` 引数がないため、現在 `subagent_type` 未指定で起動している Issue 精査には専用のサブエージェント定義を新設する。

**Tech Stack:** Markdown + YAML frontmatter。Claude Code のプラグイン機構（`plugins/dev-workflow/agents/`, `plugins/dev-workflow/skills/`）。

**Spec:** [docs/superpowers/specs/2026-07-25-subagent-exec-params-design.md](../specs/2026-07-25-subagent-exec-params-design.md)

## Global Constraints

- 割り当て値は spec の決定2に従う。`plan` は `model: opus` / `effort: xhigh`、`code-reviewer` / `plan-reviewer` / `test-designer` / `test-spec-validator` は `model: opus` / `effort: high`、`refactorer` は `model: sonnet` / `effort: high`、`issue-refiner` は `model: sonnet` / `effort: medium`
- 既存6エージェントの `model` は現行値から変更しない。追加するのは `effort` のみ
- `effort` は frontmatter の `model` の直後に置く
- ドキュメントおよび定義ファイル内のコメントは日本語で記述する
- サブエージェント定義の `description` は 200 字程度を目安とし、最長 300 字を超えない
- `allowed-tools` および `tools` は必要最小限に留める
- コミットメッセージは通常文体で書く。`-m` を複数回指定し、HEREDOC を使わない
- 各コミットの末尾に `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>` を付す

---

### Task 1: 既存6エージェントへの `effort` 明示

**Files:**
- Modify: `plugins/dev-workflow/agents/code-reviewer.md:4`
- Modify: `plugins/dev-workflow/agents/plan-reviewer.md:4`
- Modify: `plugins/dev-workflow/agents/plan.md:4`
- Modify: `plugins/dev-workflow/agents/refactorer.md:4`
- Modify: `plugins/dev-workflow/agents/test-designer.md:4`
- Modify: `plugins/dev-workflow/agents/test-spec-validator.md:4`

**Interfaces:**
- Consumes: なし
- Produces: 6エージェントが frontmatter に `effort` を持つ状態。Task 4 の README がこの値を参照する

- [ ] **Step 1: 現状を確認して effort が未設定であることを見る**

Run:

```bash
for f in plugins/dev-workflow/agents/*.md; do printf '%s: ' "$(basename "$f" .md)"; grep -hE '^(model|effort):' "$f" | tr '\n' ' '; echo; done
```

Expected: 各行に `model:` のみが現れ、`effort:` はどの行にも現れない。

```
code-reviewer: model: opus
plan-reviewer: model: opus
plan: model: opus
refactorer: model: sonnet
test-designer: model: opus
test-spec-validator: model: opus
```

- [ ] **Step 2: `code-reviewer.md` に `effort: high` を追加**

`model: opus` の直後の行に挿入する。編集後の frontmatter:

```yaml
---
name: code-reviewer
description: 差分を懐疑的にレビューする読み取り専用エージェント。要件充足・バグ/セキュリティ・規約違反・スコープ逸脱・コード重複・テスト品質をブロッカー/改善提案に分類して報告する。
model: opus
effort: high
color: green
---
```

- [ ] **Step 3: `plan-reviewer.md` に `effort: high` を追加**

```yaml
---
name: plan-reviewer
description: 実装プランを初見・独立の視点から懐疑的にレビューするエージェント。プランが参照するファイル・モジュールの実在を検証し、PASS/FAIL で判定する。
model: opus
effort: high
color: purple
---
```

- [ ] **Step 4: `plan.md` に `effort: xhigh` を追加**

`plan` のみ `xhigh` である。他の5本と値が異なる点に注意する。

```yaml
---
name: plan
description: Issue情報・補足指示・ベースブランチを入力に実装プランを生成するエージェント。計画骨格（マイクロタスク分解）を preload した superpowers writing-plans のメソドロジーで生成し、検証方針・判断依頼・AC↔テストケース対応表を dev-workflow 固有の接続契約として上乗せする。
model: opus
effort: xhigh
color: yellow
skills:
  - writing-plans
---
```

- [ ] **Step 5: `refactorer.md` に `effort: high` を追加**

`model` は `sonnet` のまま変更しない。

```yaml
---
name: refactorer
description: 確定済みコードの差分にリファクタリング観点を適用するエージェント。外部から見た振る舞いを変えず、テストが通る状態を維持しつつ内部構造を改善する。
model: sonnet
effort: high
color: blue
---
```

- [ ] **Step 6: `test-designer.md` に `effort: high` を追加**

```yaml
---
name: test-designer
description: 入力ソースからテスト仕様を設計する読み取り専用エージェント。テストコードは生成せず、検証すべき振る舞いをテストケース単位の仕様に変換する。
model: opus
effort: high
color: cyan
---
```

- [ ] **Step 7: `test-spec-validator.md` に `effort: high` を追加**

```yaml
---
name: test-spec-validator
description: テスト仕様を独立した視点から検証する読み取り専用エージェント。要件との突き合わせでカバレッジ不足・観点漏れ・仕様の誤読を検出する。
model: opus
effort: high
color: yellow
---
```

- [ ] **Step 8: 全6ファイルの値を検証**

Run:

```bash
for f in plugins/dev-workflow/agents/*.md; do printf '%s: ' "$(basename "$f" .md)"; grep -hE '^(model|effort):' "$f" | tr '\n' ' '; echo; done
```

Expected:

```
code-reviewer: model: opus effort: high
plan-reviewer: model: opus effort: high
plan: model: opus effort: xhigh
refactorer: model: sonnet effort: high
test-designer: model: opus effort: high
test-spec-validator: model: opus effort: high
```

`plan` だけが `xhigh` であること、`refactorer` だけが `sonnet` であることを目視で確認する。

- [ ] **Step 9: frontmatter が壊れていないことを確認**

Run:

```bash
for f in plugins/dev-workflow/agents/*.md; do printf '%s: ' "$(basename "$f" .md)"; awk 'NR==1 && /^---$/{ok=1} /^---$/{n++} END{print (ok && n>=2) ? "OK" : "BROKEN"}' "$f"; done
```

Expected: 全6行が `OK`。1行目が `---` で始まり、区切りが2本以上あることを確認する。

- [ ] **Step 10: コミット**

```bash
git add plugins/dev-workflow/agents/
git commit -m "feat(agents): サブエージェント6本に effort を明示" \
  -m "配布先の親セッション設定に依存せず、役割ごとに定めた水準で動くようにする。model は現行値から変更していない。" \
  -m "plan は探索と設計を伴うため xhigh、検証系4本と refactorer は high とした。" \
  -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `plan-issue` の `inherit` 記述の修正

`plan-issue` の SKILL.md は `plan-reviewer` の起動について「モデルは定義の `inherit` に従う」と述べているが、`plan-reviewer` の定義は `model: opus` を持つため実体と食い違っている。Task 1 で `effort` も加わったため、記述を実体に合わせる。

**Files:**
- Modify: `plugins/dev-workflow/skills/plan-issue/SKILL.md:117`

**Interfaces:**
- Consumes: Task 1 が確定した `plan-reviewer` の `model: opus` / `effort: high`
- Produces: なし

- [ ] **Step 1: 現状の記述を確認**

Run:

```bash
grep -n 'inherit' plugins/dev-workflow/skills/plan-issue/SKILL.md
```

Expected: 1件ヒットし、「モデルは定義の `inherit` に従う」を含む行が表示される。

- [ ] **Step 2: 記述を実体に合わせて修正**

該当箇所の現在の文:

```
Agent tool（`subagent_type: dev-workflow:plan-reviewer`）で起動する。モデルは定義の `inherit` に従う。Agent toolが使えない場合や起動に失敗した場合は、`plugins/dev-workflow/agents/plan-reviewer.md` の定義内容をプロンプト本文へ埋め込んでインラインで直接実行する（サブエージェント側からの定義ファイル再Readは行わない）。
```

これを次に置き換える:

```
Agent tool（`subagent_type: dev-workflow:plan-reviewer`）で起動する。モデルと effort は定義の frontmatter に従い、呼び出し側では指定しない。Agent toolが使えない場合や起動に失敗した場合は、`plugins/dev-workflow/agents/plan-reviewer.md` の定義内容をプロンプト本文へ埋め込んでインラインで直接実行する（サブエージェント側からの定義ファイル再Readは行わない）。
```

- [ ] **Step 3: `inherit` の記述が残っていないことを確認**

Run:

```bash
grep -rn 'inherit' plugins/dev-workflow/
```

Expected: 出力なし（終了コード 1）。

- [ ] **Step 4: コミット**

```bash
git add plugins/dev-workflow/skills/plan-issue/SKILL.md
git commit -m "fix(plan-issue): plan-reviewer の起動に関する記述を実体に合わせる" \
  -m "本文は inherit に従うと述べていたが、plan-reviewer の定義は model を明示している。記述と実体が食い違っており読み手を誤らせるため修正する。" \
  -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `issue-refiner` の新設と `refine-issue` の起動形変更

`refine-issue` は `subagent_type` を指定せず Agent tool を直接呼んでおり、既定の general-purpose で動く。Agent tool の引数に `effort` がないため、この形では `effort: medium` を実現できない。専用のサブエージェント定義を新設し、`subagent_type` 指定での起動に改める。

**Files:**
- Create: `plugins/dev-workflow/agents/issue-refiner.md`
- Modify: `plugins/dev-workflow/skills/refine-issue/SKILL.md:73`（1件モード・`--input` モード）
- Modify: `plugins/dev-workflow/skills/refine-issue/SKILL.md:98`（全件モード）

**Interfaces:**
- Consumes: なし
- Produces: サブエージェント識別子 `dev-workflow:issue-refiner`（`model: sonnet` / `effort: medium` / `tools: Read, Glob`）。Task 4 の README がこの値を参照する

- [ ] **Step 1: 新設前の状態を確認**

Run:

```bash
ls plugins/dev-workflow/agents/ && grep -nE 'モデル(は親と同じ|: `sonnet`)' plugins/dev-workflow/skills/refine-issue/SKILL.md
```

Expected: `issue-refiner.md` は存在せず、SKILL.md の2箇所（1件モードの「モデルは親と同じ」、全件モードの「モデル: `sonnet`」）がヒットする。

- [ ] **Step 2: `issue-refiner.md` を作成**

精査手順は `references/refine-prompt.md` にあり、プロンプトはメイン側で組み立てるため、定義本文は役割と参照先の明示に留める。手順を二重に書かない。

ツールは `Read` と `Glob` に限定する。精査は Issue の JSON、DoR 定義、種別プロファイル、出力形式テンプレート、精査手順を読むだけで完結し、`Glob` はプロジェクト固有 DoR の存在確認に用いる。

```markdown
---
name: issue-refiner
description: Issue の DoR（Definition of Ready）を精査する読み取り専用エージェント。渡された Issue 情報と DoR 定義・種別プロファイルを突き合わせ、不足項目・確認事項・分割提案を指定された出力形式で返却する。
model: sonnet
effort: medium
color: orange
tools:
  - Read
  - Glob
---

# issue-refiner サブエージェント

Issue の DoR（Definition of Ready）を精査する読み取り専用のサブエージェント。

## 姿勢

精査対象の Issue が「着手できる状態にある」と仮定しない。DoR 定義と突き合わせ、不足している項目を見つけ出す。一部の項目が充足しているだけで Ready と判定しない。

## ツール制限

読み取り専用ツールのみ使用する。Issue の更新・ファイルの作成や編集は一切行わない。精査結果は返却値として返す。

## 手順

精査手順・判定基準・出力形式は、起動プロンプトで渡されるパスから読み取る。本ファイルには手順を再掲しない。

プロンプトで渡されるもの:

- スキルディレクトリパス — 精査手順（`references/refine-prompt.md`）と出力形式テンプレートの参照に使う
- プラグインルートパス — 共有の DoR 定義と種別プロファイルの参照に使う
- プロジェクトルートパス — プロジェクト固有の DoR 定義と種別プロファイルの参照に使う。存在すれば共有のものより優先する
- 精査対象の Issue 情報

読み取ったこれらの手順に従って精査し、指定された出力形式で結果を返却する。
```

- [ ] **Step 3: 1件モード・`--input` モードの起動記述を変更**

`SKILL.md` の該当箇所の現在の文:

```
メイン側で以下のパス・識別子を文字列で組み立て、Agent tool を1回起動する（参照ファイル本文の埋め込みは行わない。全件モードと同型のパス渡し）。モデルは親と同じ。
```

これを次に置き換える:

```
メイン側で以下のパス・識別子を文字列で組み立て、Agent tool（`subagent_type: dev-workflow:issue-refiner`）を1回起動する（参照ファイル本文の埋め込みは行わない。全件モードと同型のパス渡し）。モデルと effort は定義の frontmatter に従い、呼び出し側では指定しない。
```

- [ ] **Step 4: 全件モードの起動記述を変更**

該当箇所の現在の文:

```
3. バッチごとに Agent tool を直接呼び出す（**最大3並列、モデル: `sonnet`**）
```

これを次に置き換える:

```
3. バッチごとに Agent tool（`subagent_type: dev-workflow:issue-refiner`）を呼び出す（**最大3並列**。モデルと effort は定義の frontmatter に従い、呼び出し側では指定しない）
```

最大3並列の制約は維持する。直下の注意書き2件（Bash の for / while で生成しない、複数呼び出しは Agent tool を直接複数回呼び出す形で記述する）はそのまま残す。

- [ ] **Step 5: 変更後の記述を検証**

Run:

```bash
grep -nE 'issue-refiner|モデルは親と同じ|モデル: `sonnet`' plugins/dev-workflow/skills/refine-issue/SKILL.md
```

Expected: `subagent_type: dev-workflow:issue-refiner` を含む行が2件ヒットし、「モデルは親と同じ」と「モデル: `sonnet`」はヒットしない。

- [ ] **Step 6: 最大3並列の記述が残っていることを確認**

Run:

```bash
grep -n '最大3並列' plugins/dev-workflow/skills/refine-issue/SKILL.md
```

Expected: 1件ヒットする。

- [ ] **Step 7: 全7エージェントの値を検証**

Run:

```bash
for f in plugins/dev-workflow/agents/*.md; do printf '%s: ' "$(basename "$f" .md)"; grep -hE '^(model|effort):' "$f" | tr '\n' ' '; echo; done
```

Expected:

```
code-reviewer: model: opus effort: high
issue-refiner: model: sonnet effort: medium
plan-reviewer: model: opus effort: high
plan: model: opus effort: xhigh
refactorer: model: sonnet effort: high
test-designer: model: opus effort: high
test-spec-validator: model: opus effort: high
```

- [ ] **Step 8: 手動確認 — エージェントがロードされること**

`./setup-local.sh` で Claude Code を起動し、`@agent-dev-workflow:issue-refiner` を入力して補完候補に現れることを確認する。現れない場合は frontmatter の YAML が壊れているか `name` が不一致である。

この手順は対話が必要なため自動化しない。確認できたら次へ進む。

- [ ] **Step 9: コミット**

```bash
git add plugins/dev-workflow/agents/issue-refiner.md plugins/dev-workflow/skills/refine-issue/SKILL.md
git commit -m "feat(agents): Issue 精査用の issue-refiner を新設し refine-issue の起動形を変更" \
  -m "refine-issue は subagent_type を指定せず Agent tool を呼んでおり、Agent tool には effort 引数がないため effort を制御できなかった。専用定義を新設して subagent_type 指定での起動に改める。" \
  -m "量が出る役割のため、値は許容最大水準として model: sonnet / effort: medium とした。あわせてツールを読み取り専用の Read と Glob に絞る。" \
  -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `dev-workflow` プラグインの README 新設

利用者に対し、各サブエージェントの実行パラメータとその意図、および環境変数による上書き手段を案内する。

**Files:**
- Create: `plugins/dev-workflow/README.md`

**Interfaces:**
- Consumes: Task 1 と Task 3 が確定した全7エージェントの `model` / `effort`
- Produces: なし

- [ ] **Step 1: 既存の README の書式を確認**

Run:

```bash
head -20 plugins/adr/README.md
```

Expected: `adr` プラグインの README の冒頭が表示される。見出しの階層と文体を揃えるための参照であり、内容を写すわけではない。

- [ ] **Step 2: `README.md` を作成**

プラグイン全体の紹介は数行に留め、実行パラメータの節を主体とする。

```markdown
# dev-workflow

Issue の起票から計画・実装・レビューまでを支援するスキルとサブエージェントを提供するプラグイン。GitHub CLI（`gh`）以外のプロジェクト固有ツールには依存しない。

スキルの一覧と使い分けは各 `skills/{name}/SKILL.md` の `description` を参照。

## サブエージェントの実行パラメータ

本プラグインのサブエージェントは、`model` と `effort` を定義ファイルの frontmatter で明示している。配布先の親セッションがどのモデル・どの effort で動いていても、各サブエージェントは以下の値で動く。

| サブエージェント | `model` | `effort` | 値の意図 |
|---|---|---|---|
| `plan` | `opus` | `xhigh` | 必要最小水準 |
| `code-reviewer` | `opus` | `high` | 必要最小水準 |
| `plan-reviewer` | `opus` | `high` | 必要最小水準 |
| `test-designer` | `opus` | `high` | 必要最小水準 |
| `test-spec-validator` | `opus` | `high` | 必要最小水準 |
| `refactorer` | `sonnet` | `high` | 必要最小水準 |
| `issue-refiner` | `sonnet` | `medium` | 許容最大水準 |

「必要最小水準」は、その役割が成立するために必要な下限として選んだ値である。セッション側でこれより低い設定を使っていても、その値までは引き上げられる。

「許容最大水準」は逆に、その役割に対して許容する上限として選んだ値である。`issue-refiner` は Issue 精査を担い、全件モードでは 15 件 × 最大 3 並列と処理量が出るため、セッション側で高い設定を使っていても抑制する。

### 値を上書きする

環境変数は frontmatter より優先される。プラグイン側の設定を変えずに、セッション全体で異なる値を使いたい場合に用いる。

| 環境変数 | 効果 |
|---|---|
| `CLAUDE_CODE_SUBAGENT_MODEL` | 全サブエージェントのモデルを指定した値にする |
| `CLAUDE_CODE_EFFORT_LEVEL` | 全サブエージェントの effort を指定した値にする |

いずれも全サブエージェントに一律で効くため、役割ごとに個別の値を与えることはできない。

Fable 5 のような、より能力の高いモデルで動かしたい場合は `CLAUDE_CODE_SUBAGENT_MODEL=fable` を設定する。本プラグインは既定では Fable 5 を採用していない。単発の生成・検証という各役割の性質に対して価格が見合わないためであり、必要とする利用者が明示的に選ぶ形としている。
```

- [ ] **Step 3: 表の値が定義ファイルと一致することを検証**

Run:

```bash
for f in plugins/dev-workflow/agents/*.md; do printf '%s: ' "$(basename "$f" .md)"; grep -hE '^(model|effort):' "$f" | tr '\n' ' '; echo; done
```

Expected: Task 3 の Step 7 と同じ7行が出力される。この出力と README の表を1行ずつ突き合わせ、7エージェントすべての `model` と `effort` が一致することを確認する。

- [ ] **Step 4: コミット**

```bash
git add plugins/dev-workflow/README.md
git commit -m "docs(dev-workflow): プラグイン README を新設し実行パラメータを案内" \
  -m "各サブエージェントの model と effort、その値を必要最小水準として選んだか許容最大水準として選んだかを表で示す。" \
  -m "あわせて CLAUDE_CODE_SUBAGENT_MODEL と CLAUDE_CODE_EFFORT_LEVEL による上書き手段と、Fable 5 を既定に採らなかった理由を記載する。" \
  -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: ADR の起票

spec の ADR 化判定で 3 点（波及・揮発性・自動強制不可）に達しており、モデル系統の更新は再発が確実である。決定と根拠を ADR に記録する。

**Files:**
- Create: `docs/adr/ADR-<日付>-<slug>.md`（採番と命名は `manage-adr` スキルの規約に従う）

**Interfaces:**
- Consumes: Task 1 から Task 4 で確定した全変更
- Produces: なし

- [ ] **Step 1: `manage-adr` スキルを起動する**

`Skill` ツールで `adr:manage-adr` を起動し、新規起票の手順に従う。採番方式・front-matter スキーマ・テンプレートはスキル側の規約に従い、本プランで独自に定義しない。

- [ ] **Step 2: ADR の内容を渡す**

1 本の ADR にまとめ、次を含める。

**決定:** 配布用プラグインのサブエージェントについて、実行パラメータ（`model` / `effort`）を frontmatter で固定値として明示し、値を役割ごとの必要最小水準として選ぶ。処理量が出る役割のみ許容最大水準として扱う。

**背景と根拠:**

- 配布物であり利用者の親セッション設定が不定であるため、`effort` を無指定にすると各サブエージェントの思考深度が利用者側の設定に従属する。検証系のサブエージェントが低い effort で見落としを出した場合、それはプラグインの欠陥として現れる
- frontmatter は固定値しか表現できず、下限を表す機構は存在しない。必要最小水準を保証すれば、それを上回る設定の利用者を引き下げる副作用が生じる
- この副作用は許容する。環境変数は frontmatter より優先され、`max` はセッション限定で永続しないため、影響は「そのセッションで `/effort max` を選び、かつサブエージェントを起動した」場合に限られる

**却下・見送りとした選択肢:**

- `model: inherit` として親セッションに追随させる案 — 親の設定が不定であるため、検証系が Haiku（effort 非対応、文脈長 20 万トークン）で動く可能性を排除できない
- 判断・検証系のみ `effort` を継承のままにする案 — 高価なモデルを浅い思考で動かす組み合わせが生じる
- Fable 5 の採用 — 現行の役割はいずれも単発の生成・検証であり、長時間の自律実行を想定した価格に見合わない。`CLAUDE_CODE_SUBAGENT_MODEL` による選択を案内する
- `maxTurns` の導入 — 適正値の根拠がなく、低すぎれば処理の途中終了として現れる。観測手段を得た段階で再検討する
- スキル frontmatter への実行パラメータ配置 — 効果がターン単位に限られ、対話を伴うスキルでは最初のターンにしか効かない。統制点はサブエージェント側に集約する
- `context: fork` の導入 — 実行パラメータではなく文脈設計の論点であり、本 ADR の対象外とする

- [ ] **Step 3: `lint-adr` で自己検証する**

`manage-adr` スキルの手順に従い、起票後の lint を実行する。front-matter のスキーマ違反や相互参照の不整合が報告された場合は修正する。

- [ ] **Step 4: 索引を更新してコミット**

`manage-adr` スキルの手順に従って索引を再生成し、ADR 本体とあわせてコミットする。コミットメッセージは通常文体で書き、`Co-Authored-By` を付す。

---

## 完了確認

全タスク完了後、次を確認する。

- [ ] **自動確認を実行する**

Run:

```bash
for f in plugins/dev-workflow/agents/*.md; do printf '%s: ' "$(basename "$f" .md)"; grep -hE '^(model|effort):' "$f" | tr '\n' ' '; echo; done
grep -rn 'inherit' plugins/dev-workflow/
grep -rnE 'モデルは親と同じ|モデル: .sonnet.' plugins/dev-workflow/
git log --oneline -6
```

Expected: 1つ目が7エージェント分を出力する。2つ目と3つ目は何も出力しない（終了コード 1）。4つ目に Task 1 から Task 5 のコミットが並ぶ。

- [ ] **README の表と定義ファイルを突き合わせる**

上の1つ目の出力7行と、`plugins/dev-workflow/README.md` の実行パラメータ表を1行ずつ照合し、`model` と `effort` がすべて一致することを確認する。

- [ ] **手動確認 — 配布先の環境に依存しないこと**

spec の「検証項目」節の1つ目に対応する。次の3通りで Claude Code を起動し、いずれの場合もサブエージェントが frontmatter の値で動くことを確認する。セッションヘッダにはモデル名と effort が表示されるため、親側の設定を確認したうえでサブエージェントを起動する。

| 起動方法 | 期待する挙動 |
|---|---|
| `./setup-local.sh` を実行後、`/model` で Sonnet 5 を選択 | `code-reviewer` などは `opus` で動く |
| `claude --effort low --plugin-dir ./plugins/dev-workflow --plugin-dir ./plugins/adr` | サブエージェントは frontmatter の値で動き、`low` に引きずられない |
| `CLAUDE_CODE_EFFORT_LEVEL=low ./setup-local.sh` | 環境変数が優先され、全サブエージェントが `low` で動く |

3つ目のみ frontmatter より環境変数が優先されるため、挙動が変わることが期待値である。

- [ ] **手動確認 — `issue-refiner` の精査品質**

spec の「検証項目」節の2つ目に対応する。同一の Issue に対して変更前（`git stash` や別ワークツリーの main 側）と変更後で `refine-issue` を実行し、次を確認する。

- DoR の不足項目として検出される項目の集合が一致すること。差分がある場合は、その項目が実際に不足しているかを人手で確認する
- 出力が `output-format-single.md` および `output-format-batch-subagent.md` の形式に沿っていること
- `Read` と `Glob` のみで手順が完走し、ツール不足によるエラーが出ないこと
