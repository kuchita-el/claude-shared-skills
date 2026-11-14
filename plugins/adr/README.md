# adr プラグイン

ADR（アーキテクチャ決定記録）の運用機構を配布する Claude Code / Codex プラグイン。どの GitHub リポジトリにも導入でき、ADR の drift-lint・有効性 index 生成・ライフサイクル操作を提供する。

## 提供物

- **drift-lint（`scripts/lint-adr.sh`）**: ADR 群（対象ディレクトリ配下の全 ADR と有効性 index の総体）が満たすべき機械検査可能な不変条件を検査する。front-matter スキーマ（状態語彙・有効性語彙・遷移整合）、有効性 index との整合、ADR 間参照（上書き関係の双方向性、`Related:` の参照先の生存性・実在性）、ファイル名と識別子の規約適合および識別子の一意性と H1 見出しとの整合が対象。
  - front-matter を持たない ADR（本文の `## Status` 節で状態を書く形式を含む）は違反として報告する。そうした ADR 群を持つリポジトリでは、導入前に各 ADR へ front-matter を付ける。
- **有効性 index 生成（`scripts/gen-adr-index.sh`）**: `validity: 有効`（既定値での綴り）の ADR を抽出して index を生成する。
- **識別子の発番（`scripts/next-adr-id.sh`）**: 起票時刻（分粒度・ローカル時刻）と同一時刻部内の連番から、次に起票する ADR の識別子 `ADR-YYYYMMDDHHMM-NN` を発番する。連番の算出対象を同一時刻部のファイルに限るため、並行するブランチがそれぞれ発番しても識別子が衝突しない。
- **設定の値の出力（`scripts/print-adr-config.sh`）**: 導入先の設定を `lint-adr.sh` と同じ規則で解決し、語の群を `キー: 値` の行で出す。設定が無ければ既定値を出す。manage-adr スキルは、この出力の値を front-matter と相互参照の節の見出しへ書き込む。
- **分割の逐語照合（`scripts/verify-split-verbatim.sh`）**: 多決定 ADR の分割の締めに、決定の対応表を入力に2点を照合する。原 ADR の各決定が、後継への逐語転記・退役・原 ADR に残すのいずれか1つに振り分けられていること（網羅性）。転記した決定の本文が後継と一致すること（逐語性）。
- **commit 前ゲート（`hooks/`）**: `git commit` 時に PreToolUse フックとして drift-lint を実行する。違反があれば commit をブロックする（exit 2）。検査するのは、commit を実行するリポジトリ（git worktree で作業している場合はその worktree）の ADR ディレクトリである。
  - 検査するのは、ステージした内容（index）である。index のブロブを一時ディレクトリへ書き出して lint に掛けるため、未ステージの変更は判定に含まれない。
  - 書き出すのはブロブそのものであり、改行変換（`core.autocrlf`・`.gitattributes` の `eol`）や smudge フィルタは通さない。
  - 設定ファイル（`.claude/adr/config`）も、検査する側の版を使う。index の検査ではステージした版を、作業ツリーの検査では作業ツリーの版を読む。index に設定ファイルが無ければ、既定値で判定する。
  - コマンドが commit の中でステージを変えうる場合は、作業ツリーも併せて検査し、どちらかに違反があればブロックする。`git add … && git commit` のような連結、`-a`、パスの指定などが当たる。
  - ステージを変えないと判別するのは、ゲートが列挙したオプション（`-m`・`-F`・`--amend` 等）だけを伴う単独の `git commit` に限る。それ以外は、ステージを変えうるものとして扱う。
  - 連結・置換・リダイレクトの記号（`;` `&` `|` `<` `>` `(` `)` `$` `` ` `` `\`）や改行を含む形も、ステージを変えうる側に入る。引用符の中にあっても同じである。
  - `$(...)` やヒアドキュメントでメッセージを組み立てる形がこれに当たる。記号を含むメッセージは `-F` のファイルで渡す。
  - ステージを変えうる側では、commit される内容が正しくても、index か作業ツリーの一方に違反が残っていればブロックされる。`git add` 等を別のコマンドとして先に実行すると、ステージした内容だけで判定される。
  - commit されうる内容に ADR ディレクトリが無い場合は何もしない（no-op）。ADR ディレクトリを持たないリポジトリと、未追跡の ADR だけがあり、ステージを変えない commit がこれに当たる。index を取り出せない場合（未解決のマージ衝突など）は、理由を示してブロックする。
  - コミット対象のリポジトリを特定できない場合は、理由を示して commit をブロックする。
- **manage-adr スキル（`skills/manage-adr/`）**: ADR の起票・承認・上書き・廃止・却下・編集・分割を対話的に行うライフサイクル操作スキル。

## ホスト差分

両ホストの成果契約は、同梱スクリプトを明示的に実行して結果を確認することです。
対象は次の5つです。`lint-adr.sh`、`gen-adr-index.sh`、`next-adr-id.sh`、`verify-split-verbatim.sh`、`print-adr-config.sh`。Claude Codeでは追加で
PreToolUseのcommitゲートを利用できます。Codexには現時点で同等のplugin単位
commit hookがないため、明示lintを必須とする `degraded` 互換です。

Codexがplugin単位のhook/policy callbackとブロック結果を提供した時点を、
host adapterへ移行するトリガーとします。移行まではホスト別のworkflowを複製しません。

同梱スクリプトのテストランナーと fixture は本配布物に含めない。配布物が持つのは検査器のみであり、検査用データの同梱と、スクリプトが自環境で動くことの確認は本配布物の責務ではない。

## 動作要件

- **bash 4.2 以上**: `lint-adr.sh` は連想配列を使う。macOS の既定の `/bin/bash` は 3.2 なので、4.2 以上の bash（例: Homebrew の bash）を導入し、PATH 上で先に見つかるようにする。版が足りない場合、`lint-adr.sh` は原因を示して exit 2 で止まる。commit 前ゲートは PATH 上の `bash` で lint を起動するため、この場合は commit がブロックされる。
- **git**: commit 前ゲートは、commit を実行するリポジトリを git から解決する。
- **jq**（任意）: commit 前ゲートが PreToolUse の入力からコマンドと作業ディレクトリを読むのに使う。無い場合も、フック自身の作業ディレクトリから解決して動作する。

## 導入

ローカル marketplace 経由（推奨）、または `claude --plugin-dir /path/to/plugins/adr` で読み込む。恒常有効化する場合は導入先リポジトリの `.claude/settings.json` の `enabledPlugins` に登録する。

## ADR ディレクトリの指定（`ADR_DIR`）

次の4つのスクリプトは、対象の ADR ディレクトリを第1引数（`ADR_DIR`）で受け取る。`lint-adr.sh` / `gen-adr-index.sh` / `next-adr-id.sh` / `print-adr-config.sh` である。対象は、前2者では検査対象、`next-adr-id.sh` では既存 ADR の列挙対象、`print-adr-config.sh` では設定を解決する起点である。**既定は `docs/adr`** である。導入先が別配置（例 `architecture/decisions`）を使う場合は引数で上書きする。commit ゲートは、commit を実行するリポジトリの既定の `docs/adr` を対象に実行する。

ADR ディレクトリを指定する手段は、現時点では引数だけである。次節の設定ファイルには、ADR ディレクトリのキーはまだ無い。

## 設定（`.claude/adr/config`）

ADR に書く語のうち言語に依存するものは、導入先のリポジトリごとに設定ファイルで定められる。設定を置かないリポジトリでは、同梱の既定値のファイル `scripts/adr-config.default` の語（日本語）を使う。1つのリポジトリの中では、1つの言語で揃える。

### 置き場

- 導入先の git のトップレベルにある `.claude/adr/config` を読む。無ければ既定値を使う。
- git のトップレベルは、スクリプトに渡した ADR ディレクトリ（引数を省いたときはカレントディレクトリ）から決める。commit 前ゲートは、検査する ADR ディレクトリから決める。
- git のトップレベルを決められないときは、既定値だけを使う。
- 環境変数 `ADR_CONFIG_ROOT` は、ゲートとテストが git の外で検査するための内部の経路である。利用者が設定を渡す手段ではない。

### キー

1行に `キー: 値` を1つ書くといった書き方は、既定値のファイルの冒頭にある。設定できるキーは次の9つである。`status` と `validity` の各役割の意味は、manage-adr スキルの状態モデルが定める。状態モデルは `skills/manage-adr/references/adr-model.md` にある。

| キー | 定める語 |
|---|---|
| `status-proposed` | `status` の値 |
| `status-approved` | `status` の値 |
| `status-rejected` | `status` の値 |
| `validity-active` | `validity` の値 |
| `validity-superseded` | `validity` の値 |
| `validity-abandoned` | `validity` の値 |
| `xref-heading` | 相互参照の節の見出し |
| `index-title` | 生成する index の題名 |
| `index-notice` | 生成する index の冒頭の注記 |

### 語の群を揃えて置く

上の9つのキーは、語の群をなす。導入先の設定に1つでも書くなら、9つすべてを書く。1つも書かなければ、9つとも既定値を使う。一部だけを置くと、1つのリポジトリの中で2つの言語が混ざるためである。`status` の3値と `validity` の3値は、6つとも互いに異なる値にする。

### 設定の誤り

次の場合、`lint-adr.sh`・`gen-adr-index.sh`・`print-adr-config.sh`・commit 前ゲートは、原因を示して exit 2 で止まる。ADR は扱わない。設定の誤りを、ADR の違反として報告しない。

- 知らないキーがある（綴りの誤りを含む）
- 同じキーが2回ある
- 値が空である
- 語の群の一部だけがある
- `status` と `validity` の6つの値に重複がある
- `キー: 値` の形でない行がある

### 英語に固定する語

次の語は、導入先の言語によらず英語に固定し、設定の対象にしない。lint のメッセージは日本語で出る。

- 節名の `Context` / `Decision` / `Consequences`
- 関係のラベル `Supersedes:` / `Superseded by:` / `Related:`
- front-matter のキー名 `status` / `validity` / `superseded-by`

### 設定に従う範囲

- 設定に従うのは、`lint-adr.sh`・`gen-adr-index.sh`・`print-adr-config.sh` と、lint を起動する commit 前ゲートである。`next-adr-id.sh` と `verify-split-verbatim.sh` は、設定の語を扱わない。
- manage-adr スキルは、front-matter と相互参照の節の見出しへ書く値を、`print-adr-config.sh` の出力から得る。語の群を設定で定めたリポジトリでも、スキルは設定の語で書き込む。
