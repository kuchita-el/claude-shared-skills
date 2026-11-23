---
name: carry-drafts
description: "プロジェクトの既定のブランチの outbox/ に在る承認済みの下書きを、手を加えずに Global Memory の candidates/ へ運ぶ。検査器で運び済みかを判定して写し、候補を足すだけのブランチを git で push する。取り込みは Global の CI が行う。送り出しの下書きを運ぶ・Global へ届けるときに使う。"
allowed-tools:
  - Read
  - Bash(node *scripts/memory.mjs*)
  - Bash(date -u*)
  - Bash(git rev-parse*)
  - Bash(git -C * rev-parse --show-toplevel*)
  - Bash(git -C * fetch --deepen=*)
  - Bash(git -C * status --porcelain*)
  - Bash(git -C * branch --show-current*)
  - Bash(git -C * rev-parse --verify --quiet refs/*)
  - Bash(git -C * switch --detach FETCH_HEAD)
  - Bash(git -C * switch -c carry/*)
  - Bash(git -C * add -- candidates/*)
  - Bash(git -C * ls-tree *)       # 取り込まれたかを確かめる
---

# 下書きを運ぶ

承認済みの送り出しの下書きを、Global Memory の候補として運ぶ。手順の正本は `${CLAUDE_PLUGIN_ROOT}/references/carrying.md` であり、ここへ写さない。

## 文脈固有ルール

- **対象範囲**: 運ぶことだけを扱う。下書きを書くこと、承認、選別は扱わない。
- **成果物**: Global Memory のリポジトリの、候補を足すだけのブランチ1本と、運んだ結果の報告。写すものが無ければ、ブランチを作らない。
- **停止条件**: `carrying.md` が止まると定める場合。理由を報告して終える。
- **変更境界**:
  - 書くのは、検査器が写す Global の `candidates/` のファイルと、それを入れるブランチとコミットだけである。
  - 下書きの中身に触れない。写すのは検査器である。
  - Project のリポジトリへは書かない。`outbox/` の下書きを消さない。
  - commit と push を、このスキルは事前に許可しない。了承は、ホストの許可の確認が受け持つ。PR は出さない。

## 引数

- `--project-root <パス>`: Project Memory の根。省くと、プロジェクトの指示ファイルが示す置き場、無ければリポジトリの根（`git rev-parse --show-toplevel`）の `docs/memory` とする。
- `--global-root <パス>`: Global Memory の根。省くと、指示ファイルが共有の記憶として指すリポジトリとする。どちらも無ければ、無いものとして扱い、止まる。スキルは探さない。

プロジェクトのリポジトリの中で起動する。

## 手順

1. `${CLAUDE_PLUGIN_ROOT}/references/carrying.md` と、`${CLAUDE_PLUGIN_ROOT}/references/format.md` の「下書きを運ぶ」を読む。
2. Global の根の利用規則を読む。在りかは、`format.md` の「記憶の根」が定める順で決める。remote と既定のブランチの名前と、運ぶことについての定めを、そこから得る。定めが無ければ、`carrying.md` の前提に従って止まる。
3. `carrying.md` の手順どおりに運ぶ。検査器は `node "${CLAUDE_PLUGIN_ROOT}/scripts/memory.mjs"` の形で実行する。

コマンドは、`carrying.md` に書いた形のまま、1回に1つずつ実行する。`&&`・`;`・パイプ・`2>&1` や、`cd`・`echo` でつないだ形は、許可した型に当たらず、拒まれる。終了コードは、足した `echo` ではなく、結果から読む。手順に無いコマンド（`ls`・`printenv` など）は Bash で使わず、パスは `Read` で読む。

## 出力

`carrying.md` の「報告」の項目を書く。push の成功を、運んだ結果として書かない。
