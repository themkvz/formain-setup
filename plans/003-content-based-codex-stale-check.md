# Plan 003: `doctor.sh` compares generated agents by content

- **Priority**: P2 | **Risk**: LOW | **Depends on**: 001, land after 002

## Problem

`scripts/doctor.sh` uses `-nt` (mtime) to check whether generated `~/.gemini/config/agents/*.md` and `~/.codex/agents/*.toml` are stale. That gives false warnings after `git pull`/`git checkout` and misses drift when `sync-gemini-agents.sh` or `sync-codex-agents.sh` changes.

## Files

- `scripts/sync-codex-agents.sh`
- `scripts/sync-gemini-agents.sh`
- `scripts/doctor.sh`
- `scripts/test.sh`
- `README.md`

## Changes

### 1. Accept an optional output directory in both sync scripts

- `scripts/sync-codex-agents.sh`: `DST="${1:-$HOME/.codex/agents}"`
- `scripts/sync-gemini-agents.sh`: `DST="${1:-$HOME/.gemini/config/agents}"`

### 2. Compare content in `scripts/doctor.sh`

Directly after `section "Shared agents"` (before the `for agent` loop):

```bash
expected_dir="$(mktemp -d)"
trap 'rm -rf "$expected_dir"' EXIT

gemini_synced=1
if ! "$AI_HOME/scripts/sync-gemini-agents.sh" "$expected_dir/gemini" >/dev/null 2>&1; then
  fail "sync-gemini-agents.sh failed; Gemini agents cannot be compared"
  gemini_synced=0
fi

codex_synced=1
if ! "$AI_HOME/scripts/sync-codex-agents.sh" "$expected_dir/codex" >/dev/null 2>&1; then
  fail "sync-codex-agents.sh failed; Codex agents cannot be compared"
  codex_synced=0
fi
```

Inside the loop, replace both `-nt` branches with `cmp -s` (guarded by `gemini_synced` / `codex_synced` so a failed sync does not emit per-agent false warnings):

- Gemini: `elif (( gemini_synced )) && ! cmp -s "$expected_dir/gemini/$name" "$gemini_agent"; then warn "Gemini agent out of date: $gemini_agent (run sync-gemini-agents.sh)"`
- Codex: `elif (( codex_synced )) && ! cmp -s "$expected_dir/codex/${name%.md}.toml" "$codex_agent"; then warn "Codex agent out of date: $codex_agent (run sync-codex-agents.sh)"`

(Also guard the `else ok ...` branches with `elif (( gemini_synced ))` / `elif (( codex_synced ))` so a failed sync is not reported as `ok`.)

### 3. `scripts/test.sh` — add content-comparison checks

Insert after `pass "doctor"`. Always target `$TEST_HOME` and invoke `doctor.sh` with `env HOME="$TEST_HOME" PATH="/usr/bin:/bin"`:

- `touch -t 200001010000` on `$TEST_HOME/.gemini/config/agents/builder.md` and `$TEST_HOME/.codex/agents/builder.toml` → assert `doctor.sh` prints no `^! .*builder\.(md|toml)` warning.
- Append `# edited` to both files → assert `doctor.sh` warns both `Gemini agent out of date` and `Codex agent out of date`.

### 4. `README.md`

Update the sentence under "Testing" (`doctor.sh writes no files.`) to: `` `doctor.sh` writes nothing outside a temporary folder that it removes. ``

## Verify

```bash
for f in bootstrap.sh scripts/*.sh; do bash -n "$f"; done
grep -c -- '-nt ' scripts/doctor.sh   # expect 0
scripts/test.sh
```
