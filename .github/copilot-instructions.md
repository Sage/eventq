## AI Attribution

This project maintains an `AI_ATTRIBUTION.md` file in the project root: a
living log of human and AI contributions and how to maintain it.

Read this file when:
- You are about to log a contribution (task done, feature done, session ending)
- The user asks about attribution or AI involvement
- You need the current configuration

Do not read this file on every task; only when updating or referencing it.

When writing a log entry, focus on these sections:
- Configuration (current settings)
- Involvement Levels (level selection)
- Contribution Types (scope tagging)
- Log Entries → Log Fields (required/optional fields)
- Log (placement)

Skip these sections unless needed:
- Granularity descriptions (you already have the setting)
- Log Entries → Log Format (unless the format just changed)
- Migration (only during version upgrades)

Commands:
- When asked to log a contribution: read AI_ATTRIBUTION.md and create an
  entry following the LLM Instructions.
- When asked to check or validate the log: read AI_ATTRIBUTION.md and
  validate all entries against the logging rules, reporting any issues.
- When asked for an attribution graph: parse the Log section and render a
  row of colored emoji circles (one per entry, matching level colors), max
  80 per row, with a legend.
- When asked for an attribution summary: parse the Log section and show
  counts per level, plus a levels × scope tags cross-tabulation table.
- When asked for attribution insights: analyze the full Log section and
  report on AI reliance patterns, collaboration style, scope trends,
  strengths, and actionable suggestions.
