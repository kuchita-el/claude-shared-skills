# growth ユビキタス言語（用語集）

growth プラグインのドメイン用語を一箇所に集約した正典。設計の進行で用語が増減・drift しても、各語が「何を指すか」を作者の意図と一致した形で参照できる状態を保つことを目的とする。

## この用語集の読み方・書き方

- **見出しは日本語を正典とし、英語表記を括弧で併記する**（`## 観測（capture）`）。意図を日本語で固定し、英語語は追跡用の別名として扱う
- 各エントリは4欄スキーマで記述する:
  - **定義** — その語が何を指すか（1〜2文）
  - **使用箇所** — 主な出現ファイル・節
  - **避ける語** — 同一概念の揺れ・旧称・使うべきでない言い換え（無ければ省略）
- コード識別子（`status` の値 `unprocessed`/`promoted`、ファイル名 `captures.md` 等の機械値）は無理に和訳せず、概念のまとまりを日本語見出しにして値を英語のまま記す。各識別子の日本語対応は §8「コード識別子と日本語の対応表」で照合する
- 正典は `plugins/growth/DESIGN.md` の設計と整合させる。乖離を見つけたら本用語集か DESIGN.md のどちらかを直す

---

## 1. 学習ループの段

growth の中核フロー。`観測 → 仮説形成 → 仮説検証 → 配布 → 測定／撤回` の5段。スコープ仮説の付与（旧「経路判定」）は独立段でなく仮説形成に内在する（用語として退役。下記「〔退役〕経路判定 / route」を参照）。

### 学習ループ（learning loop）
- **定義**: 上記6段からなる、気付きを保存・検証して配布物へ届けるパイプライン全体。
- **使用箇所**: DESIGN.md §3
- **避ける語**: 「5段ループ」（段数は Phase で変わるため数を名前に含めない）

### 観測（capture）
- **定義**: 現セッションの会話履歴から学習シグナル（予測誤差検出器・教示信号検出器の2系統）を検知し、生の観察を個人ローカルの観測置き場に記録する学習ループの第1段。解釈・原因分析・対策は含めない。
- **使用箇所**: DESIGN.md §3・§4 / skills/capture/SKILL.md
- **避ける語**: 「reflect」（reflect/distill 分離（#347）以前の旧称。現在は capture に統一）

### 仮説形成（distill）
- **定義**: 個人ローカルの観測置き場の未処理の観察をクラスタ化・重複排除し、実行可能な振る舞い差分の候補へ変換する第2段。候補には [[スコープ仮説（scope-hypothesis）]]（2観点 project-local / universal）と [[キャリア仮説（career-hypothesis）]]（昇格先媒体）の2つの仮説を付与する（旧「経路判定」も career の判定も独立段でなく仮説形成に内在する責務。#411）。
- **使用箇所**: DESIGN.md §3・§4 / skills/distill/SKILL.md
- **避ける語**: 「route」「経路判定」「ルーティング」（スコープ仮説の付与を独立段・用語として呼ばない。仮説形成の責務に内在）

### 〔退役〕経路判定 / route
- **disposition**: 棄却（退役）。スコープ仮説の付与は仮説形成に内在し、独立段・用語として残す必要がないと判断（#408 レビュー）。DESIGN.md 決定事項（Route を distill へ統合）・learning-store-spec（仮説形成は project-local と universal の2観点に分かれる）が裏付け。
- **整合待ち（#409）**: DESIGN.md・personal-store-spec・learning-store-spec・learning-promotion-spec・promote 一式の「Route」語は未整合。#409 で「スコープ仮説の付与（仮説形成の責務）」言語へ伝播する（棄却 disposition の初回適用ケース）。
- **生き残る語**: 仮説形成が付与する2つの仮説 [[スコープ仮説（scope-hypothesis）]]（空間軸）と [[キャリア仮説（career-hypothesis）]]（キャリア軸）。#411 で career の判定も distill へ移り、旧「Route判定規則」も削除された（scope・career とも routing は仮説形成に内在）。

### 仮説検証（promote）
- **定義**: 仮説形成が生成した候補を検証し、検証通過分を `gh` で Issue へ自動起票して既存ワークフローへ渡す第3段（Phase 1 スキル）。候補の scope/career 仮説は確定せず注記のまま運ぶ（ルーティング不可知。#411）。最終裁定は集約点「取り込み Issue」が担う。
- **使用箇所**: DESIGN.md §3・§4 決定事項8 / skills/promote/SKILL.md
- **避ける語**: 段・スキルとしての「仮説検証（promote）」と、全移送過程を指す広義の「昇格（promotion）」を区別する。広義は [[昇格（広義）]] を参照

### 配布（distribute）
- **定義**: 検証済みの学びを `learnings.md` 等の配布物へ物理的に追加する第4段（Phase 2）。
- **使用箇所**: DESIGN.md §3 / references/learning-promotion-spec.md
- **避ける語**: 「昇格実行」「配布反映」（配布に統一）

