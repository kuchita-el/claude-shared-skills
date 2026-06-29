# 個人ローカル store（生捕捉）仕様

growth プラグインの学習ループ（概念上の5段: `[Capture] → [Distill] → [Route] → [Promote] → [Distribute]`。Phase 1 のスキルマッピングでは Route は Distill に統合される＝DESIGN.md §4・決定事項8）の起点となる、生捕捉（未検証の観察）を蓄積する個人ローカル store の置き場・形式・状態管理を定義する。あわせて、Distill が生成し `promote` が消費する**候補ファイル（`candidates.md`）**の置き場・形式・メタ欄スキーマも本仕様で単一出典化する（#348）。

## 位置づけ

- `DESIGN.md` 決定事項3「個人 store の置き場」を具体化する文書。生の捕捉は個人ローカル（共有されない）に置き、検証を経たものだけ committed の学び置き場へ昇格させる。
- 本 store は学習ループの **Capture の書き込み先**であり、**Distill の入力源**である。Capture の検知ロジック本体・committed な学び置き場（`learnings.md`）への物理昇格（Distribute、Phase 2）・過去セッションログの横断解析は本仕様の対象外（別 Issue / 別 Phase）。一方、**store の `status` 状態機械（`unprocessed → promoted` の反転）は本仕様が定義し、反転を実行する主体は `promote` スキルである**（#348 で確定。「状態管理」節）。
- 本 store は committed な学び置き場（単一の人間可読ファイル）とは別物である。store は未検証の生記録を貯める一時領域であり、検証を経た学びは store の外（昇格先）へ移送される。
- 本仕様はさらに、Distill が生成し `promote` が消費する**候補ファイル（`candidates.md`）**の置き場・形式・メタ欄スキーマを単一出典として定義する（#348。「候補ファイル（candidates.md）」節）。候補ファイルは store（生捕捉）でも `learnings.md`（配布物）でもない第3の個人ローカル成果物である。

### memory との違い

置き場こそ既存 memory 機構と同じ user-local 領域に同居するが、store は memory とは設計意図が異なる。memory は「個人で終わる」（共有のデッドエンド）。本 store は **昇格経路を必ず持つ**点で memory と differ する。store は学びの出発点であって終点ではない——貯めた生捕捉は検証され、支持されたものが committed の配布物へ昇格していく。`status` フィールド（後述）がこの昇格状態を追跡する。

## 置き場

生捕捉 store のパスを以下に確定する。

```
~/.claude/projects/<project-id>/growth/captures.md
```

- `<project-id>` は既存 memory 機構が用いるプロジェクト識別子と同一（このリポジトリでは作業ディレクトリのパス区切りを `-` に置換した形式。例: `-home-kuchita-Development-claude-shared-skills`）。memory が `projects/<project-id>/memory/` を使うのと同階層に `projects/<project-id>/growth/` を置く。
- **スコープは per-project**。捕捉はプロジェクト文脈（作業セッション）で発生するため、プロジェクトごとに store を分離して出所文脈を保持する。Distill はこのプロジェクト単位の store を入力源とする。
- このパスはユーザースコープ（`~/.claude/` 配下）にあり、本リポジトリの work tree の外にある。したがって**配布物（プラグイン）に物理的に含まれず**、プラグイン更新で消えず、配布を受けた consumer の環境でも各自の user-local 領域として成立する。

### project-id とパスの解決手順

`<project-id>` と store パスは以下の手順で解決する。**Capture（capture スキル）と Distill（distill スキル）は本手順を共通の単一出典として参照する**（操作手順を各スキルへ二重定義せず、git のバージョン要件や置換規約の改修をここ一箇所に集約する）。

**リポジトリルートと project-id**:

```bash
git rev-parse --path-format=absolute --git-common-dir
```

このコマンドは worktree・通常リポジトリの両方で共通の `.git` ディレクトリの**絶対パス**を返す（例: `/home/user/myproject/.git`）。`--path-format=absolute` は Git 2.31 以降で利用可能。末尾の `/.git` を除いたパスをリポジトリルートとし、全 `/` を `-` に置換して `<project-id>` とする（例: `-home-user-myproject`）。

