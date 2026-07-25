---
status: 承認済み
validity: 有効
superseded-by:
---

# ADR-20260725-2: 実行パラメータの統制点をサブエージェント定義に集約する

## Context

起票時点の Claude Code では、SKILL.md の front-matter も `model` と `effort` を受け付ける。したがって実行パラメータの統制点をスキル側に置く選択肢が存在する。

ただしスキル側の指定は効果がそのターンの残りに限られ、次のプロンプトでセッション値へ戻る。

## Decision

実行パラメータは `agents/{name}.md` の front-matter にのみ置く。SKILL.md の front-matter には `model` と `effort` を置かない。

## Consequences

対話や承認の待ち合わせで複数のターンにまたがるスキル（`create-issue` / `domain-modeling` / `event-storming` / `plan-issue` / `manage-adr` / `intake` / `implementation`）でも、統制が一貫する。スキル側に置いた場合は最初のターンにしか効かず、統制として成立しない。

サブエージェント側を明示している以上、スキル front-matter の `model` 指定はサブエージェントの実行には届かない。起票時点の解決順は環境変数 → Agent tool の `model` 引数 → サブエージェント定義の front-matter → 親セッションであり、スキル front-matter の指定は主ループのモデルを差し替える形で最後尾の「親セッション」の位置に入るにとどまる。サブエージェント定義が `model` を明示している限り、この項は参照されない（`effort` も同じ構造である）。

一方で Agent tool の `model` 引数はサブエージェント定義の front-matter を上書きする。このため本 ADR の統制は、呼び出し側で `model` 引数を指定しないことを前提に成立する。スキル本文には「モデルと effort は定義の frontmatter に従い、呼び出し側では指定しない」と明記する。

統制点を2箇所に分散させれば、どちらが効いているかの追跡が難しくなる。

スキルのメイン側処理（バッチ分割・結果集約・整形）は親セッションの設定で動く。この部分を下げる手段は持たない。削減の対象はサブエージェントに委譲された処理に限られる。

## 保留した決定

- `context: fork` の導入。スキル本文をサブエージェントの指示として実行しメイン側の文脈消費を抑える機構だが、実行パラメータではなく文脈設計の論点であり本 ADR では決めない（想定継承先: S3 規律再設定層、または独立した課題として起票）

## 関連ADR

- Related: ADR-20260725-subagent-execution-parameter-pinning（実行パラメータをどのような値で固定するかを扱う独立した core。上書きでない）

## 変更履歴

- 2026-07-25: Consequences の解決順の記述を訂正。「front-matter が呼び出し側の指定より優先される」は誤りで、Agent tool の `model` 引数は front-matter を上書きする。比較対象がスキル front-matter であることを明示し、呼び出し側で `model` 引数を指定しないことが統制の前提である旨を追記した（決定は不変）
