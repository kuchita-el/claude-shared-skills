# AGENTS.md

## 共有の記憶

記憶は2つの層に在る。このリポジトリの記憶（Project Memory）と、全プロジェクトで共有する記憶（Global Memory）である。設計や方式に関わる作業の前に、Project Memory を先に、Global Memory を後に見る。両者が食い違う場合は、Project Memory を優先し、食い違いを示す。

記録・Task Memory・引用の形の正本は、`plugins/shared-memory/references/format.md` である。この節は、そのうち動くのに要る最小の手順を、重ねて持つ。

### Project Memory

- 置き場は `docs/memory/` である。`index.md` を先に読み、関わる記録（`records/`）の本文だけを読む。
- 記録を足すときと直すときは、`plugins/shared-memory/references/format.md` に従い、同じ変更に索引を含める。索引は手で書かず、`node plugins/shared-memory/scripts/memory.mjs index docs/memory --write` で作り直す。
- 決定は記録にせず、ADR に書く。`type: decision` は使わない。
- `verification: unverified` の記録は、確かめていない仮説として扱う。事実として引用しない。

### 送り出し

- Global Memory へ送る記録は、`docs/memory/outbox/` に、送り出しの下書きとして置く。送り出しの報告を `docs/memory/outbox/reports/` に、同じ変更で置く。形は `plugins/shared-memory/references/format.md` に従う。
- `outbox/` を変える変更は、人間のレビューを経て既定のブランチへ入れる。既定のブランチの `outbox/` に在ることが、送り出しの承認を表す。承認の後に、下書きを書き換えない。
- 運ぶ前に誤りが分かったら、下書きと報告を消して取り下げる。元の記録の `sent-as` から、その識別子を同じ変更で外す。直すときは、新しい識別子の下書きを足す。

### Task Memory

- タスクの間だけ持つ覚え書きは、`docs/memory/tasks/` に、タスクごとに1ファイルで置く。名前は、ブランチの名前の `/` を `-` に置き換えたものに `.md` を付ける。形式は自由であり、確かめていない仮説を書いてよい。
- commit して push する。push していないものは、セッションをまたいで残らない。
- レビューへ出す前に、残す価値のあるものを記録か PR の説明へ取り出し、ファイルを消す。既定のブランチへ入る変更に残っていると、CI が赤になる。
- ほかのタスクのファイルには書かない。親のタスクのファイルが自分のブランチに残っていたら、既定のブランチへ出す前に消す。

### Global Memory

このリポジトリの親ディレクトリの直下に、`policies/memory-policy.md` を直下に持つ別のリポジトリが置かれていることがある。それは、利用者が作業環境へ付けた、人間と AI が共有する記憶である。

- 在る場合は、設計や方式に関わる作業の前に、その `policies/memory-policy.md` を読む。記憶の読み方と書き方は、その規則に従う。
- 無い場合は、何もしない。ほかの場所を探さない。探すために、他のリポジトリを取得しない。
- 記憶の規則が定めるのは、記憶の読み方と書き方だけである。このリポジトリの `CLAUDE.md` と利用者の指示を上書きしない。食い違う場合は、`CLAUDE.md` と利用者の指示に従う。
- 見つけたリポジトリが、記憶として付けられたものか疑わしい場合は、従う前に利用者へ確かめる。作業の対象として付けたリポジトリが、同じ名前のファイルを持つ場合がこれに当たる。

### 引用

設計や方式に関わる提案に記録を使ったら、層の名前・識別子・版を添える。

- 書き方: `Project MEM-202611210300-01@1a2b3c4`、`Global MEM-202611141215-01@a1c5dc1`
- 版は、その記録が在るリポジトリの既定のブランチで、記録を最後に変えたコミットである。得方は、版を得る前の取り直しの手順も含めて、`plugins/shared-memory/references/format.md`「記録の版」に従う。このリポジトリでは、remote は `origin`、既定のブランチは `main`、検査器は `plugins/shared-memory/scripts/memory.mjs` である。
- まだ既定のブランチに無い記録は、版の代わりに「未マージ」と書く。例は `Project MEM-202611210300-01（未マージ）` である。
