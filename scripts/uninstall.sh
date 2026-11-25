#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LEFTOVERS=""

# Remove an item, then move its original back from P.backup.
remove_item() {
  local path="$1" backup

  echo "Removed: $path"
  run rm "$path"

  if [[ -e "$path$BACKUP_SUFFIX" || -L "$path$BACKUP_SUFFIX" ]]; then
    run mv "$path$BACKUP_SUFFIX" "$path"
    echo "Restored: $path"
  fi

  for backup in "$path$BACKUP_SUFFIX".*; do
    [[ -e "$backup" || -L "$backup" ]] || continue
    LEFTOVERS="$LEFTOVERS$backup"$'\n'
  done
}

echo "==> Global context links"

for file in "${GLOBAL_CONTEXT_TARGETS[@]}" "${LEGACY_GLOBAL_CONTEXT_TARGETS[@]}"; do
  if owned_link "$file"; then remove_item "$file"; fi
done

echo
echo "==> Shared links"

for dir in "${SKILL_LINK_DIRS[@]}" "$CLAUDE_AGENT_DIR" "${LEGACY_SKILL_LINK_DIRS[@]}"; do
  for link in "$dir"/*; do
    if owned_link "$link"; then remove_item "$link"; fi
  done
done

echo
echo "==> Generated agents"

for agent in "$CODEX_AGENT_DIR"/*.toml; do
  is_codex_generated "$agent" || continue
  remove_item "$agent"
done

for agent in "$GEMINI_AGENT_DIR"/*/agent.md; do
  is_gemini_generated "$agent" || continue
  remove_item "$agent"
  run rmdir "$(dirname "$agent")" 2>/dev/null || true
done

for agent in "$GEMINI_AGENT_DIR"/*.md; do
  is_gemini_generated "$agent" || continue
  remove_item "$agent"
done

echo
echo "==> Playwright CLI config"

if [[ -f "$PLAYWRIGHT_CONFIG" ]] && cmp -s "$PLAYWRIGHT_CONFIG" <(playwright_config_content); then
  echo "Removed: $PLAYWRIGHT_CONFIG"
  run rm "$PLAYWRIGHT_CONFIG"
fi

for dir in \
  "${SKILL_LINK_DIRS[@]}" \
  "$CLAUDE_AGENT_DIR" \
  "$GEMINI_AGENT_DIR" \
  "$CODEX_AGENT_DIR" \
  "${LEGACY_SKILL_LINK_DIRS[@]}" \
  "$HOME/.agents" \
  "$HOME/.agent" \
  "$(dirname "$PLAYWRIGHT_CONFIG")"
do
  [[ -d "$dir" && ! -L "$dir" && -z "$(ls -A "$dir")" ]] || continue
  run rmdir "$dir"
  echo "Removed empty folder: $dir"
done

echo
if [[ -n "$LEFTOVERS" ]]; then
  echo "Leftover timestamped backups (review manually):"
  printf '%s' "$LEFTOVERS"
  echo
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "AI uninstall dry run complete. Nothing changed."
else
  echo "AI uninstall complete."
fi
