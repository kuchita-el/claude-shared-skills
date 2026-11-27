---
# プロジェクトに依らない候補を、Global へ送り出す下書きにした（SKILL.md 手順4 の層の条件）
type: llm
---

The work memo contains a learning about a general tool behavior: `uniq -c` pads the count with leading spaces, so `cut -d' ' -f1` yields empty values. It does not depend on this project's code, configuration, conventions, or decisions. A Global Memory root (global-memory) is attached. Judge only the final response text.

PASS if the final response treats this learning as added (足す) to the Global layer as an outgoing draft (送り出し), and gives its draft path under docs/memory/outbox/.

FAIL if the final response puts this learning only in the Project layer, discards it, defers it, or gives a draft path outside docs/memory/outbox/ (for example under global-memory/).
