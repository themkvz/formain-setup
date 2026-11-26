# Skills

Shared skills live in `skills/<name>/SKILL.md`. `bootstrap.sh` links each one as `x-<name>` into `~/.claude/skills/`, `~/.gemini/config/skills/`, and `~/.agents/skills/`.

Skills marked **user-invoked only** set `disable-model-invocation: true` (Claude Code, agy) and ship `agents/openai.yaml` with `allow_implicit_invocation: false` (Codex): the agent will not load them on its own, you run them with `/x-<name>`. `doctor.sh` fails when a manual skill misses the Codex file.

Stack-specific skills are manual too. Their hint lives in the project that uses the stack, not in global context (see the BFF hint below).

## `x-preferred-stack`

Provides preferred defaults when project does not already establish another choice.

Examples:

* TypeScript
* Bun
* Biome
* React
* React Router
* Tailwind CSS
* shadcn/ui
* Zustand
* TanStack Query
* Hono / Elysia
* Drizzle ORM
* PostgreSQL / MySQL / SQLite

Priority:

```text
existing project
→ project instructions/spec
→ x-preferred-stack
→ ecosystem defaults
```

Existing project architecture always wins.

## `x-find-docs`

Uses Context7 CLI for current framework/library/API documentation.

Use when implementation depends on version-specific behavior, configuration, migrations, setup, or library-specific debugging.

```bash
ctx7 library <name> "<query>"
ctx7 docs <library-id> "<query>"
```

## `x-bff-api-architecture-flow`

User-invoked only. Chooses authentication architecture for React Router v7+ Framework Mode BFFs, external REST/Spring Boot/Elysia APIs, Valkey-backed web sessions, PostgreSQL-backed refresh tokens, and Expo mobile clients.

Covers three modes:

```text
external API, one token
API with access + refresh tokens
own full-stack monorepo
```

Constant across all three: API tokens stay server-side, the browser holds only an opaque session ID, `401` ends the session and `403` does not.

Use when implementing login, registration, session handling, access/refresh tokens, retry behavior, logout, token storage, or authorization boundaries.

## `x-bff-api-client`

User-invoked only. Wires the server-side API client inside a React Router v7+ Framework Mode BFF.

```text
createApiClient()   per-request factory
apiClientContext    React Router context
requireSession      middleware builds client, sets context
<domain>.server.ts  one thin fn per endpoint
route loader        reads client from context
```

The route never builds a client and never sees a token, so auth headers, `401` handling, correlation IDs, timeouts, and logging stay in one file.

Use when adding an API call to a loader, action, or resource route, adding an endpoint wrapper, creating a protected or guest route layout, writing auth middleware, or testing a wrapper or loader.

### BFF project hint

Paste into the `AGENTS.md` of a React Router BFF project, so the agent suggests these skills there:

```md
## Skills

Before work on auth, sessions, tokens, or the server-side API client, suggest
`/x-bff-api-architecture-flow` (auth design) or `/x-bff-api-client` (API client wiring),
and run it only after the user approves.
```

## `x-create-issue`

User-invoked only. Creates one concise issue from the current conversation using a connected tracker MCP integration or an installed, authenticated CLI. Matches an explicit format, an applicable issue template, or recent relevant issues before using its fallback format.

The fallback body fits the work: What to build and Acceptance criteria for features and tasks, What happened, Expected, and Environment for bugs, with no default Context. It fills tracker fields from the tracker's metadata, using only existing values, and sets native relations (parent, blocks, relates to, duplicate) and attachments.

It supports Linear, Jira, Azure DevOps, GitHub, GitLab, and other configured trackers. If no publishing tool is available, it returns a title and body ready to paste.

## `x-issue-comment`

User-invoked only. Posts one concise, factual comment per tracker issue. Uses Changes, Checks, and optional Notes, with Context only when the comment covers part of the issue or the issue text is out of date.

```text
/x-issue-comment        concise comment
/x-issue-comment qa     comment with detailed, reproducible checks
```

Checks distinguish observed results from suggested QA steps. Empty Context, Checks, and Notes are omitted. Uses the same tracker and tool detection as `x-create-issue`; prints the comment ready to paste if no tool is available.

## `x-unslop`

User-invoked only. Removes AI writing patterns from issue text, comments, and other technical text without changing facts, quotes, code, or structure. Returns only the edited text, or the text unchanged when it breaks no rule. `x-create-issue` and `x-issue-comment` apply it by path before they post. Rule numbers are stable ids: 3 to 33 follow cursor pstack `unslop`, 40 and up are local.

## `x-design-patterns`

Finds the design pattern that fits a concrete situation, or rejects one when a plain TypeScript feature suffices. Catalog and rationale follow refactoring.guru; examples are rewritten as idiomatic TypeScript (functions, closures, discriminated unions) with the class form noted where it earns its place.

```text
SKILL.md                 symptom → pattern table, rules, anti-signals
references/<pattern>.md  intent, use when, do not use when, TS example, pitfalls, related
```

Use when structuring new code, refactoring conditionals, duplication, or coupling, reviewing an abstraction, or when a pattern is named.

## `x-write-tests`

Best practices for writing, structuring, reviewing, and pruning test cases across unit, integration, E2E, and Robot Framework suites.

