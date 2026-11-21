---
# サブエージェントの実効の model。ケースの model は sonnet なので、opus の系列が trace に出るのは、
# 定義の front-matter（model: opus）が効いたときだけである。effort は trace に出ないので、ここでは見ない
type: regex
target: trace
pattern: '"model"\s*:\s*"claude-opus'
---
