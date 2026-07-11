# 配布物昇格 Issue 規約

growth プラグインの学習ループにおいて、`promote` スキル（#348）が検証通過仮説を `gh` で自動起票する際の Issue 本文・ラベルを定義する。本仕様は配布物昇格 Issue の**テンプレート・識別ラベルの単一出典**であり、後続手順（集約点での裁定・各キャリアへの実書き込み）はここで定義した規約を入力として受け取る。

> **career 決定モデルの再設計（ADR-20260628-2）**: 昇格先キャリアの判定（決定表）は本仕様から **distill 側（distill-procedure.md「career-hypothesis の判定（決定表）」）へ移設**した。distill が仮説単位の `career-hypothesis`（昇格先キャリア＋宛先 repo の仮説）を生成し、promote は**ルーティング不可知**でその仮説を本文注記として運ぶのみとする。career の確定（裁定）は集約点（取り込み Issue）で人間が行う。これに伴い、本仕様は career を確定する決定表を持たず、`promote:*` の4 career ラベルも廃止する（識別ラベル `growth:promote` のみ残す）。

## 位置づけ

本仕様は、`DESIGN.md` の学習ループ（`[Capture] → [Distill+Route] → [Promote] → [Distribute]`）における Promote 段の終端規約である。promote スキルが起票した Issue を**入力として受ける**規約であり、起票された Issue がどの形式・どの識別ラベル・どの仮説注記を持つべきかを定める。

- **#349 Phase 2（D2）の具体化**: #349 が決めた「新規スキルを作らず既存ワークフローに乗る Issue 規約として実現する（D2）」を、具体的なテンプレート・ラベルへ落とし込む文書。昇格先キャリアの4分類（D1）は distill が `career-hypothesis` の仮説として生成する（決定表は distill-procedure.md）ため、本仕様はその仮説を本文注記として保持する形式を定めるに留める（career の判定規則・なぜ4分類かは本仕様に転記しない）。
- **関連仕様との関係**:
  - [`learning-store-spec.md`](learning-store-spec.md) — 配布物（`learnings.md`）の**着地先形式**を定義する。昇格 Issue のうち learnings.md 行きのものが最終的に到達する先であり、本仕様はその1欄スキーマ（メタ欄を持たない）を壊さない制約に従う。
  - [`personal-store-spec.md`](personal-store-spec.md) — 昇格 Issue の**入力源**となる仮説ファイル（`candidates.md`）の `scope-hypothesis`（`universal` / `project-local`）・`career-hypothesis`（昇格先キャリア＋宛先 repo 仮説）スキーマを定義する。本仕様のテンプレート「空間」欄・「昇格先キャリア」注記はこれらのタグからマッピングされる。
  - [`distill-procedure.md`](../skills/distill/references/distill-procedure.md) — `career-hypothesis` の昇格先キャリアを判定する**決定表の移設先（単一出典）**。本仕様から移設した（ADR-20260628-2）。
  - [`DESIGN.md`](../DESIGN.md) — 設計母艦。学習ループ・2系統・共有境界軸・二段ゲートの原典。
- **promote（#348）との接続**: promote はこの規約を満たす Issue 本文を `--body-file` でプログラム生成し、`gh issue create` で自動起票する。本仕様は promote が起票した Issue の終端規約であり、promote 自身の検証・status 反転の手順（[`../skills/promote/references/promote-procedure.md`](../skills/promote/references/promote-procedure.md)）には踏み込まない。

## テンプレート

昇格 Issue の本文構造を定義する。GitHub ネイティブの `ISSUE_TEMPLATE`（`.github/` 配下の YAML/Markdown フォーム）は**採らない**。promote が `--body-file` でプログラム生成し GitHub の Issue 作成 UI を経由しないため、UI 連動のネイティブテンプレートは機能しない。本仕様は文書定義形式のテンプレートとして本文構造を規定する。

### Issue 本文の構造

昇格 Issue は次の3つを**必須欄**として持つ。いずれも単一値・規定の記法で記入する。

| 必須欄 | 記入規約 | 記法 |
|---|---|---|
| **昇格先キャリア（仮説）** | D1 の4分類（`learnings.md` / `ADR 差分` / `改善還元`（任意プラグイン／コミュニティ） / `強キャリア`）のいずれか＋宛先 repo 仮説。仮説の `career-hypothesis` から**欠落・改変なく**運ぶ**仮説注記**であり、promote は確定しない。最終裁定（career・宛先 repo の確定）は集約点（取り込み Issue）が担う。判定（決定表）は distill 側（distill-procedure.md） | 仮説注記。`<career> / repo: <宛先 repo 仮説>` を本文の `## キャリア` 欄へ転記（promote-procedure §4） |
| **空間（仮説）** | `パブリック` / `閉じた` の**いずれか1つ**。仮説の `scope-hypothesis` からマッピングする（下記マッピング表）。これも仮説であり最終裁定は refine/review | 単一値 |
| **振る舞い差分** | 仮説の規範（次回どう違う行動を取るか）。見出し（一文要約）＋理由（なぜその振る舞いを取るか） | 見出し1行＋理由本文（複数行可） |

