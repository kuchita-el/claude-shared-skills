# Team migration ledger

```migration-ledger-json
{
  "migrations":[
    {"oldPluginId":"dev-workflow","newPluginId":"dev-workflow","movedSkills":["create-issue","refine-issue","plan-issue","implementation"],"oldEntryAction":"retain","installCommand":"codex plugin add dev-workflow@claude-shared-skills","rollback":"restore the pre-cutover commit"},
    {"oldPluginId":"dev-workflow","newPluginId":"domain-design","movedSkills":["event-storming","domain-modeling"],"oldEntryAction":"retain","installCommand":"codex plugin add domain-design@claude-shared-skills","rollback":"restore the pre-cutover commit"},
    {"oldPluginId":"dev-workflow","newPluginId":"dependency-insight","movedSkills":["dependency-check"],"oldEntryAction":"retain","installCommand":"codex plugin add dependency-insight@claude-shared-skills","rollback":"restore the pre-cutover commit"}
  ],
  "releasePlugins":[
    {"id":"dev-workflow","skills":["create-issue","refine-issue","plan-issue","implementation"],"version":"0.10.0"},
    {"id":"growth","skills":[],"version":"0.2.2"},
    {"id":"adr","skills":[],"version":"0.3.1"},
    {"id":"writing","skills":[],"version":"0.2.1"},
    {"id":"domain-design","skills":["event-storming","domain-modeling"],"version":"0.1.0"},
    {"id":"dependency-insight","skills":["dependency-check"],"version":"0.1.0"}
  ],
  "users":[{"name":"team-user","claude":{"status":"confirmed","version":"local","evidence":"scripts/tests/team-migration.bats"},"codex":{"status":"confirmed","version":"local","evidence":"scripts/tests/team-migration.bats"},"pluginVersions":{"dev-workflow":"0.10.0","domain-design":"0.1.0","dependency-insight":"0.1.0"},"status":"confirmed"}],
  "approvals":{"J1":"approved","J2":"approved"},
  "releaseNotes":[
    {"pluginId":"dev-workflow","reason":"Wave 4 approved boundary migration","oldVersion":"0.10.0","newVersion":"0.10.0","compatibility":"compatible","breakingChanges":"none","rollback":"restore the pre-cutover commit","evidence":"scripts/tests/team-migration.bats"},
    {"pluginId":"domain-design","reason":"new split plugin","oldVersion":"none","newVersion":"0.1.0","compatibility":"new-plugin","breakingChanges":"none","rollback":"restore the pre-cutover commit","evidence":"scripts/tests/team-migration.bats"},
    {"pluginId":"dependency-insight","reason":"new split plugin","oldVersion":"none","newVersion":"0.1.0","compatibility":"new-plugin","breakingChanges":"none","rollback":"restore the pre-cutover commit","evidence":"scripts/tests/team-migration.bats"},
    {"pluginId":"growth","reason":"existing plugin retained","oldVersion":"0.2.2","newVersion":"0.2.2","compatibility":"compatible","breakingChanges":"none","rollback":"restore the pre-cutover commit","evidence":"scripts/tests/team-migration.bats"},
    {"pluginId":"adr","reason":"existing plugin retained","oldVersion":"0.3.1","newVersion":"0.3.1","compatibility":"compatible","breakingChanges":"none","rollback":"restore the pre-cutover commit","evidence":"scripts/tests/team-migration.bats"},
    {"pluginId":"writing","reason":"existing plugin retained","oldVersion":"0.2.1","newVersion":"0.2.1","compatibility":"compatible","breakingChanges":"none","rollback":"restore the pre-cutover commit","evidence":"scripts/tests/team-migration.bats"}
  ]
}
```
