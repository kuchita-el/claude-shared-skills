# テストの実行

本リポジトリのテストと検査器を、何がいつ走り、どの範囲は手動で走らせる必要があるかを定める。

## 1. 何が走るか

実行経路は `scripts/run-tests.sh`（以下 runner）の1本である。runner は次の2スイートを順に実行する。

| スイート | 実体 | 内容 |
|---|---|---|
| `bats` | `scripts/tests/*.bats` | adr プラグイン同梱の検査器4本（`lint-adr.sh` / `gen-adr-index.sh` / `next-adr-id.sh` / `adr-scoping-cases.sh`）と、配布物外の `scripts/lint-domain-doc.sh` のテスト |
| `validate-skills` | `scripts/validate-skills.sh` | スキル定義の `allowed-tools` 検査 |

runner はいずれかが失敗しても残りを最後まで実行してから非0で終わる。失敗を1回の実行で出揃わせるためである。成功したスイートの出力は畳み、失敗したスイートの出力だけを展開する（bats については通過ケースの `ok ` 行も畳む）。

## 2. いつ走るか — 自動起動の射程

runner は commit ゲート（`scripts/hooks/pre-commit-gate.sh`）から起動される。ゲートは `.claude/settings.json` の PreToolUse フックに登録されており、検査が違反していれば exit 2 で commit をブロックする。

**自動起動が覆うのは、Claude Code の Bash ツール経由の `git commit` だけである。** 次の経路は素通りする。

- 素の端末（Claude Code を介さないシェル）からの `git commit`
- `git -C <path> commit`（ゲートのヘッダが既知の穴として明記している。ゲートは事故を防ぐガードレールであってセキュリティ境界ではないため、意図的な回避までは塞がない）

**これらの経路で作業する場合は、runner を手動実行する必要がある。** GitHub Actions 等の CI は導入していない（理由は §6 の問い1）。

### git worktree で作業する場合

本リポジトリの作業は git worktree 上で行うことが多い。**この経路でも自動起動は働き、検査対象になるのは worktree のツリーである**（`EnterWorktree` で入った worktree セッションでの実測。詳細は §8）。ただし検査対象が worktree になるのはゲート側の仕掛けによるものであり、worktree 固有の注意も2点ある。

**検査対象はゲートが git コンテキストから解決する。** `.claude/settings.json` のフックは `${CLAUDE_PROJECT_DIR}` 配下のゲートを起動し、同変数は project root（既定のチェックアウト）を指す。ゲートがそのまま `CLAUDE_PROJECT_DIR` を検査対象にすると、走るのは**コミット対象ではない別のツリー**に対する検査になり、project root が緑なら worktree の変更内容と無関係に通ってしまう。そこでゲートは「コミットが実際に走る git コンテキスト」から検査対象を解決する。候補を上から順に試し、git のトップレベルが取れ、かつそこに runner が在る最初のものを採る。

1. PreToolUse の JSON が載せる `cwd`（ツール実行時の作業ディレクトリ）
2. フックプロセス自身の cwd
3. `CLAUDE_PROJECT_DIR`（上2つが解決できない環境向けのフォールバック）

どの候補でも解決できなければ exit 2 とする（fail-closed）。runner の実在を条件に含めるのは、無関係なリポジトリで作業しているときに候補1・2 がそちらを指しても、本ゲートがその commit を巻き込んで止めないためである。

実測では、この解決の結果として worktree のツリーが検査対象になった。候補1が project root のツリー内のいずれかを指していれば、そこで確定していたはずである。ゲートは候補を `git -C <候補> rev-parse --show-toplevel` に掛けるため、指しているのがサブディレクトリであってもトップレベルは project root に解決され、runner も在るため候補2 へ進まない。そうならなかったことから、**候補1は project root のツリー内のどこも指していない**と言える。候補1と候補2 のどちらで解決したかは切り分けていない。観測される結果はどちらでも同じであるため、機構は断定しない。

