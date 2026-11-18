# Agents

Canonical agent definitions live in `agents/*.md`.

## Debugger

Investigates failures and traces symptoms to root cause before recommending smallest fix.

## Security Reviewer

Reviews changed attack surface for concrete security vulnerabilities and trust-boundary problems.

## Builder

Implements a decided change (approved spec, known-cause fix, mechanical multi-file edit) on Haiku at high effort, then stops. Spawned proactively; limited to Read, Edit, Write, Bash, and Skill.

## Verifier

Runs the feature, adds edge-case tests at medium effort, reports problems without changing code.

## Project Manager

Keeps tracker issues in sync with the code: reads issues, compares them with code and git history, posts updates, ticks criteria that have evidence, sets status (Done only on request), creates issues on request. Does not test behavior.

## QA Assistant

Verifies an issue's change, or a changed UI behavior from a brief, in the browser, by tests, and by code. Reports Done / Missing / Differs / Not covered, posts the evidence comment, ticks verified criteria, and sets the confirmed status.

Both read `skills/issue-comment/SKILL.md` (and `skills/create-issue/SKILL.md` for the project manager) by path, because those skills set `disable-model-invocation`.

Claude consumes shared Markdown agent definitions directly.

Antigravity requires native tool names in a YAML list and rejects Claude model tiers, generated from every `agents/*.md` with:

```bash
~/.ai/scripts/sync-gemini-agents.sh
```

Codex requires TOML definitions, generated from every `agents/*.md` (description and `codex-*` keys come from the frontmatter) with:

```bash
~/.ai/scripts/sync-codex-agents.sh
```


The generated TOML uses `codex-sandbox` from the frontmatter and defaults to `sandbox_mode = "read-only"` when it is absent.

## Model settings

Model, effort, tools, and Codex sandbox are set in each file's frontmatter (`model`/`effort` for Claude, `codex-*` for Codex).
