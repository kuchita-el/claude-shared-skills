# テストの実行

本リポジトリのテストと検査器を、何がいつ走り、どの範囲は手動で走らせる必要があるかを定める。

## 1. 何が走るか

実行経路は `scripts/run-tests.sh`（以下 runner）の1本である。runner は下表のスイートを順に実行する。`claude-plugin-validate` と `living-spec` を除くスイートはfail-closedである。この2つは前提のコマンド（`claude`・`pnpm`）を解決できない場合にSKIPPEDとして理由を展開し緑で終わる（CI は要求モードで失敗へ倒す。後述）。

| スイート | 実体 | 内容 |
|---|---|---|
| `bats` | `scripts/tests/*.bats` | adr プラグイン同梱の検査器のテスト・writing プラグイン同梱の検査器のテスト・living-spec プラグインの中継（`scripts/run.mjs`）が検査器を見つけられないときの振る舞い・配布物と配布元の一方向性の検査・`run-codex-local.sh` の開発用ホームでの起動・runner 自身の fail-closed 検査（`scripts/tests/*.bats` の網羅列挙ではない） |
| `living-spec` | `pnpm --dir tools/living-spec test`（依存が入っていなければ先に `pnpm --dir tools/living-spec install --frozen-lockfile`） | living-spec の検査器の試験（規則の分岐・読み込みから出力までの見本・入口・描画） |
| `validate-plugin-manifests` | `scripts/validate-plugin-manifests.sh .` | marketplace、manifest、README、skill集合の双方向一致 |
| `validate-plugin-portability` | `scripts/validate-plugin-portability.sh .` | matrix、permission ledger、参照境界 |
| `claude-plugin-validate` | `claude plugin validate .` | marketplace定義と、そこから解決できたClaude側plugin manifestのスキーマ検証（非strict） |

この検査が読むのはmarketplace定義と、そこが `source` で指すClaude側の `plugin.json` だけである。Codex側のmarketplaceとmanifest（`.agents/plugins/marketplace.json` / `.codex-plugin/plugin.json`）は参照されない。両host manifestの整合を見るのは `validate-plugin-manifests` の `name` 一致とskill集合一致であり、本検査はその代わりにならない。marketplaceの項目が解決できなくなった場合、警告もエラーも出ないまま検査対象が静かに縮む（`source` を不在パスへ書き換えると警告件数が減ってrc=0）。この縮みを拾うのは `validate-plugin-manifests` 側である。

`claude-plugin-validate` は実体が外部CLIであり、他の検査器と違って `claude` をPATH上に解決できない場合はSKIPPEDとして理由を展開し、集計行にも `skipped: claude-plugin-validate` を出したうえで緑で終わる。`mise.toml` で版を固定する経路（npm backend）は形式上存在するが採らない——採ると利用者が各自の方法で既に導入している `claude` を、mise管理下の別実体でシャドウすることになる。固定できないのではなく、手元の導入を上書きしない側を選んだ結果である。fail-closedの担保はCI側にあり、`.github/workflows/test.yml` が版を固定した `npm install -g @anthropic-ai/claude-code@<version>` でCLIを導入したうえで、`RUN_TESTS_REQUIRE_ALL_SUITES=1` を立ててrunnerを呼ぶ。同変数が立っている環境では、runnerは前提不成立をSKIPPEDではなくFAILEDとして扱う。CLIの導入に失敗しても緑で素通りしないための担保である。同変数の値域は `1` / `0` / 未設定に限り、それ以外の値（`true`・`yes` 等）はrunnerが理由を出して非0で終わる。要求モードのつもりで立てた値が黙って「skip可」と解釈されると、検査が一度も走らないまま緑を受け取るためである。この検査が掛かるのは値だけであり、変数名を取り違えた場合は未設定と区別がつかないため届かない。skip・実行・要求モードの3経路、値域外の拒否、およびCIがrunnerを起動するそのstepで同変数を立てていることは `scripts/tests/run-tests-runner.bats` が固定する。同ファイルはworkflowをstep単位で読み、`if:` の付与・引数の追加・envの別stepへの移動といった、担保を消しながら文字列としては残る変異を赤にする。`--strict` は採らない。同オプションはversionフィールドの欠落を含む警告をエラーへ昇格させるが、本リポジトリは版をコミットSHAへ委ねておりversionを持たない（ADR-202609061416-01）。

