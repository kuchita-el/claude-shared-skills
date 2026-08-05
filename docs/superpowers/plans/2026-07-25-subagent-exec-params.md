# サブエージェント実行パラメータの統制 実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `dev-workflow` プラグインの全サブエージェントに `model` と `effort` を明示し、配布先の親セッション設定に依存せず役割ごとに定めた水準で動くようにする。

**Architecture:** サブエージェント定義の frontmatter を実行パラメータの単一の統制点とする。値は役割ごとの必要最小水準として選び、量が出る Issue 精査のみ許容最大水準として扱う。Agent tool に `effort` 引数がないため、現在 `subagent_type` 未指定で起動している Issue 精査には専用のサブエージェント定義を新設する。

文書は役割で分ける。規約の正本は `references/subagent-execution-parameters.md`、利用者向けの現行値一覧は `README.md`、判断と却下した選択肢の記録は ADR 2 本に置く。値の実体は front-matter であり、正本には値を転記しない。

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

### Task 4: 規約の正本を新設し `CLAUDE.md` からポインタを張る

本リポジトリでエージェントを追加・変更する者に向けて、実行パラメータの規約を単一出典として置く。値の一覧は持たせない。実体は front-matter であり、同じ値を複数の文書に持たせれば drift の源になる。

**Files:**
- Create: `plugins/dev-workflow/references/subagent-execution-parameters.md`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: Task 1 と Task 3 が確定した front-matter の構成
- Produces: 規約の正本。Task 6 の ADR がこの文書を参照する

- [ ] **Step 1: 既存の references の書式を確認**

Run:

```bash
head -12 plugins/dev-workflow/references/context-budget.md
```

Expected: 冒頭に単一出典であることを述べる文がある。見出しの階層と文体を揃えるための参照であり、内容を写すわけではない。

- [ ] **Step 2: `subagent-execution-parameters.md` を作成**

```markdown
# サブエージェント実行パラメータ規約（subagent-execution-parameters.md）

サブエージェントの `model` と `effort` をどこに置き、どのような意図で値を選ぶかを定める。本ファイルがこの規約の実体であり、統制点・選定基準をここ以外で独自に再定義しない。

## 統制点

実行パラメータは `agents/{name}.md` の front-matter に置く。SKILL.md の front-matter には置かない。

スキル側に置かない理由は `model` と `effort` で異なる。`effort` は効果がそのターンに限られ、対話や承認の待ち合わせで複数のターンにまたがるスキルでは最初のターンにしか効かない。`model` は逆に次のプロンプト以降も持続し、スキルを1度起動するとセッションのモデルが書き換わったまま残る。効かないことと、意図しない範囲まで効き続けることは、いずれも統制点をスキル側へ置かない理由になる。

またサブエージェント側を明示している以上、スキル側の指定はサブエージェントの実行には届かない（解決順で front-matter が優先される）。この到達可否は `model` と `effort` で共通である。統制点を 2 箇所に分散させれば、どちらが効いているかの追跡が難しくなる。

## 値を省略しない

配布物であり利用者の親セッションがどのモデル・どの effort で動いているかは不定である。`effort` を省略すると、各サブエージェントの思考深度は利用者側の設定に従属する。検証を担うサブエージェントが低い effort で見落としを出した場合、それは利用者の設定ミスではなくプラグインの欠陥として現れる。

## 値の選定基準

front-matter が表現できるのは固定値のみであり、下限や上限を表す機構は存在しない。したがって値は次のいずれかの意図で選ぶ。

| 意図 | 選び方 | 適用する役割 |
|---|---|---|
| 必要最小水準 | その役割が成立するために必要な下限として選ぶ | 生成・検証など、品質が成果を左右する役割 |
| 許容最大水準 | その役割に対して許容する上限として選ぶ | 定型性が高く、処理量が出る役割 |

必要最小水準を選べば、それを上回る設定で動かしている利用者を引き下げる副作用が生じる。これは許容する。環境変数は front-matter より優先され、`max` はセッション限定で永続しないため、影響は「そのセッションで `/effort max` を選び、かつサブエージェントを起動した」場合に限られる。

## 実装上の制約

`effort` を指定できるのは front-matter を持つ登録済みのサブエージェントに限られる。Agent tool の引数に `effort` は存在しない（引数は `description` / `isolation` / `model` / `prompt` / `run_in_background` / `subagent_type`）。

したがってスキルから `subagent_type` を指定せずに Agent tool を呼ぶ形では `effort` を制御できない。effort を制御したい役割には、専用のサブエージェント定義を設ける。

## 新規サブエージェントを追加するとき

1. `model` と `effort` を front-matter に明示する。省略しない
2. 値の意図（必要最小水準か許容最大水準か）を決め、`README.md` の表に追記する
3. `tools` を必要最小限に絞る

## 現行の値

各 `agents/{name}.md` の front-matter が権威である。一覧は [README](../README.md) を参照。本ファイルには値を転記しない。
```