> `--git-common-dir` 単体は CWD に応じて相対パスを返す場合があるため `--path-format=absolute` を必ず併用する。
> `git rev-parse --show-toplevel` は worktree 内では worktree 固有パスを返すため使用しない。

**store パスの組み立て**:

- store パス: `~/.claude/projects/<project-id>/growth/captures.md`

> capture（Capture）は同一の `<project-id>` から jsonl パス `~/.claude/projects/<project-id>/<session-UUID>.jsonl` も組み立てるが、session UUID 解決と jsonl 読取は Capture 固有の手順であり本仕様の対象外（capture SKILL.md が定義する）。

## 捕捉エントリの形式

store は Markdown ファイルであり、1捕捉を1セクション（`##` 見出し）として追記する。人間可読であり、肥大が一目で分かる（`DESIGN.md` 原理5「足場を痩せさせる」の前提）。

ファイルは Markdown として保存・閲覧するが、パースは行ベースの平文規約で完結させ、YAML パーサによる厳密解釈は前提としない。区切り規約は以下とする。

- **エントリ境界**: 1エントリは `## <timestamp>` 見出しから次の `##` 見出し（またはファイル末尾）まで。
- **メタフィールド**: `signal` / `session` / `status` は `- key: value` 形式の単一行。エントリ内の `- key: value` 行をメタとして抽出する。
- **observation 本文**: メタ行と見出し直後の空行を除いた残りの行が observation 本文。複数行を自然に含められる。YAML のブロックスカラー（`|`）等の記法は用いない。

observation を必ずメタフィールド群の後（エントリ末尾側）に置くことで、多行の生観察を行ベースの区切りだけで欠落なく抽出できる。

### スキーマ

| フィールド | 必須 | 内容 |
|---|---|---|
| 見出し（`## <timestamp>`） | 必須 | ISO 8601 形式のタイムスタンプ。捕捉時刻 |
| `signal` | 必須 | シグナル種別。値域は「シグナル種別」節を参照 |
| `session` | 必須 | 出所セッション参照。Claude Code がセッション管理に用いる識別子（UUID 形式）。どのセッションの観察かを辿るため。取得元は Phase 1 実装時に確定する |
| `status` | 必須 | 処理状態。`unprocessed`（既定）/ `promoted`。「状態管理」節を参照 |
| `observation` | 必須 | 生観察。何が起きたかの記録のみ。メタフィールドの後にエントリ末尾の本文ブロックとして記述する（複数行可、「パース規約」節を参照） |

AC の必須欄「生観察」「シグナル種別」「出所参照」はそれぞれ `observation` / `signal` / `session` に対応する。

### 生記録性（判断は後回し）

`DESIGN.md` の Capture 原則「判断は後回しにする」を構造的に担保するため、スキーマに**解釈・原因分析・対策・改善案を書くフィールドを設けない**。捕捉時点では「何が起きたか」（observation）だけを記録し、「なぜ起きたか」「次にどうするか」は Distill 以降の検証フェーズに委ねる。生記録に解釈を混ぜないことが、未検証の幻覚を配布物に流し込まない第一の防波堤になる。observation は複数行記述できるが、記録するのは観察事実に限り、分量は文脈が伝わる範囲に留める（解釈・原因・対策を書かない方針は行数に関わらず保持する）。

### 記述例

```
## 2026-06-26T14:32:10Z
- signal: 訂正
- session: 2265f83f-c5a8-41a0-b284-b5d90882a2da
- status: unprocessed

ユーザーが「git checkout ではなく git restore を使え」と訂正した。
当方はファイル復元に git checkout を提案していた。
```

## シグナル種別

`signal` の値域は `DESIGN.md` の Capture が定義するシグナル（予測誤差＝驚きの源泉）を網羅する。以下の5値とする。