runner はいずれかが失敗しても残りを最後まで実行してから非0で終わる。失敗を1回の実行で出揃わせるためである。成功したスイートの出力は畳み、失敗したスイートの出力だけを展開する（bats については通過ケースの `ok ` 行も畳む）。

living-spec の検査器はプラグインに含めず、`tools/living-spec` からソースでビルドして使う（生成物 `dist/` は追跡しない）。規則の分岐（ファイルを置かない試験）・読み込みから出力までの見本・入口・描画は工場側の試験が持ち、runner の `living-spec` スイートが走らせる（`pnpm` は `mise.toml` が版を固定する）。プラグインの中継の振る舞いは、偽の検査器を使う `living-spec-run.bats` が見る。

Writing Wave 2の追加検査は`writing-lint.bats`と`writing-contract.bats`で行う。前者は`lint-ja.sh`のfile/diff、候補、長文、退役ADR境界を検査し、後者はskill/agent、F1/F3/F4/F5正負fixture、最大2回loop、両host matrix、permission ledgerを検査する。Codex agent登録面が利用できない場合の明示起動・degraded手動検査は、`plugins/writing/compatibility.json`へ記録する。

配布プラグインの `claude plugin eval` ケース（`evals/<plugin>/`）は runner に含めない。理由・実行手順・基準値は §7 を参照。

## 2. いつ走るか — 自動起動の射程

runner は commit ゲート（`scripts/hooks/pre-commit-gate.sh`）から起動される。ゲートは `.claude/settings.json` の PreToolUse フックに登録されており、検査が違反していれば exit 2 で commit をブロックする。

**自動起動が覆うのは、Claude Code の Bash ツール経由の `git commit` だけである。** 次の経路は素通りする。

- 素の端末（Claude Code を介さないシェル）からの `git commit`
- `git -C <path> commit`（ゲートのヘッダが既知の穴として明記している。ゲートは事故を防ぐガードレールであってセキュリティ境界ではないため、意図的な回避までは塞がない）

**これらの経路で作業する場合は、runner を手動実行する必要がある。** ただし GitHub Actions が pull request と main への push で runner を実行する（`.github/workflows/test.yml`）ため、検査を受けずに済むのは push 前のローカル作業に限られる。二経路の役割分担は §6 の問い1 が定める。

### git worktree で作業する場合

本リポジトリの作業は git worktree 上で行うことが多い。**この経路でも自動起動は働き、検査対象になるのは worktree のツリーである**（2026-08-01、`EnterWorktree` で入った worktree セッションから `git commit` を打ち、runner が worktree のツリーで走ることを観測）。ただし検査対象が worktree になるのはゲート側の仕掛けによるものであり、worktree 固有の注意も2点ある。

**検査対象はゲートが git コンテキストから解決する。** `.claude/settings.json` のフックは `${CLAUDE_PROJECT_DIR}` 配下のゲートを起動し、同変数は project root（既定のチェックアウト）を指す。ゲートがそのまま `CLAUDE_PROJECT_DIR` を検査対象にすると、走るのは**コミット対象ではない別のツリー**に対する検査になり、project root が緑なら worktree の変更内容と無関係に通ってしまう。そこでゲートは「コミットが実際に走る git コンテキスト」から検査対象を解決する。候補を上から順に試し、git のトップレベルが取れ、かつそこに runner が在る最初のものを採る。

