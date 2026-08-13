# Cross-host plugin team migration ledger

Wave 5の唯一の入力は [`plugin-boundary-decision.md`](plugin-boundary-decision.md) です。Wave 4で `domain-design` と `dependency-insight` が `split` 承認済みのため、両marketplaceとrunnerのrelease集合へ追加します。旧 `dev-workflow` entryは `retain` であり、削除対象にはしません。

利用者確認は推測で補完しません。全利用者のClaude/Codex確認とJ2承認が揃うまで、旧entry削除ゲートは閉じます。

```migration-ledger-json
{
  "migrations":[
    {"oldPluginId":"dev-workflow","newPluginId":"dev-workflow","movedSkills":["create-issue","refine-issue","plan-issue","implementation"],"oldEntryAction":"retain","installCommand":"codex plugin add dev-workflow@claude-shared-skills","rollback":"restore the pre-cutover commit"},
    {"oldPluginId":"dev-workflow","newPluginId":"domain-design","movedSkills":["event-storming","domain-modeling"],"oldEntryAction":"retain","installCommand":"codex plugin add domain-design@claude-shared-skills","rollback":"restore the pre-cutover commit"},
    {"oldPluginId":"dev-workflow","newPluginId":"dependency-insight","movedSkills":["dependency-check"],"oldEntryAction":"retain","installCommand":"codex plugin add dependency-insight@claude-shared-skills","rollback":"restore the pre-cutover commit"}
  ],
  "releasePlugins":[
    {"id":"dev-workflow","skills":["create-issue","refine-issue","plan-issue","implementation"],"version":"0.10.0"},
    {"id":"growth","skills":["capture","distill","intake","promote"],"version":"0.2.2"},
    {"id":"adr","skills":["manage-adr"],"version":"0.3.1"},
    {"id":"writing","skills":["write-doc"],"version":"0.2.1"},
    {"id":"domain-design","skills":["event-storming","domain-modeling"],"version":"0.1.0"},
    {"id":"dependency-insight","skills":["dependency-check"],"version":"0.1.0"}
  ],
  "users":[{"name":"team-user-1","claude":{"status":"confirmed","version":"2.1.231","evidence":"2026-08-14: claude --plugin-dir ./plugins/dev-workflow --plugin-dir ./plugins/growth --plugin-dir ./plugins/adr --plugin-dir ./plugins/writing --plugin-dir ./plugins/dependency-insight --plugin-dir ./plugins/domain-design --help (exit 0)"},"codex":{"status":"confirmed","version":"0.147.0","evidence":"2026-08-14: codex plugin marketplace list; codex plugin list --json (marketplace registered, all six local plugins inspected)"},"pluginVersions":{"dev-workflow":"0.10.0","growth":"0.2.2","adr":"0.3.1","writing":"0.2.1","domain-design":"0.1.0","dependency-insight":"0.1.0"},"status":"confirmed"}],
  "approvals":{"J1":"approved","J2":"approved"},
  "releaseNotes":[
    {"pluginId":"dev-workflow","reason":"Wave 4 approved boundary migration; core entry retained","oldVersion":"0.10.0","newVersion":"0.10.0","compatibility":"compatible","breakingChanges":"none","rollback":"restore the pre-cutover commit","evidence":"team-user-1 confirmed Claude 2.1.231 and Codex 0.147.0 on 2026-08-14"},
    {"pluginId":"growth","reason":"existing plugin retained during Wave 5","oldVersion":"0.2.2","newVersion":"0.2.2","compatibility":"compatible","breakingChanges":"none","rollback":"restore the pre-cutover commit","evidence":"team-user-1 confirmed Claude 2.1.231 and Codex 0.147.0 on 2026-08-14"},
    {"pluginId":"adr","reason":"existing plugin retained during Wave 5","oldVersion":"0.3.1","newVersion":"0.3.1","compatibility":"compatible","breakingChanges":"none","rollback":"restore the pre-cutover commit","evidence":"team-user-1 confirmed Claude 2.1.231 and Codex 0.147.0 on 2026-08-14"},
    {"pluginId":"writing","reason":"existing plugin retained during Wave 5","oldVersion":"0.2.1","newVersion":"0.2.1","compatibility":"compatible","breakingChanges":"none","rollback":"restore the pre-cutover commit","evidence":"team-user-1 confirmed Claude 2.1.231 and Codex 0.147.0 on 2026-08-14"},
    {"pluginId":"domain-design","reason":"new plugin from Wave 4 approved split","oldVersion":"none","newVersion":"0.1.0","compatibility":"new-plugin","breakingChanges":"none","rollback":"restore the pre-cutover commit","evidence":"team-user-1 confirmed Claude 2.1.231 and Codex 0.147.0 on 2026-08-14"},
    {"pluginId":"dependency-insight","reason":"new plugin from Wave 4 approved split","oldVersion":"none","newVersion":"0.1.0","compatibility":"new-plugin","breakingChanges":"none","rollback":"restore the pre-cutover commit","evidence":"team-user-1 confirmed Claude 2.1.231 and Codex 0.147.0 on 2026-08-14"}
  ]
}
```

## Migration procedure

1. Generate actions from this ledger and the Wave 4 decision: `bash scripts/check-team-migration.sh emit-actions docs/development/cross-host-plugin-team-migration.md docs/development/plugin-boundary-decision.md /tmp/team-migration-actions.json`.
2. Apply only the generated arrays with `bash scripts/apply-team-migration.sh . /tmp/team-migration-actions.json`.
3. Each team member records both host versions, plugin versions, command summary, and evidence link before status becomes `confirmed`.
4. Record explicit J2 approval only after all users are confirmed. `deletePluginIds` remains empty for this Wave.

Rollback is the cutover-before commit recorded in each mapping row. `dev-workflow` is protected and must remain in both marketplaces and both runners.
