#!/usr/bin/env bash
# 配布プラグインの eval ケースを、配布物へ同梱せずに `claude plugin eval` で実行する。
#
# 背景（Issue #877）: eval ケース（採点器・prompt.md 等）は本リポジトリ固有の監査所見を
# 名指しており、配布先にとって意味を持たないため配布物 `plugins/<plugin>/` には置かず
# リポジトリ直下 `evals/<plugin>/` に置く。一方 `claude plugin eval` は eval の置き場を
# プラグイン配下に限る（`--eval-dir` はプラグイン配下限定）。本スクリプトは両立させるため、
# 実行のたびに `plugins/<plugin>/` を一時ディレクトリへ複製し、`evals/<plugin>/` をその
# 複製の `evals/` として配置してから `claude plugin eval <複製先> ...` を呼ぶ。
#
# 設計上の要点:
# - 複製先へ cd はしない。`claude plugin eval` へは複製先の絶対パスを引数として渡すだけで、
#   その後ろに続く利用者の引数（`--output-dir` 等）はそのまま透過する。cd しないことで、
#   利用者が指定した相対パスの `--output-dir` は「このスクリプトを呼び出した時点の cwd」
#   基準のまま claude に渡る。絶対化は行わない（呼び出し側の意図する相対パス解決を変えない
#   ための選択）
# - `--output-dir` を利用者引数に含めることを必須にする。`claude plugin eval` の既定の
#   結果出力先は eval 置き場の下（＝一時ディレクトリ配下）になり、後始末で結果ごと消える
# - `claude` は PATH から解決する（`command -v`）。テストは PATH の先頭にスタブを置いて
#   差し替える
# - `claude plugin eval` を、`TMPDIR` を実行ごとの専用ディレクトリへ向けて起動する
#   （Issue #1047）。eval は一時の根を `TMPDIR` の下に作り、子のセッションのサンドボックスへ
#   その根の `home`・`tmp` を `allowWrite` として渡す。一方 `denyWrite` には `/tmp`・`/var/tmp`・
#   `/dev/shm` が入り、禁止は許可より強い。根がこれらの下に在ると、作業ディレクトリも `TMPDIR`
#   も読み取り専用になり、Bash の `mktemp -d` や作業ディレクトリへの書き込みが EROFS で失敗する
# - 専用ディレクトリは `${XDG_CACHE_HOME:-$HOME/.cache}/claude-plugin-eval/` の下に作る。
#   リポジトリの作業ツリーの下には置かない。題材が `.git` を持たないケースで、子のセッションの
#   git がこのリポジトリへ遡って見つけるためである。解決した置き場が `/tmp`・`/var/tmp`・
#   `/dev/shm` の下なら、理由を示して止まる
# - プラグインの複製も同じ専用ディレクトリへ置き、後始末を1か所にする。親の `claude` が
#   `TMPDIR` の下に作る一時ディレクトリも、同じく消える
# - 専用ディレクトリは trap で必ず削除する（claude の起動が失敗しても、スクリプトが
#   途中で終了しても）。eval が root で動くと書き込みの権限を閉じるので、権限を戻してから消す。
#   `--keep-temp` が引数に在るときは残し、場所と消し方を標準エラーへ示す
# - スクリプトの位置からリポジトリルートを解決するため、呼び出し時の cwd に依らず動く

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

usage() {
    cat <<'USAGE'
usage: bash scripts/run-plugin-eval.sh <plugin> [claude plugin eval の引数...]

  <plugin>            plugins/<plugin>/ と evals/<plugin>/ の両方を持つプラグイン名
  [引数...]           claude plugin eval へそのまま渡す引数（--output-dir は必須）

例:
  bash scripts/run-plugin-eval.sh dependency-insight --runs 3 --ablation none \
      --no-publish --trust-plugin --scaffold --max-cost-usd 5 --output-dir .local/eval-results
USAGE
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

plugin="${1:-}"
if [ -z "$plugin" ]; then
    echo "run-plugin-eval: プラグイン名を指定してください" >&2
    usage >&2
    exit 1
fi
shift

plugin_dir="$REPO_ROOT/plugins/$plugin"
if [ ! -d "$plugin_dir" ]; then
    echo "run-plugin-eval: plugins/$plugin/ が存在しません" >&2
    exit 1
fi

evals_dir="$REPO_ROOT/evals/$plugin"
if [ ! -d "$evals_dir" ]; then
    echo "run-plugin-eval: evals/$plugin/ が存在しません" >&2
    exit 1
fi

# --output-dir の指定を要求する。`--output-dir X` と `--output-dir=X` の両形式を受理する。
has_output_dir=0
for arg in "$@"; do
    case "$arg" in
        --output-dir | --output-dir=*)
            has_output_dir=1
            break
            ;;
    esac
done
if [ "$has_output_dir" -ne 1 ]; then
    echo "run-plugin-eval: --output-dir を指定してください（既定の出力先は一時ディレクトリ配下になり、実行後に結果ごと削除されるため）" >&2
    exit 1
fi

if ! claude_bin=$(command -v claude); then
    echo "run-plugin-eval: claude を PATH 上に解決できません" >&2
    exit 1
fi

keep_temp=0
for arg in "$@"; do
    if [ "$arg" = "--keep-temp" ]; then
        keep_temp=1
        break
    fi
done

# 引数のパスが /tmp・/var/tmp・/dev/shm のどれかの下（それ自身を含む）なら真を返す
under_denied_tmp() {
    case "$1/" in
        /tmp/* | /var/tmp/* | /dev/shm/* | /private/tmp/* | /private/var/tmp/*) return 0 ;;
    esac
    return 1
}

cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/claude-plugin-eval"
if ! mkdir -p "$cache_root" || ! cache_root_physical=$(cd "$cache_root" && pwd -P); then
    echo "run-plugin-eval: 作業場所の置き場 $cache_root を作れません" >&2
    exit 1
fi
if under_denied_tmp "$cache_root" || under_denied_tmp "$cache_root_physical"; then
    echo "run-plugin-eval: 作業場所の置き場 $cache_root が /tmp・/var/tmp・/dev/shm の下に在ります。eval のサンドボックスがこれらへの書き込みを禁じ、作業ディレクトリが読み取り専用になるため、XDG_CACHE_HOME か HOME をこれらの外へ向けてください" >&2
    exit 1
fi

work_dir=$(mktemp -d "$cache_root_physical/run.XXXXXX") || exit 1
cleanup() {
    if [ "$keep_temp" -eq 1 ]; then
        echo "run-plugin-eval: --keep-temp のため、作業場所を残しました: $work_dir" >&2
        echo "run-plugin-eval: 消すには: chmod -R u+rwX '$work_dir' && rm -rf '$work_dir'" >&2
        return
    fi
    chmod -R u+rwX "$work_dir" 2>/dev/null
    rm -rf "$work_dir"
}
trap cleanup EXIT

eval_tmp="$work_dir/tmp"
if ! mkdir "$eval_tmp"; then
    echo "run-plugin-eval: 作業場所に tmp を作れません" >&2
    exit 1
fi

clone_dir="$work_dir/$plugin"
# 複製が欠けたまま eval を走らせると、欠けた題材に対する結果が基準値と比べられてしまう
if ! cp -a "$plugin_dir" "$clone_dir" \
    || ! rm -rf "$clone_dir/evals" \
    || ! cp -a "$evals_dir" "$clone_dir/evals"; then
    echo "run-plugin-eval: 一時ディレクトリへの複製に失敗しました" >&2
    exit 1
fi

TMPDIR="$eval_tmp" "$claude_bin" plugin eval "$clone_dir" "$@"
exit $?
