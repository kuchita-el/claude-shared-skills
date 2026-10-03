# 提案書の形式の出所

本スキルの構成が借りている既知の形式と、一次情報の所在。引用は原文のまま（英語は 50 語以内）。確認日は 2026-10-03。

| 形式 | 借りる要素 | 一次情報 | 引用 |
|---|---|---|---|
| Google 式 Design Doc（Malte Ubl による記述。Google の公式文書ではない） | Context and scope → The actual design → Alternatives considered の骨格。前提は簡潔に、詳細はリンクへ。却下案の節を最重要の一つと位置づける | https://www.industrialempathy.com/posts/design-docs-at-google/ | "Keep it succinct! The goal is that readers are brought up to speed but some previous knowledge can be assumed and detailed info can be linked to." ／ "this section is one of the most important ones as it shows very explicitly why the selected solution is the best given the project goals" |
| 公用文作成の考え方（文化審議会建議、2022年1月） | 結論を最初の段落に。具体例・細目は後ろへ、量が多ければ別添へ | https://www.bunka.go.jp/seisaku/bunkashingikai/kokugo/hokoku/pdf/93651301_01.pdf （解説 p.34） | 「最後まで読まないと何を言おうとしているか分からないような書き方は避ける。」「具体例、細目等は、後に示すか、分量が多くなるようであれば別途添えるなどの工夫をする。」 |
| BLUF（米陸軍 AR 25-50、2020年10月版） | 要点を文書の冒頭に。本文は 1 頁、追加情報は添付へ | https://www.maine.gov/dvem/policies/documents/AR%2025-50%20(10%20October%202020).pdf （州政府サイト掲載の写し） | 1-38b "putting the main point at the beginning of the correspondence (bottom line up front)" ／ 1-39b(7) "Write one-page letters and memorandums for most correspondence. Use enclosures for additional information." |
| PEP 1（Python Enhancement Proposal の規程） | 却下した案を理由とともに記録する。同じ案の再提起を防ぐ | https://peps.python.org/pep-0001/ | "Those rejected ideas should be recorded along with the reasoning as to why they were rejected." |
| KEP（Kubernetes Enhancement Proposal の雛形） | 却下案は提案ほど詳細でなくてよい | https://github.com/kubernetes/enhancements/blob/master/keps/NNNN-kep-template/README.md | "What other approaches did you consider, and why did you rule them out? These do not need to be as detailed as the proposal" |
| MADR（Markdown Any Decision Records） | 前提 → 選択肢 → 採択と理由 → 各案の長短 → 追加の根拠 | https://github.com/adr/madr/blob/develop/template/adr-template.md | "Chosen option: "{title of option 1}", because {justification…}" ／ "provide additional evidence/confidence for the decision outcome here" |
| 推奨報告書の層構造（MIT Sloan 15.279 Management Communication、2012） | 付録は本筋の理解に不要だが一部の読者に有用な資料。調査票・計算が典型 | https://ocw.mit.edu/courses/15-279-management-communication-for-undergraduates-fall-2012/f9832deb801447ad8638a5291c355bbf_MIT15_279F12_wrtngReports.pdf | "Each appendix contains material not necessary to understanding the main line of the analysis but potentially interesting or useful to some part of the audience." |
| Policy memo（Harvard Kennedy School） | 第 1 段落に問題と解決策（Bottom Line Upfront）。選択肢の比較と却下 | https://www.hks.harvard.edu/sites/default/files/Academic%20Dean%27s%20Office/communications_program/digital_resources/REV%202026_how_to_pol_mem.pdf | "In the first paragraph, it is customary to state the problem and solution, called your Bottom Line Upfront." |
| Minto の Pyramid Principle | 結論を頂点に、根拠を下へ。導入は SCQ（状況・複雑化・問い） | https://www.barbaraminto.com/concept | "Communicating the thinking requires only that you guide the reader down the pyramid." |

## 対応の見取り図

| 指示の要素 | 最も明文で述べる形式 | 次点 |
|---|---|---|
| 結論先行 | 公用文作成の考え方、BLUF | HKS policy memo |
| 前提 → 提案 | Design Doc、MADR | ADR（Nygard 原型） |
| 却下した代替案と理由を本文に残す | PEP 1「Rejected Ideas」 | KEP、Design Doc、MADR |
| 調査の過程・資料を付録へ | MIT Sloan の層構造 | AR 25-50（enclosure）、公用文作成の考え方（別添） |

## 借りなかったもの

- Nygard の原型 ADR（Context / Decision / Consequences）: 却下案の節が無い。決定後の記録様式であり、採否を仰ぐ文書の骨格には足りない。
- Amazon の 6-pager: 本文 6 頁と付録の慣行は二次情報でしか確認できなかった。株主書簡（2017）で確認できるのは "narratively structured six-page memos" まで。
- PREP 法・稟議書・起案書の定型: 一次情報を確認できなかった。

## 確認の区分

- 本リポジトリの作業でページを開いて照合: Design Doc、PEP 1、公用文作成の考え方、MIT Sloan。
- 調査担当（サブエージェント）が開いて照合し、本体は引用の整合だけを確認: AR 25-50、KEP、MADR、HKS、Minto、Amazon、Nygard。
