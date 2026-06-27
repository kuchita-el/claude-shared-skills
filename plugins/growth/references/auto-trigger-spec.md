# 自発トリガー機構の発火仕様・取得可能データの一次調査（spike #379）

> **位置づけ**: growth Phase 3「capture の自発化」（DESIGN.md 決定事項4・#350）の前提となる一次調査の記録。機構選定（単独/併存）の判定材料を、SessionEnd hook と nightly 系スケジューラについて対称に文書化する。決定そのものは実装時でよい（#379 完了定義）。ディスク上のログ形式は #378（[`session-log-format.md`](session-log-format.md)）が確立済みであり、本書はその「形式」に対する「発火点」を埋める。

## 調査時点・対象バージョン

- **調査日**: 2026-06-28
- **対象**: Claude Code（観測バージョン **2.1.195**）、公式ドキュメント（hooks / routines / desktop-scheduled-tasks、2026-06-28 取得）

> ⚠️ **揮発性の注意**: §3 の SessionEnd payload フィールド名・env 変数は版依存スナップショット（実機 2.1.195 で採取）であり、実装時に再検証する。§4 の機構比較・§5 の判定（適合・非対称性）は形式の細部が変わっても揺らがない恒久判断として扱ってよい。Routines は research preview のため仕様変更がありうる（公式注記）。

---

## 1. 結論：機構選定の判定

**単一セッションの即時捕捉は SessionEnd hook、複数セッション横断の一括解析はローカル実行スケジューラ。両者は競合せず併存させるのが #350 の解析単位（単一＋横断の併存）に直接対応する。ただし横断機構の具体は実行環境で分岐する（GUI 環境＝Desktop scheduled task、CLI/ヘッドレス環境＝OS ネイティブスケジューラから `claude -p` 起動、`/loop` はセッション常時起動できる場合に限る）。**

- **2つの決定的な非対称性**:
  - **実行場所（ローカルファイルアクセス）**: クラウド Routine は **Anthropic 管理のクラウドで実行され、GitHub リポジトリを fresh clone してその中のファイルのみアクセスする。ローカルの `~/.claude/projects/` セッションログにはアクセスできない**（§4・公式明記）。横断ログ解析（決定事項2・#378）はローカルログ読み取りが前提のため、**クラウド Routine は横断解析の機構として不適**。#160 が想定する「nightly Routine 基盤への相乗り」は、growth のログ解析用途にはそのままでは成立しない（§6）。
  - **プラットフォーム可用性（Desktop アプリ前提か）**: Desktop scheduled task は Claude Desktop アプリの機能であり、**Desktop アプリは macOS / Windows のみ。Linux は非対応（公式 desktop.md「The desktop app is not available on Linux; use the CLI instead.」）**。growth の配布先に含まれる CLI 利用者・Linux/WSL 環境（**本リポジトリの開発環境を含む**）では Desktop task が使えない。実行場所の非対称性と同格に決定的。
- **横断解析を満たす機構はローカル実行に限られ、環境で分岐する**（§4）:
  - GUI 環境（macOS/Windows + Desktop アプリ）: **Desktop scheduled task**（ローカル実行・ローカルファイルアクセス可・オープンセッション不要・最小1分間隔）。
  - CLI/ヘッドレス・Linux 環境: **OS ネイティブスケジューラ**（cron / systemd timer / Windows Task Scheduler）から抽出スクリプトまたは `claude -p` を起動する。これはディスク上のローカルログを全 project-id 走査でき、オープンセッション不要。ただし**公式ドキュメントはスケジューリングを3択（Routine / Desktop task / `/loop`）に閉じており OS ネイティブ手段に言及がない**——ユーザー側ラップは技術的に可能だが公式の推奨経路ではない点に留意（§4 補足）。
  - `/loop`: ローカル・全OSだが**オープンセッション必須**。週次の横断バッチを常時セッション起動で回すのは非現実的なため、横断機構としては限定的。
- **SessionEnd hook は単一セッションの軽量トリガーに最適**: 発火時 payload に終了セッションの `session_id` と `transcript_path`（jsonl 絶対パス）を直接含むため、capture が即座に当該セッションを捕捉できる（§3）。ただし side-effect 専用（出力でブロック不可・非同期バックグラウンド実行）であり、重い横断解析を同期実行する機構ではない。SessionEnd hook は CLI（全OS）の機能であり、プラットフォーム非対称性の影響を受けない。

## 2. 後続実装（#350）への前提条件

