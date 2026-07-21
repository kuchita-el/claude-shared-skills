# ADR-20260107-legacy-format-decision: 旧形式の決定

## Status

Accepted

## Context

fixture 用の旧形式 ADR（front-matter 無し）。生成器は front-matter を持たないファイルの
validity を判定できないため、index に載らない。

## Decision

（旧形式のため decision 記載は簡略）

## Consequences

index には現れない（front-matter が無いため）。
