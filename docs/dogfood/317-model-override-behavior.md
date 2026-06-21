# Issue #317 `model: inherit` 解除時のユーザー側オーバーライド挙動 調査記録

AC4「`model: inherit` を解除した場合のユーザー側オーバーライド挙動（メインセッションでモデルを切り替えても継承されないか、許可リストはどう作用するか等）の事前調査」の一次資料。

## 調査範囲

`plugins/dev-workflow/agents/*.md` のフロントマター `model` を `inherit` 以外（`sonnet` / `opus` / `haiku`）に変更したとき、次の挙動がどうなるか。

1. メインセッションのモデル（`/model` で切り替え可能）の値が、サブエージェントの実行モデルに継承されるか／されないか。
2. ユーザーがサブエージェントの実行モデルを別の値で上書き（オーバーライド）できる機構が存在するか（許可リスト等）。
3. オーバーライドを無効化／許可するコンフィグ（`settings.json` 等）が存在するか。

## 一次情報の所在

公式 plugin-dev プラグインの `agent-development` スキルが、`model` フロントマターの一次仕様を提供する。

- 場所: `/home/kuchita/.claude/plugins/marketplaces/claude-plugins-official/plugins/plugin-dev/skills/agent-development/SKILL.md`
- 該当行: L95–L105、L340

## 公式仕様（SKILL.md 抜粋）

```
### model (required)

Which model the agent should use.

**Options:**
- `inherit` - Use same model as parent (recommended)
- `sonnet` - Claude Sonnet (balanced)
- `opus` - Claude Opus (most capable, expensive)
- `haiku` - Claude Haiku (fast, cheap)

**Recommendation:** Use `inherit` unless agent needs specific model capabilities.
```

フィールド表（L340）:

```
| model | Yes | inherit/sonnet/opus/haiku | inherit |
```

## 仕様読解と挙動推定

### `inherit` の挙動

「Use same model as parent」と明記。親（メインセッション、または上位サブエージェント）のモデルを継承する。メインセッションを Opus → Sonnet → Haiku に切り替えると、`inherit` を指定したサブエージェントの実行モデルも追随する。

### `sonnet` / `opus` / `haiku` 明示指定の挙動

SKILL.md には「明示指定時のユーザー上書き挙動」を直接記述する箇所は見当たらない。ただし、`inherit` を「親と同じモデル」と説明している裏返しとして、明示指定値は親モデルから独立して固定されると読むのが自然。すなわち、メインセッションを `/model` で切り替えても、サブエージェントは指定値（例: `sonnet`）を保持する、と推定される。

### ユーザーオーバーライド機構の有無

公式 SKILL.md にはユーザーオーバーライド（許可リスト、設定上書き、CLI フラグ等）の機構は記述されていない。`agent-development` の references（`agent-creation-system-prompt.md`、`system-prompt-design.md`、`triggering-examples.md`）にも model 上書きの記述は見当たらない。

判断: 一次情報として「ユーザーが明示指定値を上書きする公式機構は存在しない、または公式ドキュメントには記述されていない」と結論する。

### `settings.json` でのオーバーライドコンフィグ

`settings.json` 側に `agentModelOverride` 等の明示的なオーバーライド機構があるかは、公式ドキュメントの一次情報を本セッションでは確認できなかった。仮定: なし（あれば agent-development スキルの「Field Reference」表で言及されるはず）。後続実機検証で `settings.json` の存在しないキーを試して挙動を観察するか、公式リファレンスを当たる。

## 矛盾点・不確実性

- 「明示指定時の挙動」が公式 SKILL.md に直接明文化されていないため、本調査は仕様読解の推論を含む。後続実機検証（メインセッションを切り替えてサブエージェント実行モデルを観察）で確定する必要がある。
- `agent-development` の references を全文 Read していない（model 関連は SKILL.md 本体に集約されている前提）。references 側で関連記述が見つかった場合は本ファイルを更新する。

## 本 Issue での反映方針

**未検証の前提**: 以下は SKILL.md の仕様読解に基づく推論であり、後続実機検証で覆る可能性がある。本 Issue では仕様読解の推論を採用するが、実機検証で異なる挙動が観察された場合は「巻き戻し条件」節の手順に従って `model` 値を `inherit` に戻す。

文書ベース推論で得た以下を前提として採用する。

1. `model: sonnet` を明示指定したエージェントは、メインセッションのモデル切り替えに連動せず Sonnet で固定動作する。
2. ユーザーが明示指定値を上書きする公式機構は存在しない（または未文書化）。
3. ユーザーが特定エージェントを Opus で動かしたい場合は、当該エージェント定義の `model` を変更する PR を出すことになる。

この前提は本 Issue の `model` 値選定（5 件 sonnet 固定、1 件 opus 固定）と整合する。

## 後続実機検証の計画

本ファイル末尾に「実機検証ログ」セクションを後追記する。検証手順:

1. 暫定的に 1 エージェント（例: `code-reviewer`）の `model` を `sonnet` に変更（本 Issue で実施済の状態）。
2. メインセッションを `/model opus` で起動し、`Agent` ツールで `subagent_type: dev-workflow:code-reviewer` を呼ぶ。
3. メインセッションを `/model sonnet` に切り替えた状態で同じ呼び出しを行い、両者の実行モデル（出力速度・コスト指標から推定）を比較。
4. 結果を本ファイルに追記し、推定（メインセッション切り替えに連動しない）が当たっているか確認。

矛盾する挙動が観察された場合は、本 Issue の選定根拠を巻き戻す（model を inherit に戻すか、ユーザーオーバーライド機構の調査を別 Issue で起票）。

## 巻き戻し条件

以下のいずれかが観察された場合、`docs/dogfood/317-evaluation-methodology.md` 末尾の「巻き戻しログ」セクションに記録した上で、対応する `plugins/dev-workflow/agents/<name>.md` の `model` を `inherit` に戻す。

1. メインセッションのモデル切り替えが、明示指定したサブエージェントに連動して反映される（推定 1 と矛盾）。
2. ユーザーオーバーライド機構（許可リスト・CLI フラグ・設定ファイル）が公式に存在し、サブエージェント定義の `model` 値より優先される（推定 2 と矛盾）。
3. プラグインローダーが `model: sonnet` 等の明示値を受理せず、警告またはエラーを出す（公式有効値仕様と現実が乖離）。

巻き戻し時はプラグインバージョンも PATCH 上げ（v0.6.1 等）し、PR で巻き戻し理由を明記する。
