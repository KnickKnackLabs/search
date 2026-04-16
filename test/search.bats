#!/usr/bin/env bats

bats_require_minimum_version 1.5.0
load ./test_helper.bash

setup() {
  export CALLER_PWD="$BATS_TEST_TMPDIR/repo"
  export SEARCH_AGENT_ROOT="$BATS_TEST_TMPDIR/agent"
  export SEARCH_SOURCE_REPO="$CALLER_PWD"
  export SEARCH_SOURCE_DEN="$BATS_TEST_TMPDIR/missing-den"
  export HUMAN_MD="$BATS_TEST_TMPDIR/HUMAN.md"

  mkdir -p "$CALLER_PWD"
  mkdir -p "$SEARCH_AGENT_ROOT/zettelkasten"
  mkdir -p "$SEARCH_AGENT_ROOT/fold/notes"

  cat > "$CALLER_PWD/README.md" <<'EOF'
# Search fixture

notes setup is required before unlocking encrypted notes.
EOF

  cat > "$SEARCH_AGENT_ROOT/zettelkasten/status.md" <<'EOF'
# Status

Need to follow up on provider namespaces later.
EOF

  cat > "$SEARCH_AGENT_ROOT/fold/notes/obfuscation.md" <<'EOF'
# Obfuscation

Run notes setup and notes unlock before trying to read encrypted notes.
EOF

  cat > "$HUMAN_MD" <<'EOF'
# HUMAN

The fully obfuscation-focused home idea keeps coming up.
EOF
}

@test "searches default sources" {
  run search obfuscation
  [ "$status" -eq 0 ]
  [[ "$output" == *"[fold] notes/obfuscation.md:"* ]]
  [[ "$output" == *"[human] HUMAN.md:"* ]]
}

@test "supports multi-word queries without quoting" {
  run search notes setup
  [ "$status" -eq 0 ]
  [[ "$output" == *"[repo] README.md:"* ]]
  [[ "$output" == *"[fold] notes/obfuscation.md:"* ]]
}

@test "--source limits the search scope" {
  run search --source fold obfuscation
  [ "$status" -eq 0 ]
  [[ "$output" == *"[fold] notes/obfuscation.md:"* ]]
  [[ "$output" != *"[human] HUMAN.md:"* ]]
}

@test "source:list is routed through the main command" {
  run search source:list
  [ "$status" -eq 0 ]
  [[ "$output" == *"SOURCE"* ]]
  [[ "$output" == *"fold"* ]]
  [[ "$output" == *"human"* ]]
}

@test "explicit unavailable source fails clearly" {
  run search --source den obfuscation
  [ "$status" -ne 0 ]
  [[ "$output" == *"source 'den' is not available"* ]]
}
