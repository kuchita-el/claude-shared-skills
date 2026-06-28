# 配布物昇格 Issue 規約

growth プラグインの学習ループにおいて、`promote` スキル（#348）が検証通過候補を `gh` で自動起票する際の Issue 本文・ラベル・昇格先キャリアの判定規則を定義する。本仕様は配布物昇格 Issue の**テンプレート・ラベル体系・Route 判定規則の単一出典**であり、後続手順（各キャリアへの実書き込み・承認フロー配線）はここで定義した規約を入力として受け取る。

## 位置づけ

本仕様は、`DESIGN.md` の学習ループ（`[Capture] → [Distill] → [Route] → [Promote] → [Distribute]`）における Promote 段の終端規約である。promote スキルが起票した Issue を**入力として受ける**規約であり、起票された Issue がどの形式・どのラベル・どの昇格先キャリアを持つべきかを定める。

- **#349 Phase 2（D1〜D2）の具体化**: #349 が決めた「昇格先キャリアの4分類（D1）」と「新規スキルを作らず既存ワークフローに乗る Issue 規約として実現する（D2）」を、具体的なテンプレート・ラベル・判定規則へ落とし込む文書。設計判断の本文（なぜ4分類か等）は #349 D1 に既出のため本仕様には転記せず、運用可能な規約に徹する。
- **関連仕様との関係**:
  - [`learning-store-spec.md`](learning-store-spec.md) — 配布物（`learnings.md`）の**着地先形式**を定義する。昇格 Issue のうち learnings.md 行きのものが最終的に到達する先であり、本仕様はその1欄スキーマ（メタ欄を持たない）を壊さない制約に従う。
  - [`personal-store-spec.md`](personal-store-spec.md) — 昇格 Issue の**入力源**となる候補ファイル（`candidates.md`）の `scope-hypothesis`（`universal` / `project-local`）スキーマを定義する。本仕様のテンプレート「空間」欄はこのタグからマッピングされる。
  - [`DESIGN.md`](../DESIGN.md) — 設計母艦。学習ループ・2系統・共有境界軸・二段ゲートの原典。
- **promote（#348）との接続**: promote はこの規約を満たす Issue 本文を `--body-file` でプログラム生成し、`gh issue create` で自動起票する。本仕様は promote が起票した Issue の終端規約であり、promote 自身の検証・status 反転の手順（[`../skills/promote/references/promote-procedure.md`](../skills/promote/references/promote-procedure.md)）には踏み込まない。

## テンプレート

昇格 Issue の本文構造を定義する。GitHub ネイティブの `ISSUE_TEMPLATE`（`.github/` 配下の YAML/Markdown フォーム）は**採らない**。promote が `--body-file` でプログラム生成し GitHub の Issue 作成 UI を経由しないため、UI 連動のネイティブテンプレートは機能しない。本仕様は文書定義形式のテンプレートとして本文構造を規定する。

### Issue 本文の構造

昇格 Issue は次の3つを**必須欄**として持つ。いずれも単一値・規定の記法で記入する。

| 必須欄 | 記入規約 | 記法 |
|---|---|---|
| **昇格先キャリア** | D1 の4分類（learnings.md / ADR 差分 / dev-workflow Issue / 強キャリア）のいずれか**1つ**。「Route 判定規則」節の決定表が一意に出力した値を記入する（本欄の列挙は4分類の名称列挙であり評価順ではない。評価順は決定表が定める） | 単一値。4分類の名称をそのまま記す |
| **空間** | `パブリック` / `閉じた` の**いずれか1つ**。候補の `scope-hypothesis` からマッピングする（下記マッピング表） | 単一値 |
| **振る舞い差分** | 候補の規範（次回どう違う行動を取るか）。見出し（一文要約）＋理由（なぜその振る舞いを取るか） | 見出し1行＋理由本文（複数行可） |

加えて、下流の refine/review が判断材料にできるよう、promote の検証段が添えた「予測（次にどんな状況で効くか）」「検証観点（どの条件で反証されうるか）」を本文に含めてよい（任意。promote-procedure §5 と整合）。

### 空間欄のマッピング（promote の `## スコープ仮説` 出力から）

