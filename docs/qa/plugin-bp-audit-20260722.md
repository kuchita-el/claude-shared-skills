# プラグイン監査レポート: スキル/プラグイン ベストプラクティス準拠（2026-07-22）

3プラグイン（dev-workflow / adr / growth）の全12スキル・6サブエージェント・hooks・scripts・マニフェストを、2026年7月時点の公式ベストプラクティスとリポジトリ自主規律（CLAUDE.md「スキル設計の token 規律」）に照らして監査した結果。

- 監査方法: 公式ドキュメント7ソース＋公式マーケットプレイス実装2件から監査基準を作成し、4系統の並列監査（読み取り専用）を実施。主要指摘6件はメインセッションで抜き取り再検証済み（文末「検証メモ」）
- 行数・文字数はすべて `wc` / Python によるコマンド実測値
- 併せて作成したモデル振り分け指針: `docs/references/model-characteristics.md`

## 監査基準の出典

| キー | 出典 |
|---|---|
| [S1] | code.claude.com/docs/en/skills |
| [S2] | code.claude.com/docs/en/plugins |
| [S3] | code.claude.com/docs/en/plugins-reference |
| [S4] | code.claude.com/docs/en/plugin-marketplaces |
| [S5] | code.claude.com/docs/en/sub-agents |
| [S6] | code.claude.com/docs/en/hooks |
| [S7] | platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices |
| [L1] | 公式プラグイン skill-creator の SKILL.md |
| [L2] | superpowers writing-skills の SKILL.md（サードパーティ。[S7]と一部立場が異なる点は両論併記で扱った） |

## 総括

指摘は計 **50件**（High 14 / Medium 22 / Low 14）。良好な点も多く、特に adr プラグインの hooks 実装（exit code 運用が公式仕様に正確整合、fail-open を作らない設計、テスト 86/86 パス）と、dev-workflow エージェントの model 配分（#317 実機評価の裏付けあり）は模範的だった。改善点は個別バグより**横断的な運用規律の欠落**（目次・バージョン・CI・参照結線）に集中している。

## 横断的所見（優先度順）

### A. `${CLAUDE_PLUGIN_ROOT}` のスキル本文内展開に疑義【High・要検証】

dev-workflow 中核4スキルの共有参照 10箇所（DoR定義・種別プロファイル・plan保存先解決・完了判定）と growth の 21箇所が `${CLAUDE_PLUGIN_ROOT}/references/*.md` を Read 対象パスに使っている。一方、一次情報間で記載が割れている:

- [S3] の環境変数節はスキル/エージェント本文での展開を記載
- [S1] の string substitution 一覧には `${CLAUDE_PLUGIN_ROOT}` が**掲載されていない**（`${CLAUDE_SKILL_DIR}` / `${CLAUDE_PROJECT_DIR}` 等のみ）
- 本リポジトリの adr プラグイン抽出時（PR #546）に「空展開で黙って壊れる」実害が発生し `${CLAUDE_SKILL_DIR}/../../` 方式へ修正した前例がある

**対応**: 実機検証で展開可否を確定し、破損が確認されたら adr の修正実績に倣い `${CLAUDE_SKILL_DIR}` 相対へ置換する。全プラグインに波及するため最優先の検証項目。（DWC-01, DWC-14）

### B. 100行超の参照ファイル 25件に目次がない【High】

[S7] は100行超の参照ファイルへの目次設置を求める。現状:

- dev-workflow: 10件（最大 `domain-model-notation.md` 547行 — 500行の公式ハード目安も超過）
- growth: 15件（最大 `distill-examples.md` 821行、`DESIGN.md` 360行、`personal-store-spec.md` 358行）
- adr: 0件（`transitions.md` 148行は目次あり。**リポ内の模範例**）

部分読み（head等）時に後半セクションを読み落とすリスクが実在する（例: distill-examples.md の例E〜Gは470行目以降）。300行超の5ファイルを優先して目次を追加する。（DWC-02, DWR-02〜05, DWR-30, GRW-05）