**注意1: 起動されるゲートの実体は project root 側のものである。** フックのコマンドが `${CLAUDE_PROJECT_DIR}` 配下を指すため、worktree 側の `scripts/hooks/pre-commit-gate.sh` は呼ばれない（診断用に「必ず exit 2」で終わるゲートを worktree へ置いても commit が通ることを実測した）。ただし **project root 側なのはゲート本体だけである**。ゲートは解決したツリーへ `cd` してから runner を相対パスで起動するため、その配下で走る runner・テスト・検査器はいずれも worktree 側のものになる（§8 のマーカー観測）。したがって自動経路で検証されないのは `pre-commit-gate.sh` 自身の改修に限る。その場合は stdin へ PreToolUse の JSON を投入する形で手元から確かめる（コマンドの形は §8）。

**注意2: worktree ごとに `mise trust` が要る。** `mise` の信頼はディレクトリ単位であり、project root を信頼していても新しく作った worktree は未信頼のままである。この状態では `mise exec` 経由で bats を解決できない。PATH にも bats が無ければ runner は非0で終わり（§4 の fail-closed）、ゲートが exit 2 で commit をブロックする。§8 の実測はこの条件下のものである。stderr に導入（`mise install`）と信頼（`mise trust`）の案内が出るので、それに従う。fail-closed が意図どおり働いた結果であり、異常ではない。

`plugins/adr/hooks/adr-commit-gate` は別のゲートであり、`lint-adr.sh` を `docs/adr` へ掛けるだけで runner を呼ばない。この役割分離は意図的なものであり、本経路とは独立している。

## 3. 手動実行

```bash
# 全スイート（commit ゲートが呼ぶ形と同じ）
bash scripts/run-tests.sh

# スイートを1本に絞る（開発時の反復用）
bash scripts/run-tests.sh bats
bash scripts/run-tests.sh validate-skills

# スイート名の一覧
bash scripts/run-tests.sh --list

# bats のテストファイルをさらに絞る（runner を介さず直接呼ぶ）
mise exec -- bats scripts/tests/lint-adr-stem.bats

# ケース数だけを数える
mise exec -- bats --count scripts/tests/*.bats
```

## 4. セットアップ

テストフレームワークは bats-core であり、版は `mise.toml` で固定している。

```bash
mise trust     # チェックアウトごとに一度。未信頼のまま mise は mise.toml を読まない
mise install   # bats 1.14.0 が入る
```

`mise trust` の信頼はディレクトリ単位で効く。project root を信頼していても、新しく作った worktree は未信頼のままであり、そこで初めて作業するときに再度必要になる（§2 の注意2）。

runner は bats を **`mise exec` 優先・PATH フォールバック**の順で解決する。版固定を効かせつつ、mise を使わない環境での手動実行経路を残すためである。

**どちらでも解決できない場合、runner は成功扱いにせず非0で終わる（fail-closed）。**

```
$ bash scripts/run-tests.sh
run-tests: bats を解決できません（mise exec・PATH のいずれでも見つからない）
  導入: mise install   （リポジトリ直下の mise.toml が版を固定する）
  信頼: mise trust     （チェックアウトごとに一度。未信頼のまま mise は設定を読まない）
$ echo $?
1
```

スキップして成功にすると、検査が一度も走らないまま commit が通り、しかも警告が出ない。既存のゲートが jq 不在時の挙動を fail-safe 側へ倒しているのと同じ方針である。

`mise.toml` が未信頼のとき、mise は `mise ERROR Config files in ... are not trusted.` を出して exit 1 する。これは対話・非対話を問わない挙動であり（信頼を求めるプロンプトは出ない）、fail-closed は成立する。

`scripts/tests/` にテストファイルが1つも無い場合も非0で終わる。空実行を成功扱いにすると、パス誤りが緑として通るためである。

## 5. 失敗時の読み方

bats は TAP 形式で報告する。runner は失敗したスイートの出力にスイート名を前置し、通過ケースの行を畳んで出す。

```
[test ] bats                 ... FAILED (exit 1, 6s)
    bats| 1..76
    bats| not ok 56 面②: 参照ファイルが期待リストに被覆されている
    bats| #   `collect_finish' failed
    bats| # 1/7 件の検査項目が失敗しました（全件を列挙する）:
    bats| #   [FAIL] AC5: surface file list covers: .../adr-demotion.md -- surface file list does not cover: ...
