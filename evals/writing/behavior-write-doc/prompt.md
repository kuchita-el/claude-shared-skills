---
max_turns: 45
timeout_seconds: 1200
model: claude-sonnet-5
tags: [behavior]
allowed_tools: [Read, Skill, Agent]
---

write-doc スキルを使って、ステージング環境向けのデプロイ手順書を起草して。次の内容で入力契約を満たす。

- documentType: 汎用
- audience: 初めて参加する開発者
- outputPath: docs/deploy-guide.md
- structure: 「概要」「手順」「背景」の3節、この順に配置する。概要では手順の対象と、この手順が Issue #421 のカナリアリリース方針に従う旨だけに触れる。方針の内容そのものの説明は概要に書かず、背景節にまとめる。
- materials（確定済み。これ以外の事実・数値・識別子を作らない）:
  1. 手順の対象はステージング環境のみで、本番環境は含まない。
  2. デプロイは `scripts/deploy.sh --env staging` を実行して行う。
  3. デプロイ後のヘルスチェックは `curl https://staging.example.com/healthz` が200を返すことで確認する。
  4. この手順は Issue #421 が定めたカナリアリリース方針に従う。
  5. カナリアリリース方針とは、新バージョンのトラフィックを一部だけ先に流し、異常が無ければ段階的に全体へ広げる方式を指す。
  6. 異常を検知した場合は `scripts/rollback.sh --to <直前のリリースタグ>` でロールバックする。
