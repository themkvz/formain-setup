---
name: x-create-issue
description: Create one concise issue from the current conversation on Linear, Jira, Azure DevOps, GitHub, GitLab, or another configured tracker, using an available MCP integration or installed CLI.
argument-hint: "[focus, tracker, or project]"
disable-model-invocation: true
effort: medium
---

# Create Issue

Create one issue from the current conversation. Keep it short and useful: someone who missed the conversation should understand what is wrong or wanted, and when it is done.

Invoking this skill is the approval to create the issue. Do not ask for a draft review unless a required value is missing.

## Process

1. **Scope.** Text passed with the command narrows the focus or names the tracker/project; it wins over inference. Prefer one problem or one vertical slice per issue (a slice is a behavior that can be shown or checked on its own). If the conversation holds several unrelated problems and no focus was given, ask which one or offer to split. When the user wants several related problems in one issue, that is fine: list each as its own numbered part or its own acceptance criteria so each can be checked separately.
2. **Tracker.** Infer it from, in order: the user's words, project instructions (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`), issue keys in the branch name or recent commits (`ENG-123`, `PROJ-45`, `AB#123`), then the git remote host (`github.com`, `gitlab`, `dev.azure.com`). An issue key beats the remote host: many GitHub repos track work in Linear or Jira. Ask only when signals conflict or none exist.
3. **Tool.** Prefer a connected MCP tool for that tracker. Otherwise use an installed, authenticated CLI and check its `--help` before the first call:
   - Linear: Linear MCP or a Linear CLI
   - Jira: Jira/Atlassian MCP, `acli`, or `jira`
   - Azure DevOps: Azure DevOps MCP or `az boards work-item create`
   - GitHub: GitHub MCP or `gh issue create`
   - GitLab: GitLab MCP or `glab issue create`
4. **Duplicates.** Run a quick search for open issues with the key terms. If a clear match exists, return it instead of creating a new one and offer to add a comment with `/x-issue-comment`. Skip this step if the tool has no search.
5. **Fields.** First read the tracker's field metadata: Jira (`listJiraProjectIssueTypesMetadata`, required fields, custom fields such as Story Points); Linear (team labels, estimate scale, cycles, projects, templates); GitHub (labels, milestones, issue types, projects); Orbit (labels, cycles, milestones, members). Then fill every field that has evidence, using only values that already exist. Never create labels or other values.
   - Type: Bug, Feature, Task, etc. from the tracker's list.
   - Labels, project, milestone, area: from project instructions, issue templates (`.github/ISSUE_TEMPLATE/`, `.gitlab/issue_templates/`), the parent issue, or matching existing labels.
   - Priority: from stated impact. Urgent = outage, data loss, or security. High = core flow broken, no workaround. Medium = workaround exists. Low = cosmetic. No impact signal: leave unset.
   - Assignee: "me" when the conversation shows the user will do the work; a named person when one is given (resolve with the tracker's user lookup); otherwise unassigned.
   - Estimate or story points: only when the team's recent issues use them and the scope is clear. Use the team's scale.
   - Cycle, sprint, due date: only when stated.
   - Parent, blocks, blocked by, relates to, duplicate of: from issue keys in the conversation. Check that each key exists. Set them as the tracker's native relations (Linear parentId, blocks, blockedBy, relatedTo, duplicateOf; Jira parent and issue links; GitHub sub-issues). If a key is a clear duplicate, return it instead of creating (see step 4).
   - Attachments and links: screenshots, logs, or files from the conversation that exist on disk, and URLs (PR, error tracker, docs, design). Upload files with the tracker's attachment tool. Add URLs as link attachments where supported. Redact secrets first.
   
   Omit any field you cannot justify. Ask one focused question only for a required field that nothing supplies.
6. **Format.** Use the user's explicit format first, then the applicable tracker or repo issue template. Otherwise inspect 2–3 recent, relevant issues in the same project or team and of the same type, if available. Match the recurring title convention, language, headings and order, detail level, and acceptance criteria style. If examples vary, use the closest issue type. Copy structure only, never facts, status, people, or labels. Even when you follow a pattern or template, leave out optional sections that have no facts for this issue, such as a `Context` heading that would only repeat the title. Use the formats below only when no usable pattern is accessible. Keep required template fields; state unknown facts as unknown, or ask only when required for a valid, actionable issue. Never invent reproduction steps.
7. **Create.** Write in the tracker's native format (Azure DevOps descriptions are HTML; Jira may need wiki markup or ADF depending on the tool). With a CLI, pass the body through a file or heredoc (`--body-file`) so newlines and backticks survive shell quoting. Before creating, edit the title and body with `~/.ai/skills/unslop/SKILL.md` (read it by path). Then check that the issue covers one problem or lists its parts separately, that a duplicate search was done (when the tool can search), that every statement is supported, that the problem and outcome are clear, that required fields are present, and that limits, negations, numbers, and units are intact.
8. **Report.** Return the identifier, title, and URL in one line. Then one short line listing the fields set (type, priority, assignee, estimate, labels, relations), so a wrong guess is easy to spot. If no suitable authenticated tool exists, name the MCP or CLI needed and print the final title and body ready to paste.

## Writing rules

- General style rules live in `~/.ai/skills/unslop/SKILL.md`. The rules here are specific to issues.
- Describe the known problem and desired outcome, not a claim that the work is already complete.
- Use short, plain words: "fix", not "implement a solution for". Standard acronyms such as DB, API, and HTTP are fine; do not invent abbreviations such as cfg, impl, or fn. Do not use arrows.
- Cut filler, ceremony, greetings, closers, and emojis. Omit branch, push, delivery, readiness, and workflow status updates.
- Fragments are fine in bullets and checklist items. Use whole sentences in description prose. Keep words such as not, never, no, only, and except, as well as exact numbers and units.
- Preserve safety instructions, for example: "Back up first. Then run migration: it drops the column."

## Fallback issue format

**Title:** action-oriented, under 80 characters. Features and tasks: imperative (`Add retry to invoice sync`). Bugs: the symptom (`Invoice sync drops items after timeout`).

**Feature or task body:**

```markdown
## What to build

<The end-to-end behavior from the user's point of view, not a layer-by-layer list. A decision already made goes here as one sentence.>

## Acceptance criteria

- [ ] <Can be checked on its own>

## Blocked by

- <Issue key>

## Parent

<Issue key>
```

Use `Blocked by` and `Parent` sections only when the tracker has no native relation or parent field. Otherwise set the native field and omit the section.

**Bug body (repro first, short):**

```markdown
## What happened

1. <Smallest steps that show the bug>

<What the app did: the error line or screenshot.>

## Expected

<What it should do.>

## Environment

<Version or commit, platform, browser: only what matters for this bug.>
```

Drop the steps when they are unknown rather than guessing. Drop Environment when it does not matter.

Rules after the formats:

- Leave out any section that has no facts. Each section must pass one test: if deleted, would the assignee lose a fact? If not, delete it. No Context or Notes section by default.
- No file paths or code snippets. They go stale. Exception: a snippet that records a decision better than prose (schema, type shape), trimmed.
- Linear only: implementation hints the assignee may want (approach, likely code areas) go in a collapsible section at the end. Write a line `+++ Agent notes`, the notes, then `+++` on its own line. Keep it out of other trackers unless the project uses something similar.

Issues are often visible to more people than the conversation was, and public on open-source repos. Never include secrets, tokens, `.env` values, personal data, customer names, or internal hostnames (links to issues and PRs are fine); paraphrase or redact.