1. PreToolUse の JSON が載せる `cwd`（ツール実行時の作業ディレクトリ）
2. フックプロセス自身の cwd
3. `CLAUDE_PROJECT_DIR`（上2つが解決できない環境向けのフォールバック）

どの候補でも解決できなければ exit 2 とする（fail-closed）。runner の実在を条件に含めるのは、無関係なリポジトリで作業しているときに候補1・2 がそちらを指しても、本ゲートがその commit を巻き込んで止めないためである。

実測では、この解決の結果として worktree のツリーが検査対象になった。候補1が project root のツリー内のいずれかを指していれば、そこで確定していたはずである。ゲートは候補を `git -C <候補> rev-parse --show-toplevel` に掛けるため、指しているのがサブディレクトリであってもトップレベルは project root に解決され、runner も在るため候補2 へ進まない。そうならなかったことから、**候補1は project root のツリー内のどこも指していない**と言える。候補1と候補2 のどちらで解決したかは切り分けていない。観測される結果はどちらでも同じであるため、機構は断定しない。

**注意1: 起動されるゲートの実体は project root 側のものである。** フックのコマンドが `${CLAUDE_PROJECT_DIR}` 配下を指すため、worktree 側の `scripts/hooks/pre-commit-gate.sh` は呼ばれない（診断用に「必ず exit 2」で終わるゲートを worktree へ置いても commit が通ることを実測した）。ただし **project root 側なのはゲート本体だけである**。ゲートは解決したツリーへ `cd` してから runner を相対パスで起動するため、その配下で走る runner・テスト・検査器はいずれも worktree 側のものになる。したがって自動経路で検証されないのは `pre-commit-gate.sh` 自身の改修に限る。その場合は stdin へ PreToolUse の JSON を投入する形で手元から確かめる（コマンドの形は §3）。

**注意2: worktree ごとに `mise trust` が要る。** `mise` の信頼はディレクトリ単位であり、project root を信頼していても新しく作った worktree は未信頼のままである。この状態では `mise exec` 経由で bats を解決できない。PATH にも bats が無ければ runner は非0で終わり（§4 の fail-closed）、ゲートが exit 2 で commit をブロックする。stderr に導入（`mise install`）と信頼（`mise trust`）の案内が出るので、それに従う。fail-closed が意図どおり働いた結果であり、異常ではない。

`plugins/adr/hooks/adr-commit-gate` は別のゲートであり、`lint-adr.sh` を `docs/adr` へ掛けるだけで runner を呼ばない。この役割分離は意図的なものであり、本経路とは独立している。

## 3. 手動実行

```bash
# 全スイート（commit ゲートが呼ぶ形と同じ）
bash scripts/run-tests.sh

# スイートを1本に絞る（開発時の反復用）
bash scripts/run-tests.sh bats
bash scripts/run-tests.sh validate-plugin-manifests
bash scripts/run-tests.sh validate-plugin-portability
bash scripts/run-tests.sh claude-plugin-validate

# スイート名の一覧
bash scripts/run-tests.sh --list

# bats のテストファイルをさらに絞る（runner を介さず直接呼ぶ）
mise exec -- bats scripts/tests/lint-adr-stem.bats

# ケース数だけを数える
mise exec -- bats --count scripts/tests/*.bats

# commit ゲートを手元から確かめる（PreToolUse の JSON を stdin へ投入する）
printf '%s' '{"tool_input":{"command":"git commit -m \"任意の変更\""}}' \
  | CLAUDE_PROJECT_DIR="$PWD" bash scripts/hooks/pre-commit-gate.sh
```

各検査器は対象集合0件、JSON不正、期待集合と実集合の不一致を非0にする。host smokeは固定promptを各3回実行し、skill-load観測APIが無い場合は自動合格にせず、`degraded` 手動検査として証拠を保存する（証拠の保存先は各Waveの運用文書に従う）。

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

読み方の要点は3つ。

