---
status: 承認済み
validity: 有効
---
# ADR-20261201-related-dangling-source: Related が非存在 slug を指す source

## Status

承認済み

## Context

fixture 用（invalid/20）。`Related:` の参照先ファイルが存在しない（dangling）。レイヤ4 が実在チェックで dangling 参照違反（AC8 の「解決不能な参照先」＝fail-safe をここに統合）を報告することを確認する。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ4 が dangling 参照違反を報告し exit 1 になる。

## 関連ADR

- Related: ADR-20261299-does-not-exist（存在しない参照先。dangling ＝ AC8 fail-safe を発火させる）