[check] validate-skills      ... ok (0s)
FAILED: 1/2 suites (6s) -- bats
```

読み方の要点は3つ。

- **`1..76` が報告ケース総数**である。この値は失敗の有無・件数によらず一定である。テストファイルの前提（fixture corpus や被テスト検査器）が満たされない場合も、そのファイルのケース群が1件へ潰れることはない。専用の「前提: …」ケースが前提不成立を名指しして落ち、その前提に依存する面のケースも1件ずつ個別に落ちる（前提不成立の失敗が1件で済むという意味ではない。潰れないこと・総数が動かないことが不変条件である）。
- **`not ok` の行が失敗したケース**であり、続く `#` 行がその内訳である。1ケースは複数の検査項目を束ねており、`collect_finish` が**落ちた項目を全件列挙する**。1件目で打ち切らないため、複数の欠落があれば1回の実行で出揃う。
- **ケース説明文の「面」は検査の面**を指す。旧ランナーの `[PASS]` ラベルは各面の内側に検査項目のラベルとして残っている（§7 参照）。

## 6. 実行経路に関する決定

### 問い1: 実行経路をどこに置くか

**決定**: 既存の commit ゲート（`scripts/hooks/pre-commit-gate.sh`）の呼び先を全スイート runner へ差し替える。GitHub Actions 等の CI は新設しない。

**理由**:

- ゲートは既に存在し、`git commit` という「変更が確定する瞬間」に発火する。テストが走る契機としてはこれで足りる。CI を新設すると、同じ検査を2箇所で維持することになる。
- 本リポジトリはスキル定義とスクリプトの集合であり、ビルド成果物や配布パイプラインを持たない。CI が担う典型的な役割（マトリクス実行・成果物の生成・デプロイ）のいずれも現時点で必要としていない。
- `plugins/adr/hooks/adr-commit-gate` へテスト全体の実行を足すことは採らない。同フックは ADR 検査へ役割を絞ることを冒頭コメントで明示しており、配布物として利用者のリポジトリでも動く。配布元固有のテストをそこへ足すと、配布先で解決できない参照が生じる。

**受容した犠牲**: 自動起動の射程が Claude Code の Bash ツール経由の commit に限られる（§2）。素の端末からの commit と `git -C` は素通りする。これは手動実行の明記で補う。

### 問い2: 実行経路は配布物境界のどちら側に属するか

**決定**: 配布物外（配布元）に置く。runner（`scripts/run-tests.sh`）・テスト（`scripts/tests/*.bats`）・fixture（`scripts/fixtures/`）のいずれもリポジトリルート配下に置き、配布物（`plugins/`）には持ち込まない。

**理由**:

- `docs/distribution-boundary.md` §2 の判断軸は「引数ですべての入力を受け既定値を持たない検査器は配布物へ、特定の corpus を前提とするテストは配布元へ」である。runner は本リポジトリのスイート構成・スクリプト配置を直接知っており、この軸では配布元側に落ちる。
- 参照方向の一方向性（配布物外 → 配布物内）を保つ。runner は配布物内の検査器を起動するが、配布物側は runner の存在を知らない。

**この決定を `docs/distribution-boundary.md` へ節として足さず、本書へ記録した理由**: 同文書 §1 が「配布物の内部構成（スキル・スクリプト・hook の分割）」を定めないと自ら宣言しており、実行経路の帰属はその明文の外にある。節を足すのは文書が引いた射程線を動かす行為であり、後続の判断が「どこまでがこの文書の責務か」を再び曖昧にする。ただし §3（テストと fixture の配置）は現況の置き場所を述べる記述であるため、実行経路が同じ側に属することと `scripts/tests/` への移動はそちらへ反映してある。

### ADR 化要否の判定（2026-08-01）

判定基準は `plugins/adr/skills/manage-adr/references/adr-scoping.md` に従う。必要条件（却下代替が在ること）を先に確認し、成立する場合のみ粒度判定基準4項目で採点した。

#### 問い1

