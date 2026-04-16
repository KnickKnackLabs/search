#!/usr/bin/env bash

SEARCH_REPO_DIR="${MISE_CONFIG_ROOT:?MISE_CONFIG_ROOT is required}"

search_parse_words() {
  local raw="${1:-}"

  if [ -z "$raw" ]; then
    return 0
  fi

  printf '%s' "$raw" | xargs printf '%s\n'
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

search_source_path() {
  local source_name="$1"
  local agent_root=""

  case "$source_name" in
    repo)
      printf '%s\n' "${SEARCH_SOURCE_REPO:-${CALLER_PWD:-}}"
      ;;
    zettel)
      if [ -n "${SEARCH_SOURCE_ZETTEL:-}" ]; then
        printf '%s\n' "$SEARCH_SOURCE_ZETTEL"
      elif agent_root="$(search_agent_root 2>/dev/null)"; then
        printf '%s\n' "$agent_root/zettelkasten"
      fi
      ;;
    fold)
      if [ -n "${SEARCH_SOURCE_FOLD:-}" ]; then
        printf '%s\n' "$SEARCH_SOURCE_FOLD"
      elif agent_root="$(search_agent_root 2>/dev/null)"; then
        printf '%s\n' "$agent_root/fold"
      fi
      ;;
    den)
      if [ -n "${SEARCH_SOURCE_DEN:-}" ]; then
        printf '%s\n' "$SEARCH_SOURCE_DEN"
      elif agent_root="$(search_agent_root 2>/dev/null)"; then
        printf '%s\n' "$agent_root/den"
      fi
      ;;
    human)
      if [ -n "${SEARCH_SOURCE_HUMAN:-}" ]; then
        printf '%s\n' "$SEARCH_SOURCE_HUMAN"
      elif [ -n "${HUMAN_MD:-}" ]; then
        printf '%s\n' "$HUMAN_MD"
      elif [ -f "$HOME/agents/or/home/notes/HUMAN.md" ]; then
        printf '%s\n' "$HOME/agents/or/home/notes/HUMAN.md"
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

search_known_source() {
  case "$1" in
    repo|zettel|fold|den|human) return 0 ;;
    *) return 1 ;;
  esac
}

search_available_sources() {
  local source_name
  local source_path

  for source_name in repo zettel fold den human; do
    source_path="$(search_source_path "$source_name" 2>/dev/null || true)"

    if [ -n "$source_path" ] && [ -e "$source_path" ]; then
      printf '%s|%s\n' "$source_name" "$source_path"
    fi
  done
}
