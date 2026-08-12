# Plugin boundary decision

Wave 4 の分離判定台帳。候補ごとに全7項目を評価し、全項目合格と承認が揃った場合だけ `split` とする。

```boundary-decision-json
{
  "candidates": [
    {"id":"domain-design","skills":["event-storming","domain-modeling"],"checks":[
      {"id":"referenceDepthOne","value":"pass","evidence":["plugins/dev-workflow/skills/event-storming/SKILL.md"]},{"id":"distributionReferencesResolve","value":"pass","evidence":["plugins/dev-workflow/skills/event-storming/references"]},{"id":"noSourceDataDependency","value":"pass","evidence":["plugins/dev-workflow/skills/domain-modeling/SKILL.md"]},{"id":"definitionsSelfContained","value":"pass","evidence":["plugins/dev-workflow/skills/event-storming/SKILL.md"]},{"id":"noAgentDependency","value":"pass","evidence":["plugins/dev-workflow/skills/domain-modeling/SKILL.md"]},{"id":"noSharedRuleCopy","value":"pass","evidence":["docs/behavior-invariants.md"]},{"id":"isolatedFixturePass","value":"pass","evidence":["scripts/fixtures/plugin-boundaries/domain-design/isolated-expected.json"]}],"decision":"split","approval":{"id":"J1","status":"approved"}},
    {"id":"dependency-insight","skills":["dependency-check"],"checks":[
      {"id":"referenceDepthOne","value":"pass","evidence":["plugins/dev-workflow/skills/dependency-check/SKILL.md"]},{"id":"distributionReferencesResolve","value":"pass","evidence":["plugins/dev-workflow/skills/dependency-check/references"]},{"id":"noSourceDataDependency","value":"pass","evidence":["plugins/dev-workflow/skills/dependency-check/SKILL.md"]},{"id":"definitionsSelfContained","value":"pass","evidence":["plugins/dev-workflow/skills/dependency-check/SKILL.md"]},{"id":"noAgentDependency","value":"pass","evidence":["plugins/dev-workflow/skills/dependency-check/SKILL.md"]},{"id":"noSharedRuleCopy","value":"pass","evidence":["docs/behavior-invariants.md"]},{"id":"isolatedFixturePass","value":"pass","evidence":["scripts/fixtures/plugin-boundaries/dependency-insight/isolated-expected.json"]}],"decision":"split","approval":{"id":"J2","status":"approved"}}
  ],
  "graph": [
    {"candidate":"domain-design","path":"plugins/dev-workflow/skills/domain-modeling/SKILL.md","direction":"outbound","target":"plugins/dev-workflow/skills/domain-modeling/references/domain-model-notation.md"},
    {"candidate":"domain-design","path":"plugins/dev-workflow/skills/domain-modeling/SKILL.md","direction":"outbound","target":"plugins/dev-workflow/skills/domain-modeling/references/domain-modeling-flow.md"},
    {"candidate":"domain-design","path":"plugins/dev-workflow/skills/event-storming/SKILL.md","direction":"outbound","target":"plugins/dev-workflow/skills/event-storming/references/big-picture-flow.md"},
    {"candidate":"domain-design","path":"plugins/dev-workflow/skills/event-storming/SKILL.md","direction":"outbound","target":"plugins/dev-workflow/skills/event-storming/references/big-picture-template.md"},
    {"candidate":"domain-design","path":"plugins/dev-workflow/skills/event-storming/SKILL.md","direction":"outbound","target":"plugins/dev-workflow/skills/event-storming/references/design-level-flow.md"},
    {"candidate":"domain-design","path":"plugins/dev-workflow/skills/event-storming/SKILL.md","direction":"outbound","target":"plugins/dev-workflow/skills/event-storming/references/event-storming-template.md"},
    {"candidate":"dependency-insight","path":"plugins/dev-workflow/skills/dependency-check/SKILL.md","direction":"outbound","target":"plugins/dev-workflow/skills/dependency-check/references/npm.md"}
  ]
}
```