**必要条件: 成立**。却下した選択肢と却下理由が対で特定できる — (a) GitHub Actions による CI の新設（同じ検査を2箇所で維持することになり、かつビルド成果物・配布パイプラインを持たない本リポジトリでは CI の典型的役割が要らない）、(b) `plugins/adr/hooks/adr-commit-gate` へテスト全体の実行を足す（同フックは配布物であり ADR 検査へ役割を絞ることを明示している。配布元固有のテストを足すと配布先で解決できない参照が生じる）、(c) runner を置いて手動運用のみとする（「実行が作業者の記憶に依存する」という本 Issue の課題が解消しない）。

| 項目 | 点 | 判定の根拠 |
|---|---|---|
| 1. 後戻りコストが高い | 0 | 反転（CI を新設しゲートから外す）で修正が要るのは `pre-commit-gate.sh` と本書の2本。CI 設定は新規追加であり既存ファイルの修正ではない。非本数条件4種（構造変更・スキーマ変更・配布済み成果物への影響・蓄積データの移行）はいずれも非該当 |
| 2. 複数の適用先に波及する | 0 | 規範が適用されるのは起動元である commit ゲート1つ。テスト・検査器は起動される側であり、起動場所の規範の適用先ではない |
| 3. 採用理由が揮発しやすい | 0 | 保持先が `scripts/hooks/pre-commit-gate.sh`（検査・強制の実行を組み込むフック）であり値域(A) を満たす |
| 4. ツールで自動強制できない | 0 | 射程内（Claude Code の Bash ツール経由の commit）では現に exit 2 で阻止される。射程外の穴があることは「警告どまり」には当たらない |
| **合計** | **0** | |

**結論: ADR 化しない**（2点以下）。行き先は「ツールで自動強制される規範 → 実装・テスト資産・操作手順」であり、`scripts/hooks/pre-commit-gate.sh`・`scripts/run-tests.sh`・本書（実行手順書）に置く。採用理由と既知の限界（§2 の射程外の穴）は併記済みである。

#### 問い2

**必要条件: 成立**。却下した選択肢は「実行経路（runner）を配布物（`plugins/`）内へ置く」であり、却下理由は「runner は本リポジトリのスイート構成とスクリプト配置を直接知っており、`docs/distribution-boundary.md` §2 の判断軸（引数ですべての入力を受け既定値を持たない検査器のみ配布物へ）では配布元側に落ちる。配布物内へ置くと参照方向の一方向性が破れる」である。

| 項目 | 点 | 判定の根拠 |
|---|---|---|
| 1. 後戻りコストが高い | 1 | 反転で `run-tests.sh` 本体・`pre-commit-gate.sh`・`distribution-boundary.md` §3・本書の4本に修正が要る（3本以上）。加えて非本数条件「ファイル群の構造変更（配置の規約変更）」にも当たる |
| 2. 複数の適用先に波及する | 0 | 新たに決めたのは runner の帰属のみである。テスト・fixture の帰属は `distribution-boundary.md` §3 が既に定めており本決定の適用先ではない。ゲートは既に配布物外に在る。数える単位が2つ以上か迷うため、同点処理により0点 |
| 3. 採用理由が揮発しやすい | 0 | 保持先が `docs/distribution-boundary.md`（共有規約文書）であり、§3 に採用理由（参照方向を一方向に固定する）が現に書かれているため値域(B) を満たす |
| 4. ツールで自動強制できない | 1 | 実行経路が配布物内へ移されたことを検出する検査は無い。`adr-scoping-cases-edge.bats` 面⑤の走査は被テスト検査器1本と配布物内の Issue 番号に限られ、この違反を検出しない |
| **合計** | **2** | |

**結論: ADR 化しない**（2点以下）。行き先は「ツールでは強制できないが複数の箇所へ効かせたい規範 → 共有規約文書」であり、規範そのものは `docs/distribution-boundary.md` §3 に、採用理由は同節に置いてある。本書 §6 の記述はその決定に至った経緯（既存の判断軸をどう適用したか、なぜ境界文書へ節を足さなかったか）であり、規範の正本ではない。

