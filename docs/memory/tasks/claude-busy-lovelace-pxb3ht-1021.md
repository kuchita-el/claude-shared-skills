# Task Memory: 学びの候補を記録として提案するスキルを足す

このファイルは、1つのタスクの間だけ持つ覚え書きである。レビューへ出す前に、残すものを取り出して消す。

## タスク

- Issue #1021「タスクの終わりに、AI が学びの候補を記録として提案できるようにする」の実装である。
- ブランチは `claude/busy-lovelace-pxb3ht-1021`。親のブランチは `claude/busy-lovelace-pxb3ht-1020`（PR #1030）で、その親が `claude/busy-lovelace-pxb3ht`（PR #1029）である。PR は draft で、base を親のブランチにする。
- このタスクの PR は #1031 である（draft。base は親のブランチ）。

## 足すもの

- スキル `propose-records`（`plugins/shared-memory/skills/propose-records/`）と、スキル配下の参照 `drafting.md`。
- 照合のサブエージェント `record-matcher`（`plugins/shared-memory/agents/`）。
- 共有の参照 `matching.md`（照合の手順）と `confidentiality.md`（機密の確認）。
- 最小の manifest（`plugins/shared-memory/.claude-plugin/plugin.json`）。配布カタログへは登録しない。
- eval のケース（`evals/shared-memory/behavior-propose-records/`）と、その題材が検査を通ることの試験。
- 設計（`docs/development/shared-memory/design.md`）と README と `docs/development/test-execution.md` の追随。

## 完了の条件

- `bash scripts/run-tests.sh` の全スイートが緑である。
- スキルの `description` が 300 字以内、本文が 170 行以内、`allowed-tools` が最小である。commit・push・PR の作成を、スキルは事前に許可しない。
- サブエージェントが `model` と `effort` を明示し、README に値と意図の表が在る。
- 配布物（`plugins/shared-memory/`）が、配布元にしかないもの（`docs/`・ADR・`scripts/tests/`・Issue の番号）を指していない。
- 変えた文書が、一文長の検査（`node plugins/writing/scripts/lint-ja.mjs`）を通る。
- スキルを1回起動し、候補の表（扱いと理由）が出る。既に在る記録と重なる候補が、足す側に入らない。
- 記憶のリポジトリへ出した記録の提案が、そのリポジトリの検査を通る。
- このファイルが、レビューへ出す前に消えている。

## 所有者が決めたこと（計画より優先する）

- スキルの名前は `propose-records` とする。
- Global Memory へ直接下書きする条件は3つである。Global の根が在る。主張と当てはまる条件が、プロジェクトに依らない。機密を含めずに書ける。迷えば Project へ置く。
- 検証状況（`verified`／`unverified`）は、層を分ける条件にしない。記録に書いて区別する。設計の原則が「未検証の区別」へ改まったためである。
- モデルを呼ぶ実行は、この実装の全体で1回だけにする。スキルを子プロセスで起動する実地の確認が、その1回である。eval は、資産として作るが、実行しない。
- Project Memory の索引は、記録を足す変更に含める。Global Memory では含めない。

## 環境の覚え書き

- `git commit` を含むコマンドは、commit ゲートが全スイート（約2分）を走らせる。メッセージはファイルで渡す。
- 本リポジトリの checkout は履歴が浅く、`refs/remotes/origin/HEAD` が無い。検査器の `version` は、ここでは版を返さずに止まる。
- 手元の Node は 22 である。bats は `/usr/local/bin/bats` に在る。

## 計画の段階で確かめたこと（2026-11-21、Claude Code 2.1.330、このコンテナ）

使い捨てのプラグインで実測した。このタスクの実装では、やり直していない。

- `claude plugin eval` の `file_exists` の採点器は、glob を受けるが、エージェントが書いたファイルしか見なかった。題材を組み立てるスクリプトが作ったファイルは、字面どおりのパスでも「missing」になった。`regex` の採点器（ファイルを読む形）は、題材のファイルを字面のパスで読めたが、glob は受けなかった。
- `Bash` を付与した eval は、`bubblewrap` と `socat` が無いコンテナでは、実行を拒まれた（「sandbox required but unavailable」。採点は全て 0 点だった）。2つを入れた後は動いた。
- その eval の子セッションでは、成功した Bash のコマンドも「Exit code 1」と表示された。標準出力は正しかった。root で動くコンテナに固有かは、確かめていない。
- `claude --plugin-dir <ディレクトリ> -p "/<プラグイン名>:<スキル名>"` で起動した子プロセスでは、スキルの `allowed-tools` に在る道具が、許可の引数を渡さなくても通った。`allowed-tools` に無い `git add -A` と `touch` は、拒まれた。

## 進み具合

- Task Memory を置いた。
- 共有の参照2本とサブエージェント、スキルと manifest と README を足した。draft の PR を作った。
- eval のケースと採点器16件、題材が検査を通ることの試験を足した。eval は実行していない。
- 設計（7.1節「候補の提案」ほか）を追随させた。
- 検索の道具が無いホストのために、機密の語の照合を `grep` でも行えるようにした（下の観測）。
- 残り: スキルを子プロセスで1回起動する実地の確認。このファイルを消すこと。

## 実装で観測したこと

- 題材が検査を通ることの試験は、題材の索引の1行を書き換えた写しで赤になった。記録の `title` だけを書き換えた写しでも赤になった（索引が記録と一致しないため）。手で1回ずつ確かめ、元へ戻した。
- 一文長の検査（`lint-ja.mjs`）は、コードブロックの中を数えなかった。長いコマンドを地の文に書くと1文として数えられたので、コードブロックへ移した。
- 計画の段階で子プロセスとして起動した Claude Code（2.1.330、`claude -p`）の記録を読むと、セッションの開始の行が挙げる道具の一覧に、`Grep` と `Glob` が無かった。5回の起動の全てで同じだった。親のセッションは、両方を持つ。このため、スキルが `Grep` だけを前提にすると、子プロセスでは語の照合を機械で行えない。計画は `Grep` だけを許可する形だったので、`Bash(grep -i -F *)` を足した。
