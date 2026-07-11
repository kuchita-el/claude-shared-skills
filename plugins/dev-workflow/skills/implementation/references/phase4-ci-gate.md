# Phase 4: CI ゲート付き Draft→Ready 完了フロー（詳細手順）

Phase 4（S6）で PR を作成する際の CI ゲート手順の正本。SKILL.md 本体は骨格＋本ファイルへのポインタに留め、詳細分岐は本ファイルに置く。

## Draft/Ready の位置づけ（feedback 整合）

PR は既定で **Draft** として作成し、CI が緑になってから **Ready** 化する。この Draft 既定は一律ルールではなく、**コンテンツ状態に基づく判断**である:

- **Draft** ＝ CI 未検証で、まだレビュー可能とは言えないコンテンツ状態。
- **Ready** ＝ CI 緑で、レビューに出せるコンテンツ状態。

これはユーザーフィードバック「Draft/Ready はコンテンツ状態で判断する（一律 Draft 禁止）」の趣旨と矛盾しない。むしろ「CI 未検証」という具体的なコンテンツ状態を Draft の根拠として明示することで、その趣旨を具体化している。コンテンツ自体が WIP（依存論点未解消・仕様確定前）のケースは Phase 4 到達前の収束ゲート／エスカレーションで既に分岐しており、Phase 4 に到達した時点で残る未検証項目は CI である。

## 責務分界（finishing-a-development-branch との関係）

PR の新規作成（Draft）は `superpowers:finishing-a-development-branch` への委譲に含めてよい。ただし **CI ゲート → Ready 化 → レビュー依頼は委譲先の範囲外**とし、常に dev-workflow 固有の上乗せ層として本手順が担う。委譲先が draft 指定の入口を持たない場合は、dev-workflow 側が直接 `gh pr create --draft` を実行するフォールバックを取る（「非導入時は最小インライン」への縮退と同じ構造）。委譲先の merge/cleanup 選択提示は Ready 化後に接続する。

## 手順

### 1. Draft で PR 作成

PR 未作成なら Draft で新規作成する:

```bash
gh pr create --draft --title "<title>" --body-file <path>
```

PR 本文には Phase 4 のセルフレビュー結果サマリを上乗せする（本文テンプレートは SKILL.md 側で指す。本ファイルからは他の references を直接参照せず、両者の関係は SKILL.md 側でのみ並列に指し示して参照の深さ 1 段を保つ）。

### 2. CI 未設定の判定（猶予付き再ポーリング）

`--watch` を回す前に、まず非 watch の `gh pr checks --required` で required check の有無を判定する。ただし **一撃判定は「CI 設定済みだが check run が未登録」と「CI 未設定」を区別できない**: GitHub Actions の `on: pull_request` 等は PR 作成から check run が commit に登録されるまで数秒のラグがあり、その間は CI ありのリポジトリでも「no checks reported」（exit 1）を返す。作成直後の一撃で「未設定」と断じると、待機を飛ばして即 Ready 化し **CI ゲート（AC2）が黙って無効化**される。また `--watch` に 0 件のチェックを渡した際の挙動（即終端かハングか）も未検証なので、待機前にここで有無を確定させる。

そこで **猶予付き再ポーリング**で判定する:

```bash
# 数秒間隔で最大 N 回問い合わせる（猶予窓 ~60 秒目安）
gh pr checks <pr> --required   # 非 watch・同期。1 回問い合わせて即返る
```

- いずれかの回で check run が出現（pending / pass / fail のいずれか）→ 3. の `--watch` 待機へ進む。
- 猶予窓を通じて「no checks reported」/「no required checks reported」（exit 1）のまま → CI 未設定と確定し、即 `gh pr ready <pr>` で Ready 化 → 完了報告（AC5）。

> 猶予窓・間隔は run 登録ラグに対するヒューリスティックであり確定的ではない。極端に登録が遅い CI では取りこぼしうるため、値はリポジトリの CI 特性に合わせて調整する。branch protection 設定を直接照会（`gh api .../branches/{branch}/protection/required_status_checks` 等）すれば確定判定できるが、保護設定の読取権限と classic/ruleset 両対応が必要になるため、移植性（`gh` のみ依存）を優先して本ヒューリスティックを既定とする。

