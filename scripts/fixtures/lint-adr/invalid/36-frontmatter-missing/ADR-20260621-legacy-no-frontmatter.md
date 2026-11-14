# ADR-20260621: front-matter を持たない旧形式 ADR

## Status

Accepted

## Context

fixture 用（invalid/36）。front-matter を持たない旧 `## Status` 形式であり、ファイル名も旧規約（時刻部・連番部なし）のままである。レイヤ1 が front-matter 欠落として報告する。レイヤ5 は front-matter を持つ ADR だけを対象にするため、ファイル名形式違反・H1 整合違反としては重ねて報告しない。

## Decision

fixture 用のため実質的な決定内容は無い。

## Consequences

レイヤ1 が front-matter 欠落を報告し、ADR 群全体は exit 1 になる。レイヤ5 の違反は出ない。
