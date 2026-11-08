# living-spec plugin

決めた仕様を、変更のたびに検査され描き直される「生きた正本」として保つプラグインです。人が決めたことが一つの矛盾の無い正本に残り続け、いつでも全体を見て確かめられる状態を目指します。

いまは要求の3層（RDRA の表・要求票・例）を扱います。要求を構造化し、整合を機械検査し、規則間の矛盾を独立文脈で突き合わせ、状態遷移図と UC ごとの縦串を1枚の HTML に描きます。画面仕様・設計など他の層は、同じ正本と検査の形で後から足す想定です。
書式・置き場・検査の規則と、基準の版との描き分け・基準の版から変わった要素の一覧の定義の正本は `references/format.md` です。

## 配布物

- `skills/structure/SKILL.md`: 要求を表→要求票→例へ写し、機械検査と突き合わせを通して終えます。
- `skills/crosscheck/SKILL.md`: 規則間の矛盾・条件の食い違い・状態遷移の抜けを報告します（直しません）。基準の版（git の版）を渡すと、そこから変わった要素だけを突き合わせます。
- `skills/view/SKILL.md`: 可視化を描き、開き方を示します。基準の版（git の版）を指定すると、そこからの違いを描き分けます。
- `agents/rule-crosschecker.md`: 表・票・例を初見で読み、矛盾を `id,severity,evidence,why,suggestion` で返します。
- `scripts/run.mjs`: 検査器を探して呼ぶ中継。引数は `check [--doc-missing] [起点]`・`render [--base <版>] [起点]`・`diff --base <版> [起点]`・`hook` です。依存を持ちません。検査器そのものはプラグインに含めません（下の「検査器の導入」）。
- `hooks/hooks.json`: 表・票・例の編集の後に全体検査と描き直しを走らせる PostToolUse フック。
- `references/starting-point.md`: 検査器へ渡す起点・基準の版・根の手順。起点と根はスキル3本が、基準の版の渡し方は `view` と `crosscheck` が従います。
- `references/templates/`: 要求票と例の雛形。

## 検査器の導入

検査器と描画は、プラグインと分けて、利用するリポジトリが持つ道具として入れます。claude-shared-skills の GitHub Release に、依存を同梱した1ファイル `living-spec-<コミット SHA>.mjs` として置いています。版は Release の一覧から SHA で選びます。要るのは Node 22 以上と、取得に使う curl です。基準の版との描き分け（`render --base`）と、`crosscheck` に基準の版を渡したときの一覧（`diff`）を使うときは、git も要ります。

プラグインは版を持たず、更新すると最新の手順と書式が届きます。検査器は選んだ SHA に固定されたままなので、プラグインを更新したら、検査器も最新の Release へ上げます。古い検査器は、プラグインの手順が書かせるキーを、許さないキーとして止めることがあります。`--base` を持たない版の検査器では、`render --base` が使い方を出して止まります。`diff` を持たない版の検査器では、`crosscheck` に基準の版を渡すと `diff` が使い方を出して止まります。どちらも、検査器を最新の Release へ上げれば使えます。

### 手元

