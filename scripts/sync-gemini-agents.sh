#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DST="${1:-$GEMINI_AGENT_DIR}"

mkdir -p "$DST"

sync_agent() {
  local source="$1"
  local name agent_name tools disallowed target_dir target description gemini_model tmp
  name="$(basename "$source" .md)"
  target_dir="$DST/$name"
  target="$target_dir/agent.md"

  description="$(plain_description "$source")" || exit 1

  agent_name="$(frontmatter_value "name" "$source")"
  agent_name="${agent_name:-$name}"
  tools="$(frontmatter_value "tools" "$source")"
  disallowed="$(frontmatter_value "disallowedTools" "$source")"

  gemini_model="$(frontmatter_value "gemini-model" "$source")"
  case "$gemini_model" in
    ''|inherit|flash_lite|flash|pro) ;;
    *)
      echo "Unsupported gemini-model in $source: $gemini_model (use inherit, flash_lite, flash, or pro)" >&2
      exit 1
      ;;
  esac

  mkdir -p "$target_dir"

  prepare_generated_target "$target" is_gemini_generated

  tmp="$(mktemp "$target_dir/.sync.XXXXXX")"
  if ! {
    DESC="$(escape_double_quoted "$description")" NAME="$agent_name" TOOLS="$tools" DISALLOWED="$disallowed" GMODEL="$gemini_model" awk '
      function has_token(list, tok,    n, i, arr) {
        n = split(list, arr, /,[[:space:]]*/)
        for (i = 1; i <= n; i++) {
          if (arr[i] == tok) return 1
        }
        return 0
      }
      function add_tool(t) {
        if (!seen[t]++) mapped = (mapped ? mapped ", " : "") t
      }
      BEGIN {
        tools = ENVIRON["TOOLS"]
        disallowed = ENVIRON["DISALLOWED"]

        if (tools != "") {
          n = split(tools, arr, /,[[:space:]]*/)
          for (i = 1; i <= n; i++) {
            t = arr[i]
            if (t == "Read" || t == "Glob" || t == "Grep") add_tool("read_file")
            else if (t == "Edit" || t == "MultiEdit") add_tool("edit_file")
            else if (t == "Write") add_tool("write_file")
            else if (t == "Bash") { add_tool("run_command"); add_tool("manage_task") }
            else if (t == "WebSearch" || t == "WebFetch") add_tool("search_web")
          }
        } else {
          add_tool("read_file")
          if (!has_token(disallowed, "Edit") && !has_token(disallowed, "MultiEdit")) add_tool("edit_file")
          if (!has_token(disallowed, "Write")) add_tool("write_file")
          add_tool("run_command")
          add_tool("manage_task")
          add_tool("search_web")
        }

        print "---"
        print "name: " ENVIRON["NAME"]
        print "description: \"" ENVIRON["DESC"] "\""
        print "subagent: true"
        print "mainAgent: true"
        if (ENVIRON["GMODEL"] != "") print "model: " ENVIRON["GMODEL"]
        print "tools: [" mapped "]"
        print "---"
      }
    ' && frontmatter_body "$source" && printf '%s\n' "$GEMINI_MARKER"
  } > "$tmp" || ! mv "$tmp" "$target"; then
    rm -f "$tmp"
    exit 1
  fi

  echo "Synced: $target"
}

while IFS= read -r source; do
  sync_agent "$source"
done < <(agent_sources)

for target in "$DST"/*/agent.md; do
  is_gemini_generated "$target" || continue
  target_dir="$(dirname "$target")"
  name="$(basename "$target_dir")"
  agent_source "$name.md" >/dev/null && continue

  rm "$target"
  rmdir "$target_dir" 2>/dev/null || true
  echo "Pruned: $target"
done

for target in "$DST"/*.md; do
  is_gemini_generated "$target" || continue

  rm "$target"
  echo "Pruned legacy: $target"
done

echo "Gemini agents synced."
