#!/usr/bin/env bash
# behavior-crosscheck-contradiction の題材を、空の作業ディレクトリへ作る。
#
# 記憶の根は docs/memory。作業ディレクトリは、コミットの無い git のリポジトリにする（スキルが、リポジトリの根を尋ねることが在る）。
# 記録の本文と識別子は、この題材のために新しく書いた作り物である。道具の名前（tokei-cron）も作り物である。
#
#   R1 MEM-202611010000-01  索引に在る。N1 と食い違う相手
#   R2 MEM-202611010000-02  索引に在る。無関係（偽陽性の対照）
#   R3 MEM-202611010000-03  索引に在る。同じ話題だが両立する（偽陽性の対照）
#   N1 MEM-202611020000-01  索引に無い新しい記録。焦点
#
# N1 を足す前の根は check を 0 で通る。足した後の違反は index.md:index: の1行だけである。
# この2点は scripts/tests/shared-memory-check.bats が確かめる。索引は検査器の出力と同じ字面で書く。
set -euo pipefail

git init -q -b main .
mkdir -p docs/memory/records

cat > docs/memory/records/MEM-202611010000-01-cron-evaluated-in-utc.md <<'REC'
---
id: MEM-202611010000-01
type: experience
title: tokei-cron は、cron 式の時刻を UTC として解釈する
author: ai
verification: verified
confidence: high
applies-when: tokei-cron の定期ジョブの起動時刻を、cron 式で指定するとき
sources:
  - 2026-10-28 に tokei-cron 2.3 で実測した
created: 2026-11-01
updated: 2026-11-01
---

## 観測したこと

2026-10-28 に、tokei-cron 2.3 で `0 9 * * *` のジョブを登録した。実行ノードの時刻帯は `Asia/Tokyo` だった。ジョブは、日本時間の 18:00（UTC の 09:00）に起動した。

## 言えること

cron 式の時刻は、実行ノードの時刻帯によらず、UTC として解釈される。日本時間の 09:00 に起動したいジョブは、`0 0 * * *` と書く。

## 当てはまらない場合

ジョブの定義に `timezone` を書いた場合は、確かめていない。
REC

cat > docs/memory/records/MEM-202611010000-02-linter-ci-before-precommit.md <<'REC'
---
id: MEM-202611010000-02
type: experience
title: リンターを既存のコードへ入れるときは、CI で警告として出す段を先に置くと、既存の違反で commit が止まらない
author: ai
verification: verified
confidence: medium
applies-when: 違反を多く抱えた既存のコードへ、リンターを後から導入するとき
sources:
  - 2026-10-20 の導入の作業で観測した
created: 2026-11-01
updated: 2026-11-01
---

## 観測したこと

pre-commit のフックへ先に入れたところ、触っていない行の違反で commit が止まった。CI で警告として出す形へ変えた後は、止まらなかった。

## 言えること

既存の違反を直し終えるまでは、CI の警告に留める。
REC

cat > docs/memory/records/MEM-202611010000-03-cron-next-shows-fire-time.md <<'REC'
---
id: MEM-202611010000-03
type: knowledge
title: tokei-cron が cron 式をどの時刻帯で解釈したかは、`tokei-cron next` が表示する次回の起動時刻で確かめられる
author: ai
verification: verified
confidence: high
applies-when: tokei-cron の定期ジョブが、意図した時刻に起動するかを確かめるとき
sources:
  - 2026-10-28 に tokei-cron 2.3 で実測した
created: 2026-11-01
updated: 2026-11-01
---

## 観測したこと

`tokei-cron next <ジョブ名>` は、次回の起動時刻を、時刻帯の表記つきで表示した。

## 言えること

登録した後に、このコマンドで起動時刻を確かめる。
REC

cat > docs/memory/records/MEM-202611020000-01-cron-evaluated-in-local-time.md <<'REC'
---
id: MEM-202611020000-01
type: experience
title: tokei-cron は、cron 式の時刻を実行ノードの時刻帯で解釈する
author: ai
verification: verified
confidence: medium
applies-when: tokei-cron の定期ジョブの起動時刻を、cron 式で指定するとき
sources:
  - 2026-11-02 に tokei-cron 2.3 で実測した
created: 2026-11-02
updated: 2026-11-02
---

## 観測したこと

2026-11-02 に、tokei-cron 2.3 で `0 9 * * *` のジョブを登録した。実行ノードの時刻帯は `Asia/Tokyo` だった。ジョブは、日本時間の 09:00 に起動した。

## 言えること

cron 式の時刻は、実行ノードの時刻帯で解釈される。日本時間の 09:00 に起動したいジョブは、`0 9 * * *` と書く。
REC

cat > docs/memory/index.md <<'IDX'
# 索引

<!-- 検査器が生成する。手で編集しない。作り直すには index --write を使う。 -->

| 識別子 | 種類 | 主張 | 当てはまる条件 | 検証 |
|---|---|---|---|---|
| [MEM-202611010000-01](records/MEM-202611010000-01-cron-evaluated-in-utc.md) | experience | tokei-cron は、cron 式の時刻を UTC として解釈する | tokei-cron の定期ジョブの起動時刻を、cron 式で指定するとき | verified |
| [MEM-202611010000-02](records/MEM-202611010000-02-linter-ci-before-precommit.md) | experience | リンターを既存のコードへ入れるときは、CI で警告として出す段を先に置くと、既存の違反で commit が止まらない | 違反を多く抱えた既存のコードへ、リンターを後から導入するとき | verified |
| [MEM-202611010000-03](records/MEM-202611010000-03-cron-next-shows-fire-time.md) | knowledge | tokei-cron が cron 式をどの時刻帯で解釈したかは、`tokei-cron next` が表示する次回の起動時刻で確かめられる | tokei-cron の定期ジョブが、意図した時刻に起動するかを確かめるとき | verified |
IDX
