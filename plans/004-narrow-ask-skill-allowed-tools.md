# Plan 004: Narrow `x-ask-skill` `allowed-tools`

- **Priority**: P3 | **Risk**: LOW | **Depends on**: none

## Problem

`skills/ask-skill/SKILL.md` sets `allowed-tools: Bash(head *)`, which pre-approves `head` on any file in Claude Code. The skill only runs `head -n 20 ~/.ai/skills/*/SKILL.md` (line 23).

## Change

In `skills/ask-skill/SKILL.md` line 6:

```yaml
# before
allowed-tools: Bash(head *) Read(~/.ai/skills/**)

# after
allowed-tools: Bash(head -n 20 ~/.ai/skills/*/SKILL.md) Read(~/.ai/skills/**)
```

## Verify

- Confirm line 6 matches the command on line 23 (`head -n 20 ~/.ai/skills/*/SKILL.md`).
- Manual check in Claude Code: run `/x-ask-skill` and confirm `head` runs without a permission prompt. (If Claude Code still prompts, fall back to `Bash(head -n 20 ~/.ai/skills/*)`.)
