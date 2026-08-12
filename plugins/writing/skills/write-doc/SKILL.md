---
name: write-doc
description: 文書を起草・検査・独立レビューする。文書作成または改稿時に、素材と読み手を指定して使う。
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(bash *scripts/lint-ja.sh*)
  - Agent
---

# 文書作成

## 文脈固有ルール

- **対象範囲**: 指定された読者・文書種別・素材だけを起草・改稿する。
- **成果物**: 入力契約と文体規約を満たす自立した文書を必要十分な分量で出力する。
- **停止条件**: 素材不足、独立レビュー不通過、または未解決の表現問題が残る場合は確定しない。
- **変更境界**: 指定ファイル以外を変更せず、内容のない水増しや無関係な改稿を行わない。

入力された素材を根拠として文書を起草し、機械検査と独立レビューを通して成果を返す。
このskillは素材を発明しない。素材が無い場合は停止し、ファイルを作らない。

## 入力契約

次の5項目を受け取る。

- `documentType`: 文書種別。
- `structure`: 必須節と配置。
- `materials`: 起草に使える確定素材の配列。
- `audience`: 読み手。
- `outputPath`: 出力先。省略時だけ安全な一時pathを割り当てる。

不足項目は補わず、`status=blocked`、`missing=[...]`、`writes=[]`を返す。
特に`materials=[]`は起草不能として停止する。

## 規約とprofile

1. `${CLAUDE_PROJECT_DIR}/.claude/writing/type-profiles.md`を読む。
2. 読めない、または該当種別が無い場合は、plugin内の`references/document-type-profiles.md`を読む。
3. 両方を読めない場合は共通規約の既定値だけを使う。

共通規約は`references/japanese-writing.md`を正本とする。skill本文へ条文を複製しない。
参照はこのskillから一段までに留め、参照先から別の参照を要求しない。

## 起草

入力を正規化し、`documentType`、`structure`、`materials`、`audience`、`outputPath`をdoc-writerへ渡す。
doc-writerにはprofileと共通規約のpathを渡す。素材にない事実、結論、引用を追加させない。
出力先が省略されたときは一時pathを割り当て、利用者へpathを返す。

## 機械検査

起草後、次の形でlintを実行する。

```text
bash <plugin-root>/scripts/lint-ja.sh --diff <base> -- <changed-paths>
```

既存箇所を明示的に確認するときだけ`--file <path>`を使う。lintの一文長違反は未解決として扱う。
識別子の説明不足は候補であり、終了コードだけで意味判定しない。allowlist、登録簿、免除語集合は作らない。

## 独立レビュー

lint後、対象文書、profile、規約、plugin root pathだけをdoc-reviewerへ渡す。
素材、起草経緯、writerの判断、allowlist pathは渡さない。
reviewerはF1、F3、F4、F5をそれぞれ判定し、`ruleId,severity,evidence,suggestion`を返す。

修正は最大2回まで行う。各回で修正、lint、reviewを記録する。
2回後も指摘が残れば`status=unresolved`と指摘一覧を返し、成功成果として表示しない。
指摘が無くなった場合だけ`status=passed`と出力pathを返す。

## host adapter

Claude Codeは登録agentを起動し、CodexはWave 0で利用できる最も狭いadapterまたは手動degraded検査を使う。
両hostは`draft→lint→review→修正0/1/2回`の状態と出力契約を共有する。
adapter差分と縮退条件はpluginの`compatibility.json`とREADMEに記録する。

## 出力契約

成功:

```text
status=passed
writes=[outputPath]
unresolved=[]
```

未解決:

```text
status=unresolved
writes=[]
unresolved=[{ruleId,severity,evidence,suggestion}]
```

素材不足:

```text
status=blocked
missing=[materials]
writes=[]
```