1. **併存設計**: SessionEnd hook（単一・即時）＋ローカル・スケジューラ（横断・週次）の二系統を併存させる。一方が他方を置換しない。
2. **横断機構はローカル必須・環境で分岐**: 横断解析を担うスケジューラは `~/.claude/projects/` を読めるローカル実行とする。GUI 環境は Desktop scheduled task、CLI/ヘッドレス・Linux 環境は OS ネイティブスケジューラ（cron / systemd timer / Task Scheduler）から `claude -p` ないし抽出スクリプトを起動する。Desktop task は Linux 非対応（§1）のため、本リポジトリのような Linux/WSL 開発環境では OS ネイティブスケジューラが既定解になる。クラウド Routine を採る場合はログを clone 可能な場所へ事前同期する別設計が要る（現時点では非推奨）。
3. **30日ローテに先んじた週次走査**（#378 §2 を継承）: 横断機構は 30 日より十分短い周期（週次程度）で走査し、抽出済みシグナルを個人 store へ永続化する。Desktop task の「最小1分・日次/週次プリセット」はこの周期要件を満たす。
4. **捕捉対象の解決は payload 優先**: capture の session UUID 解決は env（`CLAUDE_CODE_SESSION_ID`）ではなく SessionEnd payload の `session_id` / `transcript_path` を一次ソースとする（§3。capture SKILL.md の `CLAUDE_CODE_CHILD_SESSION` 懸念を解消）。

---

## 3. SessionEnd hook（発火仕様・取得可能データ）

### 3.1 発火契機（公式文書化済み）

- Claude Code セッション終了時に発火。`matcher` で終了理由を区別: `clear`（`/clear`）/ `resume`（一時停止）/ `logout` / `prompt_input_exit` / `bypass_permissions_disabled` / `other`。
- どの reason で capture を発火させるかは実装時に選択（例: 通常終了 `prompt_input_exit` と `other` を対象、`clear`/`resume` の扱いは要検討）。

### 3.2 payload スナップショット（実機 2.1.195・stdin JSON）

`claude -p` 実行で SessionEnd フックを仕込み実採取した payload:

```json
{
  "session_id": "9658f0e1-…",
  "transcript_path": "/home/<user>/.claude/projects/<project-id>/<session-uuid>.jsonl",
  "cwd": "…/worktrees/feature+379-auto-trigger-spec",
  "hook_event_name": "SessionEnd",
  "reason": "other"
}
```

- **`transcript_path`**: 終了セッションの jsonl 絶対パスを直接手渡す。capture の解析対象がそのまま得られる（#378 のパス導出を hook 経由で省略できる）。
- **`session_id`**: ファイル名 UUID と一致。
- **`reason`**: 上記 matcher 値（`-p` 終了は `other`）。

### 3.3 実行時 env（実機 2.1.195・`CLAUDE_*` のみ抜粋）

```
CLAUDE_CODE_SESSION_ID=<session-uuid>   # payload.session_id と一致
CLAUDE_PROJECT_DIR=<cwd>
CLAUDE_CODE_CHILD_SESSION=1              # -p/SDK 起動時に 1（注意点）
CLAUDE_CODE_ENTRYPOINT=sdk-cli
CLAUDE_CODE_EXECPATH=…/versions/2.1.195
```

- `-p`/SDK 経由では `CLAUDE_CODE_CHILD_SESSION=1` が立つ。**env の session 解決は文脈依存で揺れるため、payload の `session_id`/`transcript_path` を優先する**（§2-4）。
- 公式記載の追加 env: `CLAUDE_PLUGIN_ROOT`（プラグイン実行時）、`CLAUDE_CODE_REMOTE`（Web 環境で `true`）。

### 3.4 制約（公式文書化済み）

- **ブロック不可**: exit code 2 は無視され、出力に関わらずセッションは終了する（side-effect 専用＝logging/cleanup/notification）。
- **非同期**: セッションクローズ時にバックグラウンド実行。
- **未文書**: タイムアウト既定値・複数 matcher マッチ時の実行順序は公式に記載なし（実装時に実機確認）。
- → capture の用途（終了セッションの捕捉・個人 store への追記）は side-effect であり制約に抵触しない。重い横断解析を hook 内で同期完結させる設計は避ける。

---

## 4. nightly 系スケジューラの比較

公式が提示する3択（Routine / Desktop task / `/loop`）に、CLI/Linux で横断機構の既定解となる OS ネイティブスケジューラ（公式列挙外）を加えて並べる。

| | クラウド Routine | Desktop scheduled task | `/loop` | OS ネイティブ（cron 等）＋`claude -p` |
|---|---|---|---|---|
| 実行場所 | Anthropic クラウド | ローカルマシン | ローカルマシン | ローカルマシン |
| **プラットフォーム可用性** | OS 非依存（クラウド） | **macOS / Windows のみ（Linux 不可）** | CLI 全OS | CLI 全OS（OS のスケジューラに依存） |
| マシン起動要 | 不要 | 要 | 要 | 要 |
| オープンセッション要 | 不要 | 不要 | **要** | 不要 |
| 再起動跨ぎ永続 | 永続 | 永続 | `--resume` で復元（未期限） | 永続（OS スケジューラ管理） |
| **ローカルファイルアクセス** | **不可（fresh clone）** | **可** | **可** | **可** |
| 最小間隔 | 1 時間 | 1 分 | 1 分 | OS 依存（実質無制限） |
| 日次 cap | per-account（recurring が対象。one-off は対象外） | 通常の subscription 使用量 | 同左 | `claude -p` 起動分の subscription 使用量 |
| 公式サポート | あり | あり | あり | **なし（ユーザー側ラップ）** |