- **`1..N`（N はテストファイルの増減に応じて変わる報告ケース総数）**は失敗の有無・件数によらず一定である。テストファイルの前提（fixture の ADR 群や被テスト検査器）が満たされない場合も、そのファイルのケース群が1件へ潰れることはない。専用の「前提: …」ケースが前提不成立を名指しして落ち、その前提に依存する面のケースも1件ずつ個別に落ちる（前提不成立の失敗が1件で済むという意味ではない。潰れないこと・総数が動かないことが不変条件である）。現在値は §3 のケース計数コマンドで求められる。
- **`not ok` の行が失敗したケース**であり、続く `#` 行がその内訳である。1ケースは複数の検査項目を束ねており、`collect_finish` が**落ちた項目を全件列挙する**。1件目で打ち切らないため、複数の欠落があれば1回の実行で出揃う。
- **ケース説明文の「面」は検査の面**を指す。

## 6. 実行経路に関する決定

### 問い1: 実行経路をどこに置くか

**決定**: commit ゲート（`scripts/hooks/pre-commit-gate.sh`）と GitHub Actions（`.github/workflows/test.yml`）の二経路で runner を起動する。ゲートは `git commit` の瞬間に、CI は pull request と main への push の時点に発火する。

**理由**:

- ゲートは `git commit` という「変更が確定する瞬間」に発火し、手元で赤を出せる。CI はゲートの射程外（素の端末からの commit・`git -C`）を push の時点で拾う。二経路は同じ検査の二重維持ではなく、射程の異なる補い合いである。
- `claude-plugin-validate` だけが fail-closed の例外であり、その担保（前提不成立を失敗として扱う要求モード）を置ける場所は CI 側にしかない（§1）。
- `plugins/adr/hooks/adr-commit-gate` へテスト全体の実行を足すことは採らない。同フックは ADR 検査へ役割を絞ることを冒頭コメントで明示しており、配布物として利用者のリポジトリでも動く。配布元固有のテストをそこへ足すと、配布先で解決できない参照が生じる。
- runner を置いて手動運用のみとすることは採らない。実行が作業者の記憶に依存し、実行経路を定める目的が果たせない。

**受容した犠牲**: 手元のゲートが覆うのは Claude Code の Bash ツール経由の commit だけである（§2）。素の端末からの commit と `git -C` は、検出が push 時点の CI まで遅れる。

**ADR 化しない**。`plugins/adr/skills/manage-adr/references/adr-scoping.md` の粒度判定で閾値に達しない（反転に要る修正は起動元2本と本書に限られ、規範の適用先は起動場所だけで、射程内の違反はツールが現に阻止する）。行き先は「ツールで自動強制される規範 → 実装・テスト資産・操作手順」である。規範の実体は `scripts/hooks/pre-commit-gate.sh`・`scripts/run-tests.sh`・`.github/workflows/test.yml` が持ち、採用理由と既知の限界は本節と §2 に置く。

### 問い2: 実行経路は配布物境界のどちら側に属するか

**決定**: 配布物外（配布元）に置く。runner（`scripts/run-tests.sh`）・テスト（`scripts/tests/*.bats`）・fixture（`scripts/fixtures/`）のいずれもリポジトリルート配下に置き、配布物（`plugins/`）には持ち込まない。

**理由**:

- `docs/distribution-boundary.md` §2 の判断軸は「引数ですべての入力を受け既定値を持たない検査器は配布物へ、特定の ADR 群を前提とするテストは配布元へ」である。runner は本リポジトリのスイート構成・スクリプト配置を直接知っており、この軸では配布元側に落ちる。
- 参照方向の一方向性（配布物外 → 配布物内）を保つ。runner は配布物内の検査器を起動するが、配布物側は runner の存在を知らない。

