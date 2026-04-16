#!/usr/bin/env bash

if [ -z "${MISE_CONFIG_ROOT:-}" ]; then
  echo "MISE_CONFIG_ROOT not set — run tests via: mise run test" >&2
  exit 1
fi

search() {
  if [ -z "${CALLER_PWD:-}" ]; then
    echo "CALLER_PWD not set" >&2
    return 1
  fi

  cd "$MISE_CONFIG_ROOT" && CALLER_PWD="$CALLER_PWD" mise run -q search "$@"
}
export -f search
