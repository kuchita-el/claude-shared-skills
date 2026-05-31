# ADR-20260531-2: workflow-design.md を Explanation 根拠ハブへ縮退（責務再定義）

## Status

Accepted

## Context

`docs/workflow-design.md` は、性質の異なる3層を一身に抱えてきた。

- **構造層**: 全体フロー概観、ドメイン構造「決めること」、Delivery 各ゲート記述、検証ゲート構成定義
- **操作層**: spec.md 構成例、デリバリーアイテム粒度ガイドライン、ADR 記録の判断基準、テスト方針、ドキュメンテーション戦略、ドキュメント間結合度原則、スキルとフェーズの対応、作業単位の階層・Sprint 運用
- **根拠層**: 基本原則①②③、なぜ事前にドメイン構造が必要か（70%見通し）、変更パターン A/B/C、責任分担マトリクス、アンチパターン

構造層・操作層には他に SoT が存在する（構造は `docs/development/event-storming.md` / domain-model、操作は各 SKILL.md・`CLAUDE.md`・`docs/adr/README.md`・`docs/references/`）。これらを workflow-design.md が二重に抱えることが、構造ドリフトの温床になっていた。一方、根拠層には固有のホームが無い。

当初 #221 は「workflow-design.md と event-storming/domain-model 間の構造ドリフト同期」を想定したが、両者を突き合わせた結果この前提は不成立と判明した（workflow-design.md は具体的な集約名・状態名・ポリシーを記述しておらず、粗い散文要約に留まる。明確な構造の二重定義は検証ゲート構成定義のみ）。よって #221 を「workflow-design.md の縮退・再定義」へ再定義した。

ADR-20260402 は workflow-design.md v2 の構造（Discovery 追加・用語非依存化・フロー/ストック軸分離）を6決定で確定したが、「workflow-design.md がどの責務を保持する文書か」という**責務定義の facet** は当時の前提（構造・操作・根拠を集約した設計図）に立脚していた。本 ADR はこの facet のみを改訂する。残り5決定（用語フレームワーク非依存化、フロー/ストック軸分離、ドメイン分類配置、spec.md 集約、廃止事項）は今も有効なため、ADR-20260402 全体の Supersede はしない。

## Decision

縮退後の `docs/workflow-design.md`（リネーム後 `docs/principles.md`）の責務を以下に再定義する。

1. **文書類型 = Diátaxis の Explanation（根拠ハブ）**。Reference（event-storming / domain-model）、How-to（各 SKILL.md）、原子的決定（ADR）と役割分担し、本 repo に欠けていた「方法論の根拠・哲学」ジャンルを埋める。
2. **保持する内容は根拠層のみ**。基本原則①②③、70%見通し、変更パターン A/B/C、責任分担マトリクス、アンチパターン。構造層・操作層は各 SoT へ移転する。
3. **結合方向は一方向**: 根拠（hub）→ 参照 → 構造（event-storming / domain-model / big-picture）／操作（各 SKILL.md / CLAUDE.md / adr/README）。構造・操作の唯一の SoT はそれぞれの専用文書であり、根拠ハブは再記述せずリンクで委譲する。
4. **編成はフェーズ別でなく原則別**。原則①②③・責任分担・アンチパターンは全ライフサイクルに効く横断原則であり、フェーズに縛らない。
5. **スコープは build スライス（Discovery→Delivery）と明示**。ライフサイクル全体の広さの SoT は `docs/big-picture.md` が持つため、再記述せずリンクで委譲する。

## Consequences

**得られた利益**:

- 構造・操作・根拠の責務が分離され、各層が単一の SoT を持つ。構造ドリフトの温床（同一事実の二重保持）が解消される。
- 本 repo に欠けていた Explanation ジャンルが埋まり、Diátaxis 4類型（Explanation / Reference / How-to / 原子的決定）の役割分担が明示される。

**受容したトレードオフ**:

- 根拠層に固有ホームが無いため、完全削除（案B）ではなく縮退（案A）に留める。根拠ハブという新ジャンルの維持コストを受容する。
- 操作層の移転先が複数文書に分散するため、移転時のアンカー張替え・参照整合の手間が一度だけ発生する（#221 Phase 2/3 で吸収）。

**将来の留保事項**:

- 未実装フェーズ（リリース・運用・観測）の方法論は、支えるスキルも Design-Level モデルも無いため書き起こさない。広さは big-picture に委ねる。
- リネーム（`workflow-design.md` → `principles.md`）は #221 Phase 3 で実施。それまでインバウンド参照は旧名のまま。

## 関連ADR

- Amends: ADR-20260402-workflow-design-v2-structure（責務定義 facet を改訂。構造・操作・根拠を集約した設計図 → Explanation 根拠ハブへ。残り5決定は有効）
- Related: ADR-20260513-workflow-design-scope-team（スコープ・チーム規模方針）、ADR-20260531-superpowers-delegation-boundary（Delivery 散文の接続契約化・スキル委譲）

関連Issue: #221（workflow-design.md 縮退・再編本体）
