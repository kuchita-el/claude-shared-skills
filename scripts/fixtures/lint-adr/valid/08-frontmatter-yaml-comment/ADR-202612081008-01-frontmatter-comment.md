---
# 起票時のメモ（YAML コメント。行頭 `# ` に当たるため H1 と誤認されうる）
status: 承認済み
validity: 有効
---
# ADR-202612081008-01: front-matter に YAML コメントを持つ適合ADR

## Status

承認済み

## Context

fixture 用（valid/08）。front-matter 内の YAML コメント行は行頭 `# ` に当たるため、H1 整合検査が front-matter 区間を読み飛ばさないと、この行を H1 と誤認して「識別子が見つからない」と偽陽性を報告する。commit 前ゲートは lint の非ゼロ終了をそのままコミットの阻止へ流すため、偽陽性の影響がコミット停止まで届く。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

H1 整合検査は front-matter を読み飛ばし、本文側の H1 と照合して exit 0 になる。