- [ ] **Step 3: `CLAUDE.md` にポインタ節を追加**

`## スキル設計の token 規律` 節の直後、`## Rules` 節の直前に次を挿入する。

```markdown
## サブエージェントの実行パラメータ

サブエージェントの `model` / `effort` をどこに置き、どのような意図で値を選ぶかは `plugins/dev-workflow/references/subagent-execution-parameters.md` に単一出典化している。新規サブエージェントを追加する際は `model` と `effort` を front-matter に必ず明示する（本節へ転記しない）。
```

- [ ] **Step 4: 挿入位置と参照の整合を検証**

Run:

```bash
grep -n '^## ' CLAUDE.md
ls plugins/dev-workflow/references/
grep -c 'subagent-execution-parameters' CLAUDE.md
```

Expected: 1つ目で `## サブエージェントの実行パラメータ` が `## スキル設計の token 規律` の後、`## Rules` の前に現れる。2つ目に `subagent-execution-parameters.md` が含まれる。3つ目が `1`。

- [ ] **Step 5: コミット**

```bash
git add plugins/dev-workflow/references/subagent-execution-parameters.md CLAUDE.md
git commit -m "docs(dev-workflow): 実行パラメータ規約の正本を新設" \
  -m "統制点の所在、値の選定基準、実装上の制約、新規追加時の手順を単一出典として置く。context-budget.md と同じく references 配下に規約の正本を置く既存の構成に合わせる。" \
  -m "現行の値は転記せず、front-matter を権威として README を参照させる。CLAUDE.md には正本へのポインタのみを置く。" \
  -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: `dev-workflow` プラグインの README 新設

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

> 以下の表は本タスク実行時点のもの。`issue-refiner` の値はその後の実測を受けて変更し、全件モード用に `issue-refiner-batch` を分離した。最終形は末尾「手動確認の実施結果」→「対応」を参照。

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

### Task 6: ADR の起票（2 本）

spec の ADR 化判定に従い、独立に反転しうる 2 つの core をそれぞれ ADR に記録する。1 本にまとめない。

**Files:**
- Create: `docs/adr/ADR-<日付>-<slug-α>.md`
- Create: `docs/adr/ADR-<日付>-2-<slug-β>.md`（同日 2 件目のため `-2` を付す）
- Modify: `CLAUDE.md`
- Modify: `plugins/dev-workflow/references/subagent-execution-parameters.md`
- Modify: `docs/adr/index.md`（`manage-adr` が再生成する）

採番方式・front-matter スキーマ・テンプレートは `manage-adr` スキルの規約に従い、本プランで独自に定義しない。slug は内容を表す英数字ハイフン区切りとする。

**Interfaces:**
- Consumes: Task 1 から Task 5 で確定した全変更
- Produces: 2 本の ADR の full slug。Step 5 で `CLAUDE.md` と正本に追記する

- [ ] **Step 1: `manage-adr` スキルで ADR-α を起票する**

`Skill` ツールで `adr:manage-adr` を起動し、新規起票の手順に従って次の内容を渡す。

**タイトル:** サブエージェントの実行パラメータを front-matter で固定し役割ごとの必要水準として選ぶ

**Context:**

- 本リポジトリの成果物は配布用プラグインであり、利用者の親セッションがどのモデル・どの effort で動いているかは不定である
- `effort` を省略すると各サブエージェントの思考深度が利用者側の設定に従属する。検証を担うサブエージェントが低い effort で見落としを出した場合、それは利用者の設定ミスではなくプラグインの欠陥として現れる
- front-matter が表現できるのは固定値のみであり、下限や上限を表す機構は存在しない。組織単位の effort 上限は Enterprise 向けの管理者設定として存在するが、これは上限のみである
- モデル系統の更新は繰り返される。今回の検討自体、前回の選定根拠が残っていなかったため一から議論をやり直したものである

**Decision:**

サブエージェントの `model` と `effort` を親セッションから継承させず、front-matter で固定値として明示する。値は役割ごとの必要最小水準として選ぶ。定型性が高く処理量が出る役割のみ、許容最大水準として選ぶ。

**Consequences:**

- 必要最小水準を保証する結果、それを上回る設定で動かしている利用者を引き下げる副作用が生じる。これは許容する。環境変数（`CLAUDE_CODE_SUBAGENT_MODEL` / `CLAUDE_CODE_EFFORT_LEVEL`）は front-matter より優先され、`max` はセッション限定で永続しないため、影響は「そのセッションで `/effort max` を選び、かつサブエージェントを起動した」場合に限られる
- Agent tool の引数に `effort` が存在しないため、effort を制御したい役割には登録済みのサブエージェント定義が必要になる。スキルから `subagent_type` を指定せず Agent tool を呼ぶ形では effort を制御できない
- 規約の正本は `plugins/dev-workflow/references/subagent-execution-parameters.md` に置く。現行の値は各 `agents/{name}.md` の front-matter が権威であり、一覧は `plugins/dev-workflow/README.md` が持つ

**却下した選択肢:**

- `model: inherit` として親セッションに追随させる — 親の設定が不定であるため、検証を担うサブエージェントが Haiku（effort 非対応、文脈長 20 万トークン）で動く可能性を排除できない
- `effort` を指定せずセッション継承のままにする — 配布先の環境によって挙動が変わるという課題が解決しない
- 判断・検証系のみ `effort` を継承のままにする — 高価なモデルを浅い思考で動かす組み合わせが生じ、消費の効率が最も悪い状態になる
- 全サブエージェントで `model` を揃え `effort` のみで差をつける — モデル間の単価差を取り逃す
- Fable 5 を既定に採用する — 現行の役割はいずれも単発の生成・検証であり、長時間の自律実行を想定した価格に見合わない。必要とする利用者は `CLAUDE_CODE_SUBAGENT_MODEL` で選択できる
- `maxTurns` を導入する — 適正値を決める根拠がなく、低すぎれば処理の途中終了として現れる。これは消費の削減ではなく品質の劣化である

**保留した決定:** なし。節を置かない。

- [ ] **Step 2: `manage-adr` スキルで ADR-β を起票する**

同じ手順で 2 本目を起票する。同日 2 件目のため識別子は `-2` を付す。

**タイトル:** 実行パラメータの統制点をサブエージェント定義に集約する

**Context:**

- SKILL.md の front-matter も `model` と `effort` を受け付けるため、統制点をスキル側に置く選択肢が存在する
- スキル側の指定の持続範囲は `model` と `effort` で異なる。2026-08-05 時点の実測（ヘッドレス経路、スキル起動ターンとその次のターンまで観測）では、`effort` は効果がそのターンに限られ次のプロンプトでセッション値へ戻る一方、`model` は次のプロンプト以降も持続しセッションのモデルを書き換えたまま残った

**Decision:**

実行パラメータは `agents/{name}.md` の front-matter にのみ置く。SKILL.md の front-matter には `model` と `effort` を置かない。

**Consequences:**

- 対話や承認の待ち合わせで複数のターンにまたがるスキル（`create-issue` / `domain-modeling` / `event-storming` / `plan-issue` / `manage-adr` / `intake` / `implementation`）でも、統制が一貫する
- サブエージェント側を明示している以上、スキル側の指定はサブエージェントの実行には届かない（解決順で front-matter が優先される）。統制点を 2 箇所に分散させれば、どちらが効いているかの追跡が難しくなる
- 本決定の下では、スキルのメイン側処理（バッチ分割・結果集約・整形）は親セッションの設定で動く。スキル front-matter の `model` を置けば下げること自体は可能だが、`model` は持続するため効果が以降のセッション全体へ波及する

**保留した決定:**

- `context: fork` の導入。スキル本文をサブエージェントの指示として実行しメイン側の文脈消費を抑える機構だが、実行パラメータではなく文脈設計の論点であり本 ADR では決めない（想定継承先: S3 規律再設定層、または独立した課題として起票）

- [ ] **Step 3: 相互参照を設定する**

両 ADR の `## 関連ADR` 節に、互いを `Related` として記載する。上書き関係ではないため `Supersedes` / `Superseded by` は使わない。

