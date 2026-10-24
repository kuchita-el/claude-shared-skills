# tools/living-spec

`plugins/living-spec/scripts/living-spec.mjs`（living-spec プラグインの検査器と描画）の正本と、その工場側の試験。配布物は生成物の `living-spec.mjs` だけで、この置き場は配布しない。

書式と検査の規則の正本は `plugins/living-spec/references/format.md`。表のキーと置き場の既定は `src/schema.ts` が持つ。

## 由来

開発方式の試行（非公開の試行リポジトリ `tools/rdra-check`、2026-10-13 時点）から、RDRA の表・要求票・例の3層の検査と描画を切り出した。試行で持っていた1枚資料の層（`one-pager-mismatch`）とコードとの照合（`code-coined-name`・`code-missing-name`）は外した。前者は取り組みごとのフローの資料を恒久の表と照合する形の扱いが、後者は特定の置き場と識別子の規約への結合が、汎用の配布物として決まっていないため。

## 作業

```bash
pnpm --dir tools/living-spec install --frozen-lockfile
pnpm --dir tools/living-spec test     # 規則ごとの見本（examples/）の照合・入口・描画
pnpm --dir tools/living-spec build    # plugins/living-spec/scripts/living-spec.mjs を作り直す
RDRA_ENTRY="$PWD/plugins/living-spec/scripts/living-spec.mjs" node --test tools/living-spec/test/cli.test.ts tools/living-spec/test/render.test.ts  # 生成物で入口の試験を走らせる
```

`src/` を直したら build し、生成物を同じコミットに入れる。生成物の終了コードの契約は `scripts/tests/living-spec-bundle.bats` が runner の中で見る。

## 見本

`examples/<規則>/<pass|fail>-<名前>/` が1件の根。`expected.yaml` に期待する違反の (rule, file, target) を並べ、試験は集合の完全一致を見る。規則ごとに通る見本と落ちる見本を1件以上置く。見本の語は経費精算の題材のまま。
