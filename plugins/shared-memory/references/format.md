# 記録の形式

共有の記憶（Shared Memory）の記録と索引の形を定める。検査器（`scripts/memory.mjs`）は、ここに書いた規則を検査する。

## 記憶の根

記憶の根は、次を直下に持つディレクトリである。

| 場所 | 中身 |
|---|---|
| `records/` | 記録。1記録1ファイル。下の階層は読まない |
| `index.md` | 索引。検査器が生成する |

根がどこに在るかは、利用先が決める。検査器は、根を引数で受け取る。`records/` を持たないディレクトリは、記憶の根として扱わない。記録がまだ無い根は、空の `records/` を持つ。

## 記録

記録は Markdown のファイルである。先頭の front-matter に項目を持ち、本文に内容を書く。

```markdown
---
id: MEM-202611141215-01
type: experience
title: 記録の主張を1文で
author: ai
verification: verified
confidence: high
applies-when: この記録が当てはまる条件
sources:
  - 出典
created: 2026-11-14
updated: 2026-11-14
---

本文。何を観測したか、何が言えるか、当てはまらない場合を書く。
```

### 必ず書く項目

| 項目 | 値 |
|---|---|
| `id` | `MEM-<年月日時分の12桁>-<連番2桁>`。時刻は UTC で取る |
| `type` | `knowledge`（知識・事実）、`experience`（作業や検証から得た経験）、`belief`（判断基準）、`decision`（意思決定と理由）、`evolution`（何からなぜ変わったか） |
| `title` | 記録の主張を1文で |
| `author` | `human`、`ai`、`joint`。`belief` では `human` か `ai` に限る。`human` は本人が明示したもの、`ai` は AI が推測したものを表す。人間と AI が話し合って本人が認めた判断基準は、`human` とする |
| `verification` | `verified`、`unverified` |
| `confidence` | `high`、`medium`、`low` |
| `applies-when` | この記録が当てはまる条件 |
| `sources` | 出典を1件以上。作業の記録、文書の URL、別の記録の識別子 |
| `created` / `updated` | `YYYY-MM-DD` |

### 場合によって書く項目

| 項目 | 書く場合 | 値 |
|---|---|---|
| `superseded-by` | 別の記録で置き換えたとき | 置き換えた先の記録の識別子 |
| `moved-to` | 記憶の外へ移したとき | 移した先。lint の規則名、指示ファイルのパスなど |
| `from` | `type` が `evolution` のとき | 置き換えられた記録の識別子を1件以上 |
| `to` | `type` が `evolution` のとき | 置き換えた記録の識別子を1件以上 |

`superseded-by` か `moved-to` を持つ記録を、置き換え済みの記録と呼ぶ。両方を同時には書かない。

ここに無い項目を足してもよい。検査器は読み飛ばす。項目の名前には、日本語や空白を使ってよい。コロンは使えない。

### ファイル名

`<id>-<名前>.md` とする。名前は、英小文字と数字をハイフンでつないだものにする。

### front-matter の書き方

- 値は1行で書く。`sources`・`from`・`to` は、項目の次の行から「`- 値`」を並べる。
- 値に「`: `」や「` #`」を含むときは、引用符で囲む。
- 値が次の記号で始まるときも、引用符で囲む。``[ ] { } , # & * ! | > ' " % @ ` ``と、後ろに空白が続く `-`・`?`・`:` である。YAML が別の意味に読むためである。
- 改行は LF でも CRLF でもよい。

## 置き換え

記録を別の記録で置き換えるときは、次の3つを同じ変更で行う。

1. 新しい記録を足す。
2. 旧い記録に `superseded-by` を書く。旧い記録は消さない。
3. `evolution` の記録を足す。`from` に旧い記録を、`to` に新しい記録を書く。本文に、何がなぜ変わったかを書く。

記憶の外へ移すときは、旧い記録に `moved-to` を書く。`evolution` は足さない。

## 索引

索引は、記録の front-matter から検査器が生成する。手で編集しない。

- 記録1件につき1行を、識別子の順に並べる。
- 置き換え済みの記録は載せない。
- 1行は、識別子・種類・主張（`title`）・当てはまる条件（`applies-when`）・検証（`verification`）を持つ。

## 検査器が違反とするもの

| 規則 | 違反の内容 |
|---|---|
| `front-matter` | front-matter が無い、閉じていない、項目を読めない |
| `required` | 必ず書く項目が無い |
| `value` | 値が上の表の範囲に無い。`superseded-by` と `moved-to` を同時に書いている。`belief` の `author` が `joint` である |
| `filename` | ファイル名が形に合わない。ファイル名の識別子が `id` と一致しない |
| `duplicate-id` | 同じ `id` の記録が2件以上ある |
| `dangling` | `superseded-by`・`from`・`to` が指す記録が無い |
| `evolution` | `evolution` が `from` か `to` を持たない。`evolution` でない記録が `from` か `to` を持つ |
| `replacement` | `superseded-by` を持つ記録に、その置き換えを説明する `evolution` が無い。`evolution` の `from` の記録が、`to` の記録を `superseded-by` で指していない。`superseded-by` を辿ると元の記録へ戻る |
| `index` | 索引が無い。索引が記録と一致しない |

検査器は、記録の内容だけから機械で決まる違反を扱う。記録どうしの意味の矛盾や、主張の正しさは扱わない。

## 検査器の使い方

```bash
node scripts/memory.mjs check <記憶の根>          # 検査する
node scripts/memory.mjs index <記憶の根>          # 索引を標準出力へ出す
node scripts/memory.mjs index <記憶の根> --write  # 索引を index.md へ書く
```

終了コードは、違反なしが 0、違反ありが 1、引数の誤りか検査できない入力が 2 である。記憶の根でないディレクトリを渡した場合は、検査できない入力に当たる。Node 22 以上で動く。