```
- Related: <相手の full slug>（実行パラメータの統制に関する独立した core。上書きでない）
```

- [ ] **Step 4: `lint-adr` で自己検証する**

`manage-adr` スキルの手順に従って lint を実行する。front-matter のスキーマ違反、相互参照の不整合、`Related` が指す slug の実在性が検査される。報告があれば修正する。

- [ ] **Step 5: `CLAUDE.md` と正本に ADR の full slug を追記する**

`context-budget.md` が `CLAUDE.md` から `（ADR-202606270040-01）` の形で参照されているのと同じ形に揃える。

`CLAUDE.md` の「サブエージェントの実行パラメータ」節を次に更新する（`<slug-α>` / `<slug-β>` は Step 1・Step 2 で確定した full slug に置き換える）。

```markdown
## サブエージェントの実行パラメータ

サブエージェントの `model` / `effort` をどこに置き、どのような意図で値を選ぶかは `plugins/dev-workflow/references/subagent-execution-parameters.md` に単一出典化している（ADR-<slug-α> / ADR-<slug-β>）。新規サブエージェントを追加する際は `model` と `effort` を front-matter に必ず明示する（本節へ転記しない）。
```

正本 `subagent-execution-parameters.md` の末尾に次の節を追加する。

```markdown
## 関連

- ADR-<slug-α> — 実行パラメータを固定し役割ごとの必要水準として選ぶ決定
- ADR-<slug-β> — 統制点をサブエージェント定義に集約する決定
```