### 測定（measure）／撤回（retire）
- **定義**: 配布後に学びの発火回数・効果を観測し（測定）、効かない・害ある学びを配布物から物理除去する（撤回）第5段（Phase 3）。
- **使用箇所**: DESIGN.md §3
- **避ける語**: 撤回の実体は [[整理]]（忘却・畳み込み）として記述される。除去を指すときは忘却/畳み込みを使う

---

## 7. 横断・広義の語

### 昇格（広義）（promotion）
- **定義**: 学びが観測置き場 → 候補 → Issue → learnings.md へ段階的に移送される過程全体。段・スキルとしての [[仮説検証（promote）]] より広い。
- **使用箇所**: DESIGN.md §3
- **避ける語**: 文中の「昇格」は広義（promotion＝全移送過程）を指す。段・スキルとしての promote は「仮説検証」を用い、両者を混同しない

### 予測誤差（prediction error）
- **定義**: 摩擦知の探知対象。「驚き」の源泉。訂正・ツール拒否・反復試行・期待違反・客観痕跡の5シグナル種別で表現される（予測誤差検出器が拾う摩擦サブセット）。判断知は予測誤差の形を持たず、別途 [[教示信号検出器（teaching-signal detector）]] が拾う。
- **使用箇所**: DESIGN.md §3 / skills/capture/SKILL.md
- **避ける語**: 「驚き」は説明語として可。シグナルの種別値は [[シグナル（signal）]]

### シグナル（signal）
- **定義**: 観察の種別値。摩擦知5値（訂正 / ツール拒否 / 反復試行 / 期待違反 / 客観痕跡）と判断知4値（選好 / 却下理由 / 目標表明 / 設計判断）。知識型（[[判断知（judgment knowledge）]] / [[摩擦知（friction knowledge）]]）は signal がどちらの群かで導出する。
- **使用箇所**: references/personal-store-spec.md / skills/capture/SKILL.md

### 復元不能性（non-recoverability）
- **定義**: 知識がリポジトリ（コード・git・ADR・spec）やハーネスから後で復元できないかを問う基準。判断知の価値軸（一次基準）。痕跡の有無と独立な直交軸（精緻化された原理3）。
- **使用箇所**: DESIGN.md 原理3 / §3 / ADR-20260701

### 判断知（judgment knowledge）
- **定義**: 選好・却下理由・目標表明・設計判断など、コードに現れず会話でしか交わされない決定知。価値軸は [[復元不能性（non-recoverability）]]。distill では `decision-record` 型として出力される。
- **使用箇所**: DESIGN.md §3 / ADR-20260701

### 摩擦知（friction knowledge）
- **定義**: 環境摩擦・手続違反など、単発では無価値だが横断集計で「配布したルールが機能していない」を示す知識。価値軸はハーネス非強制ルールの再発（#417）。distill では `behavior-diff` 型として出力される。
- **使用箇所**: DESIGN.md §3 / ADR-20260701

### 教示信号検出器（teaching-signal detector）
- **定義**: 予測誤差の形を持たない判断知（選好・理由付き却下・目標/意図・設計境界）を user 発話から recall 優先で拾う capture の検出器。復元不能性・価値判定は distill/promote に委ねる。
- **使用箇所**: skills/capture/SKILL.md / ADR-20260701
- **英語別名**: 括弧内の英語 gloss は `teaching-signal detector`（ADR-20260705-2 原則0 に基づき確定）。日本語正典 `教示信号検出器` を先行させ、英語は追跡用の別名として扱う。

### 混在ゾーン（mixed zone）
- **定義**: 1観測が `behavior-diff`（摩擦知）と `decision-record`（判断知）の両知識型にまたがる領域。#439 の直交性（検出方法 HOW ⊥ 価値族）の帰結として構造的に生じる。partition 硬度は非排他 tag（多値 set）で表現し、仮説形成（distill）が evidence-gated で確定する（#440・DESIGN.md 決定事項10）。
- **使用箇所**: DESIGN.md §6 決定事項10 / ADR-20260705-2 decision 2 追補
- **避ける語**: 「混在クラスタ」（distill-procedure.md §4.1 の**出所軸**〔`user-utterance` / `tool-result`〕の別概念。混在ゾーンは知識型軸であり、両者は直交する）

### フリート学習（fleet learning）
- **定義**: 単一ユーザーの N セッションより、M ユーザーの集合ログの方が学びが豊かという学習戦略。Phase 3 で横断解析として実装予定。
- **使用箇所**: DESIGN.md 原理6

---

## 8. コード識別子と日本語の対応表

英語のまま使うコード識別子（フィールド名・値・ファイル名）の日本語対応。「この英語値は何を指すか」を意図と照合する場。概念としての定義は各エントリ（§1〜§7）を参照。

