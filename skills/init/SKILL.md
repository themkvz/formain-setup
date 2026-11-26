---
name: x-init
description: "Create a minimal AGENTS.md and CLAUDE.md symlink with only undiscoverable rules needed in every session. Replaces built-in /init."
argument-hint: "[path or rules, optional]"
disable-model-invocation: true
effort: medium
---

# Init

Create a minimal root `AGENTS.md` with a `CLAUDE.md -> AGENTS.md` symlink so Claude Code, Codex, and Antigravity share one file. Never generate `/init`-style repo summaries.

## Principles

- Context files load on every turn of every session. Extra lines raise token cost by 20% or more without general task gains and spend the model's instruction budget of roughly 300 to 400 rules before work begins.
- Anything the agent can read in `package.json`, lockfiles, config files, imports, or the folder tree is duplicate noise.
- File, folder, and service paths go stale and mislead. The agent finds paths faster by searching.
- Task-specific rules belong in skills loaded on demand, not in root context.
- Keep a line only when it is both undiscoverable from code or config and relevant in every session. Zero lines or a six-word file is better than filler.

## Process

1. **Check existing context files.** Check the target root (argument path or repo root) for `AGENTS.md`, `CLAUDE.md`, `CLAUDE.local.md`, `GEMINI.md`, and `.claude/CLAUDE.md`. If any non-empty file exists, stop and tell the user to run `/x-init-cleanup` instead of overwriting it.
2. **Check only for hidden traps.** Inspect top-level manifests, task runners, hooks, and local skill folders (`package.json`, `Makefile`, `justfile`, `pyproject.toml`, `Cargo.toml`, `.husky/`, `lefthook.yml`, `.agents/skills/`, `.claude/skills/`) only to find facts the agent would miss or get wrong on a normal run:
   - Required custom CLI wrappers, container commands, or monorepo filters that must replace default commands.
   - Non-standard build, test, or DB commands that fail or touch shared resources if called the obvious way.
   - Manual-only skills (`disable-model-invocation: true`) used by this repo that need a 1 to 3 line routing hint.
   Never include tech stack lists, architecture overviews, folder trees, file paths, or standard scripts already visible in config files.
3. **Ask once for human-only facts.** Unless the user already passed rules in the command arguments, ask one short question for constraints invisible in the repo: environment quirks such as OS, WSL, Docker, or VPN, off-limits commands or services, and non-obvious team conventions. Tell the user they can reply `none`.
4. **Filter candidates.** Test every candidate rule against two gates:
   - Undiscoverable, meaning not readable in configs, imports, or file search.
   - Global, meaning needed across frontend, backend, tests, docs, and DB sessions alike.
   Route undiscoverable rules that apply to only one domain into a topic skill draft (in the repo's existing skill folder, or `.agents/skills/<name>/SKILL.md` with a symlink `.claude/skills/<name> -> ../../.agents/skills/<name>`) instead of `AGENTS.md`. If nothing passes both gates, say that the repo needs no context file yet and stop unless the user still wants one.
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
