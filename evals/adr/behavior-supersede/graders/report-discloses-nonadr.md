---
# adr-01: 対象 ADR 以外への変更（または変更しなかったこと）を黙って済ませず報告した（SKILL.md:23「別判断を黙って混ぜない」）
# related/nonadr の各採点器と組み合わせ、付け替えた／黙って飛ばした／保留して報告した、を区別する
type: llm
---

The workspace contains a non-ADR document at docs/architecture.md that cites ADR-202608011000-01-jwt-auth. Judge only the final response text.

PASS if the final response names docs/architecture.md (or architecture.md) AND states one of the following about it: that its reference was changed to ADR-202609201000-01-session-cookie-auth, that it was deliberately left unchanged (with any reason), or that it is left for the user to decide.

FAIL if the final response does not name docs/architecture.md or architecture.md at all.
