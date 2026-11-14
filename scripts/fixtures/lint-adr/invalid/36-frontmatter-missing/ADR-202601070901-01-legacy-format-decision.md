# ADR-202601070901-01-legacy-format-decision: 旧形式の決定

## Status

Accepted

## Context

fixture 用（invalid/36）の旧形式 ADR（front-matter 無し）。ファイル名は新しい規約に従う。
レイヤ1 が front-matter 欠落として報告する。生成器は front-matter を持たないファイルの
validity を判定できないため、index に載らない。

## Decision

（旧形式のため decision 記載は簡略）

## Consequences

index には現れない（front-matter が無いため）。
