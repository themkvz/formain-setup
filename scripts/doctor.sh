#!/usr/bin/env bash

set -uo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FAILURES=0
WARNINGS=0

ok() {
  printf '✓ %s\n' "$1"
}

warn() {
  printf '! %s\n' "$1"
  WARNINGS=$((WARNINGS + 1))
}

fail() {
  printf '✗ %s\n' "$1"
  FAILURES=$((FAILURES + 1))
}

section() {
  printf '\n==> %s\n' "$1"
}

resolve_path() {
  local path="$1"

  if command -v realpath >/dev/null 2>&1; then
    realpath "$path" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$path" 2>/dev/null
  else
    return 1
  fi
}

check_link() {
  local target="$1"
  local expected="$2"

  if [[ ! -e "$target" && ! -L "$target" ]]; then
    fail "Missing: $target"
    return
  fi

  if [[ ! -L "$target" ]]; then
    warn "Not symlink: $target"
    return
  fi

  if [[ ! -e "$target" ]]; then
    fail "Broken symlink: $target"
    return
  fi

  local resolved_target
  local resolved_expected

  resolved_target="$(resolve_path "$target" || true)"
  resolved_expected="$(resolve_path "$expected" || true)"

  if [[ -z "$resolved_target" || -z "$resolved_expected" ]]; then
    warn "Could not resolve symlink: $target"
    return
  fi

  if [[ "$resolved_target" == "$resolved_expected" ]]; then
    ok "$target -> $expected"
  else
    fail "$target points to $resolved_target, expected $resolved_expected"
  fi
}

