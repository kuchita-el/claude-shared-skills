---
status: 承認済み
validity: 有効
---
# ADR-20260621-01: 旧規約ファイル名で識別子が重複した2本目

## Status

承認済み

## Context

fixture 用（invalid/28）。1本目と同一の識別子 `ADR-20260621-01` を持つ。識別子部の抽出パターンを形式検査と同じ厳しさへ変えると重複が報告されなくなるため、この fixture がその変異を赤化させる。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

形式違反2件に加えて識別子重複違反が報告され exit 1 になる。