### 3. CI 結審の待機（run_in_background ＋ --watch）

required check が存在する場合、CI の完了を **バックグラウンド Bash** で待つ:

```bash
gh pr checks <pr> --watch --required   # run_in_background: true で起動
```

`run_in_background` で起動する理由（採用方式）:

- **バックグラウンド `--watch`（採用）**: プロセスはターンをまたいで detached で走り続け、CI 結審（プロセス exit）で自動的にエージェントが再起動される。exit code をそのまま分岐に使える。Bash ツールの実行時間上限（最大 10 分）に縛られず、数十分かかる CI にも耐える。待機中は他作業と並行できる。
- **却下: ブロッキング `--watch`**: Bash の 10 分上限を超える CI で失敗する。壁時間を拘束する。
- **却下: ScheduleWakeup ポーリング**: 毎周のトークンとプロンプトキャッシュ（5分 TTL）を浪費する。exit による正確な完了信号が得られない。

弱点として、この方式はセッションが生存している間のみ機能する（セッション終了で背景プロセスは失われる）。これはエージェント主体方式に共通の制約であり、リポジトリ側 CI 自動化（`gh` のみ依存の移植性原則に反する）以外に回避策はない。

### 4. 結審の exit code による分岐

`--watch` 待機プロセスの終端 exit code で分岐する。**非0 を一律「CI 赤」に流さない**: `gh` の非0 は fail（exit 1）だけでなく、キャンセル（2）・認証（4）・ネットワーク断等も含む（`gh help exit-codes`）。これらを修正ループへ流すと、CI が赤でないのに存在しない失敗を追う空回りに入る。exit 1（実 fail）とそれ以外の非0（判定不能）を分ける:

| 終端 exit code | 意味 | アクション |
|---|---|---|
| 0 | 全 required check pass（緑） | `gh pr ready <pr>` で Ready 化 → レビュー依頼（5.）→ 完了報告 |
| 1 | fail を含む（赤・CI 判定確定） | 失敗ログを収集（下記）→ Phase 1〜3 の自動修正ループへ差し戻し → push → 再度 3. へ |
| 8 | pending（`--watch` 使用時は通常終端では現れない） | 3. の待機を再実行する |
| その他非0（2=cancel / 4=auth / ネットワーク等） | CI 判定不能（gh・環境エラーであり CI 赤ではない） | 修正ループへ流さず、再試行 or 判断依頼へ回す |
| （exit 1 の同一失敗が反復し収束しない） | 収束不能 | エスカレーション機構（SKILL.md『エスカレーション機構』節）へ接続 |

失敗ログの収集（exit 1 のとき）は、対象 PR の HEAD SHA から run-id を取得して行う（run-id を省略すると対話プロンプトが起動しうるため、非対話環境では run-id を明示する）:

```bash
gh run list --commit <sha> --json databaseId,conclusion   # 失敗した run の databaseId を得る
gh run view <run-id> --log-failed
```

> **exit code の典拠と検証状況**: exit 8＝「Checks pending」は `gh pr checks --help`（gh 2.89.0）で確認。pending は `--watch` で解消されるため終端では基本現れない。pass=0／fail=1／その他非0=エラー は gh の一般 exit code 規約（`gh help exit-codes`）に従う。checks が存在する経路（pending 収束後の実 exit code）の実 PR 実証には CI を持つリポジトリが必要である。exit code 対応が実測と食い違う場合は判断依頼として報告し、本表を更新する。

`gh pr ready --undo` で Draft へ差し戻せる（緑化後に問題が判明した場合の手当て）。

### 5. Ready 化後のレビュー依頼

レビュー依頼は **リポジトリ側のルールに従い、無ければ no-op** とする:

- GitHub は Draft→Ready 化時に CODEOWNERS を自動でレビュアーリクエストする。CODEOWNERS が設定されたリポジトリでは追加操作は不要（no-op）。
- リポジトリ固有のレビュアー指定ルールがあればそれに従う。
- ルールが無ければ何もしない（レビュアー自動選定ロジックは新規実装しない。`gh` のみ依存の移植性原則に沿う）。
