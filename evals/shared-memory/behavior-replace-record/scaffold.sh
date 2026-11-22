#!/usr/bin/env bash
# behavior-replace-record の題材を、空の作業ディレクトリへ作る。
#
# 記憶の根は docs/memory。git は初期化しない（replace-record は git を使わない）。
# 記録の本文と識別子は、この題材のために新しく書いた作り物である。道具の名前（tokei-cron）も作り物である。
#
#   O1 MEM-202611010000-01  置き換えられる旧い記録
#   K1 MEM-202611010000-02  触ってはならない無関係の記録
#
# この根が check を 0 で通ることは、scripts/tests/shared-memory-check.bats が確かめる。
# 索引は検査器の出力と同じ字面で書く。
set -euo pipefail

mkdir -p docs/memory/records

cat > docs/memory/records/MEM-202611010000-01-failed-job-retried-three-times.md <<'REC'
---
id: MEM-202611010000-01
type: knowledge
title: tokei-cron は、失敗したジョブを既定で3回まで再試行する
author: ai
verification: verified
confidence: high
applies-when: tokei-cron のジョブが失敗したときの挙動を前提に、後続の処理を設計するとき
sources:
  - 2026-10-20 に tokei-cron 2.3 で実測した
created: 2026-11-01
updated: 2026-11-01
---

## 観測したこと

2026-10-20 に、tokei-cron 2.3 で、必ず失敗するジョブを登録した。`retries` は指定しなかった。ジョブは4回起動し、4回目の失敗で止まった。

## 言えること

`retries` を指定しないジョブは、3回まで再試行される。
REC

cat > docs/memory/records/MEM-202611010000-02-job-log-kept-thirty-days.md <<'REC'
---
id: MEM-202611010000-02
type: knowledge
title: tokei-cron は、ジョブの実行ログを30日で消す
author: ai
verification: verified
confidence: medium
applies-when: tokei-cron のジョブの失敗を、後から調べるとき
sources:
  - 2026-10-20 に tokei-cron 2.3 の設定の既定値を読んだ
created: 2026-11-01
updated: 2026-11-01
---

## 言えること

30日より前の失敗は、実行ログからは調べられない。
REC

cat > docs/memory/index.md <<'IDX'
# 索引

<!-- 検査器が生成する。手で編集しない。作り直すには index --write を使う。 -->

| 識別子 | 種類 | 主張 | 当てはまる条件 | 検証 |
|---|---|---|---|---|
| [MEM-202611010000-01](records/MEM-202611010000-01-failed-job-retried-three-times.md) | knowledge | tokei-cron は、失敗したジョブを既定で3回まで再試行する | tokei-cron のジョブが失敗したときの挙動を前提に、後続の処理を設計するとき | verified |
| [MEM-202611010000-02](records/MEM-202611010000-02-job-log-kept-thirty-days.md) | knowledge | tokei-cron は、ジョブの実行ログを30日で消す | tokei-cron のジョブの失敗を、後から調べるとき | verified |
IDX
