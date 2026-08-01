# growth の ADR 化候補

growth プラグインの構想から切り出しうる確定判断のうち、ADR 化の候補として追跡しているものの一覧。

粒度判定は `plugins/adr/skills/manage-adr/references/adr-scoping.md`「粒度判定基準」に照らした暫定評価であり、判定項目とスコア境界は同ファイルを単一の出典とする（本書に再掲しない）。起票タイミングは「まず設計母艦に判断を書き、横断再発または実装 PR 時に昇格」とする。

## 由来

本書は `plugins/growth/DESIGN.md` §7「ADR 化候補」を配布元へ移設したもの（#652）。本リポジトリの Issue 番号と ADR ファイルを名指す配布元固有の管理情報であり、`docs/distribution-boundary.md` §2 の判断軸により配布物へ置かない資産にあたるため移した。移設以前の本表を名指す記述（ADR-202606261847-01 の Context、ADR-202607010734-01 の Context）は当時の所在を記録したものであり、遡及して改めない。

## 候補

| 候補 | 粒度判定（暫定） | 昇格タイミング |
|---|---|---|
| 内省機能を dev-workflow に混ぜず独立プラグイン growth として分離 | 後戻りコスト高・横断・却下選択肢あり・自動強制不可 → 3点以上、ADR 級 | 昇格済み: [ADR-202606261847-01-growth-plugin-separation](../../adr/ADR-202606261847-01-growth-plugin-separation.md)（#343 のスケルトン作成 PR で昇格） |
| 学びの共有は配布物（git ファイル）を本体とし、Issue は前段の品質ゲートとする | 横断・採用理由揮発 → 要再判定 | 再発時 |
| 配布ファイルの内容モデル（2面 origin/consumer・fan-out/fan-in 分離・配布の2空間・1欄スキーマ・整理＝物理除去） | 後戻りコスト高・複数モジュール波及・採用理由揮発・自動強制不可 → 3点以上、ADR 級 | #344 で DESIGN.md＋[`learning-store-spec.md`](../../../plugins/growth/references/learning-store-spec.md) に記述。横断再発または別キャリアへの波及時に昇格（現状は spec 参照で足りる） |
| 二段ゲート（保存=自動 / 仕組み化=レビュー） | 整合確認済み（2026-06-26）。既存の自律度 L0–L3／承認ゲート軸（ADR-202606012328-01 / ADR-202606020032-01）で表現でき矛盾なし。新規 ADR 不要 | — |
| 活性化モデル（時間軸折衷）＋発火観測（本文スキル経由の使用台帳・fan-in） | 後戻りコスト高・複数モジュール波及・採用理由揮発 → 3点以上、ADR 級。ただし現状は DESIGN.md §6 決定事項7＋[`learning-store-spec.md`](../../../plugins/growth/references/learning-store-spec.md) の記述で足りる | #380 で DESIGN.md §6＋spec に記述。Phase 3 実装 PR 時に昇格候補 |
| ライブ相乗り解析 UX の適否（mid-session 割り込み型を不採用、境界・別時間型へ再定義） | 後戻りコスト低〜中・複数モジュール波及中・採用理由揮発高・自動強制不可 → 2〜3点。現状は DESIGN.md §6 決定事項4「4-補」の記述で足りる | #381 で DESIGN.md §6 に記述。Phase 3 実装 PR 時に昇格候補（争点は (b-2) deliver 層の just-in-time 提示） |
| 学習シグナルの復元不能性基準と distill 出力2系統分離（原理3 精緻化・判断知/摩擦知の2軸・decision-record） | 後戻りコスト高・複数モジュール波及・採用理由揮発・自動強制不可 → 4点、ADR 級 | 昇格済み: [ADR-202607010734-01-learning-signal-recoverability-and-output-forms](../../adr/ADR-202607010734-01-learning-signal-recoverability-and-output-forms.md)（#432 のドッグフーディングを再発契機として昇格） |
| 混在ゾーンの partition 硬度＝非排他 tag（`type`→`tags` 改称・distill evidence-gated 分岐。決定事項10） | 後戻りコスト高・複数モジュール波及・採用理由揮発・自動強制不可 → 4点、ADR 級 | 記録済み（Amend）: [ADR-202607051220-01](../../adr/ADR-202607051220-01-growth-learning-vocabulary-frame.md) decision 2 へ #440 で追補（同 ADR が委譲した partition 硬度の確定。新規 ADR は起票せず自己 Amend） |

## 関連

- `docs/distribution-boundary.md` — 本書を配布元へ置く根拠となる判断軸
- `plugins/adr/skills/manage-adr/references/adr-scoping.md` — 粒度判定基準の単一出典
- `plugins/growth/DESIGN.md` — growth の設計母艦。本表が追跡する各判断の本体