なお `ADR-202607230648-01`（ADR 運用機構のプラグイン抽出）決定2 の射程の注記は、テスト・fixture の配布物内／外の別を自らの射程外と明示している。実行経路の帰属を扱う既存 ADR は無く、既存 ADR の枠組みへの非core 改訂にもあたらない。

## 7. 移行の対応（旧ランナー → bats）

テストは bash のランナー4本（`scripts/test-*.sh`）から bats のケースへ載せ替えた。対応の要約は次のとおり。

| 移行前のランナー | 緑経路の `[PASS]` ラベル数 | 移行後のファイル | ケース数 |
|---|---|---|---|
| `test-lint-adr.sh` | 137 | `lint-adr-index.bats` / `lint-adr-layers.bats` / `lint-adr-xref.bats` / `lint-adr-surface.bats` / `lint-adr-stem.bats` | 3 / 17 / 7 / 5 / 9 = 41 |
| `test-adr-scoping-cases.sh` | 75 | `adr-scoping-cases-basic.bats` / `adr-scoping-cases-edge.bats` | 16 / 8 = 24 |
| `test-lint-domain-doc.sh` | 5 | `lint-domain-doc.bats` | 3 |
| `test-next-adr-id.sh` | 14 | `next-adr-id.bats` | 7 |
| 合計 | 231 | 9ファイル | **75** |

**ケース数はアサーション数ではない。** 1ケースは検査の面に対応し、その面に属する検査項目（旧ランナーの `[PASS]` ラベル）を内側に束ねている。移行の完了時点では、旧ラベル231件はすべて `.bats` 本文へ文字列として残してあり、`grep -F` で1件ずつ突き合わせて欠落0件を確認した。その後 2026-08-07 のパーク欄廃止（#563）で `lint-adr-xref.bats` のラベルが8種変化しており、以降は欠落0件が成立しない。**移行に伴う喪失と、廃止に伴う意図的な削除・言い換えを混同しないこと。** 内訳は次のとおり。

- **削除4件**: `(AC6/AC7): 保留した決定が非存在slugを指すと dangling 参照違反` 系3件（exit 1／`dangling 参照違反` を含む／`ADR-202612121021-01-park-missing` を含む）と、`(park link dedup): リンク形式 park dangling は1回のみ報告（count=1）`
- **言い換え4件**: `(AC2/AC7-誤検出回避)` 系3件は park の記述を落として `(AC2-誤検出回避)` へ。`(AC5): ヘッダにレイヤ4（Related/park 参照の生存性・実在性）仕様が成文化されている` は `（Related 参照の生存性・実在性）` へ

75 の内訳は **面 66 ＋ 前提不成立 9** である。旧ラベルを持たない新規ケースは次の **11件** に限る。

- **前提不成立ケース 9件**（`.bats` ファイル1つにつき1件）— fixture corpus・被テスト検査器の不在を、ファイル全体の潰れではなく専用ケースの失敗として報告するためのもの。bats は `setup_file` が失敗するとそのファイルの全ケースを1件へ潰し、報告総数が失敗の有無で変動する。これを避けるため、共有 `setup_file` は判定を一切せず常に `return 0` で終わり、前提の判定は専用ケースが行う。
- **`lint-adr-surface.bats` の面①（期待リストのファイル存在）と面②（参照ファイルの被覆）の 2件** — 旧 `run_ac5_edit_mechanism` はこの2検査について失敗時にしか総数を加算せず、緑経路では `[PASS]` を1件も出さなかった。集約報告化に伴い緑経路でも報告される独立ケースになるため、旧ラベルを持たない新規ケースとして扱う。前提不成立ケースではない。

移行前後で「実行アサーション数が保存される」という不変条件は採らない。旧ランナーの総数加算箇所の多くは前提不成立分岐であり、それをケース化すれば総数は必ず増えるため、等号は算術的に成立しない。代わりに「旧ラベル集合の包含」と「増分の事前宣言（上記11件）」を不変条件とした。

## 8. 動作確認済み

