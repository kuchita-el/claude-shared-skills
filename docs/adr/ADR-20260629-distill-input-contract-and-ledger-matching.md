# ADR-20260629: distill の入力契約拡張と既存ルール台帳突合

## Status

Accepted

## Context

growth の capture/distill が生成した store を評価したところ、`candidates.md` が環境摩擦と既知ルールの再発見で希釈されていた（#417 背景。「python3 -c 禁止」のような既に成文化済みルールが provenance 24 件の新規候補として再発見される実例）。この希釈により、本当に学びとなる判断誤りが候補の中に埋もれる。

#417 は distill に「観察の分類（環境摩擦 vs 判断誤り）・user 訂正の重み付け・スコープ別の既存ルール台帳との突合・既存ルール再発の知見化」を加え、`candidates.md` の信号対雑音比を高めることを目的とする。このうち台帳突合と再発の知見化は、distill が既存ルール台帳（user/project 2層の `CLAUDE.md`・`learnings.md`・`candidates.md` 自身）の**現在の状態**を読むことを必要とする。

しかし現行の distill の入力契約は「入力源は正準パス `captures.md` のみ。in-repo の `plugins/growth/.local/` は走査しない」と定めている（`personal-store-spec.md`「構成上の保証」、`distill-procedure.md` §2、`distill/SKILL.md` Phase 1 スコープ）。台帳突合はこの入力契約の拡大であり、`docs/adr/README.md` の粒度判定4項目（影響範囲・不可逆性・トレードオフ・横断性）すべてに該当する構造的判断のため、本 ADR で束ねる。#417 本文自身も「責務線引き＋distill 入力範囲の拡大が ADR 級か判定する。該当すれば本線引きを束ねる ADR を起票する」と求めている。

## Decision

以下の4点を決定する。

### 1. 入力の種別分離（処理源 / 参照源）

distill の入力を2種に分離し、現行文言「入力源は `captures.md` のみ」をこの二分で書き換える。

- **処理源（work queue）= `captures.md` のみ（不変）**: 何を候補化するか。`status: unprocessed` のエントリを provenance キーで upsert する対象。in-repo `.local/` 非走査、および冪等性（`status` 軸の再走査抑止＋provenance upsert）はこの処理源に紐づき、本決定で変更しない。
- **参照源（consultation）= 既存ルール台帳（読み取り専用・新規）**: 何と突合するか。user/project 2層の `CLAUDE.md`・`learnings.md`・`candidates.md` 自身。台帳から候補を**生成しない**（候補の発明には使わず、観察が既知か novel かの照合にのみ用いる）。

### 2. 入力定義の拡張と時間不変性の意図的放棄

distill を `f(captures.md)` から `f(captures.md, 台帳の現在状態)` へ拡張する。

- 台帳を**明示的入力**として宣言することで、**決定性**（同一入力→同一出力）と**参照透過性**（隠れ状態に依存しない）は保持する。
- 一方、台帳が時変であるため**時間不変性は意図的に手放す**。すなわち、同一の `captures.md` でも既存ルールの成文化が進めば出力（分類・候補化可否）が変わることを許容する。これは #417 の目的そのものである。
- 手放した**再現性**は、突合でマッチした台帳ルールへの参照を candidate に記録することで、監査可能性として回復する。

### 3. pending 候補の再評価ポリシー（毎回再評価）

- pending 候補は distill 実行時の台帳で再評価し最新化する。既存ルールと一致すれば「ルール追加候補」から「既存ルール X が N 回再発」知見へ upsert で置換する。
- `promoted` / `rejected` の候補は**不可侵**とする。distill は再評価でこれらを覆さない（特に promote が `rejected` にした候補を再生成・pending 復活させない）。
- 再評価は同一 provenance での内容置換＝既存 upsert の範囲内で行い、新たな削除操作や `status` 反転を導入しない。

### 4. 責務境界の確認

台帳突合は distill の既存責務「クラスタ化・重複排除」の母集団拡大（store 内の観察どうし → 既存ルール台帳）であり、promote の検証（配布価値・予測力・反証可能性の判定）には侵入しない。「既知か novel か」と「本物か・配布価値があるか」は別軸である。台帳突合を promote 側に置くと候補選別ロジックが promote に漏れて境界が濁るため、distill に置くのが正しい。

境界を保つために distill が守るべき3条件:

1. 再評価対象は pending のみ。`rejected` / `promoted` は不可侵（promote の検証判断を覆さない）。
2. distill は「既知 / novel」までしか判定しない。「予測力がない / 配布価値がない」での棄却（promote の検証）は行わない。
3. 再発知見は事実集計（N 回再発）までとし、「機能不全だから撤去せよ」等の裁定はしない。裁定は下流（promote → Issue → 人間）が担う。

## Consequences

- **得られる利益**: `candidates.md` の信号対雑音比が向上する。既知ルールの単純な再発見を新規候補にせず「既存ルールが機能していない（N 回再発）」知見へ変換することで、本当に学びとなる判断誤りが埋もれない。
- **受容したコスト**: distill が外部の可変状態（台帳）に依存し、時間不変性を失う。同一 `captures.md` でも実行時点により出力が変わりうるため、テスト・再現には台帳状態の固定または記録を要する。distill の読み取り対象が増え、スコープ別台帳の解決（universal / project-local / 特定プラグインで突合先が異なる）に実装コストが生じる。
- **自己参照の留保**: 参照源に `candidates.md` 自身を含むため、distill が `candidates.md` を読んで書き戻す自己参照ループになる。provenance キー upsert で収束する前提だが、収束条件は実装 Issue で明示する。
- **本 ADR に含めない範囲（実装 Issue 側で詰める）**: 出力スキーマの具体（再発回数を専用フィールドにするか本文記述にするか）、スコープ別台帳の解決範囲（Phase 1 でどこまで突合するか）、自己参照ループの収束条件の具体実装。
- **将来の留保事項**: 時間不変性の放棄が再現性・テスト容易性に与える影響が許容範囲を超える場合、(a) pending 候補を生成時点の台帳状態で凍結する方式への切り替え、または台帳スナップショットの永続化を再検討する。

## 関連ADR

- Amended by: ADR-20260711-store-state-model-captures-stateless（決定1 の work-queue 選択 facet ＝ status 軸の再走査抑止を provenance ＋ recency 導出へ改訂。決定2・3・4 は存続）
- Related: ADR-20260626-growth-plugin-separation（growth の疎結合分離。distill の台帳読み取りは distill 内部の入力であり、promote → Issue 起票の疎結合とは別レイヤ）
- Related: ADR-20260628-2-career-decision-model（distill が仮説を生成し、確定・裁定は下流が担うという責務線引きの先例）
- 関連Issue: #417, #416
