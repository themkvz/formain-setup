---
name: x-init-cleanup
description: "Audit and cut CLAUDE.md, AGENTS.md, and GEMINI.md down to undiscoverable global rules, 1-line house constraints, mandatory check gates, and compact on-demand doc links. Move task-specific rules into skills and wait for approval before saving."
argument-hint: "[file, folder, or --global]"
disable-model-invocation: true
effort: medium
---

# Init cleanup

Act as a context editor. Treat every line in a context file as a cost paid on every request. Cut context files down to undiscoverable, session-wide lines, move task-specific steering into skills, cut the rest, show the full before and after proof in one pass, and wait for `OK` before changing any file.

## Principles

- Auto-generated `/init` output goes.
- Context files load into every session. They raise inference cost by 20% or more without general task gains and take room from exploring, building, and testing.
- Models follow roughly 300 to 400 instructions at once. Irrelevant lines spend that budget before the task starts.
- Package and version inventories, `tsconfig` aliases, `src/` folder trees, generic LLM advice, and standard commit or PR templates go.
- `src/` paths and folder trees belong in search. Verified Markdown links (`[file.md](docs/path/file.md) — when to read`) are lazy on-demand pointers and stay when they point to active guides not routed by a skill. Convert eager `@docs/...` imports to Markdown links.
- Task-specific steering belongs in skills loaded on demand. Never duplicate a rule or doc link in both a skill and the root context file.
- Keep a line only when it states an undiscoverable global rule, mandatory verification gate, 1-line cross-cutting house constraint, 1-sentence domain summary, or verified active doc pointer. Six words or zero lines is valid.

## Audit layers

Run all seven layers in one pass and present one combined report before waiting for approval.

1. **Inventory.** Find context files in the repo: root and nested `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`, `GEMINI.md`, and `.claude/CLAUDE.md`. Scan global files (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`, and their resolved symlink targets) only when the user explicitly passes `--global` or a path outside the repo. Check symlinks with `readlink` so linked files are audited once, not twice. Number lines and count lines, words, and rough tokens (`words * 1.3`, rounded) per file.
2. **Discoverable check.** Mark `CUT` on package or version inventories, `tsconfig` aliases, compiler or linter flags, generic LLM coding advice, commit templates, and pure config restatements already visible in `package.json`, lockfiles, `tsconfig.json`, linter or test configs, `Dockerfile`, CI workflows, imports, or the folder tree. Name the file that already states each cut item. Distinguish **constraints from inventories**: do not cut mandatory pre-push verification commands (which scripts must pass), cross-cutting house wrappers or boundaries an agent might violate when editing a single file (compress to 1-line rules: `KEEP` if cross-cutting, `MOVE` if single-domain), or a 1-sentence product or domain summary when it adds domain terms invisible in manifests.
3. **Path and doc-link check.** Verify every file, folder, service path, and `@path` reference on disk:
   - Missing paths -> `CUT (stale path)`.
   - `src/` paths and directory trees -> `CUT (searchable path)` unless naming a strict write boundary (for example, `translations/<ns>/en.json`).
   - Project docs (`docs/...`): historical migration or upgrade plans, audits, changelogs, or version-table docs -> `CUT (stale/duplicate doc)`; single-domain docs moving with a topic -> `MOVE -> <skill>`; active cross-cutting or un-skilled operational or architectural guides -> `KEEP` under `## Docs` as `- [file.md](docs/path/file.md) — <when to read>` (shorten `[docs/x/file.md](docs/x/file.md)` to `[file.md](docs/x/file.md)` and convert `@docs/...` imports to Markdown links).
4. **Global relevance check.** On each remaining line, check whether it applies across sessions. Keep active `## Docs` pointers not owned by a skill (1 line per doc, or 1 grouped line for a tight doc set when a skill is overkill) and 1 to 3 line routing hints for manual-only skills (`disable-model-invocation: true`) as `KEEP`. Mark single-domain rules and their doc pointers `MOVE -> <skill>`.
5. **Skill drafts.** Group `MOVE` lines by topic and draft one skill per topic with `name` and a `description` stating when to load it. Use the repo's existing skill folder when present. Otherwise target `.agents/skills/<name>/SKILL.md` with a symlink `.claude/skills/<name> -> ../../.agents/skills/<name>` so Claude Code, Codex, and Antigravity share it.
6. **Keep gate and file consolidation.** Keep only non-obvious environment facts (OS, WSL, required custom CLI instead of the default), mandatory verification gates, 1-line cross-cutting house constraints or boundaries, a 1-sentence domain summary when needed, verified active `## Docs` pointers, and manual-only skill hints. When separate unlinked root `AGENTS.md` and `CLAUDE.md` files exist, or when `CLAUDE.md` only contains `@AGENTS.md` or duplicates `AGENTS.md`, propose merging any unique root rules into `AGENTS.md` and replacing `CLAUDE.md` with `CLAUDE.md -> AGENTS.md`. Because Gemini and Antigravity already load `AGENTS.md` directly, flag any duplicate root `GEMINI.md` so its unique undiscoverable rules merge into `AGENTS.md`, and ask before removing `GEMINI.md`.
7. **Proof and delivery.** Output one review package and stop:
   - Inventory summary per file (symlinks noted, lines, words, rough tokens).
   - One verdict table with columns `File:Line | Verdict | Reason` (`KEEP`, `MOVE -> <skill>`, or `CUT`), grouping contiguous boilerplate blocks such as folder trees into line ranges (`L10-L28`) when they share one reason.
   - Before and after line and token counts per file, plus the percentage of lines and tokens that survived.
   - Full replacement text for `AGENTS.md` (and any kept nested files).
   - Full path and `SKILL.md` draft for every moved topic skill.
   - Questions (at most once) for any line that looks safety-critical or load-bearing where the reason is unclear.
   - End with the single command to inspect or verify first after saving (for example `git status -s && git diff --stat`), and wait for `OK`.

## Report format

````markdown
## Inventory

- `<path>`: <lines> lines, <words> words, ~<tokens> tokens (<symlink status>)

## Verdicts

| File:Line | Verdict | Reason |
| --- | --- | --- |
| `<file>:<line or range>` | `KEEP` / `MOVE -> <skill>` / `CUT` | <reason> |

## Token summary

| File | Before | After | Survived |
| --- | --- | --- | --- |
| `<file>` | <lines>L / ~<tokens>t | <lines>L / ~<tokens>t | <pct>% lines, <pct>% tokens |

## New AGENTS.md

```markdown
<replacement AGENTS.md>
```

## Drafted skills

### `<path>`

```markdown
<SKILL.md draft>
```

## Questions

- <optional question on unclear safety-critical lines>

**First check after saving:** `git status -s && git diff --stat`

**Apply these changes? Reply OK (or list line overrides).**
````

Omit `## Drafted skills` when no `MOVE` lines exist, and omit `## Questions` when none apply.

## Rules

- Change nothing on disk until the user approves (`OK`, or `OK` with specific line overrides).
- Never delete a tracked context file silently. Rewrite in place, or replace duplicate `CLAUDE.md` with a symlink to `AGENTS.md` after approval, so git keeps the old version. If zero lines survive, ask whether to keep a minimal file or run `git rm`.
- Never invent conventions the repo does not have.
- Never commit.
