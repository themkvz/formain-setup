#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/scripts/lib.sh"

if [[ ! -f "$AI_HOME/GLOBAL.md" ]]; then
  echo "Missing $AI_HOME/GLOBAL.md" >&2
  exit 1
fi

if [[ -d "$INSTALL_DIR" && ! -L "$INSTALL_DIR" && "$(cd "$INSTALL_DIR" 2>/dev/null && pwd -P)" == "$AI_HOME" ]]; then
  echo "Run bootstrap.sh from a repository clone outside $INSTALL_DIR." >&2
  exit 1
fi

if [[ -d "$INSTALL_DIR/.git" && ! -L "$INSTALL_DIR" ]]; then
  echo "Refusing to overwrite git repository at $INSTALL_DIR; move the clone elsewhere first." >&2
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
  local real_source="$1"
  local link_source="$2"
  local target="$3"

  [[ -d "$real_source" ]] || return 0

  run mkdir -p "$(dirname "$target")"

  if [[ -L "$target" ]]; then
    run rm "$target"
  elif [[ -e "$target" ]]; then
    echo "Skip existing non-symlink: $target"
    return 0
  fi

  run ln -s "$link_source" "$target"
  echo "Linked: $target -> $link_source"
}

prune_dangling() {
  local dir="$1"
  local link target name

  [[ -d "$dir" ]] || return 0

  for link in "$dir"/*; do
    owned_link "$link" && [[ ! -e "$link" ]] || continue

    if [[ "$DRY_RUN" == "1" ]]; then
      target="$(readlink "$link")"
      case "$target" in
        "$INSTALL_DIR"/skills/*)
          name="${target#"$INSTALL_DIR"/skills/}"
          skill_source "$name" >/dev/null && continue
          ;;
        "$INSTALL_DIR"/agents/*)
          name="${target#"$INSTALL_DIR"/agents/}"
          agent_source "$name" >/dev/null && continue
          ;;
      esac
    fi

    run rm "$link"
    echo "Pruned: $link"
  done
}

echo "==> Compile setup"
if [[ -L "$INSTALL_DIR" ]]; then
  run rm "$INSTALL_DIR"
elif [[ -e "$INSTALL_DIR" ]] && ! is_managed_install "$INSTALL_DIR"; then
  if [[ -d "$INSTALL_DIR" && -L "$INSTALL_DIR/root" ]]; then
    run rm "$INSTALL_DIR/root"
  fi
  if [[ -d "$INSTALL_DIR" && -z "$(ls -A "$INSTALL_DIR")" ]]; then
    run rmdir "$INSTALL_DIR"
  else
    backup="$(next_backup_path "$INSTALL_DIR")"
    echo "Backing up: $INSTALL_DIR -> $backup"
    run mv "$INSTALL_DIR" "$backup"
  fi
fi

run mkdir -p "$INSTALL_DIR/skills" "$INSTALL_DIR/agents" "$INSTALL_DIR/scripts"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] would compile GLOBAL.md, skills, agents, docs, and scripts into $INSTALL_DIR"
else
  printf '%s\n' "$INSTALL_MARKER" > "$INSTALL_DIR/.formain-managed"
  cp "$AI_HOME/GLOBAL.md" "$INSTALL_DIR/GLOBAL.md"

  if [[ -d "$AI_HOME/docs" ]]; then
    rm -rf "$INSTALL_DIR/docs"
    cp -R "$AI_HOME/docs" "$INSTALL_DIR/docs"
  fi

  while IFS= read -r skill; do
    name="$(basename "$skill")"
    rm -rf "$INSTALL_DIR/skills/$name"
    cp -R "$skill" "$INSTALL_DIR/skills/$name"
    echo "Compiled skill: $INSTALL_DIR/skills/$name"
  done < <(skill_sources)

  for stale in "$INSTALL_DIR"/skills/*; do
    [[ -d "$stale" ]] || continue
    name="$(basename "$stale")"
    skill_source "$name" >/dev/null && continue
    rm -rf "$stale"
    echo "Pruned compiled skill: $stale"
  done

  while IFS= read -r agent; do
    name="$(basename "$agent")"
    cp "$agent" "$INSTALL_DIR/agents/$name"
    echo "Compiled agent: $INSTALL_DIR/agents/$name"
  done < <(agent_sources)

  for stale in "$INSTALL_DIR"/agents/*.md; do
    [[ -f "$stale" ]] || continue
    name="$(basename "$stale")"
    agent_source "$name" >/dev/null && continue
    rm -f "$stale"
    echo "Pruned compiled agent: $stale"
  done

  for script in lib.sh doctor.sh uninstall.sh sync-gemini-agents.sh sync-codex-agents.sh; do
    cp "$AI_HOME/scripts/$script" "$INSTALL_DIR/scripts/$script"
  done
  chmod +x "$INSTALL_DIR"/scripts/*.sh
fi
echo

echo "==> Global context"

for target in "${GLOBAL_CONTEXT_TARGETS[@]}"; do
  backup_and_link "$INSTALL_DIR/GLOBAL.md" "$target"
done

echo
echo "==> Shared skills"

while IFS= read -r skill; do
  name="$(basename "$skill")"

  for skill_link_dir in "${SKILL_LINK_DIRS[@]}"; do
    link_dir "$skill" "$INSTALL_DIR/skills/$name" "$skill_link_dir/x-$name"
  done
done < <(skill_sources)

for skill_link_dir in "${SKILL_LINK_DIRS[@]}"; do
  prune_dangling "$skill_link_dir"
done

echo
echo "==> Shared agents"

while IFS= read -r agent; do
  name="$(basename "$agent")"

  backup_and_link "$INSTALL_DIR/agents/$name" "$CLAUDE_AGENT_DIR/$name"
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