- [ ] **Step 6: 索引を再生成してコミット**

`manage-adr` スキルの手順に従って `docs/adr/index.md` を再生成する。索引は front-matter から機械生成される導出ビューであり、人手編集しない。

```bash
git add docs/adr/ CLAUDE.md plugins/dev-workflow/references/subagent-execution-parameters.md
git commit -m "docs(adr): 実行パラメータの統制方針を ADR 2 本に記録" \
  -m "独立に反転しうる 2 つの core を分けて起票する。1 本目は実行パラメータを front-matter で固定し役割ごとの必要水準として選ぶ決定、2 本目は統制点をサブエージェント定義に集約する決定。" \
  -m "context: fork の導入は 2 本目の保留した決定に記録した。maxTurns は後で決着させる必要のある未決事項ではないため却下した選択肢として扱う。" \
  -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## 完了確認

全タスク完了後、次を確認する。

- [ ] **自動確認を実行する**

Run:

```bash
for f in plugins/dev-workflow/agents/*.md; do printf '%s: ' "$(basename "$f" .md)"; grep -hE '^(model|effort):' "$f" | tr '\n' ' '; echo; done
grep -rn 'inherit' plugins/dev-workflow/
grep -rnE 'モデルは親と同じ|モデル: .sonnet.' plugins/dev-workflow/
ls plugins/dev-workflow/README.md plugins/dev-workflow/references/subagent-execution-parameters.md
grep -c 'subagent-execution-parameters' CLAUDE.md
git log --oneline -7
```

Expected: 1つ目が7エージェント分を出力する。2つ目と3つ目は何も出力しない（終了コード 1）。4つ目が2ファイルとも存在すると出力する。5つ目が `1`。6つ目に Task 1 から Task 6 のコミットが並ぶ。

- [ ] **README の表と定義ファイルを突き合わせる**

上の1つ目の出力7行と、`plugins/dev-workflow/README.md` の実行パラメータ表を1行ずつ照合し、`model` と `effort` がすべて一致することを確認する。

- [ ] **文書間の参照が閉じていることを確認する**

- `CLAUDE.md` の「サブエージェントの実行パラメータ」節が正本と 2 本の ADR を指している
- 正本の「関連」節が 2 本の ADR を指している
- 正本が値を転記しておらず、README を参照させている
- 2 本の ADR が互いを `Related` で参照している

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

---

## 手動確認の実施結果（2026-07-25）

### 観測方法

サブエージェントの実効値は自己申告ではなく、セッション記録から取得した。

- 実効 `model` / `effort`: `~/.claude/projects/{project}/{session-id}/subagents/agent-*.jsonl` の各アシスタントエントリが持つ `.message.model` と `.effort`
- 起動されたエージェント種別: 同ディレクトリの `agent-*.meta.json` の `.agentType`

親セッションの設定を変える3条件は、対話セッションの `/model` 切り替えや再起動ではなく `claude -p`（ヘッドレス）で再現した。`--model` / `--effort` / `--plugin-dir` がいずれもヘッドレスで有効なため、条件ごとに独立したセッションを作れる。

### 結果1: エージェントのロード（Task 3 Step 8）

`issue-refiner` がエージェント一覧・補完候補に出ることを目視で確認した。合格。

### 結果2: 配布先の環境に依存しないこと

| 起動条件 | 親の実測値 | 起動したサブエージェント | サブエージェントの実測値 | 判定 |
|---|---|---|---|---|
| `--model sonnet` | `claude-sonnet-5` / `xhigh` | `code-reviewer` | `claude-opus-5` / `high` | 期待どおり（front-matter が親を上書きし、モデルは引き上げられた） |
| `--effort low` | `claude-opus-5` / `low` | `refactorer` | `claude-sonnet-5` / `high` | 期待どおり（親の `low` に引きずられない） |
| `CLAUDE_CODE_EFFORT_LEVEL=low` | `claude-opus-5` / `low` | `refactorer` | `claude-sonnet-5` / `low` | 期待どおり（環境変数が front-matter に優先） |

2行目と3行目は同一エージェント・同一の親モデルで `effort` の供給元だけが異なる対照条件であり、`high` と `low` の差がそのまま現れた。3条件とも合格。

### 結果3: `issue-refiner` の精査品質（対象 Issue #509）

変更前（main のプラグインを `--plugin-dir` で読み込み）と変更後（本ブランチ）で、親モデルを `opus` に揃えて同一 Issue を精査させた。変更前は `general-purpose` が親追随で `claude-opus-5` / `xhigh`、変更後は `dev-workflow:issue-refiner` が front-matter どおり `claude-sonnet-5` / `medium` で動いた。

| 判定基準 | 結果 |
|---|---|
| `Read` と `Glob` のみで完走し、ツール不足のエラーが出ない | 合格。2回とも `Read` 5回・`Glob` 2回のみでエラーなし。`gh` の実行はメイン側（`Bash` 3回）に残り、役割分離も設計どおり |
| 出力が `output-format-single.md` の形式に沿う | おおむね合格。2回目のみ最上位見出しが `#`（規定は `##`）という軽微な逸脱 |
| DoR の不足項目の集合が変更前と一致する | 不合格 |

Ready 判定（Not Ready）、要分割、主要ブロッカー（#508 との順序未確定、拘束手段が未決のため見積もり不能）は変更前後で一致した。一致しなかったのは受入条件レベルの精査深度であり、変更後が2回とも見落とした次の項目は、Issue 本文および実ファイルとの突き合わせでいずれも実在の不足と確認した。

1. AC3 が検証不可であること。AC3 は「メイン作業ツリーを読まないことが実測で確認されている」であり、不在の証明に対する観測手段が未規定。変更前は不足として検出し書き換え案まで提示したが、変更後は2回とも「検証可能」と誤判定し、その帰結として「受入条件の改善提案」節ごと出力されなかった
2. 制約節の「正当な参照」の定義漏れ。Issue は正当な参照を「割り当て worktree 内に存在する共有規約」に限定するが、実際には `skill_dir` / `plugin_root` が worktree 外へ解決される。変更後は2回とも指摘なし
3. 観測時の権限モードが未記録であること（AC1 の調査結論を左右する）。変更後は2回とも指摘なし

AC2 の「全6エージェント」が実体とずれる件は変更後の2回目で報告されたが、検出したのはメイン側の再検証ステップであり、`issue-refiner` 自身は2回とも Issue 本文の「6」を無検証で踏襲していた。

### 結果4: 劣化要因の切り分け

環境変数で `issue-refiner` の実効値だけを変えて再実行し、劣化が `effort` と `model` のどちらに起因するかを確認した。実効値はいずれも記録で検証済み。

| 構成 | 受入条件の検証可能性 | 改善提案節 | 未解決論点の数 | 到達した指摘 |
|---|---|---|---|---|
| `sonnet` / `medium`（現行、2回） | 検証可能と誤判定 | なし | 2〜3 | — |
| `sonnet` / `high` | 検証可能と誤判定 | なし | 3 | AC2 の件数、#508、AC1 の記録先 |
| `opus` / `medium` | 正しく検出 | AC1〜AC3 の3行 | 5 | 上記に加え、脱出は4件中2件の確率事象であり1サンプルでは拘束の効果と偶然の非発生を分離できないという AC3 の非決定性 |
| `opus` / `xhigh`（変更前） | 正しく検出 | 1行 | 6 | 正当な参照の定義漏れ、権限モードの未記録 |

`effort` を `high` へ上げても受入条件の検証可能性の分析には届かず、`opus` は `medium` でも届いた。差を生んでいるのは `model` である。`opus` / `medium` は変更前（`opus` / `xhigh`）が挙げなかった AC3 の非決定性にも到達しており、水準としてはむしろ上だった。

### 未決事項

`issue-refiner` の値を確定していない。判断材料は上表のとおりで、論点は全件モード（15件 × 最大3並列）を `opus` で回す負荷を許容するかどうかにある。選択肢は、`opus` / `medium` へ変更する、1件モードと全件モードでエージェントを分ける、現行のまま劣化をトレードオフとして明記する、のいずれか。この結果を根拠に別途判断する。

### 対応

用途の異なる 2 本に分ける案を採った。

根拠は 2 点ある。1 件モードは処理量が出ないため `opus` にしても変更前（実測で `opus` / `xhigh`）より軽く、コスト増が問題になるのは全件モードだけであること。そして実測で Ready 判定・要分割・主要ブロッカーが変更前後で一致しており、棚卸しに必要な粒度は `sonnet` で満たされていることである。乖離したのは受入条件レベルの深度であり、これは着手判断を下す 1 件精査の側で効く。

| 定義 | 起動元 | `model` | `effort` | 意図 |
|---|---|---|---|---|
| `issue-refiner` | 1 件モード・`--input` モード | `opus` | `medium` | 必要最小水準 |
| `issue-refiner-batch`（新設） | 全件モード | `sonnet` | `medium` | 許容最大水準 |

あわせて次を更新した。

- `agents/issue-refiner.md` — `opus` / `medium` へ変更。姿勢の節に、受入条件が実際に検証可能かまで踏み込む役割であることを追記
- `agents/issue-refiner-batch.md` — 新設。姿勢の節に、棚卸し用途であり深い精査は `issue-refiner` が担うことを明記
- `skills/refine-issue/SKILL.md` — 全件モードの起動先を `issue-refiner-batch` へ変更
- `README.md` — 表に 2 本を反映し、用途の違いによる値の差を説明
- `references/subagent-execution-parameters.md` — 用途による分割の指針、`effort` が `model` の差を埋めるとは限らないこと、実効値の確認方法を追記
- `docs/superpowers/specs/2026-07-25-subagent-exec-params-design.md` — 決定2・決定3 を修正し「実測による割り当ての修正」節を追加
- `docs/adr/ADR-202607251922-01-subagent-execution-parameter-pinning.md` — Consequences に実効値の検証手段と、`model` が支配的な要因になる場合がある知見を追記

### 対応後の再検証（Issue #509、1件モード）

分割後の `issue-refiner` で同一 Issue を再度精査した。親モデルは `opus` に揃え、`claude -p` で実行した。

| 項目 | 実測値 |
|---|---|
| `agentType` | `dev-workflow:issue-refiner` |
| 実効 `model` / `effort` | `claude-opus-5` / `medium` |
| サブエージェントのツール使用 | `Read` 6 回、`Glob` 2 回のみ。エラーなし |
| メイン側のツール使用 | `Agent` 1 回、`Bash` 4 回 |
| 出力形式 | `output-format-single.md` に沿う |

変更前が検出し、`sonnet` / `medium` が見落とした 3 項目の再現状況は次のとおり。

| 項目 | 結果 |
|---|---|
| AC3 が検証不可（観測手段が未規定） | 回復。観測手段と検証モデルの未規定を指摘し、DoR 表でも「受入条件が検証可能」を ❌ と判定。AC 書き換え案 3 行を出力 |
| 正当な参照の定義漏れ | 部分的。「制約に対応する AC が不在」は指摘したが、`skill_dir` / `plugin_root` が worktree 外へ解決される点には触れていない |
| 権限モードの未記録 | 未検出 |

検証可能性の検出、改善提案 3 行、未解決論点 5 件という観測値は結果4 の `opus` / `medium` 行と一致し、再現した。変更前になかった指摘（AC2 が暗黙に「定義側」案を前提しており、プロンプト側案なら反映先が起動側スキルになる）も出ている。

3 項目の完全一致には至らないが、最大の劣化点であった受入条件の検証可能性の誤判定と改善提案の欠落は解消した。判定の核（Not Ready、要分割、主要ブロッカー）も一致している。指摘の集合は実行ごとに揺れる性質があり、結果4 でも `opus` / `medium` は変更前が挙げなかった論点に到達していた。以上から合格と判定した。

## レビュー指摘を受けて追加した実測（2026-07-25）

観測方法は前節と同じ（`claude -p` で条件ごとに独立したセッションを作り、実効値はセッション記録から取得）。

### 全件モードの起動経路（`issue-refiner-batch`）

所見3「`issue-refiner-batch` の起動経路が未検証」に対応する。`/dev-workflow:refine-issue --limit 45` を実行し、45 件を 15 件 × 3 バッチへ分割させた。

| 項目 | 実測値 |
|---|---|
| `agentType` | 3 本とも `dev-workflow:issue-refiner-batch` |
| 実効 `model` / `effort` | 3 本とも `claude-sonnet-5` / `medium` |
| 並列数 | 3 本が同一メッセージで起動し、開始時刻は 14 秒以内に収まる。最大 3 並列の制約を満たす |
| ツールエラー | 0 件 |
| サブエージェントの返却 | `output-format-batch-subagent.md` の構造（Issue ごとに size / type / is_ready / clarification_items） |
| メイン側の集約 | `output-format-batch.md` のサマリー表として 45 件を出力 |

合格と判定した。

なお本条件はバッチ数がちょうど 3 であり、バッチ数が 3 を超えたときの段階実行（複数メッセージへの分割）は通っていない。ただしこの段階実行の指示は本変更で触れていない既存の記述であり、変更が及ぶのは `subagent_type` の指定と、呼び出し側で `model` を指定しないことの 2 点である。いずれも Agent 呼び出し 1 回ごとに独立して解決される性質で、3 本の実測で成立を確認している。4 本目以降が新たに検証する対象はないため、本変更に対する検証としてはこの条件で足りると判断した。

### 検証系の effort の切り分け（`plan-reviewer`）

所見1 のうち「`high` を維持するのか `xhigh` へ上げるのかを明示的に選び直す」に対応する。本プランの初版（既知の欠陥を 2 件含む）を `plan-reviewer` にレビューさせ、`model` を `opus` に固定して `effort` のみを変えた。

| `effort` | 判定 | 既知欠陥1（`inherit` の修正漏れ） | 既知欠陥2（起票時は索引の再生成が不要） | ブロッカーとして挙げた論点 |
|---|---|---|---|---|
| `high` | FAIL | 検出 | 未検出 | 必須セクションの欠落、判断明示の不在、`inherit` の修正漏れ、実効値の観測手段が不成立、`issue-refiner` の値が未検証の前提に立つ |
| `xhigh` | FAIL | 検出 | 未検出 | 必須セクションの欠落、`inherit` の修正漏れ、現行 spec・ADR との乖離 3 件（`issue-refiner` の値と意図、正本と `issue-refiner-batch` のスコープ漏れ、ADR 本数） |

両条件の指摘集合は包含関係にない。`high` はプラン内部の欠陥（実効値の観測手段、値の根拠）へ寄り、`xhigh` はプランと現行の spec・ADR との世代乖離へ寄った。`xhigh` はさらに、レビュー対象の範囲外にある spec 自身の検証項目節が 2 エージェント分割前の記述のまま残っていることを発見した。これは実在の欠落であり、この指摘を受けて修正した。

リポジトリ内の他の成果物との照合はプランレビューの中核であることから、`plan-reviewer` のみ `xhigh` とした。他の検証系 4 本は実測がなく、かつ本プラグインのスキルからは起動されないため `high` を維持する。