空間欄は、promote が Issue 本文へ出力する `## スコープ仮説`（candidates.md の `scope-hypothesis` タグに基づく。promote-procedure §4）から**欠落・改変なく**マッピングする。対応は次の通り。

| promote の `scope-hypothesis`（`## スコープ仮説` 出力） | 本テンプレートの空間欄 | 共有境界 |
|---|---|---|
| `universal` | `パブリック` | 全世界 × 全プロジェクト（パブリック/グローバル空間 = `learnings.md` 相当） |
| `project-local` | `閉じた` | チーム / プロジェクト（閉じた空間） |

- 空間情報は promote が付した仮説であり、本テンプレートは**保持するのみ**で確証・改変しない。最終裁定は起票後の refine/review が担う（promote-procedure §4 と整合）。
- マッピングは1対1であり、`universal`→`パブリック`、`project-local`→`閉じた` の2値以外を取らない。

### 記入済みサンプル

```markdown
## 昇格先キャリア
learnings.md

## 空間
パブリック

## 振る舞い差分
### ファイル復元には git restore を使う
ファイルを復元するとき git checkout ではなく git restore を使う。git checkout はブランチ切り替えと復元が多重定義されており、誤操作で別ブランチへ移る事故を招くため。

## スコープ仮説
- 適用範囲（仮説・未確証）: universal（パブリック/グローバル空間 = learnings.md 相当へ向かう候補）
- 最終裁定は refine/review に委ねる。本タグは Distill の蒸留観点に基づく仮説。

## 検証メモ
- 予測: ファイル復元を伴う全セッションで効く。
- 検証観点: git restore が使えない古い git バージョン環境では反証されうる。
```

### learnings.md の1欄スキーマを壊さない制約

昇格 Issue が運ぶメタ情報（昇格先キャリア・空間・provenance・予測/検証観点）は、**Issue 側に保持する**。learnings.md へ昇格する段（Distribute、#383/#384）で、これらメタ欄は配布物エントリへ持ち込まない。learnings.md は見出し＋本文の1欄スキーマ（[`learning-store-spec.md`](learning-store-spec.md)「1欄スキーマ」）であり、共有境界・provenance・撤回追跡は空間と git 履歴が担う。昇格 Issue のメタ情報はあくまで「揉む場」である Issue に留め、配布物の薄さ（原理5）を壊さない。

## Route 判定規則

候補の性質を入力に、昇格先キャリアを**一意に**出力する決定表を定義する（D1 の4分類）。一意性は入力条件の相互排他ではなく、**上から順に評価して最初に合致した行を採る順序評価**と、**行4を「上記いずれにも該当しない」残余枝（既定枝）として定義する**ことで保証する。行1〜3の条件は重なりうる（例: 強キャリア化可能な候補は同時に汎用ルールでもある）が、順序評価＋強キャリア最優先により一意に決まる。

### 決定表（D1 4キャリア）

| # | 入力条件（候補性質の判別基準。上から評価し最初に合致した行を採る） | 出力キャリア | キャリア固有の振る舞い注記 |
|---|---|---|---|
| 1 | 候補が **skill / hook / lint / test へ構造変換可能**な強キャリアである（決定論的ガードレールへ畳み込める。「二度と起こせない構造」へ変換できる） | 強キャリア（skill / hook / lint / test） | コードレベルの直接配布。**learnings.md に1欄を追加しない**（畳み込み対象。learning-store-spec.md「畳み込み」）。テキスト規範ではなく構造へ変換する |
| 2 | 候補が **dev-workflow スキル自体の改善**を命じる（既存スキルの手順・判定・出力形式の変更） | dev-workflow への Issue / PR | プロセス/ツール改善。growth の配布物ではなく dev-workflow プラグインへ Issue/PR を立てる（DESIGN.md「学びの2系統」上段） |
| 3 | 候補が **後戻りコストが高く横断再発する構造的な設計判断**である（複数モジュール波及・採用理由揮発・却下選択肢ありの設計決定） | ADR 差分 | `docs/adr/` への差分。ADR 運用ルールの粒度判定（README の4項目チェックリスト）に乗せる |
| 4 | 上記いずれにも該当しない、**テキスト規範として置くしかない汎用の振る舞いルール**（次回どう違う行動を取るかを一文で命じられる） | learnings.md | 知識配布先。growth の配布物（単一可読ファイル）へ1欄追加。強キャリアへ変換可能になれば畳み込みで除去される（learning-store-spec.md） |

