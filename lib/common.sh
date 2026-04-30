#!/usr/bin/env bash

SEARCH_REPO_DIR="${MISE_CONFIG_ROOT:?MISE_CONFIG_ROOT is required}"

search_parse_words() {
  local raw="${1:-}"

  if [ -z "$raw" ]; then
    return 0
  fi

  printf '%s' "$raw" | xargs printf '%s\n'
}

search_join_args() {
  local result=""
  local arg

  for arg in "$@"; do
    if [ -z "$result" ]; then
      result="$arg"
    else
      result="$result $arg"
    fi
  done

  printf '%s\n' "$result"
}

search_agent_root() {
  if [ -n "${SEARCH_AGENT_ROOT:-}" ]; then
    printf '%s\n' "$SEARCH_AGENT_ROOT"
    return 0
  fi

  if [ -n "${GIT_AUTHOR_NAME:-}" ]; then
    printf '%s/agents/%s\n' "$HOME" "$GIT_AUTHOR_NAME"
    return 0
  fi

  return 1
}

search_env_name() {
  local provider="$1"
  local variable="$2"
  local provider_upper
  local variable_upper

  provider_upper="$(printf '%s' "$provider" | tr '[:lower:]-' '[:upper:]_')"
  variable_upper="$(printf '%s' "$variable" | tr '[:lower:]-' '[:upper:]_')"
  printf 'SEARCH_%s_%s\n' "$provider_upper" "$variable_upper"
}

search_env_get() {
  local provider="$1"
  local variable="$2"
  local env_name

  env_name="$(search_env_name "$provider" "$variable")"
  eval "printf '%s\\n' \"\${$env_name:-}\""
}

search_default_limit() {
  local provider="$1"
  local fallback="$2"
  local configured

  configured="$(search_env_get "$provider" limit)"
  if [ -n "$configured" ]; then
    printf '%s\n' "$configured"
  else
    printf '%s\n' "$fallback"
  fi
}

search_default_repo() {
  local provider="$1"
  search_env_get "$provider" default_repo
}

search_agent_home() {
  local agent_root=""

  if [ -n "${SEARCH_SOURCE_HOME:-}" ]; then
    printf '%s\n' "$SEARCH_SOURCE_HOME"
    return 0
  fi

  if [ -n "${SEARCH_SOURCE_ZETTEL:-}" ]; then
    printf '%s\n' "$SEARCH_SOURCE_ZETTEL"
    return 0
  fi

  if agent_root="$(search_agent_root 2>/dev/null)"; then
    if [ -e "$agent_root/home" ]; then
      printf '%s\n' "$agent_root/home"
    else
      printf '%s\n' "$agent_root/zettelkasten"
    fi
    return 0
  fi

  return 1
}

search_human_path() {
  if [ -n "${SEARCH_SOURCE_HUMAN:-}" ]; then
    printf '%s\n' "$SEARCH_SOURCE_HUMAN"
  elif [ -n "${HUMAN_MD:-}" ]; then
    printf '%s\n' "$HUMAN_MD"
  elif [ -f "$HOME/agents/or/home/notes/HUMAN.md" ]; then
    printf '%s\n' "$HOME/agents/or/home/notes/HUMAN.md"
  fi
}

search_module_path() {
  local module_name="$1"
  local home_path=""

  if home_path="$(search_agent_home 2>/dev/null)"; then
    printf '%s\n' "$home_path/modules/$module_name"
  fi
}

search_source_path() {
  local source_name="$1"

  case "$source_name" in
    home|zettel)
      search_agent_home
      ;;
    *)
      search_module_path "$source_name"
      ;;
  esac
}

search_known_note_source() {
  local source_name="$1"
  local source_path=""

  case "$source_name" in
    repo|human)
      return 1
      ;;
    home|zettel)
      return 0
      ;;
    *)
      source_path="$(search_module_path "$source_name" 2>/dev/null || true)"
      [ -n "$source_path" ] && [ -e "$source_path" ]
      ;;
  esac
}

search_available_note_sources() {
  local home_path=""
  local module_dir=""
  local module_name=""

  home_path="$(search_agent_home 2>/dev/null || true)"
  if [ -n "$home_path" ] && [ -e "$home_path" ]; then
    printf 'home|%s\n' "$home_path"
  fi

  if [ -n "$home_path" ] && [ -d "$home_path/modules" ]; then
    for module_dir in "$home_path"/modules/*; do
      [ -d "$module_dir" ] || continue
      module_name="$(basename "$module_dir")"
      printf '%s|%s\n' "$module_name" "$module_dir"
    done
  fi
}
