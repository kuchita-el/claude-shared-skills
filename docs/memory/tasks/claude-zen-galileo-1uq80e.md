# #1047 のプラン

## 決めたこと

- 置き場の条件: 正本（confidentiality.md「いつ行うか」）に合わせ、必須は「昇格先（別のリポジトリ）の作業ツリーの外」。
  `mktemp -d` で作るので、どの作業ツリーの追跡下にも入らず、プロジェクトのコミットにも混ざらない。これは別の理由として書き分ける。
- `mktemp -d` が失敗したら: 別の手段で置き場を作らず止まり、失敗を報告する。作業ツリーの中へ置き場を作らない。利用者に置き場を尋ねる経路は足さない（非対話で尋ねられない）。
- 差し替える TMPDIR: `${XDG_CACHE_HOME:-$HOME/.cache}/claude-plugin-eval/` の下に実行ごとのディレクトリ。
  リポジトリの `.local/` は採らない。題材に `.git` が無いケースで、git がこのリポジトリへ遡って見つけるため。
  解決した置き場が /tmp・/var/tmp・/dev/shm の下なら、スクリプトは理由つきで止まる。
- 複製も同じ実行ごとのディレクトリへ置き、後始末を1か所にする（chmod -R u+rwX してから rm -rf）。`--keep-temp` のときは残し、場所と消し方を示す。
- Claude Code への不具合報告: 外部への送信なので、このタスクではしない。利用者に委ねる。
- table-lists-all: 計測の trace と判定の理由で切り分けてから決める。

## 実測（2026-11-23）

- 最小のケースで、既定では `mktemp -d`・`touch ./x` が EROFS、`TMPDIR=~/.cache/...` で両方通る。`.bashrc: Permission denied` は出る。
- denyWrite にはプラグインの複製（の各ディレクトリ）が入る。作業ツリーの下を TMPDIR にしても、複製でない限り拒まれない。

## 手順

1. scripts/run-plugin-eval.sh と scripts/tests/run-plugin-eval.bats
2. test-execution.md §7.2 の書き換え
3. 外した採点器の復帰、report-lists-changes の条件の復帰
4. promote-record・propose-records の手順5
5. shared-memory の3ケースを --runs 3 で計測。table-lists-all の切り分け
6. Task Memory を消して PR
