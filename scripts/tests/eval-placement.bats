#!/usr/bin/env bats
# 配布物へ eval ケースを同梱しないことの機械検査（Issue #877 AC1）。
#
# 【主題】eval ケースはリポジトリ直下 `evals/<plugin>/` に置き、配布物 `plugins/` 配下へは
# 一切置かない（docs/distribution-boundary.md §2・§3 と同じ判断軸——採点器が本リポジトリ
# 固有の監査所見を名指しており、配布先にとって意味を持たない）。`distribution-boundary.bats`
# は adr プラグイン単体を語彙走査するのに対し、本ファイルは「`plugins/` 配下のどのプラグイン
# にも `evals/` ディレクトリが存在しない」ことをプラグイン横断・実在リポジトリに対して直接
# 検査する。fixture の複製は用いず、REPO_ROOT 直下の実ツリーを見る（複製すると評価対象が
# 複製時点のスナップショットに固定され、以後の `plugins/` 配下への意図しない `evals/` の
# 混入を拾えなくなるため）。
#
# 【対照】`evals/<plugin>/` が正しい置き場に実在することも併せて確認する。空集合検査
# （`find` が1件も無い）だけでは、走査根の解決自体が壊れて何も見ていない場合も同じ
# 「0件」を返すため、判定として区別が付かない。

load 'helpers/common'

@test "plugins/ 配下のどのプラグインにも evals ディレクトリが存在しない" {
  run bash -c "find '$REPO_ROOT/plugins' -type d -name evals"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "対照: evals/<plugin>/ はリポジトリ直下に実在する（5プラグイン分）" {
  local plugin
  for plugin in adr dependency-insight domain-design growth writing; do
    [ -d "$REPO_ROOT/evals/$plugin" ] || {
      echo "evals/$plugin/ が存在しない" >&2
      return 1
    }
  done
}
