# ADR（Architecture Decision Records）

本ディレクトリは横断的・後戻りコスト高な技術的意思決定（アーキテクチャ・設計方針）を ADR として蓄積・参照・廃止する運用基盤。`docs/development/event-storming.md` の「技術的意思決定」集約の実体であり、同集約の状態遷移・コマンド・イベント定義と整合する。`index.md` は `validity: 有効` な ADR を列挙する導出ビュー（生成物）であり、人手編集しない。

## 運用ルールの所在

ADR 化要否の判定・採番・起票・承認・上書き・廃止・却下・編集の各手順は `manage-adr` スキルが実体を持つ。本 README はこれらを再掲しない。

- [`manage-adr/SKILL.md`](../../plugins/adr/skills/manage-adr/SKILL.md) — スキル本体。各遷移と編集判定の入口
- [`references/adr-model.md`](../../plugins/adr/skills/manage-adr/references/adr-model.md) — 状態2軸の値域・front-matter スキーマ・配置・採番方式
- [`references/adr-scoping.md`](../../plugins/adr/skills/manage-adr/references/adr-scoping.md) — ADR 化要否の粒度判定基準・起票のタイミング・命名規約の ADR 化基準
- [`references/transitions.md`](../../plugins/adr/skills/manage-adr/references/transitions.md) — 5遷移と分割の実行手順・双方向相互参照の書き込み・index の再生成
- [`references/edit-decision.md`](../../plugins/adr/skills/manage-adr/references/edit-decision.md) — core／非core／些末 の編集判定フローと3段構え編集機構
- [`references/template.md`](../../plugins/adr/skills/manage-adr/references/template.md) — 新規 ADR の雛形。スキルを導入していない場合はこれをコピーして使う

## 運用ルールの出所

上記の各規定は以下の ADR が決定として記録している。規定の内容はスキル側を、決定の経緯・根拠は以下を参照する。

- **状態を承認軸と有効性軸の2軸に分離する** — ADR-20260711-3 決定1（2軸分離の背景と設計判断の詳細は同 ADR 全体）
- **front-matter を唯一の権威とし、有効 ADR index を導出ビューとする**（front-matter スキーマと遷移ごとの必須ルール、および `index.md` を機械生成の生成物として人手編集しない扱い） — ADR-20260711-3 決定2
- **有効性軸を可変性のゲートとする凍結原則と3段構えの編集機構** — ADR-20260711-3 決定3
- **`Amends:` / `Amended by:` 機構の廃止** — ADR-20260711-3 決定4
- **旧「モデル制約由来の設計判断インデックス」（人手キュレーションによる設計判断の意味索引）の廃止（意味逆引きは各 ADR 本文で代替する）** — ADR-20260711-3 決定7
- **ADR 化要否の3基準（粒度判定・起票のタイミング・命名規約）と記録の参照原則** — ADR-20260719
- **ADR スキーマの「保留した決定」セクション（意図的な非決定のスナップショット記録）と非 Supersede 関係の参照妥当性 lint** — ADR-20260720-4（意味論・充足規約・lint 要件の詳細は同 ADR）