**この決定を `docs/distribution-boundary.md` へ節として足さず、本書へ記録した理由**: 同文書 §1 が「配布物の内部構成（スキル・スクリプト・hook の分割）」を定めないと自ら宣言しており、実行経路の帰属はその明文の外にある。節を足すのは文書が引いた射程線を動かす行為であり、後続の判断が「どこまでがこの文書の責務か」を再び曖昧にする。ただし §3（テストと fixture の配置）は現況の置き場所を述べる記述であるため、実行経路が同じ側に属することと `scripts/tests/` への移動はそちらへ反映してある。

## 7. 配布プラグインの eval（`claude plugin eval`）

配布プラグインのプロンプト（trigger の発火条件・behavior の手順）を変更する作業で、変更前後の挙動の差を再現可能に比べるための手動実行系である。runner（`bash scripts/run-tests.sh`）には**組み込まない**。eval は課金を伴い、かつログイン済みの子セッション（`claude` の認証情報）を要する。commit ゲート・CIの双方から自動起動される runner にこれを混ぜると、commit のたびに課金が発生し、CI 環境の認証情報整備という別種の前提を背負うことになるため、意図的に外している。

### 7.1 置き場と実行スクリプト

eval ケース（プロンプト・採点器・`scaffold.sh`・`case.yaml`）は配布物 `plugins/<plugin>/` の外、リポジトリ直下 `evals/<plugin>/` に置く。ケースの採点器は本リポジトリ固有の監査所見を名指しており配布先にとって意味を持たないため、`docs/distribution-boundary.md` §2・§3 と同じ判断軸で配布物から外している。一方 `claude plugin eval` は eval の置き場をプラグイン配下に限る（`--eval-dir` はプラグイン配下限定）ため、両立させる実行スクリプト `scripts/run-plugin-eval.sh` を用意した。

```bash
bash scripts/run-plugin-eval.sh <plugin> [claude plugin eval の引数...]
```

スクリプトは `plugins/<plugin>/` を一時ディレクトリへ複製し、`evals/<plugin>/` をその複製の `evals/` として配置してから `claude plugin eval <複製先> [引数...]` を呼ぶ。実行後、一時ディレクトリは trap により必ず削除する。`plugins/<plugin>/` と `evals/<plugin>/` の作業ツリーには一切書き込まない。

引数検証: プラグイン名の省略、`plugins/<plugin>/` の不在、`evals/<plugin>/` の不在、`--output-dir`（`--output-dir X` / `--output-dir=X` のどちらの形式も可）の省略を、それぞれ理由付きで拒否する（非0終了）。`--output-dir` を必須にしているのは、省略時の既定の出力先が eval 置き場の下（＝一時ディレクトリ配下）になり、実行後の後始末で結果ごと消えるためである。

**複製先へは `cd` しない。** `claude plugin eval` へは複製先の絶対パスを引数として渡すだけで、後続のユーザー引数（`--output-dir` 等）はそのまま透過する。したがって `--output-dir` に相対パスを渡した場合、その解決基準は「このスクリプトを呼び出した時点の cwd」のままであり、複製先基準へ絶対化する処理は行わない。

`claude` は PATH から解決する（`command -v claude`）。これらの引数検証・複製・配置・後始末・引数透過・終了コード透過は、本物の `claude` を呼ばず PATH 上をスタブに差し替えた `scripts/tests/run-plugin-eval.bats` が検査する。`plugins/` 配下のどのプラグインにも `evals/` が存在しないこと（配布物へ eval ケースを同梱していないこと）は `scripts/tests/eval-placement.bats` が機械検査する。両ファイルとも runner の bats スイートに含まれるため、`bash scripts/run-tests.sh` で走る。

### 7.2 実行条件

