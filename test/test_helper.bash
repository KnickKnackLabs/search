#!/usr/bin/env bash

search() {
  if [ -z "${CALLER_PWD:-}" ]; then
    echo "CALLER_PWD not set" >&2
    return 1
  fi

  cd "$REPO_DIR" && CALLER_PWD="$CALLER_PWD" mise run -q search "$@"
}
export -f search
