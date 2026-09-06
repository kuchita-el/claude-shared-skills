# Claude Code における同梱資産への到達手段

**host が Claude Code である場合に限った**、配布プラグインの本文から同梱資産（`references/` `scripts/` `agents/`）へ到達する手段の単一の出典。どの走査面に書かれたどのパス変数が Claude Code に解決されるかを定める。配布プラグインを新設するとき、既存プラグインの本文へ同梱資産の参照を足すとき、サブエージェントの側から同梱資産へ届かせたいときに参照する。

射程は次の2つで限られる。

- **host は Claude Code のみ**。Codex をはじめとする他 host の到達機構（`{pluginRoot}` の注入等）は扱わない。host 間の差分は `docs/references/cross-host-plugin-conformance.md` の軸が持つ
- **扱うのは到達可能性（どの形なら届くか）のみ**。到達の要否や、届く複数の形のうちどれを正規形とするかは扱わない

## 1. Claude Code の置換の機構

Claude Code は、スキル定義と agents 定義の**本文を読み込む時点でテキストとして置換する**。Bash ツールの実行環境には、これらの変数は環境変数として存在しない。

この機構から、走査面ごとに次の2つの状態のいずれかを取る。

- **置換される走査面**: モデルが本文を見る時点で既に絶対パスへ変わっている。Bash のコマンド引数に書いても Read の対象に書いても同じく届く。用途によって成否が分かれない
- **置換されない走査面**: 変数の文字列がそのまま本文に残る。Bash へ渡せばシェルが未設定の変数として空文字列へ展開するため、`${CLAUDE_SKILL_DIR}/references/x.md` は `/references/x.md` へ潰れて起動できない。Read へ渡せば存在しないパスとして失敗する

置換はプラグインの読み込み経路に依存しない。ローカルディレクトリを直接読み込ませた場合と、marketplace 経由で導入した場合の双方で同じに起きる。

なお、スキル本文の先頭には `Base directory for this skill: <絶対パス>` が host により付加される。スキルディレクトリの絶対パスは、本文が変数を持たなくてもこの行から得られる。

## 2. 到達可能性マトリクス（Claude Code）

| 走査面 | 変数 | Bash 実行（コマンド引数） | Read 対象 | 判定根拠となった観測 |
|---|---|---|---|---|
| SKILL.md 本文 | `${CLAUDE_PLUGIN_ROOT}` | 届く | 届く | 単引用符で囲った `printf` が絶対パスを出力（シェル展開を封じても置換済み）。同じ形の `cat` が同梱ファイルの内容を取得 |
| SKILL.md 本文 | `${CLAUDE_SKILL_DIR}` | 届く | 届く | 同上 |
| スキル配下 references 本文 | `${CLAUDE_PLUGIN_ROOT}` | 届かない | 届かない | `cat` が `/references/...: No such file or directory` で終了。Read は変数を含む文字列のまま渡され `File does not exist` |
| スキル配下 references 本文 | `${CLAUDE_SKILL_DIR}` | 届かない | 届かない | 同上 |
| agents 定義本文 | `${CLAUDE_PLUGIN_ROOT}` | 届く | 届く | 定義本文の逐語出力が絶対パスを示し、同じ形の `cat` と Read がいずれも成功 |
| agents 定義本文 | `${CLAUDE_SKILL_DIR}` | 届かない | 届かない | 定義本文の逐語出力が変数のまま。`cat` は空展開で失敗し、Read も `File does not exist` |

観測条件: Claude Code 2.1.263 / 2026-09-06 に観測。全セルを観測済みで、未観測のセルは無い。マトリクスの値は Claude Code の挙動であり、他 host へは持ち越せない。

`${CLAUDE_SKILL_DIR}` が agents 定義本文で解決されないのは、エージェントの起動にスキルの文脈が伴わないためである。エージェント定義からプラグインルートへ届く形は `${CLAUDE_PLUGIN_ROOT}` に限られる。

## 3. Claude Code のモデルは未解決の変数を補完しない

置換されない走査面から読み取った変数入りのパスを、モデルは自力で絶対パスへ直さない。文字列のまま Read へ渡して失敗する。これは、同じ文脈に置換済みの絶対パスが既に現れており、そこからプラグインルートを導ける状態でも変わらない。

したがって、置換されない走査面に書かれた到達指示は、「保証は無いが実際には動いている」状態にはならない。届かない。

## 4. 帰結（Claude Code 向けに書くとき）

- スキル本文から同梱資産へ届かせる形は、`${CLAUDE_PLUGIN_ROOT}` と `${CLAUDE_SKILL_DIR}` のいずれでもよい。親相対（`${CLAUDE_SKILL_DIR}/../../`）も、段数が正しい限り届く
- references ファイルの本文には、到達指示を置けない。同梱資産を指す必要がある場合、そのパスは呼び出し元のスキル本文が解決して渡すか、参照そのものをスキル本文へ移す
- agents 定義本文から同梱資産を指す場合は `${CLAUDE_PLUGIN_ROOT}` を使う

## 関連

- `docs/development/coding-agent-plugin-design-principles.md`（配布プラグイン全件に掛かる設計原則。工場と配布物の資産の別、host 依存方向、正本の一意性を定める）
- `docs/references/document-permanence.md`（`docs/` 配下へ何を残すかの規約。本文書は恒久文書として §2 の追随義務を負う）
- `docs/references/cross-host-plugin-conformance.md`（Claude Code と Codex の host 差分を隠さず plugin 適合性を検査するための契約）