- 実行回数は `--runs 3`、`--ablation none`（プラグイン無しの腕は前後比較に要らない）、`--no-publish`、`--trust-plugin`、`--scaffold` を付ける。挙動ケースは `case.yaml` の `scaffold_script` で題材を組み立てるため、`--scaffold` が無いと題材の無い状態で走る（基準値も `--scaffold` 付きで取得した）。**一時複製は実行のたびに新しいディレクトリになるため、`--trust-plugin` を付けない場合の信頼確認プロンプトが毎回出る**
- `--max-cost-usd` で上限を掛ける
- モデルは各ケースの front-matter の `model:` に従う。`--model` で一律に上書きしない
- `adr` と `writing` は `--allow-tools Write Edit Bash` を付ける。許可パターンを限ると、検証ゲートの複合コマンドが確認なしモードで拒否され、挙動が測れない
- `domain-design` は `--allow-tools Write` を付ける。スキルの `allowed-tools` に Write があっても、eval の子セッションには付与されない。付けないと挙動ケースが成果物を書けずに止まり、不合格になる（基準値は Write・Edit を持つ状態で取得している）
- `growth` は `--allow-tools Write 'Bash(git rev-parse *)' 'Bash(date *)' 'Bash(rm ~/.claude/projects/*/growth/captures-*.md)'` を付ける（Write と、distill の `allowed-tools` と同じ Bash パターン）。基準値は Bash・Write・Edit を持つ状態で取得している
- `growth` の `behavior-distill` の採点器のうち `cursor-advanced`・`example-entry-hypothesized`・`upsert-preserves-existing` は、拒否された Write の試みの内容で判定する。拒否後に書き込みを試みるかは回ごとに揺れるため、不合格が出たら trace の最終応答で判断の中身を確かめてから退行と判定する
- 付与の過不足は、結果の trace（`--keep-temp` で残る `trace.jsonl`）の system 行が持つ `tools` の一覧で確かめられる
- `Bash` を付与する挙動ケース（`adr`・`writing`・`growth`）は、`~/.docker` 内に symlink があると eval 側が起動を拒否する。実行の直前に退避し、終了後に戻す（**この退避はスクリプトが自動化しない。手順として実行者が行う**）

  ```bash
  mv ~/.docker ~/.docker.eval-off
  # ここで対象の eval を実行する
  mv ~/.docker.eval-off ~/.docker
  ```

- Claude Code のサンドボックス内からは実行しない。サンドボックスが認証情報の読み取りを拒否し、子セッションが未ログイン状態になる
- `growth` の `behavior-distill` は、eval の実行系が `~/.claude` 配下への書き込みを拒否するため、書き込み成功を前提とする採点器3件（`completion-report-items`・`retention-rm-old-bucket`・`retention-rm-only-deletable`）を `.md.off` で無効化してある。distill の完了報告の全項目列挙はこの eval では測れないため、distill の挙動を変える Issue はこの3件を手動実行で別途確かめる
- 結果の出力先（`--output-dir`）は追跡外の置き場を指定する。リポジトリ直下の `.local/eval-results/` は `.gitignore` で無視されるため、`.local/eval-results/<plugin>/` を推奨する

```bash
mv ~/.docker ~/.docker.eval-off  # Bash 付与ケースのみ
bash scripts/run-plugin-eval.sh dependency-insight \
  --runs 3 --ablation none --no-publish --trust-plugin --scaffold \
  --max-cost-usd 5 --output-dir .local/eval-results/dependency-insight
mv ~/.docker.eval-off ~/.docker  # Bash 付与ケースのみ
```

### 7.3 基準値（main 250cf56 時点）

変更前に各ケースを3回実行した合格率。以後の比較はこの値を基準にする。

| プラグイン | 発火判定 | 挙動 | 補足 |
|---|---|---|---|
| adr | 1.0 | 1.0 | |
| dependency-insight | 1.0 | 1.0 | |
| domain-design | 1.0 | 1.0 | run0 の不合格は採点器 `document-structure` の誤判定で、採点器を直した後の値 |
| growth | 1.0 | 1.0 | 採点器 `priority-ignores-origin` を llm から regex へ置き換えて取得済み応答へ当て直した値。書き込み成功を前提とする3採点器は無効化中（§7.2） |
| writing | 1.0 | 1.0 | |
