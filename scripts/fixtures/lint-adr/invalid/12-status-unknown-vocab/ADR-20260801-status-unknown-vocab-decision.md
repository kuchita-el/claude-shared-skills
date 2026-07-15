---
status: Accepted
---
# ADR-20260801-status-unknown-vocab-decision: 語彙外 status の決定

## Context

fixture 用。`status` が旧英文状態（`Accepted`）のままで、ADR-20260711-3 決定1 の語彙（`提案中` / `承認済み` / `却下`）に属さない ADR。レイヤ1の語彙メンバシップ違反（status）を検出させる。

値が非空のため既存の「status が空」検査は発火せず、`承認済み` でないため「status=承認済み だが validity が空」検査も発火しない。語彙検査が無いと素通りする経路の再現。

## Decision

fixture 用のため実質的な決定内容は無い。
