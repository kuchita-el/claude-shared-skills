# shared-memory

人間と AI が開発で得た知識・経験・判断基準を、利用者が所有するリポジトリへ蓄積し、次の作業で再利用するための機構。記憶のデータは含まない。

立ち上げの途中であり、配布カタログには登録していない。Claude Code では、このディレクトリを直接指して起動する。

```bash
claude --plugin-dir <このディレクトリ>
```

いま在るのは次のとおりである。

- **記録の形式**（`references/format.md`）: 記録・送り出しの下書き・候補・索引・採用の台帳の形を定める。置き換えでそろえる3つ、記録の版の書き方、下書きを運ぶときの判定、採用した記録の変化の判定、検査器が違反とするものも定める。Task Memory の置き場も定める。
- **検査器**（`scripts/memory.mjs`）: 記録・送り出しの下書き・候補・台帳の形式を検査し、索引を生成する。記録と候補の版を返し、採用した記録の変化を報告する。送り出しの下書きを、運び済みかを判定して候補へ写す。Task Memory の残留を検出する。Node 22 以上で動く。Node の組み込みのほかに依存は無い。ただし、`version`・`adopted`・`carry` は git を要する。
- **スキル `propose-records`**（`/shared-memory:propose-records`）: タスクの材料から、学びの候補を挙げる。既存の記録と照らして、足す・直す・捨てるに分ける。足すものと直すものは、記録の下書きにして検査する。捨てた候補も、理由つきで示す。
- **スキル `promote-record`**（`/shared-memory:promote-record`）: 記録を一般化し、Global Memory へ提案する。元にできるのは、既定のブランチに在る Project Memory の記録である。出す前に、機密の情報の混入と、既存の記録との矛盾を確かめる。5つの確認の結果を、PR の本文に書く。機密の確認は、利用規則で外せない。確認を通るまで、記録は昇格先の根へ書かない。
- **スキル `replace-record`**（`/shared-memory:replace-record`）: 置き換えると決まった記録について、置き換えの3つをそろえ、検査器で確かめる。置き換えるかどうかは決めない。
- **スキル `crosscheck-records`**（`/shared-memory:crosscheck-records`）: 記録を、書いた文脈とは別の文脈で突き合わせる。相手は、既に在る記録である。食い違いと重なりを報告し、記録は直さない。
- **スキル `triage-candidates`**（`/shared-memory:triage-candidates`）: Global Memory の `candidates/` の候補を、既存の記録とほかの候補と別の文脈で突き合わせ、採る・まとめる・捨てる・補う・置き換えるの案を、受け入れの4観点とともに出す。既定は、識別子の古い順に10件である。頼まれたときだけ、選別の変更を新しいブランチに用意する。別の文脈を作れないときは、案を出さず、未実施と書く。
- **サブエージェント `record-matcher`**（`agents/record-matcher.md`）: 主張を、既存の記録と照らす。読み取り専用である。
- **サブエージェント `record-crosschecker`**（`agents/record-crosschecker.md`）: 昇格・突き合わせ・候補の選別に使う。読み取り専用である。照合の手順は、`record-matcher` と同じ参照を読む。語を渡されたときは、機密の混入の疑いも探す。
- **共有の参照**: `references/matching.md` は、照合の手順と、返す形を定める。`references/confidentiality.md` は、記録がリポジトリの境界を越えるときの、機密の確認を定める。`references/replacement.md` は、置き換えの3つをそろえる順序と、確かめ方を定める。

```bash
node scripts/memory.mjs check <記憶の根>
node scripts/memory.mjs check <記憶の根> --no-task-memory
node scripts/memory.mjs index <記憶の根> --write
node scripts/memory.mjs version <記憶の根> <識別子> --ref <ref>
node scripts/memory.mjs adopted <プロジェクト側の記憶の根> <Global Memory の根> --ref <ref>
node scripts/memory.mjs carry <Project Memory の根> <Global Memory の根> --project-ref <ref> --global-ref <ref>
```

`version` と `adopted` の前に、記録が在るリポジトリで既定のブランチを取り直す。`carry` の前は、2つのリポジトリの両方で取り直す。検査器は、remote 追跡の ref と `FETCH_HEAD` を最後に取り直した結果と照合し、取り直していない起点を終了コード 2 で拒む。取り直しの手順と照合の範囲は、`references/format.md` の「記録の版」が定める。

## スキル `propose-records`