### 一意性と曖昧時のフォールバック

- 入力条件は**上から順に評価し、最初に合致した行のキャリアを採る**。強キャリア（行1）への変換可能性を最優先に判定するのは、強制可能な制約 > 書かれたルール（原理4）に従い、可能な限り強いキャリアへ寄せるため。
- 行1〜3のいずれにも明確に該当しない候補は**既定枝として行4（learnings.md）にフォールバック**する。テキスト規範は最弱だが最も導入コストが低く、後から畳み込み（強キャリア化）で上へ移送できるため、迷う候補の既定の受け皿に適する。
- 強キャリア化の可否やキャリア妥当性に確信が持てない候補は、Issue として起票したうえで**最終裁定を起票後の refine/review に委ねる**（promote は確証しない。判定はあくまで仮説）。割り切れない候補を起票前に握り潰さず、下流ゲートへ送る。

### 判定例

| 候補（振る舞い差分） | 判別 | 出力キャリア |
|---|---|---|
| 「ファイル復元には `git checkout` ではなく `git restore` を使え」型の汎用規範 | 行1〜3に該当せず、テキスト規範として置く汎用ルール → 行4 | learnings.md |
| 「内省機能を dev-workflow に混ぜず独立プラグインへ分離する」型の構造判断 | 後戻りコスト高・横断・却下選択肢ありの設計決定 → 行3 | ADR 差分 |
| 「create-issue の AC 生成を検証可能性チェックで厳格化する」型 | dev-workflow スキル自体の手順改善 → 行2 | dev-workflow への Issue / PR |
| 「長文 CLI 引数の破損を lint で機械的に禁止する」型 | skill/hook/lint へ構造変換可能な強キャリア → 行1 | 強キャリア（lint） |

### キャリア軸 ⊥ 空間軸（直交）

この4キャリア軸（昇格先＝何のキャリアへ配るか）は、#348 の2空間軸（`universal` / `project-local` ＝ パブリック / 閉じた）と**直交する**（DESIGN.md「種別軸 ⊥ 共有境界軸」）。同じ learnings.md 行きの候補でもパブリック空間と閉じた空間に分かれうるため、テンプレートは昇格先キャリアと空間を独立した2欄として持つ。

## ラベル体系

昇格 Issue を機械的に絞り込めるよう、既存ラベル慣習（`growth`、`type:feature` の `prefix:value` 形式）に整合するラベル体系を定義する。

### ラベル定義

| ラベル | 役割 | hex | 根拠 |
|---|---|---|---|
| `growth:promote` | 識別（昇格 Issue 全体） | `#0B6E4F` | `growth #0E8A16` 同系の濃緑（teal 寄り）で growth ドメインの昇格ゲートを示す。キャリアの緑と被らせない |
| `promote:learnings` | キャリア: learnings.md | `#2DA44E` | 知識配布先。growth 系の緑で「学び」を想起 |
| `promote:adr` | キャリア: ADR 差分 | `#0969DA` | 設計判断。`type:feature` の青系に寄せる |
| `promote:dev-workflow` | キャリア: dev-workflow Issue | `#8250DF` | プロセス/ツール。`type:spike #5319E7` 系の紫 |
| `promote:strong` | キャリア: 強キャリア(skill/hook/lint/test) | `#BC4C00` | コードレベルの直接配布。暖色で「強・直接」 |

### 付与規約

- 識別ラベル `growth:promote` は既存 `growth` ラベルと**併用**する。昇格 Issue は `growth` ＋ `growth:promote` ＋ キャリア1種（`promote:*` のいずれか1つ）を持つ。`growth` は growth ドメイン全体の識別、`growth:promote` は昇格 Issue のサブ識別、`promote:*` は「Route 判定規則」が出力した昇格先キャリアに対応する。
- キャリアラベルは決定表の4分類に1対1で対応する（learnings.md→`promote:learnings`、ADR 差分→`promote:adr`、dev-workflow Issue→`promote:dev-workflow`、強キャリア→`promote:strong`）。

