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

## 見本

`examples/<規則>/<pass|fail>-<名前>.txtar` が1件の見本。1件の根に置くファイル（`expected.yaml` と `docs/rdra/*.yaml` 等）を、`-- <根からのパス> --` の行で区切って1つのテキストに束ねてある。試験は `test/fixture.ts` で一時ディレクトリへ展開してから検査器を走らせ、違反の (rule, file, target) の集合が `expected.yaml` と完全一致するかを見る。規則ごとに通る見本と落ちる見本を1件以上置く。見本の語は経費精算の題材のまま。

束ねたのは、見本ごとに表を全部写すとファイル数が膨らみ（115件で約920ファイル）、差分も読みにくいため。却下: 共通の土台の表に見本ごとの差分だけを重ねる形（ファイル数は減るが、1件の見本を読むのに土台と重ね合わせる必要があり、土台を直すと多くの見本の意味が黙って変わる）。

手で展開して見るとき: `node tools/living-spec/test/fixture.ts <見本.txtar> <展開先>`
