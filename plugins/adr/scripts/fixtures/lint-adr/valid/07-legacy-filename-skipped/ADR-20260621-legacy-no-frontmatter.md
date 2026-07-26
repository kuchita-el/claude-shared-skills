# ADR-20260621: front-matter を持たない旧形式 ADR

## Status

Accepted

## Context

fixture 用（valid/07）。front-matter を持たない旧 `## Status` 形式であり、ファイル名も旧規約（時刻部・連番部なし）のままである。レイヤ1 がこの種の ADR を検査対象外としてスキップするのと同じ対象集合をレイヤ5 も用いるため、形式違反としては報告されない。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ5 は旧形式 ADR を検査せず、corpus 全体が exit 0 で通過する。