### 機械絞り込みレシピ

後続手順（#383/#384 等のキャリア別書き込み）は、ラベルの組み合わせで対象 Issue を機械的に絞り込む。例:

```bash
# learnings.md 行きの昇格 Issue（オープン）だけを列挙する
gh issue list --label growth:promote --label promote:learnings --state open

# ADR 差分行きの昇格 Issue を列挙する
gh issue list --label growth:promote --label promote:adr --state open
```

`--label` を複数指定すると AND 条件になるため、`growth:promote` ＋ キャリア1種で各キャリアの作業キューを一意に取り出せる。

ただし**空間（パブリック / 閉じた）はラベルで区別しない**。キャリア軸 ⊥ 空間軸の直交（前述）により、同一キャリアラベル（例 `promote:learnings`）にパブリックと閉じたが混在する。後続ハンドラがキャリア × 空間で仕分ける場合は、ラベルでキャリアを絞り込んだうえで Issue 本文の `## 空間` 欄を読んで最終仕分けする。

### セットアップ手順（ラベル実体の作成）

上記ラベルの**実体作成は本 PR では実行しない**。マージ前のリポジトリにラベルを作るとリポジトリ状態を汚すため、実作成は #385（承認フロー配線）またはセットアップ手順の実行時に委譲する。本仕様は作成コマンドを掲載するに留める。

```bash
# ラベル実体の作成（本 PR では実行しない。セットアップ時に実行する）
gh label create growth:promote        --color 0B6E4F --description "配布物昇格 Issue（識別）"
gh label create promote:learnings     --color 2DA44E --description "昇格先キャリア: learnings.md"
gh label create promote:adr           --color 0969DA --description "昇格先キャリア: ADR 差分"
gh label create promote:dev-workflow  --color 8250DF --description "昇格先キャリア: dev-workflow Issue"
gh label create promote:strong       --color BC4C00 --description "昇格先キャリア: 強キャリア(skill/hook/lint/test)"
```

## スコープ境界

| 本仕様が定義する（IN） | 本仕様が定義しない（OUT） |
|---|---|
| 昇格 Issue のテンプレート（3必須欄・空間マッピング・記入サンプル） | 各キャリアへの実書き込み手順（learnings.md / ADR / dev-workflow Issue / 強キャリアへの物理配布。#383/#384） |
| 昇格先キャリアを一意に出力する Route 判定規則（D1 4分類の決定表・フォールバック） | #348 の2空間 Route 最小（promote の `scope-hypothesis` 注記）の再実装（promote が既に担う。本仕様はその出力を入力として受けるのみ） |
| ラベル体系（5ラベル・色・付与規約・絞り込みレシピ） | 承認フロー・越境ゲートの配線（二段ゲート L2 の具体配線。#385） |
| learnings.md の1欄スキーマを壊さない制約 | ラベル実体の作成（`gh label create` の実行。#385/セットアップ手順へ委譲） |

## 関連

- [`learning-store-spec.md`](learning-store-spec.md) — 配布物（`learnings.md`）の着地先形式（1欄スキーマ・2空間モデル・参照規約）
- [`learning-promotion-spec.md`](learning-promotion-spec.md) — 本規約準拠の learnings.md 行き昇格 Issue を1欄エントリへ翻訳する変換規約（#383）。本仕様を入力として受ける後続手続き
- [`personal-store-spec.md`](personal-store-spec.md) — 昇格 Issue の入力源 候補ファイル（`candidates.md`）の `scope-hypothesis` スキーマ
- [`DESIGN.md`](../DESIGN.md) — 設計母艦（学習ループ・学びの2系統・共有境界軸・二段ゲート）
- [`promote/SKILL.md`](../skills/promote/SKILL.md) — 昇格 Issue を自動起票する Promote 段スキル（#348）
- #349 — 昇格先キャリアの4分類（D1）と Issue 規約として実現する方針（D2）の決定 Issue