check_dangling() {
  local dir="$1"
  local link

  [[ -d "$dir" ]] || return 0

  for link in "$dir"/*; do
    owned_link "$link" && [[ ! -e "$link" ]] || continue

    fail "Dangling link: $link (run bootstrap.sh)"
  done
}

section "Shared configuration"

if [[ -L "$INSTALL_DIR" ]]; then
  fail "Legacy symlink at $INSTALL_DIR (run bootstrap.sh to compile)"
elif ! is_managed_install "$INSTALL_DIR"; then
  fail "Missing compiled setup: $INSTALL_DIR (run bootstrap.sh)"
else
  ok "$INSTALL_DIR"
fi

if [[ -f "$INSTALL_DIR/GLOBAL.md" ]]; then
  ok "$INSTALL_DIR/GLOBAL.md"
else
  fail "Missing: $INSTALL_DIR/GLOBAL.md"
fi

running_from_install=0
if [[ -d "$INSTALL_DIR" && ! -L "$INSTALL_DIR" ]] &&
   [[ "$AI_HOME" == "$(cd "$INSTALL_DIR" 2>/dev/null && pwd -P)" ]]; then
  running_from_install=1
fi

if (( ! running_from_install )); then
  for file in \
    "$AI_HOME/GLOBAL.md" \
    "$AI_HOME/bootstrap.sh"
  do
    if [[ -f "$file" ]]; then
      ok "$file"
    else
      fail "Missing: $file"
    fi
  done

  if [[ -f "$INSTALL_DIR/GLOBAL.md" ]] && ! cmp -s "$AI_HOME/GLOBAL.md" "$INSTALL_DIR/GLOBAL.md"; then
    warn "Compiled GLOBAL.md out of date (run bootstrap.sh)"
  fi
fi

section "Global context links"

for target in "${GLOBAL_CONTEXT_TARGETS[@]}"; do
  check_link "$target" "$INSTALL_DIR/GLOBAL.md"
done

section "Shared skills"

check_skill() {
  local skill="$1"
  local name
  name="$(basename "$skill")"

  if [[ ! -f "$skill/SKILL.md" ]]; then
    fail "$name missing SKILL.md"
    return
  fi

  ok "$name"

  if grep -q '^disable-model-invocation: true' "$skill/SKILL.md" &&
     ! grep -qs 'allow_implicit_invocation: false' "$skill/agents/openai.yaml"; then
    fail "$name is manual-only but has no agents/openai.yaml for Codex"
  fi

  if is_managed_install "$INSTALL_DIR"; then
    if [[ ! -d "$INSTALL_DIR/skills/$name" ]]; then
      fail "Missing compiled skill: $INSTALL_DIR/skills/$name (run bootstrap.sh)"
    elif (( ! running_from_install )) && ! diff -rq "$skill" "$INSTALL_DIR/skills/$name" >/dev/null 2>&1; then
      warn "Compiled skill out of date: $name (run bootstrap.sh)"
    fi
  fi

  for skill_link_dir in "${SKILL_LINK_DIRS[@]}"; do
    check_link "$skill_link_dir/x-$name" "$INSTALL_DIR/skills/$name"
  done
}

while IFS= read -r skill; do
  check_skill "$skill"
done < <(skill_sources)

for skill_link_dir in "${SKILL_LINK_DIRS[@]}"; do
  check_dangling "$skill_link_dir"
done

section "Shared agents"

expected_dir="$(mktemp -d)"
trap 'rm -rf "$expected_dir"' EXIT

gemini_synced=1
if ! out="$("$AI_HOME/scripts/sync-gemini-agents.sh" "$expected_dir/gemini" 2>&1)"; then
  fail "sync-gemini-agents.sh failed: $(tail -n 1 <<<"$out"); Gemini agents cannot be compared"
  gemini_synced=0
fi

codex_synced=1
if ! out="$("$AI_HOME/scripts/sync-codex-agents.sh" "$expected_dir/codex" 2>&1)"; then
  fail "sync-codex-agents.sh failed: $(tail -n 1 <<<"$out"); Codex agents cannot be compared"
  codex_synced=0
fi

check_agent() {
  local agent="$1"
  local name agent_id gemini_agent codex_agent
  name="$(basename "$agent")"
  agent_id="${name%.md}"
  gemini_agent="$GEMINI_AGENT_DIR/$agent_id/agent.md"
  codex_agent="$CODEX_AGENT_DIR/$agent_id.toml"

  ok "$name"

  if is_managed_install "$INSTALL_DIR"; then
    if [[ ! -f "$INSTALL_DIR/agents/$name" ]]; then
      fail "Missing compiled agent: $INSTALL_DIR/agents/$name (run bootstrap.sh)"
    elif (( ! running_from_install )) && ! cmp -s "$agent" "$INSTALL_DIR/agents/$name"; then
      warn "Compiled agent out of date: $name (run bootstrap.sh)"
    fi
  fi

  check_link "$CLAUDE_AGENT_DIR/$name" "$INSTALL_DIR/agents/$name"

  if [[ -L "$gemini_agent" ]]; then
    fail "Gemini agent is a raw symlink: $gemini_agent"
  elif [[ ! -f "$gemini_agent" ]]; then
    warn "Gemini agent not synced: $gemini_agent"
  elif (( gemini_synced )) && ! cmp -s "$expected_dir/gemini/$agent_id/agent.md" "$gemini_agent"; then
    warn "Gemini agent out of date: $gemini_agent (run sync-gemini-agents.sh)"
  elif (( gemini_synced )); then
    ok "$gemini_agent"
  fi

  if [[ ! -f "$codex_agent" ]]; then
    warn "Codex agent not synced: $codex_agent"
  elif (( codex_synced )) && ! cmp -s "$expected_dir/codex/$agent_id.toml" "$codex_agent"; then
    warn "Codex agent out of date: $codex_agent (run sync-codex-agents.sh)"
  elif (( codex_synced )); then
    ok "$codex_agent"
  fi
}

while IFS= read -r agent; do
  check_agent "$agent"
done < <(agent_sources)

check_dangling "$CLAUDE_AGENT_DIR"

for gemini_agent in "$GEMINI_AGENT_DIR"/*/agent.md; do
  is_gemini_generated "$gemini_agent" || continue
  agent_id="$(basename "$(dirname "$gemini_agent")")"
  agent_source "$agent_id.md" >/dev/null && continue

  fail "Orphan Gemini agent: $gemini_agent (run sync-gemini-agents.sh)"
done

for gemini_agent in "$GEMINI_AGENT_DIR"/*.md; do
  is_gemini_generated "$gemini_agent" || continue

  fail "Legacy Gemini agent: $gemini_agent (run sync-gemini-agents.sh)"
done

for codex_agent in "$CODEX_AGENT_DIR"/*.toml; do
  is_codex_generated "$codex_agent" || continue
  name="$(basename "$codex_agent" .toml).md"
  agent_source "$name" >/dev/null && continue

  fail "Orphan Codex agent: $codex_agent (run sync-codex-agents.sh)"
done

if command -v agy >/dev/null 2>&1; then
  agy_agents="$(agy agents 2>/dev/null || true)"

  while IFS= read -r agent; do
    agent_id="$(basename "$agent" .md)"

    if grep -Fxq -- "$agent_id" <<<"$agy_agents"; then
      ok "agy loads agent: $agent_id"
    else
      warn "agy did not load agent: $agent_id"
    fi
  done < <(agent_sources)
fi

section "Playwright CLI config"

if [[ ! -e "$PLAYWRIGHT_CONFIG" && ! -L "$PLAYWRIGHT_CONFIG" ]]; then
  warn "Missing: $PLAYWRIGHT_CONFIG (run bootstrap.sh)"
elif [[ -f "$PLAYWRIGHT_CONFIG" ]] && cmp -s "$PLAYWRIGHT_CONFIG" <(playwright_config_content); then
  ok "$PLAYWRIGHT_CONFIG"
elif grep -q 'outputDir' "$PLAYWRIGHT_CONFIG" 2>/dev/null; then
  warn "Custom config, not managed by formain-setup: $PLAYWRIGHT_CONFIG"
else
  warn "No outputDir in $PLAYWRIGHT_CONFIG: playwright-cli writes output into each project"
fi

section "Scripts"

for script in "$AI_HOME"/scripts/*.sh "$AI_HOME/bootstrap.sh"; do
  [[ -f "$script" ]] || continue

  name="$(basename "$script")"

  if [[ -x "$script" ]]; then
    ok "$name executable"
  else
    fail "$name not executable"
  fi

  if bash -n "$script" >/dev/null 2>&1; then
    ok "$name syntax"
  else
    fail "$name syntax error"
  fi
done

section "JSON configs"

if command -v jq >/dev/null 2>&1; then
  json_files=(
    "$HOME/.claude/settings.json"
    "$HOME/.gemini/antigravity-cli/settings.json"
    "$HOME/.gemini/config/hooks.json"
  )

  for file in "${json_files[@]}"; do
    [[ -f "$file" ]] || continue

    if jq empty "$file" >/dev/null 2>&1; then
      ok "$file"
    else
      fail "Invalid JSON: $file"
    fi
  done
else
  warn "jq not installed; JSON validation skipped"
fi

section "Codex TOML"

if command -v python3 >/dev/null 2>&1 &&
   python3 -c 'import tomllib' >/dev/null 2>&1; then

  toml_files=("$HOME/.codex/config.toml")

  for file in "$CODEX_AGENT_DIR"/*.toml; do
    [[ -f "$file" ]] && toml_files+=("$file")
  done

  for file in "${toml_files[@]}"; do
    [[ -f "$file" ]] || continue

    if python3 - "$file" <<'PY' >/dev/null 2>&1
import sys
import tomllib

with open(sys.argv[1], "rb") as f:
    tomllib.load(f)
PY
    then
      ok "$file"
    else
      fail "Invalid TOML: $file"
    fi
  done
else
  warn "Python tomllib unavailable; TOML validation skipped"
fi

section "Tools"

show_version() {
  local binary="$1"
  shift

  if ! command -v "$binary" >/dev/null 2>&1; then
    warn "$binary not installed"
    return
  fi

  local output
  output="$("$@" 2>&1 || true)"
  output="${output%%$'\n'*}"

  if [[ -n "$output" ]]; then
    ok "$binary: $output"
  else
    warn "$binary installed but version unavailable"
  fi
}

show_version claude claude --version
show_version codex codex --version
show_version agy agy --version
show_version rtk rtk --version
show_version ctx7 ctx7 --version
show_version playwright-cli playwright-cli --version

section "Claude integrations"

if command -v claude >/dev/null 2>&1; then
  plugin_output="$(claude plugin list 2>/dev/null || true)"

  if grep -q 'ponytail' <<<"$plugin_output"; then
    ok "Ponytail detected"
  else
    warn "Ponytail not detected"
  fi

  if grep -q 'typescript-lsp' <<<"$plugin_output"; then
    ok "TypeScript LSP detected"
  else
    warn "TypeScript LSP not detected"
  fi
fi

section "RTK"

if command -v rtk >/dev/null 2>&1; then
  rtk_output="$(rtk init --show 2>/dev/null || true)"

  if grep -q '\[ok\] Hook:' <<<"$rtk_output"; then
    ok "RTK Claude hook configured"
  else
    warn "RTK Claude hook not detected"
  fi

  gain_output="$(rtk gain 2>/dev/null || true)"

  if [[ -n "$gain_output" ]]; then
    saved_line="$(grep 'Tokens saved:' <<<"$gain_output" | head -n 1 || true)"

    if [[ -n "$saved_line" ]]; then
      ok "$saved_line"
    fi
  fi
else
  warn "rtk not installed"
fi

printf '\n==> Summary\n'
printf 'Failures: %d\n' "$FAILURES"
printf 'Warnings: %d\n' "$WARNINGS"

if (( FAILURES > 0 )); then
  exit 1
fi

exit 0
