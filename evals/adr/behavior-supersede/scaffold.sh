#!/usr/bin/env bash
# behavior-supersede の題材を空の作業ディレクトリへ作る。
#
# 上書き前の状態で `lint-adr.sh docs/adr` が exit 0 になるように組む。
# git は初期化しない（manage-adr の手順と同梱スクリプトは git を使わず、commit も依頼しない）。
#
# 登場する ADR（対象ディレクトリ docs/adr）:
#   Z ADR-202607011000-01-basic-auth         上書き済み（A が後継）。凍結済みで編集してはならない
#   A ADR-202608011000-01-jwt-auth           有効。今回上書きされる旧 ADR
#   B ADR-202608151000-01-api-rate-limit     有効。`Related:` の先頭で A を指す（lint レイヤ4 が付け替えを強制する側）
#   C ADR-202608201000-01-audit-logging      有効。`Related:` 行の2件目で A を指す（lint が見ない側。締めの確認の2点目）
#   S ADR-202609201000-01-session-cookie-auth 有効（承認済み）。後継
# 非 ADR 文書 docs/architecture.md:
#   現在形で A を出典として名指しする行（付け替える側）と、過去の事実として A を述べる行（据え置く側）を持つ
set -euo pipefail

mkdir -p docs/adr

cat > docs/adr/ADR-202607011000-01-basic-auth.md <<'EOF'
---
status: 承認済み
validity: 上書き済み
superseded-by: ADR-202608011000-01-jwt-auth
---

# ADR-202607011000-01: API の認証に Basic 認証を用いる

## Context

社内向け API を最小構成で公開するため、認証方式を早期に決める必要があった。

## Decision

1. API の認証には HTTP Basic 認証を用いる。

## Consequences

資格情報を毎リクエスト送るため、TLS の終端を必須とする。

## 関連ADR

- Superseded by: ADR-202608011000-01-jwt-auth
EOF

cat > docs/adr/ADR-202608011000-01-jwt-auth.md <<'EOF'
---
status: 承認済み
validity: 有効
superseded-by:
---

# ADR-202608011000-01: API の認証に JWT を用いる

## Context

外部クライアントの増加に伴い、毎リクエストで資格情報を送る Basic 認証をやめる必要が生じた。

## Decision

1. API の認証には署名付き JWT（有効期限15分）を用いる。
2. JWT はクライアントがローカルストレージに保持し、Authorization ヘッダで送る。

## Consequences

トークン失効をサーバ側で即時に反映できない。失効が必要な場面では有効期限切れを待つ。

## 関連ADR

- Supersedes: ADR-202607011000-01-basic-auth
EOF

cat > docs/adr/ADR-202608151000-01-api-rate-limit.md <<'EOF'
---
status: 承認済み
validity: 有効
superseded-by:
---

# ADR-202608151000-01: API のレート制限を認証主体単位で掛ける

## Context

一部のクライアントが短時間に大量のリクエストを送り、他の利用者の応答が遅れた。

## Decision

1. レート制限は認証主体ごとに毎分600リクエストとする。

## Consequences

未認証のリクエストは IP アドレス単位の別枠で制限する。

## 関連ADR

- Related: ADR-202608011000-01-jwt-auth — 認証方式の出典
EOF

cat > docs/adr/ADR-202608201000-01-audit-logging.md <<'EOF'
---
status: 承認済み
validity: 有効
superseded-by:
---

# ADR-202608201000-01: 監査ログに認証主体を記録する

## Context

障害調査の際に、どの認証主体が操作したかを追えなかった。

## Decision

1. 更新系 API の監査ログに認証主体の識別子を記録する。

## Consequences

監査ログの保持期間は90日とし、個人情報を含む項目はマスクする。

## 関連ADR

- Related: ADR-202608151000-01-api-rate-limit, ADR-202608011000-01-jwt-auth — 認証主体の単位と認証方式の出典
EOF

cat > docs/adr/ADR-202609201000-01-session-cookie-auth.md <<'EOF'
---
status: 承認済み
validity: 有効
superseded-by:
---

# ADR-202609201000-01: API の認証にセッション Cookie を用いる

## Context

JWT をローカルストレージに保持する方式では、トークンの即時失効ができず、XSS 時の漏洩範囲も大きい。

## Decision

1. API の認証にはサーバ側セッションと HttpOnly・Secure 属性付きの Cookie を用いる。
2. セッションの失効はサーバ側で即時に反映する。

## Consequences

セッションストアの可用性が認証の可用性を左右する。

## 関連ADR

該当なし
EOF

cat > docs/adr/index.md <<'EOF'
<!-- このファイルは gen-adr-index.sh による生成物。手動編集禁止。 -->
# 有効 ADR インデックス

- [ADR-202608011000-01-jwt-auth](./ADR-202608011000-01-jwt-auth.md): API の認証に JWT を用いる
- [ADR-202608151000-01-api-rate-limit](./ADR-202608151000-01-api-rate-limit.md): API のレート制限を認証主体単位で掛ける
- [ADR-202608201000-01-audit-logging](./ADR-202608201000-01-audit-logging.md): 監査ログに認証主体を記録する
- [ADR-202609201000-01-session-cookie-auth](./ADR-202609201000-01-session-cookie-auth.md): API の認証にセッション Cookie を用いる
EOF

cat > docs/architecture.md <<'EOF'
# システム構成

## 認証

API の認証方式は ADR-202608011000-01-jwt-auth が定める。

## レート制限

レート制限の単位は ADR-202608151000-01-api-rate-limit が定める。

## 経緯

2026年8月の初期構築では、ADR-202608011000-01-jwt-auth の決定に基づいて JWT 認証を導入した。それ以前は ADR-202607011000-01-basic-auth に基づいて Basic 認証を用いていた。
EOF
