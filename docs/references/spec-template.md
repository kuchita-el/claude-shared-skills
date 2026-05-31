# ユースケース仕様（spec.md）の構成

デリバリーアイテムのストック情報を集約するユースケース仕様（`docs/{domain}/use-cases/{name}/spec.md`）の構成例。ユースケース仕様を作成した後、AC を転記して Issue を起票する。ユースケース仕様はストック情報（蓄積・繰り返し参照される）として残り、Issue は作業駆動用のフロー情報として使い分ける。

## 構成例

```markdown
# 契約の新規作成

## ドメインマッピング
- 集約: Contract
- 状態遷移: [*] → Draft → PendingApproval → Active
- コマンド: CreateContract, SubmitContract, ApproveContract

## 受け入れ基準
- Draft状態の契約を作成できる
- Draft契約を承認申請に提出できる
- 承認者が契約をActiveにできる

## 今回は実装しないが、ドメイン構造で考慮済みのもの
- Amendment（集約として定義済みだがロジックは後続アイテム）
- 自動更新（状態遷移として定義済みだが後続アイテム）
- 解約（状態遷移として定義済みだが後続アイテム）

## 外部リソース
- デザイン: https://figma.com/file/xxx
- 詳細仕様: https://xxx.atlassian.net/wiki/...
```

「今回は実装しないがドメイン構造で考慮済み」のセクションにより、AI は将来の拡張の見通しを理解した上でコードを書ける。
