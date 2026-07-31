---
status: 承認済み
validity: 有効
---
# ADR-2026120-01: 時刻部の桁数が不足したファイル名

## Status

承認済み

## Context

fixture 用（invalid/24）。ファイル名の時刻部が11桁で、`ADR-YYYYMMDDHHMM-NN-<slug>` の形式に適合しない。レイヤ5 が形式違反を報告することを確認する。H1 の識別子部はファイル名の識別子部と一致させ、形式違反だけを単離する。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ5 がファイル名形式違反を報告し exit 1 になる。
