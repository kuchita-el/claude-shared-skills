#!/usr/bin/env bash
# behavior-patch-update: 破壊的変更の無いパッチ更新（lodash 4.17.20→4.17.21）の題材を作る。
# SKILL.md の Phase 1/2 がロックファイルと package.json だけで完結できるよう、
# バージョン情報はすべてこのスクリプトが作るファイルに収める（外部レジストリ照会に頼らせない）。
set -euo pipefail

mkdir -p src
mkdir -p node_modules/lodash

cat > package.json <<'EOF'
{
  "name": "sample-app",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "lodash": "^4.17.20"
  }
}
EOF

cat > package-lock.json <<'EOF'
{
  "name": "sample-app",
  "version": "1.0.0",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "sample-app",
      "version": "1.0.0",
      "dependencies": {
        "lodash": "^4.17.20"
      }
    },
    "node_modules/lodash": {
      "version": "4.17.20",
      "resolved": "https://registry.npmjs.org/lodash/-/lodash-4.17.20.tgz",
      "integrity": "sha512-PlhdFcillOINfeV7Ni6oF1TAEayyZBoZ8bcshTHqOYJYlrqzRK5hagpagky5o4HfCzzd1TRkXPMFq6cKk9rGmA=="
    }
  },
  "dependencies": {
    "lodash": {
      "version": "4.17.20",
      "resolved": "https://registry.npmjs.org/lodash/-/lodash-4.17.20.tgz",
      "integrity": "sha512-PlhdFcillOINfeV7Ni6oF1TAEayyZBoZ8bcshTHqOYJYlrqzRK5hagpagky5o4HfCzzd1TRkXPMFq6cKk9rGmA=="
    }
  }
}
EOF

cat > node_modules/lodash/package.json <<'EOF'
{
  "name": "lodash",
  "version": "4.17.20",
  "description": "Lodash modular utilities."
}
EOF

cat > src/user-service.js <<'EOF'
const _ = require('lodash');

function getDisplayName(user) {
  return _.get(user, 'profile.displayName', 'unknown');
}

function mergeSettings(defaults, overrides) {
  return _.merge({}, defaults, overrides);
}

module.exports = { getDisplayName, mergeSettings };
EOF

cat > src/report-builder.js <<'EOF'
import { pick, groupBy } from 'lodash';

export function buildSummary(records) {
  const grouped = groupBy(records, 'category');
  return Object.entries(grouped).map(([category, items]) => ({
    category,
    items: items.map((item) => pick(item, ['id', 'name'])),
  }));
}
EOF
