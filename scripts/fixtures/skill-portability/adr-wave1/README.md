# ADR Wave 1 portability fixture

This fixture records the ADR plugin's host-neutral result contract and the
host-specific execution paths used to produce it.

- **explicit ADR validation**: both hosts must be able to run the bundled
  `lint-adr.sh`, `gen-adr-index.sh`, and `next-adr-id.sh` operations and
  observe their exit status/output.
- **Claude Code hook**: Claude Code may enforce the same lint at
  `git commit` through the bundled PreToolUse hook.
- **Codex: degraded**: Codex has no equivalent per-plugin commit hook in the
  current contract, so explicit lint is mandatory and commits outside that
  workflow retain a residual drift risk.
- **adapter migration trigger**: introduce a host adapter when Codex exposes a
  supported per-plugin hook/policy callback that can invoke the same lint and
  return a blocking result. Until then, do not duplicate the ADR workflow.
