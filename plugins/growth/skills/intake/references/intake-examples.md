# 取り込み worked example

intake スキルの手順([`intake-procedure.md`](intake-procedure.md))を具体例でトレースする。本文書は手順の挙動確認用であり、判定基準の出典は procedure 側に置く。

## 例1: 新規取り込み Issue を作成して3候補を束ねる

### 入力

inbox に `growth:promote` 候補が3件ある。

```
#401 ファイル復元には git restore を使う        (scope-hypothesis: universal)
#402 内省機能は独立プラグインへ分離する          (scope-hypothesis: project-local)
#403 長文 CLI 引数の破損を lint で機械的に禁止する (scope-hypothesis: universal)
```

### トレース

- **§1 対象特定**: 引数 `401 402 403`。`gh issue view` で各本文を読む。
- **§2 重複検出**: `gh issue list --label growth:intake --state open` → open の取り込み Issue なし → **新規作成**。
- **§3 裁定提案**: #401＝learnings.md/パブリック、#402＝ADR 差分/閉じた、#403＝強キャリア(lint)/パブリック を提案。
- **§4 承認**: 裁定対象・束ね先(新規)・裁定提案を提示。人間が #401〜#403 の career・空間を承認(変更なし)。
- **§5 起票**: 本文を一時ファイルへ書き出し、`gh issue create --title "学びの取り込み(git/設計/lint)" --body-file ... --label growth --label growth:intake` で #420 を起票。

```markdown
## 取り込んだ候補
- #401
- #402
- #403

## 裁定結果
| 候補 | career | 空間 | 備考 |
|---|---|---|---|
| #401 | learnings.md | パブリック | scope 仮説: universal |
| #402 | ADR 差分 | 閉じた | scope 仮説: project-local |
| #403 | 強キャリア(lint) | パブリック | scope 仮説: universal |

## 成果物
- [ ] learnings.md への1欄追加 PR（#401 由来）
- [ ] docs/adr/ への ADR 差分 PR（#402 由来）
- [ ] lint ルール追加（#403 由来。強キャリア）
```

- **§6 取り込み時クローズ**: #401〜#403 に「取り込み Issue #420 へ取り込みました」コメント → `gh issue close <番号> --reason "not planned"`。`gh issue list --label growth:promote --state open` から3件が外れたことを確認。

### 完了報告

```
候補3件を取り込みました。
- 束ね先: 新規取り込み Issue #420
- 裁定結果: #401 → learnings.md（パブリック） / #402 → ADR 差分（閉じた） / #403 → 強キャリア(lint)（パブリック）
- 取り込み時クローズ: 候補3件（not planned ＋ リンクコメント）
inbox 確認: is:open label:growth:promote から3件が外れました。
```

## 例2: 内容重複する既存取り込み先へ合流する

### 入力

inbox に新たな候補 #410（「git restore でファイル復元」を補強する別観察）。既に #420 が同種の git 操作の学びを束ねて open。

### トレース

- **§2 重複検出**: `gh issue list --label growth:intake --state open` → #420 がヒット。#420 の「裁定結果」に #401(git restore) があり、#410 と意味的に重複 → **既存 #420 へ合流**を第一提案。
- **§4 承認**: 束ね先=「既存 #420 へ合流」を提示。人間が合流を承認、#410 の career=learnings.md/パブリックを確定。
- **§5 追記**: `gh issue view 420 --json body` で現本文を取得し、「取り込んだ候補」へ `#410` を、「裁定結果」へ1行を、必要なら「成果物」へ task を追記して `gh issue edit 420 --body-file ...`。既存記載は破壊しない。
- **§6 クローズ**: #410 に「取り込み Issue #420 へ取り込みました」コメント → not planned クローズ。

### ポイント

集約先を引数で固定せず内容重複で合流先を選ぶ（不変条件「集約先は複数ありうる」）。確信が持てなければ新規作成を既定に倒し、合流可否を §4 で人間に委ねる。

## 例3: 承認が得られず候補を inbox に残す

### 入力

候補 #405（public への昇格を提案したが、人間が「これは閉じた空間に留めるべき」と判断）。

### トレース

- **§3 裁定提案**: #405＝learnings.md/パブリック を提案（scope 仮説 universal 由来）。
- **§4 承認**: 人間が空間を「パブリック → 閉じた」へ変更（public 昇格の拒否。不変条件2）。career は learnings.md のまま承認。
- **§5 起票**: 「空間=閉じた」で裁定結果へ記録。閉じた空間 × learnings.md は learning-promotion-spec.md のパブリックハンドラ対象外であり、成果物 task は閉じた空間の着地先（別 Issue で追跡）として残す。

別パターン（**承認自体が得られない**）:

- 非対話実行で §4 の承認が取れない、または人間が「いったん保留」とした場合 → **起票・クローズを行わず**「裁定承認が必要」と報告して終了。#405 は `open` のまま inbox に残り、再実行可能。裁定を握り潰して自動確定しない。

## 例4: 一部候補のクローズに失敗した場合（冪等な再実行）

### トレース

- **§5 起票**: #420 を起票成功。
- **§6 クローズ**: #401・#402 はクローズ成功。#403 が権限エラーでクローズ失敗。
- **挙動**: 起票済み #420 と成功済みクローズ（#401・#402）は維持。#403 は inbox に残り報告する。再実行すると #403 のみ閉じられる（#420 は既存合流として検出され、#401・#402 は既に closed で対象外）。

### ポイント

「起票/追記成功を確認してから候補を閉じる」順序と、一部失敗時に成功分を巻き戻さない冪等性により、取り込み先が確定しないまま候補が inbox から消える事故を防ぐ。

## 関連

- [`intake-procedure.md`](intake-procedure.md) — 各段の判定基準・コマンド・本文書式・エラー処理の単一出典
- [`intake-issue-spec.md`](../../../references/intake-issue-spec.md) — 取り込み Issue の構造・裁定結果の記録形式・不変条件