1. 使う版のコミット SHA（40桁）を [Release の一覧](https://github.com/kuchita-el/claude-shared-skills/releases)から選び、添付物を取ります。置き場はリポジトリの外にします（commit や検査の対象に混ざりません）。

```bash
curl -fsSL --create-dirs -o ~/.local/share/living-spec/living-spec-<SHA>.mjs https://github.com/kuchita-el/claude-shared-skills/releases/download/living-spec-<SHA>/living-spec-<SHA>.mjs
```

2. エージェント（Claude Code・Codex 等）を起動するシェルで、`LIVING_SPEC_BIN` に取ったファイルのパスを入れます。シェルの設定ファイルに書いてもかまいません。`~` は中継が展開しません。下のように引用符で囲まない `export` で書いてシェルに展開させるか、絶対パスを入れます。引用符で囲んだ値や、シェルを通らない設定（エージェントの設定ファイルの環境変数の欄等）に `~` を書くと、文字のまま残り、検査器が見つからない扱いになります。エージェントが実行するコマンドへ渡す環境変数を設定で絞っている場合は、`LIVING_SPEC_BIN` を渡す対象に含めます。

```bash
export LIVING_SPEC_BIN=~/.local/share/living-spec/living-spec-<SHA>.mjs
```

上の2段は、エージェントに頼まず、端末で自分で実行します。エージェントに頼むと、取ったファイルを直接実行させる操作を、エージェントの権限の仕組み（Claude Code の auto mode の分類器等）が外から取ったコードの実行として止めることがあります。取得も、サンドボックスの書き込みの許可によっては、置き場へ書けずに失敗することがあります。2段を済ませてからエージェントを起動すれば、スキルは中継を通して検査器を呼べます。

中継は、まず `LIVING_SPEC_BIN` を見ます。次に、作業ディレクトリ（フックでは `CLAUDE_PROJECT_DIR`）から解決できるパッケージ `@kuchita-el/living-spec` を探します。ここでの解決の起点は、正本の根（下の「契約」）とは別のものです。見つからなければ、フックは何もせず、スキルからの呼び出しは導入の手順を出して止まります。

パッケージ `@kuchita-el/living-spec` は npm へ公開していません。利用者は `LIVING_SPEC_BIN` を使います。

### CI（GitHub Actions）

CI のジョブの中で添付物を取り、直接走らせます。claude-shared-skills は公開リポジトリのため、認証なしで取れることを前提にしています。

```yaml
jobs:
  living-spec:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    env:
      # 取る検査器の版。コミット SHA で固定し、上げるときはこの行を書き換える
      LIVING_SPEC_REF: <claude-shared-skills のコミット SHA（40桁）>
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1

      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1  # v7.1.0
        with:
          node-version: 24

      - name: living-spec の検査器を取る
        run: curl -fsSL -o "$RUNNER_TEMP/living-spec.mjs" "https://github.com/kuchita-el/claude-shared-skills/releases/download/living-spec-${LIVING_SPEC_REF}/living-spec-${LIVING_SPEC_REF}.mjs"

      - name: 表・要求票・例を検査する
        run: node "$RUNNER_TEMP/living-spec.mjs" check
        # ルート以外に根を置いたときは、根を引数で渡す: ... check docs
      - name: 書き漏らしの向きを検査する
        run: node "$RUNNER_TEMP/living-spec.mjs" check --doc-missing
```

- 版は `LIVING_SPEC_REF` のコミット SHA だけで決まります。Release のある 40桁の SHA 以外を入れると取得が失敗し、ジョブが失敗します。公開した Release の添付物は差し替えられないため、同じ SHA は同じ検査器を指し続けます。
- 検査の根は、起点（引数が無ければ作業ディレクトリ）から上へ辿って最も近い目印で決まります。決まった根は出力の1行目に出ます。置き場の変更は根の `.living-spec.json` に従います。
- ルート以外に根を置いたときは、根ごとに `check <根>` と `check --doc-missing <根>` を1回ずつ走らせます。
- 起点なしの `check` はルートを根にします。ルートに目印が無ければ正本が見つからず、ルートの置き場が下の根の中にあれば設定の誤りで止まります。
- 違反があると検査器は非 0 で終わり、ジョブが失敗します。
- 取ったファイルは `$RUNNER_TEMP` に置くため、検査の対象に混ざりません。

## 前提

- Node 22 以上（22.23・24.16 で確かめています）と、検査器の取得に使う curl。基準の版との描き分け（`render --base`）と、`crosscheck` に基準の版を渡したときの一覧（`diff`）には git も要ります。
- 可視化の図は Mermaid を jsdelivr から読むため、表示にネットワークが要ります。

## 契約

- 終わりの判定は、機械検査の違反0件と、突き合わせの blocker 0件の両方です。
- 根は、編集したファイルや `check` の起点から上へ辿って最も近い目印で決まります。1 リポジトリに複数置けます。規則と、設定の誤りになる置き場は `references/format.md` の「置き場の設定」が定めます。置き場は根の `.living-spec.json` で変えられます。
- 正本が無いとき（目印が無い、根に表の置き場が無い）、フックは何もしません。根に属さない置き場の中のファイルの編集では、フックはその根の誤りを示しません（別の根を検査するか、何もしません）。置き場の誤りを示す経路は、`references/format.md` の「置き場は根に属する」が定めます。
- フックは違反があると終了コード 2 で AI へ違反を返し、直させます。止めたい根の `.living-spec.json` で `hook` を `false` にします。効くのはその根の編集だけで、設定の無い領域や別の根の編集には効きません。
- 可視化の HTML と、基準の版との描き分けの HTML は派生物です。手で直さず、`.gitignore` へ入れます。描き分けの書き出し先は `references/format.md` の「基準の版との描き分け」が定めます。

## host 差分

- Claude Code: スキル・エージェント・フックのすべてが動きます。
- Codex: スキルと検査器は動きます。plugin 単位のフックが無いため、編集ごとの自動検査と描き直しはありません。スキルの手順どおり `node scripts/run.mjs check` と `node scripts/run.mjs render` を明示的に実行します。基準の版を渡した `crosscheck` では、`node scripts/run.mjs diff --base <版> [起点]` も明示的に実行します。版の渡し方は `references/starting-point.md` の「基準の版の渡し方」に従います。端末で自分で実行するなら、取ったファイルを `node <取ったファイルのパス> check` で直接走らせてもかまいません。`render` と `diff --base <版> [起点]` も、`scripts/run.mjs` と同じ引数で走らせられます。突き合わせのエージェントが使えない場合は、別の会話で `agents/rule-crosschecker.md` の指示を与えて実行します。入力には plugin root path（`references/format.md` を含むこのディレクトリ）も渡します。

## 検査と書式に期待できること

### 機械検査が違反を出す場面

既存の文書から1回で3層を揃えて写す一括の写しでは、違反0件が普通です。同じときに写した層どうしは、ずれにくいためです。
違反が出るのは主に、後で層の片方だけを直したときです。たとえば、要求票の要求文を書き換えたのに、例のルール名が追い付いていない場合です。
一括の写しで違反0件を見ても、検査器の価値はその後の変更の局面で出ます。0件は一括の写しで普通というだけで、写す途中で書き損じれば違反は出ます。

### 書く段階で表に出るもの

一括の写しでは、収穫の多くは違反として届く前に、書式の規律に沿って書く段階で見つかります。
規律は、規則ごとに要求文を1行で書くことと、1ルールあたりの例の数に上限があることです。
この規律に沿って書くと、束になった規則・元の文書の空白・文言の不一致が表に出ます。束になった規則は、1行や例の上限に収まらないことで見つかります。
例の上限のように、検査器も違反として止める規律があります。上限の数は `references/format.md` の「例」が、要求文の書き方は `references/format.md` の「要求票」が定めます。

### 機械検査が見ないもの

違反0件は、意味の正しさを保証しません。意味は突き合わせ（`crosscheck`）と人の確認に残ります。何が検査の外かは `references/format.md` の「機械検査が見ないもの」が定めます。