| 値（ラベル） | 意味 |
|---|---|
| `訂正` | ユーザーが当方の出力・提案を訂正した |
| `ツール拒否` | ツール呼び出しが拒否された（権限拒否・hook ブロック等） |
| `反復試行` | 同一目的の操作を繰り返した（再試行の連続） |
| `期待違反` | 予測した結果と実際の結果が食い違った |
| `客観痕跡` | git revert・CI 失敗等の外部の客観的痕跡 |

- ラベルは日本語を正準とする（`DESIGN.md` の表記に準拠）。
- `客観痕跡` は Phase 1（痕跡ソースが現セッションの会話履歴に限られる）では投入されない見込みだが、値域には含める。git revert・CI 失敗の取得は Phase 3 以降であり、その時点で同一スキーマに追記できるようにするため。

## 状態管理

各エントリは `status` フィールドで処理状態を持つ。Distill が未処理の捕捉を識別できるようにするための状態軸である。

### 値と遷移

| 状態 | 意味 |
|---|---|
| `unprocessed` | 未処理（既定値）。Capture が書き込んだ直後の状態。Distill の処理対象 |
| `promoted` | 昇格済み。Distill による候補化を経て、`promote` スキルが Issue 起票に成功した後に `status` を反転したもの。Distill は再走査しない |

```
unprocessed ──(Distill が候補化 → promote が起票成功後に反転)──▶ promoted
```

- Capture が新規エントリを書き込むときの `status` は必ず `unprocessed`。
- Distill は store を走査し、`status: unprocessed` のエントリのみを処理対象として選択する。`promoted` は無視する。Distill 自身は `status` を反転しない（候補化・候補ファイルへの永続化までに責務を限定する。distill スキル参照）。
- エントリは store 内に残したまま `status` をインラインで反転させる（アーカイブへ移送しない）。捕捉履歴を可逆・監査可能な形で保持するため。
- **`status` の `unprocessed → promoted` への反転を実行する主体は `promote` スキルである**（#348 で確定）。promote は候補を検証し、`gh issue create` による Issue 起票に**成功した後にのみ**、候補の provenance（「候補ファイル（candidates.md）」節）が指す store エントリの `status` をインライン反転する。起票失敗・候補棄却・ゲート拒否時は反転しない。本仕様は状態軸・遷移規約・反転主体を定義し、反転の具体手順は promote スキルが持つ。

### 二段ゲートとの整合

この状態遷移は `DESIGN.md` の二段ゲート、および自律度モデル L0–L3 / 承認ゲート軸（ADR-20260601 / ADR-20260602-2）と整合する。

- **保存（store への書き込み）= L3（AI 自律・承認段が縮退）**: 捕捉は無ゲートで自動的に `unprocessed` として貯まる。
- **仕組み化（昇格＝ committed への移送）= L2（提案→承認の二段）**: `promoted` への遷移は、promote の検証段（原理2＝未検証候補を配布経路に乗せないフィルタ）を通過した候補が `gh` で自動起票されたことを表す。**起票前に人間承認ゲートは置かない**（自動化を阻害し下流ゲートと二重になるため）。L2 の規範的な仕組み化ゲート（承認またはマルチエージェントレビュー）は、起票後の既存ワークフロー（refine-issue / DoR / PR レビュー）が担う。`status: promoted` は、この L3 で貯めた記述的ナレッジが promote の検証を経て共有経路（Issue）へ投入された状態を表す。

## 候補ファイル（candidates.md）

Distill が生成し `promote` が消費する**候補ファイル**の置き場・形式・スキーマを単一出典として定義する（#348）。候補ファイルは生捕捉 store（`captures.md`）でも配布物（`learnings.md`）でもない**第3の個人ローカル成果物**であり、Distill の蒸留結果（候補）を `promote` の入力として永続化する一時領域である。

### 置き場

```
~/.claude/projects/<project-id>/growth/candidates.md
```

