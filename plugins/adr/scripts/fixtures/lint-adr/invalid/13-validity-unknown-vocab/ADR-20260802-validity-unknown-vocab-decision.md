---
status: 承認済み
validity: 有郊
---
# ADR-20260802-validity-unknown-vocab-decision: 語彙外 validity の決定

## Context

fixture 用。`validity` が `有効` の誤字（`有郊`）で、ADR-20260711-3 決定1 の語彙（`有効` / `上書き済み` / `廃止済み`）に属さない ADR。レイヤ1の語彙メンバシップ違反（validity）を検出させる。

値が非空のため「status=承認済み だが validity が空」検査は発火せず、`上書き済み` でないため superseded-by 必須検査も発火しない。一方 `gen-adr-index.sh` は `有効` の完全一致でしか採録しないため、この ADR は index から静かに脱落する。語彙検査が無いと index 脱落と lint 通過が同時に成立する経路の再現。

## Decision

fixture 用のため実質的な決定内容は無い。
