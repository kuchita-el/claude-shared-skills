# growth の ADR 化候補

growth プラグインの構想から切り出しうる確定判断のうち、ADR 化の候補として追跡しているものの一覧。

判定項目とスコア境界は `plugins/adr/skills/manage-adr/references/adr-scoping.md`「粒度判定基準」を単一の出典とし、本書に再掲しない。表の「粒度判定」列が持つのは**判定当時の暫定評価の結論のみ**である。

**未昇格の候補は、昇格の局面で現行の同ファイルに照らして判定し直す。** 表の点数は評価時点の記録であり、判定項目の改訂（例: 項目2 の改名〔#641〕、却下代替を加点項目でなく必要条件として前置する扱い〔ADR-202608011651-01 決定1〕）を遡及して反映しない。点数の導出（どの項目に該当したか）は、昇格済みの候補については各 ADR の `## Context` が保持する。

起票タイミングは「まず設計母艦に判断を書き、横断再発または実装 PR 時に昇格」とする。

## 由来

本書は `plugins/growth/DESIGN.md` §7「ADR 化候補」を配布元へ移設したもの（#652）。根拠は `docs/distribution-boundary.md` §2 の判断軸である。

**§7 を他の節から切り分けた決め手は第1軸（配布先の環境で解決できるか）である。** growth プラグイン全体から配布元 `docs/` へ張られていた相対リンクは3件で、そのすべてが §7 の候補表の中にあった。§7 を出すことで `plugins/growth/` 配下の解決不能参照は0件になる。

第2軸（配布元固有のデータを含むか）だけでは、この線は引けない。`DESIGN.md` は §7 の外でも本リポジトリの Issue 番号を名指しており（冒頭の「進捗の出典」が `#343–#348` / `#349–#353`、§6 決定事項が `#440` 等）、第2軸をそのまま適用すると DESIGN.md 本体が対象になる。**設計文書そのものを配布物へ置くかどうかは本移設の射程外**であり、`docs/qa/plugin-bp-audit-20260722.md` GRW-11 が扱う論点として残る。

移設以前の本表を名指す記述（ADR-202606261847-01 の Context、ADR-202607010734-01 の Context）は当時の所在を記録したものであり、遡及して改めない。

## 候補

| 候補 | 粒度判定（判定当時の結論） | 昇格タイミング |
|---|---|---|
| 内省機能を dev-workflow に混ぜず独立プラグイン growth として分離 | 3点以上、ADR 級 | 昇格済み: [ADR-202606261847-01-growth-plugin-separation](../../adr/ADR-202606261847-01-growth-plugin-separation.md)（#343 のスケルトン作成 PR で昇格。判定の導出は同 ADR の Context） |
| 学びの共有は配布物（git ファイル）を本体とし、Issue は前段の品質ゲートとする | 要再判定 | 再発時 |
| 配布ファイルの内容モデル（2面 origin/consumer・fan-out/fan-in 分離・配布の2空間・1欄スキーマ・整理＝物理除去） | 3点以上、ADR 級 | #344 で DESIGN.md＋[`learning-store-spec.md`](../../../plugins/growth/references/learning-store-spec.md) に記述。横断再発または別キャリアへの波及時に昇格（現状は spec 参照で足りる） |
| 二段ゲート（保存=自動 / 仕組み化=レビュー） | 新規 ADR 不要（2026-06-26 に整合確認）。既存の自律度 L0–L3／承認ゲート軸（ADR-202606012328-01 / ADR-202606020032-01）で表現でき矛盾なし | — |
| 活性化モデル（時間軸折衷）＋発火観測（本文スキル経由の使用台帳・fan-in） | 3点以上、ADR 級。ただし現状は [`design.md`](design.md) §6 決定事項7＋[`learning-store-spec.md`](../../../plugins/growth/references/learning-store-spec.md) の記述で足りる | #380 で DESIGN.md §6＋spec に記述。Phase 3 実装 PR 時に昇格候補 |
| ライブ相乗り解析 UX の適否（mid-session 割り込み型を不採用、境界・別時間型へ再定義） | 2〜3点。現状は [`design.md`](design.md) §6 決定事項4「4-補」の記述で足りる | #381 で DESIGN.md §6 に記述。Phase 3 実装 PR 時に昇格候補（争点は (b-2) deliver 層の just-in-time 提示） |
| 学習シグナルの復元不能性基準と distill 出力2系統分離（原理3 精緻化・判断知/摩擦知の2軸・decision-record） | 4点、ADR 級 | 昇格済み: [ADR-202607010734-01-learning-signal-recoverability-and-output-forms](../../adr/ADR-202607010734-01-learning-signal-recoverability-and-output-forms.md)（#432 のドッグフーディングを再発契機として昇格。判定の導出は同 ADR の Context） |
| 混在ゾーンの partition 硬度＝非排他 tag（`type`→`tags` 改称・distill evidence-gated 分岐。決定事項10） | 4点、ADR 級 | 記録済み（Amend）: [ADR-202607051220-01](../../adr/ADR-202607051220-01-growth-learning-vocabulary-frame.md) decision 2 へ #440 で追補（同 ADR が委譲した partition 硬度の確定。新規 ADR は起票せず自己 Amend） |

## 関連

- `docs/distribution-boundary.md` — 本書を配布元へ置く根拠となる判断軸
- `plugins/adr/skills/manage-adr/references/adr-scoping.md` — 粒度判定基準の単一出典
- `design.md` — growth の設計母艦。本表が追跡する各判断の本体
