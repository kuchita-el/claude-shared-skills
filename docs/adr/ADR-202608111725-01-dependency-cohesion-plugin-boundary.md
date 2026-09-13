---
status: 却下
validity:
---

# ADR-202608111725-01: 依存凝集に沿ってplugin境界を限定分割する

## Context

`dev-workflow` は複数スキルと共有規約・agentsを含む。pluginをスキル単位へ全面分割すると、共有参照の複製と名前空間の破壊が起きる一方、依存凝集に沿った限定分割なら独立した反転単位を得られる。

## Decision

plugin境界は、共有規約とagentsの依存凝集を維持しながら、独立して配布できるまとまりだけを限定的に分割する。Wave 0では既存plugin名、marketplaceの探索位置、`dev-workflow:<name>` 名前空間を維持し、個別Waveで実測した依存グラフが独立境界を示した場合にのみ後続ADRを起票する。

## Alternatives

- 全スキルを個別pluginへ分割する: 共有規約の複製と参照driftを招くため採用しない。
- `dev-workflow`を一切分割しない: 独立した配布単位を表現できないため採用しない。

## Consequences

- plugin名と既存導入経路を維持したまま、後続Waveで境界を検証できる。
- 分割候補は依存凝集と互換性fixtureを伴うため、判断コストが増える。
- Wave 0の適合性検査はplugin単位を正本とし、skill単位の分割を前提にしない。

## 却下理由

- 2026-09-13: 一度も承認に至らないまま適用先が消滅したため却下。本決定が Wave 0 で維持すると定めた `dev-workflow:<name>` 名前空間・marketplace の探索位置・既存 plugin 名は、いずれも `dev-workflow` に属する。同配布物は ADR-202609110017-01 決定1 が退役を決め、決定5・決定6 が本リポジトリでの使用を止めており、維持すべき対象そのものが効力を失っている。後続 Wave で依存グラフを実測して境界を検証する前提も同時に失われた。

## 関連ADR

Related: ADR-202605250838-01-subagent-agents-consolidation（共有agentsをplugin rootへ集約する原則）

## 変更履歴

- 2026-08-11: Wave 0の依存凝集判断として起票。