### C. SKILL.md から到達できない孫参照 3件【High】

[S7] は「参照はSKILL.mdから1階層のみ、孫参照禁止」と明示する。確定3件:

1. `plan-issue`: SKILL.md → `agent-prompt-construction.md` → `plan-prompt.md`（199行・目次なしの二重ヒット）（DWC-10）
2. `implementation`: SKILL.md → `phase0-input-detection.md` → `plan-location-resolution.md`（`${CLAUDE_PLUGIN_ROOT}` 使用で所見Aとも重複）（DWC-14）
3. `event-storming`: SKILL.md → 各flowファイル**末尾**（149/151行目、172/173行目）→ テンプレート2件。部分読みでテンプレート未適用出力になるリスクが高い（DWR-06）

いずれも SKILL.md 本体への直接参照追加で解消できる。domain-modeling は両参照を1階層で直接リンクしており模範。

### D. plugin.json のバージョン運用が3プラグインとも機能していない【High】

[S3] の警告どおり「version を上げない限り新コミットが配布されない」罠が実際に発生している:

- **dev-workflow**: commit `e5b50aa`（plan-reviewer/test-spec-validator の opus 化）が version 0.7.0 のまま。同29分前の commit `36b6626` 自身が「モデル変更＝MINOR」と宣言しており、自己規律に違反した状態（DWR-26）
- **growth**: DESIGN.md 自身が「Phase N 完了 → 0.N.0」と定義し、Phase 2 相当の intake スキルが実装済みなのに 0.1.0 のまま（GRW-09）
- **adr**: 0.1.0 のまま2コミット経過（ADR-05）

加えて `.github/workflows/` が存在せず `claude plugin validate --strict` を含む CI 検証が皆無（DWR-27）。version bump 漏れ・マニフェスト型不整合を機械検出できない。**dev-workflow の 0.8.0 bump と CI 導入をセットで行うのが本命の対処**。3プラグインとも author/license/keywords 等の推奨メタデータも未設定（DWR-25, ADR-06, GRW-10 — リポ全体方針として一括判断が妥当）。

### E. description 規律の逸脱【High 1件＋soft超過多数】

- **ハード違反**: `distill` 353字（上限300字超過。手順8段をほぼ全て要約しており、[L2]が警告する「本文を読まず description で短絡する」リスクも高い構成）（GRW-01, GRW-03）
- 上限内だが目安200字を大きく超過: `manage-adr` 293字（ADR-01）、`intake` 263字、`dependency-check` 248字、`implementation` 238字（DWC-16）
- `implementation` はトリガー語句7個で規律の「3〜5個」を超過（DWC-15）。3〜5個へ絞れば文字数も自然に圧縮できる
- 模範例: `plan-issue` 178字・トリガー5個（DWC-11で確認）

### F. モデル/effort 運用のドキュメント齟齬と未整備【High 1件】

- **確定した記載矛盾**: `plan-issue` SKILL.md:117 と `agent-prompt-construction.md`:59,79 が「モデルは定義の `inherit` に従う」と記すが、実際の `plan.md` / `plan-reviewer.md` は `model: opus` 固定（メインセッションで grep 再検証済み）。保守者がコスト試算・モデル変更判断を誤る実害がある（DWC-08）
- 6エージェント全てに `effort` 未指定。検証系（code-reviewer 等）の厳密さが親セッションの effort 設定に依存する。`effort: high` 明示を検討（DWR-15）
- `plan` エージェントのみ #317 実機評価の対象外で opus 設定の裏付けがない（DWR-14）
- `refine-issue` は全件モード `sonnet` 固定・1件モード inherit と方針が非一貫（意図なら理由を本文に明記）（DWC-06）
- 6エージェント全てに `tools:` frontmatter がなく、本文の「読み取り専用」宣言が構造的に強制されていない。**既存 Issue #508 で追跡中**（DWR-13）

