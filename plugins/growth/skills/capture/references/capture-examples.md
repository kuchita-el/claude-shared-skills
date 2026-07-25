# capture 記述例

capture SKILL.md の Step 3（生観察の生成）・Step 4（store 書き込み）から参照される記述例。判定基準の詳細は `${CLAUDE_SKILL_DIR}/references/capture-procedure.md` を参照する。

## observation 本文の例（Step 3）

```
ユーザーが「git checkout ではなく git restore を使え」と訂正した。
当方はファイル復元に git checkout を提案していた。
```

## エントリの記述例（Step 4）

記述例（tool-result 由来。上記 user-utterance 由来の訂正例と対比できる）:

```
## 2026-06-26T15:10:02Z
- signal: ツール拒否
- session: 2265f83f-c5a8-41a0-b284-b5d90882a2da
- origin: tool-result
- expected: rm のツール呼び出しが許可され実行される
- actual: tool_result.is_error=true、permission denied で拒否された

rm コマンドのツール呼び出しをユーザーが許可プロンプトで対話的に拒否した（常設 deny ルールによる自動拒否は D3 で既定除外。本例は対話的拒否のため観測対象）。
```

記述例（判断知。予測誤差の形を持たず `expected` / `actual` は空）:

```
## 2026-06-29T08:50:02Z
- signal: 設計判断
- session: 2265f83f-c5a8-41a0-b284-b5d90882a2da
- origin: user-utterance
- expected:
- actual:

ユーザーが「プランを追跡対象に変えることはない。追跡可否は利用者に委ねる」と設計境界を確定した。
```
