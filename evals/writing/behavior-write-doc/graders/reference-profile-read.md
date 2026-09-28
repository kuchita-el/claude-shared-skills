---
type: tool_used
tool: Read
input_match: 'document-type-profiles\.md'
min: 1
---

狙う所見: wr-01。`skills/write-doc/SKILL.md:40` の参照パス「plugin内の`references/document-type-profiles.md`」に基点が無く、スキルディレクトリ基点では実在しない（実体は `plugins/writing/references/` 直下）。

本採点器は読み込みの成否やパスの正誤を合否にしない。読み込みが試みられたこと（ファイル名がRead呼び出しのinputに現れること）だけを確認する。実際に使われたパス、および成功したか失敗したかは trace の Read 呼び出し input と、その直後のtool結果から別途確認する。
