# 個人ローカル store（生捕捉）仕様

growth プラグインの学習ループ（`[Capture] → [Distill] → [Route] → [Promote] → [Distribute]`）の起点となる、生捕捉（未検証の観察）を蓄積する個人ローカル store の置き場・形式・状態管理を定義する。

## 位置づけ

- `DESIGN.md` 決定事項3「個人 store の置き場」を具体化する文書。生の捕捉は個人ローカル（共有されない）に置き、検証を経たものだけ committed の学び置き場へ昇格させる。
- 本 store は学習ループの **Capture の書き込み先**であり、**Distill の入力源**である。Capture の検知ロジック本体・committed への昇格処理・過去セッションログの横断解析は本仕様の対象外（別 Issue / 別 Phase）。
- 本 store は committed な学び置き場（単一の人間可読ファイル）とは別物である。store は未検証の生記録を貯める一時領域であり、検証を経た学びは store の外（昇格先）へ移送される。

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

## 捕捉エントリの形式

store は Markdown ファイルであり、1捕捉を1セクション（`##` 見出し）として追記する。人間可読であり、肥大が一目で分かる（`DESIGN.md` 原理5「足場を痩せさせる」の前提）。

ファイルは Markdown として保存・閲覧するが、各エントリのフィールド行は `key: value` の平文規約として扱う。読み取り側（Distill 等）はフィールドを行単位のテキストとして抽出する想定であり、YAML パーサによる厳密解釈は前提としない（`##` 見出しと `- key: value` 行の混在は意図的に「人が読める追記ログ」を優先したもの）。

### スキーマ

| フィールド | 必須 | 内容 |
|---|---|---|
| 見出し（`## <timestamp>`） | 必須 | ISO 8601 形式のタイムスタンプ。捕捉時刻 |
| `signal` | 必須 | シグナル種別。値域は「シグナル種別」節を参照 |
| `session` | 必須 | 出所セッション参照。Claude Code がセッション管理に用いる識別子（UUID 形式）。どのセッションの観察かを辿るため。取得元は Phase 1 実装時に確定する |
| `status` | 必須 | 処理状態。`unprocessed`（既定）/ `promoted`。「状態管理」節を参照 |
| `observation` | 必須 | 生観察。何が起きたかの記録のみ |

AC の必須欄「生観察」「シグナル種別」「出所参照」はそれぞれ `observation` / `signal` / `session` に対応する。

### 生記録性（判断は後回し）

`DESIGN.md` の Capture 原則「判断は後回しにする」を構造的に担保するため、スキーマに**解釈・原因分析・対策・改善案を書くフィールドを設けない**。捕捉時点では「何が起きたか」（observation）だけを記録し、「なぜ起きたか」「次にどうするか」は Distill 以降の検証フェーズに委ねる。生記録に解釈を混ぜないことが、未検証の幻覚を配布物に流し込まない第一の防波堤になる。

### 記述例

```
## 2026-06-26T14:32:10Z
- signal: 訂正
- session: 2265f83f-c5a8-41a0-b284-b5d90882a2da
- status: unprocessed
- observation: |
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
| `promoted` | 昇格済み。Distill が拾い上げ、昇格処理を経たもの。Distill は再走査しない |

```
unprocessed ──(Distill が拾い上げ・昇格)──▶ promoted
```

- Capture が新規エントリを書き込むときの `status` は必ず `unprocessed`。
- Distill は store を走査し、`status: unprocessed` のエントリのみを処理対象として選択する。`promoted` は無視する。
- エントリは store 内に残したまま `status` をインラインで反転させる（アーカイブへ移送しない）。捕捉履歴を可逆・監査可能な形で保持するため。
- **昇格処理（`status` の `unprocessed → promoted` への反転を実行する主体）は本仕様の対象外**（別 Issue: reflect 検証→起票）。本仕様は状態軸と遷移規約の定義に留める。

### 二段ゲートとの整合

この状態遷移は `DESIGN.md` の二段ゲート、および自律度モデル L0–L3 / 承認ゲート軸（ADR-20260601 / ADR-20260602-2）と整合する。

- **保存（store への書き込み）= L3（AI 自律・承認段が縮退）**: 捕捉は無ゲートで自動的に `unprocessed` として貯まる。
- **仕組み化（昇格＝ committed への移送）= L2（提案→承認の二段）**: `promoted` への遷移は検証・承認またはマルチエージェントレビューを経る。`status` は、この L3 で貯めた記述的ナレッジが L2 の規範的な仕組み化ゲートを通過したか否かを表す。

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
| 捕捉エントリの形式（必須欄・Markdown 形式） | committed 学び置き場への昇格処理（`status` 反転の実行） |
| シグナル種別の値域（5値） | 過去セッションログの横断解析（Phase 3） |
| 状態管理（`status` 軸と遷移規約） | git revert・CI 失敗の取得（Phase 3 以降） |
| store が配布物に混入しない構成保証 | |

## 関連

- `plugins/growth/DESIGN.md` — 設計母艦（決定事項3・§3 保存設計・二段ゲート・Capture シグナル定義）
- `docs/adr/ADR-20260601-autonomy-approval-gate-alignment.md` / `docs/adr/ADR-20260602-2-autonomy-ladder-convention.md` — 二段ゲートが依拠する自律度 L0–L3 / 承認ゲート軸
