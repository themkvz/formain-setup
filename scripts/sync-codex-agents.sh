#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DST="${1:-$CODEX_AGENT_DIR}"

mkdir -p "$DST"

sync_agent() {
  local source="$1"
  local name target description
  name="$(basename "$source" .md)"
  target="$DST/$name.toml"

  description="$(plain_description "$source")" || exit 1
  description="$(escape_double_quoted "$description")"

  # Codex-specific model/effort from frontmatter. Absent means: inherit
  # Codex's default model/effort.
  local codex_model codex_effort codex_sandbox
  codex_model="$(frontmatter_value "codex-model" "$source")"
  codex_effort="$(frontmatter_value "codex-effort" "$source")"
  codex_sandbox="$(frontmatter_value "codex-sandbox" "$source")"

  # Strip YAML frontmatter from shared Markdown agent.
  body="$(frontmatter_body "$source")"

  if [[ "$body" == *"'''"* ]]; then
    echo "Agent body contains ''' and cannot be written as TOML: $source" >&2
    exit 1
  fi

  local tmp
  prepare_generated_target "$target" is_codex_generated

  tmp="$(mktemp "$DST/.sync.XXXXXX")"
  if ! {
    echo "$CODEX_MARKER"
    echo "name = \"$name\""
    echo "description = \"$description\""
    [[ -n "$codex_model" ]] && echo "model = \"$codex_model\""
    [[ -n "$codex_effort" ]] && echo "model_reasoning_effort = \"$codex_effort\""
    echo "sandbox_mode = \"${codex_sandbox:-read-only}\""
    echo
    # Literal string: backslashes in the body stay as written.
    echo "developer_instructions = '''"
    echo "$body"
    echo "'''"
  } > "$tmp" || ! mv "$tmp" "$target"; then
    rm -f "$tmp"
    exit 1
  fi

  echo "Synced: $target"
}

while IFS= read -r source; do
  sync_agent "$source"
done < <(agent_sources)

for target in "$DST"/*.toml; do
  is_codex_generated "$target" || continue
  name="$(basename "$target" .toml).md"
  agent_source "$name" >/dev/null && continue

  rm "$target"
  echo "Pruned: $target"
done

echo "Codex agents synced."