## プラグイン別の主要指摘（横断所見に含まれないもの）

### dev-workflow

| ID | 重要度 | 対象 | 指摘 |
|---|---|---|---|
| DWR-32 | High | `references/workflow-patterns.md` | 「スキルが実行時に参照するため」と自称するがどの SKILL.md からも参照されない孤立ファイル（grep 再検証済み）。結線・位置づけ明記・削除のいずれかの判断が必要 |
| DWC-09/13 | Medium | plan-issue 187行 / implementation 178行 | 170行目安超過。plan-issue は「人間レビュー却下後のリカバリ」節（43行）が切り出し候補 |
| DWC-05 | Medium | refine-issue allowed-tools | Bashパターンがハンドロール glob で本文の `${CLAUDE_SKILL_DIR}` と不一致。公式推奨の同一変数指定へ揃える |
| DWC-12 | Medium | implementation allowed-tools | カテゴリ見出しコメント4件が CLAUDE.md の「カテゴリ別コメントの羅列を避け」と字面上矛盾（git 履歴精査の結果、PR #299 の実態は「見出し短縮」であり全廃ではなかった。CLAUDE.md 側の文言修正か見出し撤去かの判断が必要） |
| DWR-20 | Medium | hooks.json | timeout 未指定（明示推奨） |
| DWR-33 | Low | `references/context-budget.md` | 設計時規約であることが冒頭から読み取れない（workflow-patterns との位置づけ差を明記推奨） |
| DWC-04, DWR-11, DWR-16, DWR-21, DWR-23, DWR-29 | Low | — | 詳細は原監査参照（create-issue 検証節の Skill 未許可、dependency-check 命名、color フィールド要検証、run-hook.cmd シバン、session-start の環境変数活用、marketplace description） |

### adr

| ID | 重要度 | 対象 | 指摘 |
|---|---|---|---|
| ADR-04 | High（要検証） | `scripts/lint-adr.sh:380,384` | `declare -A` が bash 4.0+ を要求（grep 再検証済み）。macOS 既定 bash 3.2 では lint が起動失敗し、commit ゲートが fail-closed のため**全コミットが無条件ブロックされうる**。`BASH_VERSINFO` ガード＋要件明記か bash 3.2 互換化を推奨（実機 3.2 での再現は未実施） |
| ADR-09 | Medium | transitions.md ほか | 決定的操作（front-matter 遷移・相互参照追記）が非スクリプト化。特に「旧ADR本文への `Superseded by:` 行追記」は lint の検査対象外という既知の盲点が自己文書化されており、この定型書き込みだけでもスクリプト化する価値が高い |
| ADR-03 | Medium（要検証） | `references/template.md:44` | 「保留した決定」節の“運用規約”の指し先が不明（自己言及か未作成文書か判別不能） |
| ADR-02, ADR-07, ADR-08 | Low | — | Grep 許可の使用箇所不記載 / hooks timeout 未指定 / shell形式採用は意図的設計と確認（指摘ではなく記録） |

良好点: exit code 運用（Exit 2 のみブロック）が公式仕様に正確整合、jq 不在時も fail-open を作らないフォールバック、voodoo constants なし、`LC_ALL=C sort` 等の可搬設計、テスト 86/86 パス（実行確認済み）。

### growth