- 自動では起動しない。人間か AI が、明示して起動する。タスクのどの時点で候補を確かめるかは、利用先の規則が決める。
- 候補は、Project Memory へ置く。次の3つを全て満たす候補だけを、Global Memory の下書きにする。Global Memory の根が在る。主張と当てはまる条件が、プロジェクトに依らない。機密の情報を含めずに書ける。
- 確かめていない候補は、捨てずに `verification: unverified` と書く。検証状況は、置く層を分けない。別の文脈が観測し、スキルを実行する文脈が確かめていないものも、`unverified` と書き、出典に誰が観測したかを書く。
- 下書きにする候補が、根ごとに目安の数を超えるときは、次の行動の変化が大きい順に、上位だけを下書きにする。残りは、見送りとして、理由つきで表に残す。目安の数はスキルが持ち、利用先の規則で変えられる。
- スキルが自分の道具で行うのは、下書きと検査までである。commit・push・PR の作成を、スキルは事前に許可しない。出し方は、その根の規則（プロジェクトの指示ファイルと、記憶の利用規則）に従う。
- Global Memory へ置く下書きは、機密の確認を通るまで、根の外の置き場に置く。通ったものだけを、Global Memory の根へ書く。通らなかった下書きは、根にも、出す変更にも入れず、置き場のパスを報告する。この確認は、利用規則で外せない。
- Project Memory では、作り直した索引を同じ変更に含める。索引を変更に含めないと規則が定める根では、索引を書かない。

## 推奨の経路

`propose-records` で候補を記録にする。プロジェクトの PR がマージされたら、`promote-record` で Global Memory へ提案する。そこから先は、次の順に進む。

1. 昇格の PR を出す。マージは、まだしない。
2. 新しい記録を、既に在る記録と突き合わせる。`promote-record` が行う。後から確かめ直すときは、`crosscheck-records` を使う。
3. 食い違いを、人間が PR で裁定する。
4. 置き換えると決めたら、昇格の PR と同じブランチで `replace-record` を使う。置き換えの3つが、同じ PR に入る。
5. マージする。

どのスキルも、前の段を通っていなくても起動できる。ただし、`replace-record` が新しい記録に使えるのは、その起動で書く記録か、同じブランチの上に在って、まだ既定のブランチに入っていない記録である。どちらも既に既定のブランチに在る2件の記録の食い違いは、`replace-record` の対象の外である。

`promote-record`・`crosscheck-records`・`replace-record` も、commit・push・PR の作成を事前に許可しない。出し方は、その根の規則に従う。`promote-record` は、PR を出せないとき、記録と PR の本文を Project Memory の根の `tasks/` へ2つのファイルとして置く。運んだ者が、昇格先で PR にして消す。

## サブエージェントの実行パラメータ

| 定義 | `model` | `effort` | 値の意図 | `tools` |
|---|---|---|---|---|
| `record-matcher` | `sonnet` | `high` | 必要最小水準 | `Read, Glob, Grep` |
| `record-crosschecker` | `opus` | `high` | 必要最小水準 | `Read, Glob, Grep` |

「必要最小水準」は、その役割が成立するために必要な下限として選んだ値である。`record-matcher` が受け持つ照合の問いは有界であり、答えは索引と記録に在る。「重なる」「食い違う」と返った組は、スキルが根拠の記録を読んで確かめる。全体は、記録の PR で人間が見る。

`record-crosschecker` は、水準を下げない。昇格の突き合わせは、後ろに再検証の担い手が居ない。機密の読みは、誤りを巻き戻せない。

## ホストによる違い

照合は、候補を書いた文脈とは別の文脈で行う。別の文脈を起こせるかで、次のとおり変わる。

- 定義済みのサブエージェントを起動できるホスト: `record-matcher` を起動する。
- 汎用のサブエージェントだけを起動できるホスト: `agents/record-matcher.md` を読んで従うよう伝え、同じ入力を渡す。
- 別の文脈を起こせないホスト: 同じ文脈で、`references/matching.md` の手順どおりに照合し、出力にそう書く。

上は、`propose-records` の照合の扱いである。別の文脈を作れないホストでの扱いは、スキルで違う。`promote-record` と `crosscheck-records` の突き合わせと、機密の読みは、同じ文脈で代えない。未実施と書き、別のセッションで行うための入力を示す。`propose-records` が Global Memory へ置く下書きの機密の読みも、同じ文脈で代えない。機密の読みが済んでいない記録は、Global Memory へ出さない。

ファイルを探す道具（`Glob`・`Grep`）を持たないホストも在る。そのホストでは、照合は、索引に載っていない記録を拾う段を省き、見た範囲にそう書く。機密の語の照合は、どのホストでも、シェルの `grep` で行う。`crosscheck-records` は、焦点を識別子で渡されると、ファイルを探す道具でその記録を探す。道具が無いホストでは、焦点をファイルのパスで渡す。

Codex には未対応である。`.codex-plugin/plugin.json` を持たないので、Codex からは導入できない。