出典: 公式 `routines` / `desktop-scheduled-tasks` / `desktop`。OS ネイティブ列は公式ドキュメント未言及であり、`claude -p` を cron 等から起動する構成（本書 §3 の payload 採取も `claude -p` 経由で実行）をユーザー側で組む前提。Desktop task は worktree トグルで各実行を隔離 worktree で走らせられる（#378 のサブエージェントログ含む走査と相性良）が Linux では使えない。

---

## 5. #350「自発化の設計軸」3軸への適合 ＋ 非対称性マトリクス

### 5.1 解析単位軸への適合

| 解析単位（#350 確定） | 適合機構 | 理由 |
|---|---|---|
| 単一セッション内の確認（即時） | **SessionEnd hook**（CLI 全OS） | 終了時に当該セッションの transcript_path を手渡し。軽量・即時。 |
| 複数セッション横断の一括確認（週次） | GUI 環境＝**Desktop scheduled task** / CLI・Linux 環境＝**OS ネイティブスケジューラ（cron 等）＋`claude -p`**（`/loop` はセッション常時起動できる場合に限る） | ローカル全 project-id 走査が可能。30日ローテ前の週次走査要件を満たす。具体機構はプラットフォーム可用性で分岐（§5.2）。 |

### 5.2 非対称性マトリクス（機構選定の判定基準）

| 観点 | SessionEnd hook | Desktop task | OS ネイティブ＋`claude -p` | クラウド Routine |
|---|---|---|---|---|
| 即時性 | 高（終了直後） | 低（次スケジュール） | 低（次スケジュール） | 低 |
| **プラットフォーム可用性** | CLI 全OS | **macOS/Win のみ（Linux 不可）** | CLI 全OS | OS 非依存 |
| ローカル `~/.claude/projects/` アクセス | 可（payload で直渡し） | 可 | 可 | **不可** |
| オープンセッション依存 | セッション稼働時 | 不要 | 不要 | 不要 |
| コスト課金 | hook 実行のみ（API課金なし） | subscription 使用量 | `claude -p` 起動分 | recurring は per-account cap |
| 実装複雑度 | 低（side-effect スクリプト） | 中（Desktop UI/タスク定義） | 中（OS スケジューラ設定・公式外） | 中（環境・clone 前提） |
| マシン起動依存 | セッション稼働時のみ | 要（睡眠中はスキップ/catch-up） | 要（マシン稼働時） | 不要 |
| 横断解析適性 | 不適（単一のみ） | **適**（GUI 環境のみ） | **適**（CLI/Linux の既定解） | 不適（ローカル不可） |
| 公式サポート | あり | あり | **なし（ユーザー側ラップ）** | あり |

### 5.3 UX軸・機構軸

- UX軸（ライブ相乗りの適否）は #381 の担当であり本 spike の範囲外。SessionEnd hook は「終了後」発火のためライブ相乗り問題を回避する（セッション稼働を妨げない）。
- 機構軸は #350 方針どおり本書では固定せず、上記判定基準と適合範囲の提示に止める（決定は実装時）。

---

## 6. #160 相乗り可否の評価

#160 は「Routines ベース nightly grooming」を採用アーキテクチャとするが、その Routines が**クラウド Routine**を指す場合、growth のログ横断解析（ローカル `~/.claude/projects/` 読み取り）には**ローカルファイルアクセス不可のため相乗りできない**。#160 の対象（issue tracker / リポジトリ操作）はクラウドで完結するため Routine が適合するが、growth のログ解析とは実行環境要件が異なる。したがって両者の nightly 基盤は共有できず、**growth 側はローカル実行スケジューラを独自に採るのが妥当**（GUI 環境＝Desktop scheduled task、CLI/Linux 環境＝OS ネイティブスケジューラ＋`claude -p`。§4・§5.2）。重複回避の担当範囲整理（#350 関連メモ）は、この実行環境・プラットフォームの差を前提に行う。

---

## 関連

- 親エピック: #350（growth Phase 3）／本 spike: #379／隣接 spike: #378（ログ形式）・#380（活性化モデル）・#381（ライブ相乗り UX）
- 隣接: #160（Routines ベース nightly grooming。本書 §6 で相乗り不可と評価）
- DESIGN.md 決定事項2（取得手段＝事後解析主軸）・決定事項4（capture 自発化）・「実装時に一次確認する事項」
- 形式の一次調査: [`session-log-format.md`](session-log-format.md)（#378）