- 昇格先キャリアと空間はいずれも distill 由来の**仮説注記**であり、promote が確定するものではない（promote はルーティング不可知。ADR-20260628-2）。career は集約点が、空間は refine/review が最終裁定する。
- キャリア軸（昇格先＝何の成果物へ）と空間軸（`universal` / `project-local`）は**直交**する（DESIGN.md「種別軸 ⊥ 共有境界軸」）。同じ `learnings.md` 行きでもパブリック空間と閉じた空間に分かれうるため、テンプレートは両者を独立した欄として持つ。
- 加えて、下流の refine/review・集約点が判断材料にできるよう、promote の検証段が添えた「予測（次にどんな状況で効くか）」「検証観点（どの条件で反証されうるか）」を本文に含めてよい（任意。promote-procedure §5 と整合）。

### 空間欄のマッピング（promote の `## スコープ` 出力から）

空間欄は、promote が Issue 本文へ出力する `## スコープ`（candidates.md の `scope-hypothesis` タグに基づく。promote-procedure §4）から**欠落・改変なく**マッピングする。対応は次の通り。

| promote の `scope-hypothesis`（`## スコープ` 出力） | 本テンプレートの空間欄 | 共有境界 |
|---|---|---|
| `universal` | `パブリック` | 全世界 × 全プロジェクト（パブリック/グローバル空間 = `learnings.md` 相当） |
| `project-local` | `閉じた` | チーム / プロジェクト（閉じた空間） |

- 空間情報は promote が付した仮説であり、本テンプレートは**保持するのみ**で確証・改変しない。最終裁定は起票後の refine/review が担う（promote-procedure §4 と整合）。
- マッピングは1対1であり、`universal`→`パブリック`、`project-local`→`閉じた` の2値以外を取らない。

### 記入済みサンプル

```markdown
## キャリア
- 昇格先キャリア（仮説・未確証）: learnings.md
- 宛先 repo（仮説・未確証）: 配布元プラグイン repo（本リポジトリ）
- 最終裁定（career・宛先 repo の確定）は集約点（取り込み Issue）に委ねる。本タグは Distill の仮説形成観点に基づく仮説。

## 空間
パブリック

## 振る舞い差分
### ファイル復元には git restore を使う
ファイルを復元するとき git checkout ではなく git restore を使う。git checkout はブランチ切り替えと復元が多重定義されており、誤操作で別ブランチへ移る事故を招くため。

## スコープ
- 適用範囲（仮説・未確証）: universal（パブリック/グローバル空間 = learnings.md 相当へ向かう仮説）
- 最終裁定は refine/review に委ねる。本タグは Distill の仮説形成観点に基づく仮説。

## 検証メモ
- 予測: ファイル復元を伴う全セッションで効く。
- 検証観点: git restore が使えない古い git バージョン環境では反証されうる。
```

### learnings.md の1欄スキーマを壊さない制約

昇格 Issue が運ぶメタ情報（昇格先キャリア・空間・provenance・予測/検証観点）は、**Issue 側に保持する**。learnings.md へ昇格する段（Distribute、#383/#384）で、これらメタ欄は配布物エントリへ持ち込まない。learnings.md は見出し＋本文の1欄スキーマ（[`learning-store-spec.md`](learning-store-spec.md)「1欄スキーマ」）であり、共有境界・provenance・撤回追跡は空間と git 履歴が担う。昇格 Issue のメタ情報はあくまで「揉む場」である Issue に留め、配布物の薄さ（原理5）を壊さない。

## ラベル体系

昇格 Issue を機械的に絞り込めるよう、既存ラベル慣習（`growth`、`type:feature` の `prefix:value` 形式）に整合するラベル体系を定義する。

### ラベル定義

| ラベル | 役割 | hex | 根拠 |
|---|---|---|---|
| `growth:promote` | 識別（昇格 Issue 全体／inbox 識別子） | `#0B6E4F` | `growth #0E8A16` 同系の濃緑（teal 寄り）で growth ドメインの昇格ゲートを示す |

