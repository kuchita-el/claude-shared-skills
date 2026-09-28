#!/usr/bin/env bash
# behavior-distill の題材を作る。
#
# 実行環境（claude plugin eval --scaffold）: cwd は実行ごとの作業ディレクトリ
# （<root>/home/cwd）、HOME は実行ごとの一時 HOME（<root>/home）。エージェントも同じ
# HOME で動くため、store は $HOME/.claude/projects/<project-id>/growth/ に置けば
# distill の正準パス解決（personal-store-spec.md「project-id とパスの解決手順」）と一致する。
#
# 日付は実行日から相対に作る（retention horizon M=60 日の境界判定を実行日に追随させるため）。
# 各観察の見出しキーの時刻部は一意（T10:01:01Z 等）にしてあり、採点器は時刻部で照合する。
set -euo pipefail

days_ago() {
  date -u -d "$1 days ago" +%F 2>/dev/null || date -u -v-"$1"d +%F
}

D60=$(days_ago 60)   # horizon 境界ちょうど（保持側）
D10=$(days_ago 10)   # 直近 M 日・処理済み（保持側）
D3=$(days_ago 3)     # カーソル日付（バケットなし）
D2=$(days_ago 2)     # カーソルより新しい
D1=$(days_ago 1)     # カーソルより新しい
OLD=2026-01-15       # horizon 超・処理済み（削除対象）。採点器が固定名で照合する

