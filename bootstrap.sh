#!/usr/bin/env bash

set -euo pipefail

AI_HOME="$HOME/.ai"
DRY_RUN="${DRY_RUN:-0}"

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

if [[ ! -f "$AI_HOME/GLOBAL.md" ]]; then
  echo "Missing $AI_HOME/GLOBAL.md" >&2
  exit 1
fi

backup_and_link() {
  local source="$1"
  local target="$2"

  run mkdir -p "$(dirname "$target")"

  if [[ -L "$target" ]]; then
    run rm "$target"
  elif [[ -e "$target" ]]; then
    local backup="${target}.backup"

    if [[ -e "$backup" || -L "$backup" ]]; then
      backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    fi

    echo "Backing up: $target -> $backup"
    run mv "$target" "$backup"
  fi

  run ln -s "$source" "$target"
  echo "Linked: $target -> $source"
}

link_dir() {
  local source="$1"
  local target="$2"

  [[ -d "$source" ]] || return 0

  run mkdir -p "$(dirname "$target")"

  if [[ -L "$target" ]]; then
    run rm "$target"
  elif [[ -e "$target" ]]; then
    echo "Skip existing non-symlink: $target"
    return 0
  fi

  run ln -s "$source" "$target"
  echo "Linked: $target -> $source"
}

prune_dangling() {
  local dir="$1"
  local link

  [[ -d "$dir" ]] || return 0

  for link in "$dir"/*; do
    [[ -L "$link" && ! -e "$link" ]] || continue
    [[ "$(readlink "$link")" == "$AI_HOME"/* ]] || continue

    run rm "$link"
    echo "Pruned: $link"
  done
}

echo "==> Global context"

backup_and_link "$AI_HOME/GLOBAL.md" "$HOME/.claude/CLAUDE.md"
backup_and_link "$AI_HOME/GLOBAL.md" "$HOME/.codex/AGENTS.md"
backup_and_link "$AI_HOME/GLOBAL.md" "$HOME/.gemini/GEMINI.md"
backup_and_link "$AI_HOME/GLOBAL.md" "$HOME/.copilot/copilot-instructions.md"

echo
echo "==> Shared skills"

for skill in "$AI_HOME"/skills/*; do
  [[ -d "$skill" ]] || continue

  name="$(basename "$skill")"

  link_dir "$skill" "$HOME/.claude/skills/x-$name"
  link_dir "$skill" "$HOME/.gemini/config/skills/x-$name"
  link_dir "$skill" "$HOME/.agents/skills/x-$name"
  link_dir "$skill" "$HOME/.agent/skills/x-$name"
done

prune_dangling "$HOME/.claude/skills"
prune_dangling "$HOME/.gemini/config/skills"
prune_dangling "$HOME/.agents/skills"
prune_dangling "$HOME/.agent/skills"

echo
echo "==> Shared agents"

for agent in "$AI_HOME"/agents/*.md; do
  [[ -f "$agent" ]] || continue

  name="$(basename "$agent")"

  backup_and_link "$agent" "$HOME/.claude/agents/$name"
done

prune_dangling "$HOME/.claude/agents"

echo
echo "==> Gemini agents"

if [[ -x "$AI_HOME/scripts/sync-gemini-agents.sh" ]]; then
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] would sync Gemini agents"
  else
    "$AI_HOME/scripts/sync-gemini-agents.sh"
  fi
else
  echo "Skip: sync-gemini-agents.sh not found or not executable"
fi

echo
echo "==> Codex agents"

if [[ -x "$AI_HOME/scripts/sync-codex-agents.sh" ]]; then
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] would sync Codex agents"
  else
    "$AI_HOME/scripts/sync-codex-agents.sh"
  fi
else
  echo "Skip: sync-codex-agents.sh not found or not executable"
fi

echo
echo "==> Scripts"

for script in "$AI_HOME"/scripts/*.sh; do
  [[ -f "$script" ]] || continue
  run chmod +x "$script"
done

echo

if [[ "$DRY_RUN" == "1" ]]; then
  echo "AI bootstrap dry run complete. Nothing changed."
else
  echo "AI bootstrap complete."
fi