- `captures.md` と**同一階層**（`~/.claude/projects/<project-id>/growth/`）に置く。per-project・user-local。`<project-id>` の解決は「project-id とパスの解決手順」を共通参照する（Distill・promote とも同手順）。
- captures.md 同様ユーザースコープ（`~/.claude/` 配下）にあり work tree の外。配布物に物理的に含まれない。
- **in-repo dogfooding**: growth プラグイン自身を本リポジトリで開発・dogfooding する際にリポジトリ内へ候補を書き出す運用も、既存 `.gitignore` の `plugins/growth/.local/` がディレクトリごと追跡対象外にするためカバーされる。候補ファイルのための `.gitignore` 追加変更は不要。

### 形式とスキーマ

候補ファイルは Markdown であり、1候補を1セクション（`##` 見出し）として持つ。captures.md と同じく行ベースの平文規約でパースする（YAML パーサによる厳密解釈は前提としない）。captures.md と異なり、候補は**メタ欄を持つ**（learnings.md の1欄スキーマとは別物。下記参照）。

| 要素 | 必須 | 内容 |
|---|---|---|
| 見出し（`## <規範の短い見出し>`） | 必須 | 候補が命じる振る舞い差分の一文要約（規範）。learnings.md へ昇格した際そのまま見出しになる形 |
| `provenance` | 必須 | 由来する store エントリへの一意参照。値は `captures.md` の `## <timestamp>` 見出し（ISO 8601）。クラスタが複数 observation を畳む場合は複数 timestamp をカンマ区切り等で列挙する。`promote` の `status` 反転対象を特定する粒度 |
| `scope-hypothesis` | 必須 | スコープ仮説タグ。値域は `project-local` / `universal` の2値（learning-store-spec.md「2空間モデル」に対応）。Distill が蒸留観点として付与する**仮説**であり、確証しない（最終裁定は人間の refine/review、横断解析は Phase 3 の支援どまり） |
| `career-hypothesis` | 必須 | キャリア仮説タグ。**昇格先キャリア**（`強キャリア` / `改善還元` / `ADR 差分` / `learnings.md` の4分類）＋**宛先 repo の仮説**を `<career> / repo: <宛先 repo 仮説>` の1行形式で持つ。判定基準（4分類の決定表）は distill 側（distill-procedure.md「career-hypothesis の判定（決定表）」）を単一出典とする。`scope-hypothesis` と**対称・直交**な独立メタ欄であり（キャリア軸 ⊥ 空間軸。DESIGN.md「種別軸 ⊥ 共有境界軸」）、Distill が蒸留観点として付与する**仮説**で確証しない。career と宛先 repo の最終裁定は集約点（取り込み Issue）で行い、promote は確定しない（ADR-20260628-2） |
| `candidate-status` | 必須 | 候補の処理状態。`pending`（既定。未処理）/ `rejected`（promote の検証で棄却）/ `promoted`（promote が Issue 起票成功後に付与。任意・推奨。再走査からの除外。promote-procedure.md §4 参照）。再 distill 時の再提示ループを断つための追跡軸（下記「冪等性」参照） |
| 本文 | 必須 | 規範差分の具体（次回どう違う行動を取るか）＋理由。メタ欄の後にエントリ末尾の本文ブロックとして記述する（複数行可） |

### provenance 規約

- provenance は由来 store エントリの `## <timestamp>` 見出し（ISO 8601）を一意参照キーとして保持する。`promote` はこのキーで `captures.md` の該当エントリを特定し、起票成功後に `status` を反転する。
- **前提**: 同一 store 内で timestamp が衝突しない（capture 時刻が秒単位で一意）。衝突する場合は反転対象が曖昧になるため、安定 ID 導入の検討が必要（本仕様は timestamp 一意を前提とする）。

### Distill の書き込み方式（upsert）

- Distill は候補を provenance キーで **upsert**（同一 provenance キーの既存候補があれば置換、なければ追加）して候補ファイルへ永続化する。単純追記は再実行で重複し、全置換は既存候補を失うため。provenance キーでの upsert により再 distill が冪等になる。

### 冪等性（candidate-status による再提示抑止）