Applies a behavior-first gate both when writing new tests and when pruning existing ones: keep only tests anchored to intended behavior (rejecting tests tied to removed code, platform/type guarantees, private implementation details, duplicates, or test-only production hooks). Covers readable structure, isolated repeatable test data without hardcoded secrets, scoped setup/teardown with safe cleanup, focused reusable helpers, real outcome assertions, semantic locators, and `.robot` formatting rules.

Automatically invoked when writing, updating, or pruning tests.

## `x-playwright-cli`

Provides browser automation for frontend validation:

* navigation
* forms
* interactions
* console errors
* network failures
* screenshots
* user flows
* signed-in checks through a per-project persistent profile
* screenshots, video, and traces as evidence for approving UI changes

Auto-named output goes to the temp folder set in `~/.playwright/cli.config.json` by bootstrap, and only evidence files go into the project's `.playwright-cli/proof/`.

Signed-in pages: the agent prefers a login with no human (seeded test user, dev-only login route). Otherwise it opens `~/.cache/playwright-cli/profiles/<project>` in a headed window once, you sign in there with a test account (SSO, 2FA, captcha), and later checks run headless with the same profile. When the session expires, the agent asks you to sign in again. Parallel agents share the login through a saved state file in `~/.cache/playwright-cli/state/`. Your own browser is never touched.

Attaching to a running browser (`attach --cdp=chrome`, extension) is a last resort, only when you ask for it or a profile cannot work.

When a command prints "Update available", the agent tells you; it never updates the CLI itself.

The body and `references/` are a copy of the skill bundled with `@playwright/cli`; only the frontmatter and the `Local rules` section are ours. To sync after a CLI update:

```bash
bun add -g @playwright/cli@latest
src=~/.bun/install/global/node_modules/playwright-core/lib/tools/skills/playwright-cli   # path printed by playwright-cli --help
diff -r "$src" ./skills/playwright-cli   # review, then copy the changed upstream files
```

Keep `name: x-playwright-cli`, the local description and `allowed-tools`, and the `Local rules` section.

## `x-ship-check`

User-invoked only. Final pre-launch verification for any product type: website, web app, internal tool, backend/API, worker, CLI, or mobile app. Detects the product type, runs the project's own checks, walks the matching checklists, and reports findings with evidence and a ship verdict. Changes nothing.

```text
/x-ship-check
/x-ship-check api https://staging.example.com
```

Report sections: Performance, Security, Best practices, UX, Maintainability, plus "Needs confirmation" for what the repo cannot prove (DNS, backups, store settings). Checklists live in `references/` (core, web, backend, mobile) and load by product type.

## `x-untangle-codebase`

User-invoked only. A structural refactor of the whole codebase, or of one area per run when the codebase is big (it proposes areas ranked by churn, co-change, and size). Asks whether to also prune comments and tests, records a baseline of the project's checks, then lists every hidden link, needless link, surplus piece, and special case in `.untangle/decision-log.md`, with each redesign fix above the problems it solves. Stops for approval of the plan: fixes grouped into batches, highest leverage first, with fixes that touch a public API, data format, or dependency marked `[contract]`. Then fixes the approved batches, has subagents search again, and repeats until nothing worth fixing is left in scope. Each batch ends with green checks, so a run can stop there; running the skill again resumes from the log. Never commits.

```text
/x-untangle-codebase
/x-untangle-codebase src/billing
```

`scripts/cochange.sh` prints git churn and files that change together; `references/tooling.md` lists skeleton and import-graph commands per ecosystem.

## `x-wait-what`

User-invoked only. Re-explains the last message as a smart caveman: short line, 3–6 steps, why, next action. Keeps real terms and `path:line` references. Runs at low effort to save tokens. Pass the confusing part to narrow it.

```text
/x-wait-what
```

## `x-ask-skill`

User-invoked only. Reads the current session and recommends the best-fitting skill: shared `x-*` skills first (including manual-only ones the agent cannot see), other installed skills only when they fit better. Returns the pick, the exact command with arguments filled from context, at most one alternative, or "no skill needed". Never runs the pick without a yes. Pass a short problem to steer it.

```text
/x-ask-skill
```

## `x-design-system-board`

User-invoked only. Generates a design system documentation board (sections DS-00 to DS-05) with dark-theme, tech-blue defaults. Pass product, theme, or brand color to override the defaults.

```text
/x-design-system-board
```

## `x-init`

User-invoked only. Creates a minimal root `AGENTS.md` and a `CLAUDE.md -> AGENTS.md` symlink so Claude Code, Codex, and Antigravity share one file. Keeps only rules that are undiscoverable from code or config and needed in every session. Stops for `/x-init-cleanup` if a non-empty context file already exists, routes domain-specific rules into topic skills, and waits for `OK` before writing files.

```text
/x-init
/x-init src/apps/web
```

## `x-init-cleanup`

User-invoked only. Audits `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`, and `GEMINI.md` across seven layers in one pass. Marks discoverable lines and hardcoded paths as `CUT`, moves task-specific rules into drafted topic skills, consolidates duplicate root files into `AGENTS.md` with a `CLAUDE.md -> AGENTS.md` symlink, and waits for `OK` before editing files. Pass `--global` to include global context files.

```text
/x-init-cleanup
/x-init-cleanup --global
```
