---
status: 承認済み
validity: 有効
superseded-by:
---

# ADR-20260723: ADR運用機構を独立プラグイン adr として抽出・配布

## Context

ADR運用機構（drift-lint `lint-adr.sh`・index生成器 `gen-adr-index.sh`・commit ゲート・`manage-adr` スキル一式・front-matter スキーマ）は、当初 dev-workflow プラグインおよび repo ルートの `scripts/` に同居していた。しかし ADR は dev-workflow 固有の機能ではなく、dev-workflow と growth の双方が消費する横断基盤である。特定プラグインに属させたままにすると、消費側の増加や別リポジトリでの再利用時に結合が障害になる。

#463 ファミリで内部運用（状態2軸 `status`/`validity` モデル＝ADR-20260711-3、ライフサイクル操作スキル `manage-adr`）を確定したのち、この機構を任意のリポジトリで単独導入可能にする要求が生じた（別リポでの ADR 運用試用＝#492）。

段階の順序については、プラグイン化を先に設計するとレイヤ上書き（プラグイン default / プロジェクト override）の継ぎ目を推測で決めて外すため、「内部運用の確定 → 別リポ試用による継ぎ目の実測 → プラグイン抽出」の順に精緻化した（#463 の再枠付け。当初コメントの「プラグイン即抽出」を上書き）。抽出骨格は試用に先行して #492 の PR #546 で front-load 実施した。

ADR化シグナル: dev-workflow 同梱案（案2）を検討し、関心が異なること（開発ワークフロー基盤 vs 横断的 ADR 基盤）と可搬性の要求から却下し、独立プラグイン案（案1）を採用した。先例として、growth を同種の理由（関心分離＋常時ロード分離）で独立プラグイン化した ADR-20260626 がある。本決定はその判断を ADR 運用ルールの粒度判定（後戻りコスト高 / 複数モジュール波及 / 採用理由揮発 / ツール自動強制不可）に照らし4項目該当＝ADR級と評価したものである。

## Decision

ADR運用機構を dev-workflow から分離し、独立プラグイン `plugins/adr/` として抽出・配布する。

1. **配布単位**: marketplace カタログに dev-workflow・growth とは別エントリ（`source: ./plugins/adr`）として登録し、単独で導入・無効化できる配布単位とする。
2. **可搬アーティファクトの集約**: `lint-adr.sh` / `gen-adr-index.sh` / テスト / fixtures / `manage-adr` スキル一式 / commit ゲート hook を `plugins/adr/` 配下へ集約する。スクリプト2本は `$(dirname "$0")` 相互解決のため同居させる。
3. **ゲートのプラグイン同梱**: drift-lint ゲートを同梱の PreToolUse hook（`adr-commit-gate`）として配送し、導入先の `docs/adr`（`ADR_DIR` 可変、既定 `docs/adr`）を検査する。ADR 無関係の検査（`validate-skills`）は巻き込まない。`docs/adr` 不在の host では no-op で通す。
4. **消費側としての dogfood**: 本リポジトリ自身も消費側の一つとして、`.claude/settings.json` の `enabledPlugins` 登録で adr プラグインを常時有効化し、自らの `docs/adr` を dogfood する。
5. **既存 ADR 実体は非搭載**: 既存の ADR ファイルはプラグインに乗せない。各リポジトリが自分の `docs/adr` を育て、プラグインは運用機構のみを配送する。

理由: (1) **関心の分離** — ADR は横断基盤であり dev-workflow の一部ではない。(2) **可搬性** — 任意のリポジトリで単独導入できることが別リポ試用（#492）・横断的再利用の前提である。(3) **常時ロードの分離** — `manage-adr` の description を、ADR を使わない dev-workflow 利用者のセッションに常時加算しない（ADR-20260626 と同じコンテキスト効率の論拠）。

## Consequences

- **得られる利益**: ADR 機構が dev-workflow のリリースサイクルから独立し、任意リポジトリへ単独導入できる。dev-workflow / growth のいずれも消費側として疎結合に依存できる。`manage-adr` の description が ADR 不使用の dev-workflow 利用者に常時加算されない。
- **受容したコスト**: プラグインが3個体制（dev-workflow / growth / adr）になり、marketplace エントリ・バージョニング・配布の管理対象が増える。ADR を使う利用者は adr プラグインの導入（`enabledPlugins` 登録または `setup-local.sh`）が要る。commit ゲートをプラグイン hook 化したため、導入形態（`--plugin-dir` / marketplace / `enabledPlugins`）ごとの発火挙動を導入先で確認する必要がある（本リポでは `enabledPlugins` 経由の通常セッションでゲート発火を実地確認済み＝#493）。
- **段階順序に伴う留保**: 抽出骨格は試用に先行して front-load した（#492 PR #546）。プラグイン default / プロジェクト override のレイヤ上書き境界は、別リポ試用（#492）で得る継ぎ目リスト（`docs/development/adr-plugin-portability-seams.md`）の実測を入力に #548 で設計する。本 ADR は抽出・配布の戦略決定のみを記録し、レイヤ上書きの具体設計は #548 の後続 ADR 候補とする（独立に反転しうる core を束ねない＝ADR-20260711-3 決定3）。

## 保留した決定

- レイヤ上書き（プラグイン default / プロジェクト override）の境界と override 機構の具体設計（想定継承先: #548）。本 ADR は「独立プラグインとして抽出・配布する」という戦略決定に射程を限り、override の設計は #492 の継ぎ目リスト実測を入力に別途決める。

## 関連ADR

- Related: ADR-20260626-growth-plugin-separation（横断／メタ機構を独立プラグインへ分離する同型の先例。関心分離＋常時ロード分離の論拠を共有）
- Related: ADR-20260711-3-adr-two-axis-status-validity-model（本機構が配送する ADR 運用モデルの正本。決定5 の drift-lint 配置が本抽出で `plugins/adr/` へ移設され、PR #546 で非core amend 済み）
- 関連Issue: #463, #492, #493, #548
