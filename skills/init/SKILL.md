---
name: x-init
description: "Create a minimal AGENTS.md and CLAUDE.md symlink with undiscoverable global rules, house constraints, and compact on-demand doc links. Replaces built-in /init."
argument-hint: "[path or rules, optional]"
disable-model-invocation: true
effort: medium
---

# Init

Create a minimal root `AGENTS.md` with a `CLAUDE.md -> AGENTS.md` symlink so Claude Code, Codex, and Antigravity share one file. Never generate `/init`-style repo summaries.

## Principles

- Context files load on every turn of every session. Extra lines raise token cost by 20% or more without general task gains and spend the model's instruction budget of roughly 300 to 400 rules before work begins.
- Package and version lists, `tsconfig` aliases, standard scripts, and `src/` folder trees readable in configs or directory listings are duplicate noise.
- `src/` paths and folder trees go stale and belong in search. Agents do not scan `docs/` automatically, so verified Markdown links (`[file.md](docs/path/file.md) — when to read`, using the basename as link text so the path is not tokenized twice) act as lazy on-demand pointers (0 tokens of doc body until needed). Never use `@path` imports for docs because Claude Code and Gemini inline them on every turn while Codex ignores them.
- Keep task-specific steering in skills loaded on demand, not in root context. Never duplicate a rule or doc link in both a skill and `AGENTS.md`.
- Keep a line only when it states an undiscoverable global rule, mandatory verification gate, 1-line cross-cutting house constraint, 1-sentence domain summary (when non-obvious from repo name), or verified active doc pointer. Zero lines or a six-word file is better than filler.

## Process

1. **Check existing context files.** Check the target root (argument path or repo root) for `AGENTS.md`, `CLAUDE.md`, `CLAUDE.local.md`, `GEMINI.md`, and `.claude/CLAUDE.md`. If any non-empty file exists, stop and tell the user to run `/x-init-cleanup` instead of overwriting it.
2. **Check for hidden traps, house constraints, and active docs.** Inspect top-level manifests, task runners, hooks, local skill folders (`package.json`, `Makefile`, `justfile`, `pyproject.toml`, `Cargo.toml`, `.husky/`, `lefthook.yml`, `.agents/skills/`, `.claude/skills/`), and `docs/` to find facts an agent would miss or get wrong:
   - Required CLI wrappers, container commands, monorepo filters, and the exact verification script gate required before finishing or pushing when manifests define multiple check or test scripts.
   - Non-standard build, test, or DB landmines, plus cross-cutting house conventions and wrappers an agent could violate when editing one file (for example, required server-action or auth wrappers, styling or API-client boundaries, secret storage rules, custom locale route overrides). Write these as 1-line constraints, never package inventories.
   - Active operational or architectural guides in `docs/` formatted under `## Docs` as `- [file.md](docs/path/file.md) — <when to read>`. Skip historical migration or upgrade plans, audits, changelogs, version-list docs, and docs already routed by a skill.
   - Manual-only skills (`disable-model-invocation: true`) used by this repo that need a 1 to 3 line routing hint.
   Never include generic LLM coding advice, package or version inventories, `tsconfig` aliases, `src/` folder trees, architecture overviews, or commit/PR templates.
3. **Ask once for human-only facts.** Unless the user already passed rules in the command arguments, ask one short question for constraints invisible in the repo: environment quirks such as OS, WSL, Docker, or VPN, off-limits commands or services, and non-obvious team conventions. Tell the user they can reply `none`.
4. **Filter candidates.** Test every candidate against two gates:
   - Undiscoverable, meaning not readable in configs, imports, or file search (or an active `docs/` guide an agent does not scan automatically).
   - Global, meaning needed across sessions: mandatory check gates, cross-cutting 1-line house constraints, a 1-sentence domain summary when non-obvious from the repo name, verified `[file.md](docs/...)` pointers not covered by a skill, and manual-only skill hints.
   Route single-domain rules and their `docs/` pointers together into a topic skill draft (in the repo's existing skill folder, or `.agents/skills/<name>/SKILL.md` with a symlink `.claude/skills/<name> -> ../../.agents/skills/<name>`) instead of `AGENTS.md`. If nothing passes both gates, say that the repo needs no context file yet and stop unless the user still wants one.
5. **Preview and wait for approval.** Show the exact `AGENTS.md` draft, the planned `CLAUDE.md -> AGENTS.md` symlink (skip the symlink only if the user requested one specific filename or the OS blocks symlinks), any optional skill drafts, and the line, word, and rough token count (`words * 1.3`, rounded). Write nothing until the user says `OK`.
6. **Save.** After the user replies `OK`, write `AGENTS.md`. If an empty `CLAUDE.md` or broken `CLAUDE.md` symlink exists, remove it before running `ln -s AGENTS.md CLAUDE.md`. Write any approved skills. Never commit.

## Preview format

````markdown
**Target:** `AGENTS.md` + symlink `CLAUDE.md -> AGENTS.md` (<lines> lines, <words> words, ~<tokens> tokens)

```markdown
<AGENTS.md draft>
```

**Optional skill draft (`<path>`):**

```markdown
<SKILL.md draft>
```

**Save this? Reply OK to write files.**
````

Omit the optional skill draft block when no domain-specific rules need a skill.
