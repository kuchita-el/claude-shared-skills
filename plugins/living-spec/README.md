# living-spec plugin

決めた仕様を、変更のたびに検査され描き直される「生きた正本」として保つプラグインです。人が決めたことが一つの矛盾の無い正本に残り続け、いつでも全体を見て確かめられる状態を目指します。

いまは要求の3層（RDRA の表・要求票・例）を扱います。要求を構造化し、整合を機械検査し、規則間の矛盾を独立文脈で突き合わせ、状態遷移図と UC ごとの縦串を1枚の HTML に描きます。画面仕様・設計など他の層は、同じ正本と検査の形で後から足す想定です。
書式・置き場・検査の規則の正本は `references/format.md` です。

## 配布物

- `skills/structure/SKILL.md`: 要求を表→要求票→例へ写し、機械検査と突き合わせを通して終えます。
- `skills/crosscheck/SKILL.md`: 規則間の矛盾・条件の食い違い・状態遷移の抜けを報告します（直しません）。
- `skills/view/SKILL.md`: 可視化を描き、開き方を示します。
- `agents/rule-crosschecker.md`: 表・票・例を初見で読み、矛盾を `id,severity,evidence,why,suggestion` で返します。
- `scripts/run.mjs`: 検査器を探して呼ぶ中継（`check [--doc-missing] [根]`・`render [根]`・`hook`）。依存を持ちません。検査器そのものはプラグインに含めません（下の「検査器の導入」）。
- `hooks/hooks.json`: 表・票・例の編集の後に全体検査と描き直しを走らせる PostToolUse フック。
- `references/templates/`: 要求票と例の雛形。

## 検査器の導入

検査器と描画は、プラグインと分けて、利用するリポジトリが持つ道具として入れます。いまはソースからビルドします。

```bash
# claude-shared-skills のチェックアウトで
pnpm --dir tools/living-spec install --frozen-lockfile
pnpm --dir tools/living-spec build          # tools/living-spec/dist/living-spec.mjs ができる

# 利用するリポジトリで（どちらか）
npm i -D <claude-shared-skills>/tools/living-spec    # package.json に入れ、CI からも npx living-spec check で走らせる
export LIVING_SPEC_BIN=<claude-shared-skills>/tools/living-spec/dist/living-spec.mjs   # リポジトリに入れずに使う
```

中継は `LIVING_SPEC_BIN`、次に根から解決できるパッケージ `@kuchita-el/living-spec` の順に探します。見つからなければ、フックは何もせず、スキルからの呼び出しは導入の手順を出して止まります。

## 前提

- Node 22 以上（22.23・24.16 で確かめています）。ビルドには pnpm が要ります。
- 可視化の図は Mermaid を jsdelivr から読むため、表示にネットワークが要ります。

## 契約

- 終わりの判定は、機械検査の違反0件と、突き合わせの blocker 0件の両方です。
- 置き場は根の `.living-spec.json` で変えられます。表の置き場が無いリポジトリでは、フックは何もしません。
- フックは違反があると終了コード 2 で AI へ違反を返し、直させます。止めたくなければ `.living-spec.json` の `hook` を `false` にします。
- 可視化の HTML は派生物です。手で直さず、`.gitignore` へ入れます。

## host 差分

- Claude Code: スキル・エージェント・フックのすべてが動きます。
- Codex: スキルと検査器は動きます。plugin 単位のフックが無いため、編集ごとの自動検査と描き直しはありません。スキルの手順どおり `node scripts/run.mjs check` と `render`（または導入した検査器の `living-spec check` と `render`）を明示的に実行します。突き合わせのエージェントが使えない場合は、別の会話で `agents/rule-crosschecker.md` の指示を与えて実行します。

## 機械検査が見ないもの

意味の正しさ（規則どうしの論理の矛盾、業務として正しいか）は機械検査の外です。突き合わせと人の確認に残ります。