### フィールド名

| コード識別子 | 日本語 | 意味・対応エントリ |
|---|---|---|
| `signal` | シグナル種別 | 予測誤差の種別 → シグナル（signal） |
| `session` | 出所セッション参照 | どのセッションの観察か（UUID） |
| `observation` | 観察（生観察） | 何が起きたかの生記録 → 観察（observation） |
| `status` | 処理状態 | 観測置き場の処理状態 → 処理状態（status） |
| `provenance` | 由来 | 候補の出自参照 → 由来（provenance） |
| `scope-hypothesis` | スコープ仮説 | 共有範囲の仮説タグ → スコープ仮説（scope-hypothesis） |
| `candidate-status` | 候補状態 | 候補の処理状態 → 候補状態（candidate-status） |
| `career-hypothesis` | キャリア仮説 | 昇格先キャリア＋宛先 repo の仮説 → キャリア仮説（career-hypothesis） |
| `tags` | 候補の知識型（多値 set） | 知識型による候補出力形の集合 → `{behavior-diff, decision-record}` の非空部分集合。混在ゾーンは両値併記。詳細は personal-store-spec.md「tags 別スキーマ」・#440 決定事項10 |

### フィールドの値

| コード識別子 | 日本語 | 属する欄 |
|---|---|---|
| `unprocessed` | 未処理（既定） | status |
| `promoted` | 昇格済み | status / candidate-status（後者は任意・推奨値） |
| `pending` | 検証待ち（既定） | candidate-status |
| `rejected` | 棄却 | candidate-status |
| `universal` | 全世界 × 全プロジェクト対象 | scope-hypothesis |
| `project-local` | チーム・プロジェクト限定 | scope-hypothesis |
| `behavior-diff` | 振る舞い差分（摩擦知） | tags |
| `decision-record` | 文脈付き決定知（判断知） | tags |

`signal` の値（摩擦知 `訂正` / `ツール拒否` / `反復試行` / `期待違反` / `客観痕跡`、判断知 `選好` / `却下理由` / `目標表明` / `設計判断`）は日本語を正準とする（personal-store-spec.md「シグナル種別」）。英語コードは持たない。

> **`type`→`tags` の設計決定と実装（#440・DESIGN.md §6 決定事項10 → #446 実装）**: [[混在ゾーン（mixed zone）]]（1観測が両知識型にまたがる）の partition 硬度を非排他 tag（多値 set）で確定したことに伴い（#440 決定事項10）、排他 `type`（単値）を廃し `candidates.md` では **`tags`（多値 set、値域 {behavior-diff, decision-record} の部分集合）**へ改称した。廃止されたのは排他制約であって `behavior-diff` / `decision-record` のカテゴリ自体は tag 値として存続する（旧 `type` 単値は後方互換で要素数1の `[<値>]` へ写す）。上表は改称後のスキーマ（`tags` 行）を反映する。物理スキーマ改称の実装（本対応表・personal-store-spec.md・distill/promote 手順書の書き換え）は #446 が担った。設計の一次記録は DESIGN.md §6 決定事項10。

### ファイル名・その他

| コード識別子 | 日本語 | 意味・対応エントリ |
|---|---|---|
| `captures.md` | 観測置き場 | → 観測置き場（captures.md） |
| `candidates.md` | 候補ファイル | → 候補ファイル（candidates.md） |
| `learnings.md` | 学び置き場 | → 学び置き場（learnings.md） |
| `project-id` | プロジェクト識別子 | 作業ディレクトリ絶対パスのスラッシュを `-` に置換した識別子 |
| `fan-out` | （暫定で英語のまま） | origin → consumer の一方向配布。和訳要否は #409 |
| `fan-in` | （暫定で英語のまま） | consumer → origin のフィードバック還流。和訳要否は #409 |

---

## 未収録（継続拡充候補）

初版では中核と英語ジャーゴン・表記揺れを優先した。以下は #409 の保守機構で順次定義する長い裾の用語（一部）:

パブリック／グローバル空間、閉じた空間、origin 面 / consumer 面、客観痕跡、生記録性、confabulation（作話）、仮説、記法ルール、1欄スキーマ、メタ欄、upsert、冪等性、一般化、抽出、見出し圧縮、疎結合、compaction（Claude Code 機能）、自発トリガー、横断解析、in-repo dogfooding、仮説検証ループ

※ コード識別子の値（universal / project-local、status・candidate-status の各値、project-id 等）は §8 の対応表で照合できる。

#405/#411 がマージ済みのため追補可能（#409 で拡充）: 取り込み Issue（集約点・最終裁定）、改善還元 / ADR 差分 / 強キャリア / learnings.md 行き 各キャリアの個別エントリ、宛先 repo 仮説
