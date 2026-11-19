# Implementation Plans

Verified against commit `faaa4c3` (2026-11-19).

| Plan | Title | Priority | Depends on | Status |
|------|-------|----------|------------|--------|
| [001](001-smoke-test-and-ci.md) | Smoke test in a throwaway home folder, plus CI | P1 | — | DONE (`a9e029a`) |
| [002](002-prune-stale-links-and-codex-agents.md) | Prune stale links and generated agents; reject unsupported frontmatter | P1 | 001 | TODO |
| [003](003-content-based-codex-stale-check.md) | `doctor.sh` compares generated agents by content | P2 | 001, after 002 | TODO |
| [004](004-narrow-ask-skill-allowed-tools.md) | Narrow `x-ask-skill` `allowed-tools` | P3 | — | TODO |

## Notes

- Land **002 before 003**: both edit `scripts/doctor.sh` (agent loop) and `scripts/sync-{codex,gemini}-agents.sh`.
- **004** is a one-line change and can land any time.