- **2026-08-01（#645）**: 移行完了時点の実測。
  - `bash scripts/run-tests.sh` が exit 0。報告ケース数 76、失敗 0。
  - 所要時間は 6.0〜9.4 秒（同一環境で3回計測。初回 9.44s / 2回目 6.84s / 3回目 6.04s）。実装時の見込み（約6秒）の範囲内であり、面のさらなる集約を検討する閾値（10秒）は超えていない。
  - **AC2 の失敗観測**: `scripts/tests/lint-adr-surface.bats` の期待リストから `adr-demotion.md` を1件外した状態で、
    - `bash scripts/run-tests.sh` → exit 1。`not ok 56 面②: 参照ファイルが期待リストに被覆されている` と、未登録ファイル名を名指す `[FAIL]` 行が出る。報告ケース総数は 76 のまま変わらない。
    - commit ゲートへ PreToolUse の JSON を投入 → **exit 2**（commit をブロックする状態）。stderr に失敗したスイート名とケース名が現れる。

      ```bash
      printf '%s' '{"tool_input":{"command":"git commit -m \"任意の変更\""}}' \
        | CLAUDE_PROJECT_DIR="$PWD" bash scripts/hooks/pre-commit-gate.sh
      ```
    - 期待リストを復元 → runner が exit 0、ゲートが exit 0。
  - この失敗は Issue #645 の発端となった検知漏れ（`manage-adr/references/` へファイルが増えたのに期待リストへ未登録）と同一の型である。
  - **検査対象ツリーの解決**（§2「git worktree で作業する場合」）: JSON の `cwd` に worktree を、`CLAUDE_PROJECT_DIR` に project root を与えた状態で、worktree 側だけを壊すと exit 2、戻すと exit 0 になることを確認。`cwd` を持たない JSON・git 外の cwd・runner を持たないツリーの各分岐についても、フォールバック順と fail-closed（exit 2）を確認した。
  - **観測方法についての注記**: 上記のゲート観測は PreToolUse の JSON を stdin へ直接投入する形で行った。ゲートが受け取る入力は PreToolUse の JSON そのものであり、投入経路はゲートの判定に影響しないため、ブロック挙動の証拠としては等価である。ハーネス経由での実地確認は #653 で別途行った（下記）。
  - **bats 解決失敗時の fail-closed**: `mise` も PATH 上の `bats` も見えない環境（`env -i PATH=/usr/bin:/bin`）で runner を起動すると exit 1 で終わり、導入手順（`mise install` / `mise trust`）が stderr に出ることを確認。
- **2026-08-01（#653）**: worktree セッションからハーネス経由（Claude Code の Bash ツールで `git commit --allow-empty` を打つ形）で観測した。`EnterWorktree` で入った worktree から2回実施し、いずれも同じ結果。
  - 観測手段は2系統。`ps -eo pid=,args=` を 0.05 秒間隔でポーリングして `pre-commit-gate.sh` / `run-tests.sh` / `bats` のプロセスを拾い `readlink /proc/<pid>/cwd` で cwd を読む方法と、worktree 側の `scripts/run-tests.sh` 冒頭にのみ `$PWD` を追記するマーカーを一時的に仕込む方法（観測後に `git restore` で戻す）。
  - **ゲートは発火する**。起動されたのは project root 側の `pre-commit-gate.sh` であり、その配下で `bash scripts/run-tests.sh` が **cwd=worktree** で走った。worktree 側マーカーも `PWD=worktree` で発火した。観測期間中、cwd が project root のプロセスは1つも現れていない。所要は約6.2秒（プロセス初出から最終出現まで）、commit は exit 0 で通った。
  - **未信頼 worktree での fail-closed**: 1回目は worktree の `mise.toml` が未信頼で bats を解決できず、runner が非0、ゲートが exit 2 で commit をブロックした。runner は `mise exec` に失敗すると PATH へフォールバックする（§4）ため、この環境では PATH 上にも `bats` が無かったことになる。`mise trust --show` で project root=trusted / worktree=untrusted を確認。`mise trust` 後に上記の緑になった。
  - この観測により、#645 時点の §2 の記述（worktree では自動起動が働かないため手動実行が要る）が誤りであることが確定した。