- promote の検証で棄却された候補は `status` 反転されず、由来 `captures.md` エントリが `unprocessed` のまま残る。何もしなければ次回 distill で同一候補が再生成・再提示される。これを避けるため、候補ファイルに `candidate-status` 欄を持たせ、promote が棄却した候補を `rejected` で追跡する。Distill は upsert 時に既存の `rejected` 候補を尊重し、安易な再提示を避ける。

### 1欄スキーマ（learnings.md）との区別

learnings.md（配布物）は**メタ欄を持たない1欄スキーマ**（learning-store-spec.md「1欄スキーマ」）であり、provenance・scope・撤回追跡は空間・git 履歴が担う。一方、候補ファイルは個人ローカルの一時領域であり、`promote` が消費するための機械的メタ欄（provenance・scope-hypothesis・career-hypothesis・candidate-status）を持つ。候補が learnings.md へ昇格する際にこれらメタ欄は落ち、見出しと本文（規範）だけが残る。

### 記述例

```
## git restore でファイル復元する
- provenance: 2026-06-26T14:32:10Z
- scope-hypothesis: universal
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo（本リポジトリ）
- candidate-status: pending

ファイル復元には git checkout ではなく git restore を使う。git checkout は復元とブランチ切替が多重定義され誤操作を招くため。
```

## 構成上の保証と検証手段

生捕捉が配布物（リポジトリ）に混入しないことを構成で保証し、検証可能にする（AC5）。

### ユーザースコープ store（正準の置き場）

正準の置き場 `~/.claude/projects/<project-id>/growth/captures.md` は本リポジトリの work tree の外にあるため、リポジトリの `git status` には原理上現れない。リポジトリのどのブランチからもトラッキング対象にならないことが、置き場の選定そのものによって保証される。

### in-repo dogfooding 時の防御

growth プラグイン自身を本リポジトリで開発・dogfooding する際、リポジトリ内のパスへ捕捉を書き出す運用がありうる。その場合に未検証捕捉が誤ってコミットされないよう、リポジトリルートの `.gitignore` で `plugins/growth/.local/` を追跡対象外にする。検証手順は以下。

なお **Distill の入力源は正準パス（`captures.md`）のみ**である。in-repo の `plugins/growth/.local/` は手動 dogfooding 時に捕捉を誤コミットから守るための保護領域であって、Distill の走査対象ではない。両方にファイルが存在する場合も Distill は正準パスだけを読む。

```bash
# .gitignore のマッチ規則が返れば追跡対象外であることが確認できる
git check-ignore -v plugins/growth/.local/captures.md

# ダミーファイルを置いても untracked にすら現れないことを確認する
mkdir -p plugins/growth/.local && touch plugins/growth/.local/captures.md
git status --porcelain plugins/growth/.local/   # 出力が空であること
```

## スコープ境界

| 本仕様が定義する（IN） | 本仕様が定義しない（OUT） |
|---|---|
| store の置き場（確定パス・per-project） | Capture の予測誤差検知ロジック本体 |
| 捕捉エントリの形式（必須欄・Markdown 形式） | committed 学び置き場（`learnings.md`）への物理昇格（Distribute、Phase 2） |
| シグナル種別の値域（5値） | 過去セッションログの横断解析（Phase 3） |
| 状態管理（`status` 軸・遷移規約・反転主体＝promote） | git revert・CI 失敗の取得（Phase 3 以降） |
| 候補ファイル（`candidates.md`）の置き場・形式・メタ欄スキーマ・provenance 規約 | promote の検証・Route 注記・起票の具体手順（promote スキルが定義） |
| store が配布物に混入しない構成保証 | |

## 関連

- `plugins/growth/DESIGN.md` — 設計母艦（決定事項3・§3 保存設計・二段ゲート・Capture シグナル定義）
- `docs/adr/ADR-20260601-autonomy-approval-gate-alignment.md` / `docs/adr/ADR-20260602-2-autonomy-ladder-convention.md` — 二段ゲートが依拠する自律度 L0–L3 / 承認ゲート軸