| ID | 重要度 | 対象 | 指摘 |
|---|---|---|---|
| GRW-07 | High | `references/career-promotion-spec.md`（168行） | どのファイルからも参照されない**完全な孤立ファイル**（grep 再検証済み）。#532 で更新された生きた仕様書なのに、ファイル名を知らない限り到達不能。DESIGN.md Distribute 段・姉妹規約 learning-promotion-spec からの導線追加を推奨 |
| GRW-04 | Medium | `capture/SKILL.md`（206行） | 唯一の170行超過。他3スキルの procedure/examples 分離パターン未踏襲。記述例 約54行を `references/` へ抽出すれば170行前後に収まる |
| GRW-11 | Medium | `DESIGN.md`（360行） | 内部設計文書が配布物ルートに同居。リポ慣習（設計文書は `docs/` 配下）からの逸脱で、`docs/development/` への移動を検討（実行時 Read 対象でないことは確認済み、移動してもスキル動作に影響なし） |
| GRW-08 | Medium（要検証） | `*-procedure.md` | 地の文引用による実質2ホップ参照。実行時に誤読が起きるかドッグフーディングでの確認を推奨 |
| GRW-06 | Medium | `distill-examples.md`（821行） | 分岐網羅のテストケース集として機能しており分割は必須でないが、目次追加は最優先（所見B） |
| GRW-12, GRW-13 | Low | — | capture のみ `## 関連` 節がない / learnings.md の役割説明の導線 |

良好点: allowed-tools が4スキルとも使用箇所と1対1で過不足なし、ハードコードパスなし（project-id 動的解決で配布先でも成立）、仕様の単一出典化が徹底され重複定義なし、[L2] のナラティブ実例アンチパターン該当なし。

## 推奨対応順

1. **要検証2件の決着**（所見A の `${CLAUDE_PLUGIN_ROOT}` 実機検証、ADR-04 の bash 3.2 確認）— 修正方針が事実に依存するため最初に
2. **機械的に直せる High**: DWC-08 の記載修正、孫参照3件の結線（所見C）、GRW-07 の導線追加、GRW-01 の description 圧縮、300行超5ファイルへの目次追加
3. **バージョンと CI**（所見D）: dev-workflow 0.8.0 bump、adr/growth の version 方針決定、`.github/workflows/` に `claude plugin validate --strict` ＋ version bump チェック導入 — 再発防止の本命
4. **設計判断を要するもの**（下記「判断待ち項目」）
5. **Low 群**: 対応任意。次回改修時に同時対応で足りる

## 判断待ち項目（ユーザー裁定が必要）

- DWC-12: CLAUDE.md の「カテゴリ別コメント」文言を実態に合わせるか、implementation の見出しコメントを撤去するか
- DWR-32: workflow-patterns.md を結線するか、設計中と明記するか、docs/ へ降格・削除するか
- GRW-09: growth version を 0.2.0 へ上げるか、DESIGN.md ロードマップ側に現状ステータスを明記するか
- GRW-11: DESIGN.md を `docs/development/` へ移動するか
- DWR-15: 検証系エージェントへの `effort: high` 明示（予防的提案。品質低下の実測証跡はない）
- DWC-06: refine-issue 1件モードのモデル方針（sonnet に揃えるか、inherit の意図を明記するか）
- 3プラグイン共通の plugin.json メタデータ（author/license/keywords）拡充方針
- description 設計の流儀: [S7]「何を＋いつ」併記型（現行）を維持するか、[L2] のトリガー限定型を距離を置いて参考にするか（現行維持が無難。GRW-03 参照）

## 検証メモ

監査エージェントの主要主張のうち以下6件をメインセッションで独立に再検証し、全件一致を確認した:

1. 6エージェントの `model:` 実値（opus×5 / sonnet×1）と plan-issue 側「inherit に従う」記載の矛盾（DWC-08）
2. `workflow-patterns.md` が全 SKILL.md から未参照（DWR-32）
3. `plan-prompt.md` が plan-issue SKILL.md から直接参照ゼロ＝孫参照（DWC-10）
4. `lint-adr.sh:380,384` の `declare -A`（ADR-04）
5. `career-promotion-spec` の被参照ゼロ（GRW-07）
6. distill description の300字超過（GRW-01）

また DWR-13（tools 未宣言）は既存 Issue #508、DWR-26（version 据え置き）は commit `36b6626`/`e5b50aa` の git 履歴、DWR-14（model 配分の経験的裏付け）は #317 評価記録と、それぞれ監査エージェントが一次情報で突き合わせ済み。
