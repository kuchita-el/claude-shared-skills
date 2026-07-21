#!/usr/bin/env bash
# このリポジトリのプラグインをローカルで読み込んでClaude Codeを起動する
set -euo pipefail
cd "$(dirname "$0")"

exec claude --plugin-dir ./plugins/dev-workflow --plugin-dir ./plugins/adr