# 作業ディレクトリをリポジトリ化する（$HOME/.git へのフォールバック解決を避け、
# project-id を作業ディレクトリ由来に固定する）
git init -q .
COMMON_DIR=$(git rev-parse --path-format=absolute --git-common-dir)
REPO_ROOT=${COMMON_DIR%/.git}
PROJECT_ID=${REPO_ROOT//\//-}

# project CLAUDE.md（project-local 台帳。§7.1 の突合対象）
cat > CLAUDE.md <<'EOF'
# CLAUDE.md

## 開発ルール

- DB マイグレーションファイルを手書きしない。必ず `make migration name=<名前>` で生成する。生成時にチェックサムが登録され、手書きのファイルは `make migrate` で拒否されるため。
- テストは `make test` で実行する。
EOF

STORE="$HOME/.claude/projects/$PROJECT_ID/growth"
mkdir -p "$STORE"

# --- カーソル（前回 distill の到達点） ---
printf -- '- distill-cursor: %sT12:00:00Z\n' "$D3" > "$STORE/distill-state.md"

# --- 既存の仮説ファイル（upsert で保持されるべき rejected / promoted） ---
cat > "$STORE/candidates.md" <<EOF
## 差分外のファイルまで一括フォーマットしない
- tags: [behavior-diff]
- provenance: ${D60}T08:00:00Z
- scope-hypothesis: universal
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo
- candidate-status: rejected

整形ツールは差分に含まれるファイルにだけ適用する。無関係な差分がレビューを妨げるため。

## コミットは関連ファイルのみをステージングする（git add -A を使わない）
- tags: [behavior-diff]
- provenance: ${D10}T09:00:00Z
- scope-hypothesis: universal
- career-hypothesis: learnings.md / repo: 配布元プラグイン repo
- candidate-status: promoted

コミット時は変更に関係するファイルだけを明示的に git add する。git add -A は無関係なファイルを巻き込むため。
EOF

# --- sealed バケット（カーソル通過済み） ---
cat > "$STORE/captures-${OLD}.md" <<EOF
## ${OLD}T08:00:00Z
- signal: 訂正
- session: 0b7e2c1a-5d3f-4e8a-9c21-7f6a0d4b3e10
- origin: user-utterance
- expected: PR タイトルに変更ファイル数を入れれば受け入れられる
- actual: ユーザーが「PR タイトルに件数を入れるな」と訂正した

PR タイトルに変更ファイル数を入れたところ、ユーザーが件数を入れないよう訂正した。
EOF

cat > "$STORE/captures-${D60}.md" <<EOF
## ${D60}T08:00:00Z
- signal: 反復試行
- session: 5c1d9e7f-2a4b-4c6d-8e0f-1a2b3c4d5e6f
- origin: tool-result
- expected: prettier を実行すれば変更箇所だけが整形される
- actual: git diff --stat が 214 files changed を示した

prettier を全体に実行したところ、差分外のファイルまで整形され、無関係な差分が大量に出た。
EOF

cat > "$STORE/captures-${D10}.md" <<EOF
## ${D10}T09:00:00Z
- signal: 訂正
- session: 9a8b7c6d-5e4f-4a3b-2c1d-0e9f8a7b6c5d
- origin: user-utterance
- expected: git add -A でまとめてステージすれば受け入れられる
- actual: ユーザーが「コミットは関連ファイルだけステージしろ、git add -A は使うな」と訂正した

コミット前に git add -A を実行しようとしたところ、ユーザーが関連ファイルだけをステージするよう訂正した。
EOF

# --- カーソルより新しいバケット（処理源） ---
# T10:01:01Z: distill-examples 例A エントリ1 と同一の観察（learnings.md 記入例と一致。growth-40）
# T10:02:02Z / T09:03:03Z: project CLAUDE.md の既存ルールの再発（tool-result 由来。growth-01 の順位比較用）
cat > "$STORE/captures-${D2}.md" <<EOF
## ${D2}T10:01:01Z
- signal: 訂正
- session: 3f2a6b1c-8d4e-4f7a-b9c0-d1e2f3a4b5c6
- origin: user-utterance
- expected: ファイル復元に git checkout を提案すれば受け入れられる
- actual: ユーザーが「git checkout ではなく git restore を使え」と訂正した

ユーザーが「git checkout ではなく git restore を使え」と訂正した。当方はファイル復元に git checkout を提案していた。

## ${D2}T10:02:02Z
- signal: 期待違反
- session: 3f2a6b1c-8d4e-4f7a-b9c0-d1e2f3a4b5c6
- origin: tool-result
- expected: 手書きしたマイグレーションファイルで make migrate が通る
- actual: make migrate が「checksum mismatch: add_orders_index.sql」で失敗した

orders テーブルへのインデックス追加のため、マイグレーションファイル add_orders_index.sql を手書きで作成して make migrate を実行したところ、チェックサム不一致で失敗した。make migration name=add_orders_index で生成し直して成功した。
EOF

# T09:03:03Z: 上記ルールの再発2件目
# T11:11:11Z: signal が値域外（メモ）で知識型を判定できない観察（growth-37）
# T13:05:05Z: 純記述（棄却されるべき観察）。今回走査の最新見出しキー＝前進後カーソル
cat > "$STORE/captures-${D1}.md" <<EOF
## ${D1}T09:03:03Z
- signal: 反復試行
- session: 7d6c5b4a-3e2f-4a1b-9c8d-7e6f5a4b3c2d
- origin: tool-result
- expected: 手書きしたマイグレーションファイルで make migrate が通る
- actual: make migrate が「checksum mismatch: add_users_email.sql」で2回続けて失敗した

users テーブルへのカラム追加で、マイグレーションファイルを手書きで作成して make migrate を実行し、チェックサム不一致で失敗した。ファイル内容を直して再実行しても同じエラーで失敗し、make migration name=add_users_email で生成し直して成功した。

## ${D1}T11:11:11Z
- signal: メモ
- session: 7d6c5b4a-3e2f-4a1b-9c8d-7e6f5a4b3c2d
- origin: user-utterance
- expected:
- actual: ユーザーが「設定は TOML に揃えて。YAML はもう増やさない」と述べた

新しいサービスの設定ファイルを config.yaml として作成したところ、ユーザーが config.toml に書き直し、「設定は TOML に揃えて。YAML はもう増やさない」と述べた。

## ${D1}T13:05:05Z
- signal: 期待違反
- session: 7d6c5b4a-3e2f-4a1b-9c8d-7e6f5a4b3c2d
- origin: tool-result
- expected: npm run build が 1 分程度で終わる
- actual: npm run build の完了まで 4 分 12 秒かかった

npm run build が前回より遅く、完了まで 4 分 12 秒かかった。
EOF