> **`promote:*` の4 career ラベルは廃止した**（ADR-20260628-2 決定事項5）。career の裁定が人間による集約点（取り込み Issue）トリアージへ移り、1つの取り込み Issue が複数仮説を異種 career へ裁定しうるため、1-Issue-1-career-label のルーティング機構は意味を失う。career の結果は実際の成果物（ADR PR / プラグイン Issue / `learnings.md` PR / 強キャリア Issue）として実現し、取り込み Issue の task list が追跡する。4 career ラベルは #385 で未作成のため、これは「作らない」決定であり teardown コストはゼロ。

### 付与規約

- 識別ラベル `growth:promote` は既存 `growth` ラベルと**併用**する。昇格 Issue は `growth` ＋ `growth:promote` の2ラベルを持つ。`growth` は growth ドメイン全体の識別、`growth:promote` は昇格 Issue（集約点へ取り込む inbox 仮説）のサブ識別である。
- **昇格先キャリアはラベルで区別しない**。career は distill が `career-hypothesis` の仮説として生成し、本文の `## キャリア` 注記として運ばれる。最終裁定は集約点（取り込み Issue）が人間トリアージで行うため、起票時にキャリアをラベルで固定しない（ADR-20260628-2）。

### 機械絞り込みレシピ

後続手順（集約点＝取り込みスキル）は、識別ラベルで未処理の昇格 Issue（inbox）を機械的に絞り込む。例:

```bash
# 未取り込みの昇格 Issue（inbox 仮説・オープン）を列挙する
gh issue list --label growth:promote --state open
```

`growth:promote` は inbox 識別子であり、集約点はこのラベルで取り込み対象の仮説 Issue を一括取得する。

**career（昇格先キャリア）も空間（パブリック / 閉じた）もラベルで区別しない**。career の裁定は集約点の人間トリアージが、空間の最終裁定は refine/review が担うため、起票時にラベルで固定しない。後続ハンドラ・集約点がキャリア × 空間で仕分ける場合は、Issue 本文の `## キャリア` 欄・`## 空間` 欄（distill 由来の仮説）を読んで判断材料にする。

### セットアップ手順（ラベル実体の作成）

識別ラベル `growth:promote` の**実体作成は本 PR では実行しない**。マージ前のリポジトリにラベルを作るとリポジトリ状態を汚すため、実作成は #385（inbox 識別子のセットアップへ縮小。ADR-20260628-2 決定事項5）またはセットアップ手順の実行時に委譲する。本仕様は作成コマンドを掲載するに留める。`promote:*` の4 career ラベルは廃止したため作成しない。

```bash
# ラベル実体の作成（本 PR では実行しない。セットアップ時に実行する）
gh label create growth:promote        --color 0B6E4F --description "配布物昇格 Issue（識別／inbox 識別子）"
```

## スコープ境界

| 本仕様が定義する（IN） | 本仕様が定義しない（OUT） |
|---|---|
| 昇格 Issue のテンプレート（必須欄・空間マッピング・キャリア/スコープ注記・記入サンプル） | 各キャリアへの実書き込み手順（learnings.md / ADR / 改善還元 Issue / 強キャリアへの物理配布。#383/#384） |
| 識別ラベル `growth:promote`（inbox 識別子・色・付与規約・絞り込みレシピ） | 昇格先キャリアの判定規則（決定表）の定義（distill 側＝distill-procedure.md へ移設。ADR-20260628-2） |
| learnings.md の1欄スキーマを壊さない制約 | career・宛先 repo の裁定（集約点＝取り込み Issue が担う。promote/本仕様は仮説を運ぶのみ） |
| 仮説注記（distill 由来の career/scope 仮説）を保持する本文形式 | 集約点（取り込み Issue 規約・取り込みスキル）の新設（別 Issue）。承認フロー・越境ゲートの配線（#385）。ラベル実体の作成（`gh label create` の実行。#385/セットアップ手順へ委譲） |

## 関連

- [`learning-store-spec.md`](learning-store-spec.md) — 配布物（`learnings.md`）の着地先形式（1欄スキーマ・2空間モデル・参照規約）
- [`learning-promotion-spec.md`](learning-promotion-spec.md) — 本規約準拠の learnings.md 行き昇格 Issue を1欄エントリへ翻訳する変換規約（#383）。本仕様を入力として受ける後続手続き
- [`personal-store-spec.md`](personal-store-spec.md) — 昇格 Issue の入力源 仮説ファイル（`candidates.md`）の `scope-hypothesis` スキーマ
- [`DESIGN.md`](../DESIGN.md) — 設計母艦（学習ループ・学びの2系統・共有境界軸・二段ゲート）
- [`promote/SKILL.md`](../skills/promote/SKILL.md) — 昇格 Issue を自動起票する Promote 段スキル（#348）
- #349 — 昇格先キャリアの4分類（D1）と Issue 規約として実現する方針（D2）の決定 Issue
