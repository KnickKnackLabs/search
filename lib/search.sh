#!/usr/bin/env bash

source "$MISE_CONFIG_ROOT/lib/common.sh"

search_relpath() {
  local path="$1"
  local root="$2"

  case "$path" in
    "$root")
      basename "$path"
      ;;
    "$root"/*)
      printf '%s\n' "${path#"$root"/}"
      ;;
    *)
      basename "$path"
      ;;
  esac
}

search_rg() {
  local query="$1"
  local path="$2"

  rg \
    --color=never \
    --line-number \
    --with-filename \
    --no-heading \
    --smart-case \
    -g '*.md' \
    -g '!**/.git/**' \
    -g '!**/.obsidian/**' \
    -g '!**/.mise/**' \
    -g '!**/node_modules/**' \
    -- "$query" "$path"
}

search_run_source() {
  local source_name="$1"
  local source_path="$2"
  local query="$3"
  local output=""
  local status=0
  local line=""
  local file_path=""
  local remainder=""
  local line_no=""
  local text=""
  local rel_path=""

  if output="$(search_rg "$query" "$source_path")"; then
    while IFS= read -r line; do
      file_path="${line%%:*}"
      remainder="${line#*:}"
      line_no="${remainder%%:*}"
      text="${remainder#*:}"
      rel_path="$(search_relpath "$file_path" "$source_path")"
      printf '[%s] %s:%s: %s\n' "$source_name" "$rel_path" "$line_no" "$text"
    done <<EOF
$output
EOF
    return 0
  fi

  status=$?
  if [ "$status" -eq 1 ]; then
    return 1
  fi

  return "$status"
}
