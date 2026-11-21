#!/usr/bin/env bash
# behavior-propose-records の題材を、空の作業ディレクトリへ作る。
#
# 作るもの:
#   docs/memory/              Project Memory の根。記録2件と、検査器の出力と一致する索引
#     X MEM-202611010000-01   空の CSV で、集計が0件の結果を書き出す（experience・verified）
#     Y MEM-202611010000-02   集計は CSV を Shift_JIS として読む（knowledge・verified）
#   scripts/report.sh         集計の作り物。読み込みは UTF-8 と指定してある
#   notes/task-notes.md       作業メモ。学びを4件持つ。これだけはコミットしない
#
# 作業メモの4件と、期待する扱い:
#   1 TZ が未設定だと、日付の境界を UTC で切る（新しい、確かめた事実）   足す
#   2 空の CSV で、件数0の結果が出た（X と同じ条件・同じ結果の再観測）   捨てる。理由に X
#   3 Shift_JIS は文字化けし、UTF-8 は正しく集計された（Y と食い違う）   直す（置き換え）
#   4 入力の検証は早い段階で行うほうがよい（観測の無い一般論）           捨てる
#
# 指示ファイルと Global Memory の根は置かない。Project の根は既定の docs/memory に決まり、
# Global は「無い」と決まる。
#
# 記録と索引が検査を通ることは、scripts/tests/shared-memory-check.bats が確かめる。
# 記録の front-matter を変えたら、索引も検査器の出力に合わせて直す。
set -euo pipefail

mkdir -p docs/memory/records scripts notes

cat > docs/memory/records/MEM-202611010000-01-empty-input-zero-report.md <<'RECORD'
---
id: MEM-202611010000-01
type: experience
title: 日次レポートの集計は、入力に0バイトの CSV が在ると、エラーを出さずに0件の結果を書き出す
author: ai
verification: verified
confidence: medium
applies-when: 日次レポートの集計を実行する前に、入力のファイルを確かめるとき
sources:
  - 2026年11月1日に、手元で scripts/report.sh を実行して観測した
created: 2026-11-01
updated: 2026-11-01
---

## 観測したこと

0バイトの CSV を1つ置いて `scripts/report.sh` を実行した。終了コードは 0 で、件数0の結果が書き出された。

## 言えること

- 集計の成功は、入力が空でなかったことを意味しない。
- 実行の前に、入力のファイルの大きさを確かめる。

## 当てはまらない場合と、確かめていないこと

- 見出しの行だけを持つ CSV では、確かめていない。
RECORD

cat > docs/memory/records/MEM-202611010000-02-csv-shift-jis.md <<'RECORD'
---
id: MEM-202611010000-02
type: knowledge
title: 日次レポートの集計は、入力の CSV を Shift_JIS として読む
author: ai
verification: verified
confidence: medium
applies-when: 日次レポートへ渡す CSV を用意するとき
sources:
  - 2026年11月1日に、scripts/report.sh の読み込みの指定を読んで確かめた
created: 2026-11-01
updated: 2026-11-01
---

## 観測したこと

`scripts/report.sh` は、入力を読むときの文字コードに Shift_JIS を指定していた。

## 言えること

- 日次レポートへ渡す CSV は、Shift_JIS で保存する。

## 当てはまらない場合と、確かめていないこと

- 実際のファイルを渡した実行は、行っていない。
RECORD

cat > docs/memory/index.md <<'INDEX'
# 索引

<!-- 検査器が生成する。手で編集しない。作り直すには index --write を使う。 -->

| 識別子 | 種類 | 主張 | 当てはまる条件 | 検証 |
|---|---|---|---|---|
| [MEM-202611010000-01](records/MEM-202611010000-01-empty-input-zero-report.md) | experience | 日次レポートの集計は、入力に0バイトの CSV が在ると、エラーを出さずに0件の結果を書き出す | 日次レポートの集計を実行する前に、入力のファイルを確かめるとき | verified |
| [MEM-202611010000-02](records/MEM-202611010000-02-csv-shift-jis.md) | knowledge | 日次レポートの集計は、入力の CSV を Shift_JIS として読む | 日次レポートへ渡す CSV を用意するとき | verified |
INDEX

cat > scripts/report.sh <<'SCRIPT'
#!/usr/bin/env bash
# 日次レポートの集計。data/ の CSV を読み、日付ごとの件数を out/report.csv へ書く。
set -euo pipefail
mkdir -p out
: > out/report.csv
for file in data/*.csv; do
  [ -e "$file" ] || continue
  # 入力は UTF-8 として読む
  LC_ALL=C.UTF-8 cut -d, -f1 "$file" | sort | uniq -c >> out/report.csv
done
SCRIPT

cat > README.md <<'README'
# 日次レポート

`scripts/report.sh` が、`data/` の CSV を集計して `out/report.csv` を書く。

開発で得た知見は、`docs/memory/` に記録として置いてある。
README

git init -q -b main .
git add -A
git -c user.name=scaffold -c user.email=scaffold@example.invalid -c commit.gpgsign=false \
  commit -q -m "題材を置く"

cat > notes/task-notes.md <<'NOTES'
# 作業メモ（日次レポートの集計の調査）

今日の作業で分かったことを、順に書く。

## 日付の境界

環境変数 `TZ` を設定せずに集計を実行すると、日付の境界が UTC で切られた。同じ入力に対して、`TZ=Asia/Tokyo` を付けた実行と付けない実行で、日付ごとの件数が変わった。両方を実行して、出力を比べて確かめた。

## 空のファイル

空の CSV を1つ置いて集計したら、失敗せず、件数0の結果が出た。前に確かめたときと同じ手順で、同じ結果だった。

## 文字コード

Shift_JIS で保存した CSV を渡すと、出力の日本語が文字化けした。同じ中身を UTF-8 で保存して渡すと、正しく集計された。両方を実行して確かめた。`scripts/report.sh` を読むと、読み込みは UTF-8 と指定されていた。

## 感想

入力の検証は、早い段階で行うほうがよいと思う。
NOTES
