# tools/living-spec

living-spec の検査器と描画（コマンド `living-spec`、パッケージ `@kuchita-el/living-spec`）の正本と、その工場側の試験。プラグイン（`plugins/living-spec`）には含めず、利用者がここからビルドして、利用するリポジトリへ入れる（導入の手順は `plugins/living-spec/README.md`）。npm へは公開していない（`private`）。

書式と検査の規則の正本は `plugins/living-spec/references/format.md`。表のキーと置き場の既定は `src/schema.ts` が持つ。

## 由来

開発方式の試行（非公開の試行リポジトリ `tools/rdra-check`、2026-10-13 時点）から、RDRA の表・要求票・例の3層の検査と描画を切り出した。試行で持っていた1枚資料の層（`one-pager-mismatch`）とコードとの照合（`code-coined-name`・`code-missing-name`）は外した。前者は取り組みごとのフローの資料を恒久の表と照合する形の扱いが、後者は特定の置き場と識別子の規約への結合が、汎用の配布物として決まっていないため。

## 作業

```bash
pnpm --dir tools/living-spec install --frozen-lockfile
pnpm --dir tools/living-spec test     # 規則ごとの見本（examples/）の照合・入口・描画
pnpm --dir tools/living-spec build    # dist/living-spec.mjs（依存を同梱した1ファイル。追跡しない）を作る
RDRA_ENTRY="$PWD/tools/living-spec/dist/living-spec.mjs" node --test tools/living-spec/test/cli.test.ts tools/living-spec/test/render.test.ts  # ビルドした物で入口の試験を走らせる
```

`dist/` は追跡しない。`npm i -D` で入れたリポジトリはこの置き場への symlink を持つため、`src/` を直して build し直せば、入れた側にもそのまま効く。

## 試験の置き方

試験は2層に分ける。

- **規則の分岐（`test/rules.test.ts`、件は `test/cases/<規則>.ts`）**: 1件ごとに、その判定に要る表・要求票・例だけを、根からの相対パス → 中身の対応で渡す（表のファイルが無ければ空の表として扱う）。ファイルは置かず、読み込みを外した判定（`checkSources`）を呼ぶ。期待する違反の (rule, file, target) の集合と完全一致を見る。通る件（`pass-`）と落ちる件（`fail-`）を規則ごとに1件以上置き、落ちる件はその規則の違反だけが出る入力にする。各件の直前に、何を確かめる件かを1行で書く
- **読み込みから出力までのつながり（`test/examples.test.ts`、見本は `examples/<規則>/<pass|fail>-<名前>.txtar`）**: 規則ごとに通る1件・落ちる1件を、表一式を置いたリポジトリの形で持つ。1件の根に置くファイル（`expected.yaml` と `docs/rdra/*.yaml` 等）を `-- <根からのパス> --` の行で区切って1つのテキストに束ね、`test/fixture.ts` で一時ディレクトリへ展開してから、置き場から読む入口（`checkRepo`）を走らせる

規則の分岐を足すときは `test/cases/` に件を足す。見本は、置き場の読み方や違反の出力の形を変えたときに直す。

2層に分けたのは、すべての分岐を表一式を置いたリポジトリの形で持つと、件ごとに表を丸ごと写すことになり量が膨らむため（115件で約7千行。分けた後は件が約2.3千行、見本が約2千行）。却下: 見本を1件ずつ要る記録だけに削る（読み込みを通すために残る記録が増え、ファイルを置かない形より長い）、規則ごとに代表の数件へ減らす（分岐の網羅が落ちる）。

手で見本を展開して見るとき: `node tools/living-spec/test/fixture.ts <見本.txtar> <展開先>`
