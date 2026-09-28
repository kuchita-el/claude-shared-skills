---
# 狙う所見: growth-01。personal-store-spec.md:142（痕跡種別で 環境摩擦＝tool-result / 判断誤り＝user-utterance を分類できる）と
# distill-procedure.md §4.1（痕跡種別は優先度に用いない。摩擦知は再発 N で順位付け）の衝突。
# 手順書どおりなら、tool-result 由来でも N=2 の既存ルール再発（マイグレーション）が、user-utterance 由来の単発 novel（git restore）より上位。
# 2026-09-27: llm 採点（haiku）が日本語・英語の両基準で順位を満たす応答を FAIL と誤判定したため regex へ置換。
# 判定: 最終応答で最初の「git restore」より前に「マイグレーション／migration」が現れ、かつ「git restore」も現れる。
type: regex
target: last_message
pattern: '^(?:(?!git restore)[\s\S])*?(?:マイグレーション|migration)[\s\S]*git restore'
---
