#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/scripts/lib.sh"

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
    local backup
    backup="$(next_backup_path "$target")"

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
    owned_link "$link" && [[ ! -e "$link" ]] || continue

    run rm "$link"
    echo "Pruned: $link"
  done
}

echo "==> Global context"

for target in "${GLOBAL_CONTEXT_TARGETS[@]}"; do
  backup_and_link "$AI_HOME/GLOBAL.md" "$target"
done

echo
echo "==> Shared skills"

while IFS= read -r skill; do
  name="$(basename "$skill")"

  for skill_link_dir in "${SKILL_LINK_DIRS[@]}"; do
    link_dir "$skill" "$skill_link_dir/x-$name"
  done
done < <(skill_sources)

for skill_link_dir in "${SKILL_LINK_DIRS[@]}"; do
  prune_dangling "$skill_link_dir"
done

echo
echo "==> Shared agents"

while IFS= read -r agent; do
  name="$(basename "$agent")"

  backup_and_link "$agent" "$CLAUDE_AGENT_DIR/$name"
done < <(agent_sources)

prune_dangling "$CLAUDE_AGENT_DIR"

echo
echo "==> Scripts"

for script in "$AI_HOME"/scripts/*.sh; do
  [[ -f "$script" ]] || continue
  run chmod +x "$script"
done

echo
echo "==> Playwright CLI config"

if [[ ! -e "$PLAYWRIGHT_CONFIG" && ! -L "$PLAYWRIGHT_CONFIG" ]]; then
  run mkdir -p "$(dirname "$PLAYWRIGHT_CONFIG")"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] would write $PLAYWRIGHT_CONFIG"
  else
    playwright_config_content > "$PLAYWRIGHT_CONFIG"
    echo "Wrote: $PLAYWRIGHT_CONFIG"
  fi
elif cmp -s "$PLAYWRIGHT_CONFIG" <(playwright_config_content); then
  echo "Up to date: $PLAYWRIGHT_CONFIG"
else
  echo "Skip existing: $PLAYWRIGHT_CONFIG"
fi

echo
echo "==> Generated agents"

for sync_script in sync-gemini-agents.sh sync-codex-agents.sh; do
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] would run $sync_script"
  else
    bash "$AI_HOME/scripts/$sync_script"
  fi
done

echo

if [[ "$DRY_RUN" == "1" ]]; then
  echo "AI bootstrap dry run complete. Nothing changed."
else
  echo "AI bootstrap complete."
fi
