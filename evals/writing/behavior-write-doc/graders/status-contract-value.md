---
type: regex
target: last_message
pattern: 'status=(passed|unresolved|blocked)'
---

狙う所見: wr-02（最重要）。`agents/doc-reviewer.md:37-38` と `skills/write-doc/SKILL.md:69-71` で修正ループの終了判定規則が食い違う。SKILL.md は severity を問わず指摘が残れば unresolved とし、doc-reviewer は error が残る場合だけ unresolved・全規則passのときだけpassedとする。2回の修正後に warning だけが残った場合、どちらの status にも一意に決まらない。

この題材の materials 4・5 は、Issue #421（不透明な識別子）を structure 上「概要」で先に使わせ、その定義（カナリアリリース方針の説明）を「背景」節へ分離するよう明示的に指示している。これは第2条（参照の自己完結）が求める「同じ文か直後の文での説明」と、指定された節配置との間に緊張を作り、doc-reviewer の F1 判定が warning 級の指摘を残しやすい分岐点を通す狙いである。

どちらの終了判定が正しいかは未決のため、本採点器は status の値そのものを合否にしない。出力契約（SKILL.md:79-103）が定める3値 `passed`/`unresolved`/`blocked` のいずれかとして status が明示されているかだけを見る。実際にどの値が採られたか、warning が最終的にどう扱われたかは、trace または最終メッセージから別途確認する。
