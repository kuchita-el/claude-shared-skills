#!/usr/bin/env bash
# behavior-triage-candidates の題材を、空の作業ディレクトリへ作る。
#
# Global Memory の根は global-memory。作業ディレクトリは、コミットの無い git のリポジトリにする。
# 記録の本文と識別子は、この題材のために新しく書いた作り物である。道具の名前（tokei-cron）も作り物である。
#
#   R1 MEM-202611010000-01  records/。cron 式は UTC として解釈される
#   R2 MEM-202611010000-02  records/。リンターは CI の警告から入れる
#   C1 MEM-202611150000-01  candidates/。R1 と同じことを言い、補うものが無い（重なる）
#   C2 MEM-202611150000-02  candidates/。R2 と食い違う。確かめていない
#   C3 MEM-202611150000-03  candidates/。記録とは触れ合わない。C4 と食い違い、根拠は C4 より強い
#   C4 MEM-202611150000-04  candidates/。C3 とだけ食い違う。確かめていない
#
# 索引は、C3 の行を意図して欠く（C4 の行は在る）。検査器は index.md:index: の1行だけを出す（記録・候補の形式は通る）。
# スキルは、この1行を報告に付して進み、索引を作り直さない（手順2）。この点は scripts/tests/shared-memory-check.bats が確かめる。
set -euo pipefail

git init -q -b main .
mkdir -p global-memory/records global-memory/candidates

cat > global-memory/records/MEM-202611010000-01-cron-evaluated-in-utc.md <<'REC'
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

cat > global-memory/records/MEM-202611010000-02-linter-ci-before-precommit.md <<'REC'
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

cat > global-memory/candidates/MEM-202611150000-01-cron-utc-again.md <<'REC'
---
id: MEM-202611150000-01
type: experience
title: tokei-cron は、cron 式の時刻を UTC として解釈する
author: ai
verification: verified
confidence: high
applies-when: tokei-cron の定期ジョブの起動時刻を、cron 式で指定するとき
sources:
  - 2026-11-10 に tokei-cron 2.3 で実測した
created: 2026-11-15
updated: 2026-11-15
---

## 観測したこと

2026-11-10 に、tokei-cron 2.3 で `30 8 * * *` のジョブを登録した。実行ノードの時刻帯は `Asia/Tokyo` だった。ジョブは、日本時間の 17:30（UTC の 08:30）に起動した。

## 言えること

cron 式の時刻は、実行ノードの時刻帯によらず、UTC として解釈される。

## 当てはまらない場合

ジョブの定義に `timezone` を書いた場合は、確かめていない。
REC

cat > global-memory/candidates/MEM-202611150000-02-linter-precommit-first.md <<'REC'
---
id: MEM-202611150000-02
type: belief
title: リンターは、既存の違反が多いコードでも、最初から pre-commit のフックへ入れる
author: ai
verification: unverified
confidence: low
applies-when: 違反を多く抱えた既存のコードへ、リンターを後から導入するとき
sources:
  - あるプロジェクトの導入の作業での印象
created: 2026-11-15
updated: 2026-11-15
---

## 言えること

CI の警告に留めると、違反が直されないまま残る。最初から pre-commit のフックへ入れ、違反を直しながら進めるほうがよい。
REC

cat > global-memory/candidates/MEM-202611150000-03-job-name-length-limit.md <<'REC'
---
id: MEM-202611150000-03
type: knowledge
title: tokei-cron のジョブ名は、64 文字を超えると登録が拒まれる
author: ai
verification: verified
confidence: high
applies-when: tokei-cron へ、長い名前のジョブを登録するとき
sources:
  - 2026-11-12 に tokei-cron 2.3 で実測した
created: 2026-11-15
updated: 2026-11-15
---

## 観測したこと

2026-11-12 に、tokei-cron 2.3 で、65 文字のジョブ名を登録したところ、拒まれた。64 文字の名前は登録できた。

## 言えること

ジョブ名は 64 文字までに収める。

## 当てはまらない場合

2.3 より後の版は、確かめていない。
REC

cat > global-memory/candidates/MEM-202611150000-04-job-name-length-128.md <<'REC'
---
id: MEM-202611150000-04
type: knowledge
title: tokei-cron のジョブ名は、128 文字まで登録できる
author: ai
verification: unverified
confidence: low
applies-when: tokei-cron へ、長い名前のジョブを登録するとき
sources:
  - 設定画面の入力欄の表示の印象
created: 2026-11-15
updated: 2026-11-15
---

## 言えること

ジョブ名は 128 文字まで登録できる。
REC

cat > global-memory/index.md <<'IDX'
# 索引

<!-- 検査器が生成する。手で編集しない。作り直すには index --write を使う。 -->

| 識別子 | 種類 | 主張 | 当てはまる条件 | 検証 |
|---|---|---|---|---|
| [MEM-202611010000-01](records/MEM-202611010000-01-cron-evaluated-in-utc.md) | experience | tokei-cron は、cron 式の時刻を UTC として解釈する | tokei-cron の定期ジョブの起動時刻を、cron 式で指定するとき | verified |
| [MEM-202611010000-02](records/MEM-202611010000-02-linter-ci-before-precommit.md) | experience | リンターを既存のコードへ入れるときは、CI で警告として出す段を先に置くと、既存の違反で commit が止まらない | 違反を多く抱えた既存のコードへ、リンターを後から導入するとき | verified |

## 候補

| 識別子 | 種類 | 主張 | 当てはまる条件 | 検証 |
|---|---|---|---|---|
| [MEM-202611150000-01](candidates/MEM-202611150000-01-cron-utc-again.md) | experience | tokei-cron は、cron 式の時刻を UTC として解釈する | tokei-cron の定期ジョブの起動時刻を、cron 式で指定するとき | verified |
| [MEM-202611150000-02](candidates/MEM-202611150000-02-linter-precommit-first.md) | belief | リンターは、既存の違反が多いコードでも、最初から pre-commit のフックへ入れる | 違反を多く抱えた既存のコードへ、リンターを後から導入するとき | unverified |
| [MEM-202611150000-04](candidates/MEM-202611150000-04-job-name-length-128.md) | knowledge | tokei-cron のジョブ名は、128 文字まで登録できる | tokei-cron へ、長い名前のジョブを登録するとき | unverified |
IDX
