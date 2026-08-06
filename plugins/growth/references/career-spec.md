# キャリア軸（配布先媒体）仕様

growth プラグインの学習ループが仮説へ付与する `career-hypothesis` の**軸**を定義する。キャリアの値域、強キャリアの内訳（機構強制／モデル媒介）、および空間軸との関係を、配布物内の単一出典として持つ。

## 位置づけ

- 本仕様が定義するのは**キャリア軸そのもの**（値域と各値の意味、強キャリア内部の区別）である。仮説をどのキャリアへ振り分けるかの**判定表**は [`distill-procedure.md`](../skills/distill/references/distill-procedure.md)（「career-hypothesis の判定（決定表）」）を単一出典とし、本仕様は複製しない。
- 仮説のメタ欄としての書式（`<career> / repo: <宛先 repo 仮説>` の1行）とスキーマは [`personal-store-spec.md`](personal-store-spec.md)（`career-hypothesis`）が持つ。
- distill が付与するキャリアは**仮説**であり確証しない。キャリアと宛先 repo の最終裁定は集約点（取り込み Issue）が担う（ADR-202606282107-01）。

## キャリアの値域

学びを載せる先は4種のキャリア（配布先媒体）に分かれる。

| キャリア | 配布先媒体 | 性質 |
|---|---|---|
| 強キャリア | hook / lint / test / 型 / CI・skill / CLAUDE.md | テキスト規範より強い構造的キャリア。`learnings.md` には載らず、テキスト規範から除去される（畳み込みの移送先） |
| 改善還元 | 当該 repo への Issue / PR | 任意プラグイン／コミュニティの改善（dev-workflow に限らない） |
| ADR 差分 | ADR ファイル | 判断知（decision-record）を設計判断の記録として配布 |
| `learnings.md` | growth 学び置き場 | テキスト規範として配布される最も弱いキャリア |

## 強キャリアの内訳（機構強制／モデル媒介）

強キャリアの値域は、強制の性質によって 2 群に分かれる。

| 群 | 値 | 強制の性質 |
|---|---|---|
| **機構強制** | hook / lint / test / 型 / CI | モデルの裁量外で機械的に強制・検出する「二度と起こせない構造」 |
| **モデル媒介** | skill / CLAUDE.md | 構造化された指示だが、遵守は確率的 |

- 両群はいずれも**強キャリア**であり、決定表 行1 の出力キャリアは同一である。区別は強制の確実性にあり、キャリアの値を分けるものではない。
- 決定表 行1 が「強キャリアへ構造変換可能か」を判定する際、変換先が機構強制とモデル媒介のいずれであっても行1 に合致する。
- 本節の値域を再掲している箇所は [`distill-procedure.md`](../skills/distill/references/distill-procedure.md) の決定表 行1 のみである（決定表を読みながら評価する動線を切らないため、当該セルにのみ再掲を許す）。値域を変える際はそこも併せて追随させる。

## 空間軸との関係（キャリア軸 ⊥ 空間軸）

キャリア軸（昇格先＝何の成果物へ配るか）は、共有境界を表す空間軸（`universal` / `project-local`）と**直交する**独立軸である。同じ `learnings.md` 行きの仮説でもパブリック空間と閉じた空間に分かれうるため、`career-hypothesis` と `scope-hypothesis` は対称・独立な 2 メタ欄として持つ。空間軸の値域と 2 空間の実体は [`learning-store-spec.md`](learning-store-spec.md)（「2空間モデル」）が定義する。

## 関連

- [`distill-procedure.md`](../skills/distill/references/distill-procedure.md) — 4 分類の判定表（「career-hypothesis の判定（決定表）」）の単一出典。本仕様は判定表を持たない
- [`personal-store-spec.md`](personal-store-spec.md) — `career-hypothesis` のメタ欄スキーマ・書式・provenance 規約
- [`learning-store-spec.md`](learning-store-spec.md) — 空間軸（2空間モデル）の定義。本仕様のキャリア軸と直交する
