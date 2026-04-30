#!/usr/bin/env bats

bats_require_minimum_version 1.5.0
load ./test_helper.bash

setup() {
  export CALLER_PWD="$BATS_TEST_TMPDIR/repo"
  export SEARCH_AGENT_ROOT="$BATS_TEST_TMPDIR/agent"
  export HUMAN_MD="$BATS_TEST_TMPDIR/HUMAN.md"
  export BRAVE_SEARCH_API_KEY="test-key-123"
  export CURL="$BATS_TEST_TMPDIR/bin/curl"
  export GH="$BATS_TEST_TMPDIR/bin/gh"
  unset SEARCH_ISSUES_DEFAULT_REPO
  unset SEARCH_PRS_DEFAULT_REPO
  unset SEARCH_CODE_DEFAULT_REPO
  unset SEARCH_NOTES_LIMIT
  unset SEARCH_WEB_LIMIT
  unset SEARCH_ISSUES_LIMIT

  mkdir -p "$CALLER_PWD"
  mkdir -p "$SEARCH_AGENT_ROOT/home/modules/fold/notes"
  mkdir -p "$BATS_TEST_TMPDIR/bin"

  cat > "$CALLER_PWD/README.md" <<'EOF'
# Search fixture

notes setup is required before unlocking encrypted notes.
EOF

  cat > "$SEARCH_AGENT_ROOT/home/status.md" <<'EOF'
# Status

Need to follow up on provider namespaces later.
EOF

  cat > "$SEARCH_AGENT_ROOT/home/modules/fold/notes/obfuscation.md" <<'EOF'
# Obfuscation

Run notes setup and notes unlock before trying to read encrypted notes.
EOF

  cat > "$HUMAN_MD" <<'EOF'
# HUMAN

The fully obfuscation-focused home idea keeps coming up.
EOF

  mock_curl "$REPO_DIR/test/fixtures/brave-response.json"
  mock_gh
}

mock_curl() {
  local fixture="$1"
  cat > "$CURL" <<MOCK
#!/usr/bin/env bash
echo "\$@" > "$BATS_TEST_TMPDIR/curl-args"
cat "$fixture"
MOCK
  chmod +x "$CURL"
}

mock_gh() {
  cat > "$GH" <<MOCK
#!/usr/bin/env bash
echo "\$@" > "$BATS_TEST_TMPDIR/gh-args"
case "\$1 \$2" in
  "search issues")
    printf '[issues] KnickKnackLabs/shimmer#737 [open] require explicit model\\n  https://github.com/KnickKnackLabs/shimmer/issues/737\\n'
    ;;
  "search prs")
    printf '[prs] KnickKnackLabs/shimmer#738 [open] provider subcommands\\n  https://github.com/KnickKnackLabs/shimmer/pull/738\\n'
    ;;
  "search code")
    printf '[code] KnickKnackLabs/search:lib/search.sh\\n  https://github.com/KnickKnackLabs/search/blob/main/lib/search.sh\\n'
    ;;
  *)
    echo "unexpected gh args: \$*" >&2
    exit 1
    ;;
esac
MOCK
  chmod +x "$GH"
}

@test "rejects naked queries" {
  run search obfuscation
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown provider or command 'obfuscation'"* ]]
  [[ "$output" == *"search all"* ]]
}

@test "notes searches local markdown sources" {
  run search notes obfuscation
  [ "$status" -eq 0 ]
  [[ "$output" == *"[notes:fold] notes/obfuscation.md:"* ]]
  [[ "$output" != *"[human]"* ]]
}

@test "human searches HUMAN.md separately" {
  run search human obfuscation-focused
  [ "$status" -eq 0 ]
  [[ "$output" == *"[human] HUMAN.md:"* ]]
}

@test "repo is not a notes source" {
  run search notes --source repo notes
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown notes source 'repo'"* ]]
}

@test "notes limit caps local results" {
  run search notes --limit 1 notes
  [ "$status" -eq 0 ]
  result_count=$(printf '%s\n' "$output" | grep -c '^\[notes:')
  [ "$result_count" -eq 1 ]
}

@test "all searches notes and configured web by default" {
  run search all obfuscation
  [ "$status" -eq 0 ]
  [[ "$output" == *"== notes =="* ]]
  [[ "$output" == *"== web =="* ]]
  [[ "$output" == *"[notes:fold]"* ]]
  [[ "$output" != *"== human =="* ]]
  [[ "$output" == *"[web] First Result Title"* ]]
}

@test "all provider flags select only requested providers" {
  run search all --notes obfuscation
  [ "$status" -eq 0 ]
  [[ "$output" == *"== notes =="* ]]
  [[ "$output" != *"== web =="* ]]
}

@test "all can explicitly include human" {
  run search all --human obfuscation-focused
  [ "$status" -eq 0 ]
  [[ "$output" == *"== human =="* ]]
  [[ "$output" == *"[human] HUMAN.md:"* ]]
  [[ "$output" != *"== notes =="* ]]
}

@test "all selected providers continue after no-result providers" {
  run search all --notes --web unique-web-only
  [ "$status" -eq 0 ]
  [[ "$output" == *"== notes =="* ]]
  [[ "$output" == *"no notes results"* ]]
  [[ "$output" == *"== web =="* ]]
  [[ "$output" == *"[web] First Result Title"* ]]
}

@test "all supports provider-prefixed overrides" {
  run search all --notes --notes-limit 1 notes
  [ "$status" -eq 0 ]
  result_count=$(printf '%s\n' "$output" | grep -c '^\[notes:')
  [ "$result_count" -eq 1 ]
}

@test "web formats Brave results" {
  run search web test query
  [ "$status" -eq 0 ]
  [[ "$output" == *"[web] First Result Title"* ]]
  [[ "$output" == *"https://example.com/first"* ]]
  [[ "$output" == *'"quotes"'* ]]
  [[ "$output" != *"<b>"* ]]
}

@test "web json returns raw result array" {
  run search web --json test query
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e 'length == 3'
}

@test "web passes limit and offset to curl" {
  run search web --limit 7 --offset 10 test query
  [ "$status" -eq 0 ]
  grep -q 'count=7' "$BATS_TEST_TMPDIR/curl-args"
  grep -q 'offset=10' "$BATS_TEST_TMPDIR/curl-args"
}

@test "web reports API errors" {
  mock_curl "$REPO_DIR/test/fixtures/brave-error.json"
  run search web test query
  [ "$status" -ne 0 ]
  [[ "$output" == *"API key is invalid"* ]]
}

@test "issues requires repo flag or env default" {
  run search issues model plumbing
  [ "$status" -ne 0 ]
  [[ "$output" == *"SEARCH_ISSUES_DEFAULT_REPO"* ]]
}

@test "issues uses env default repo and provider limit" {
  export SEARCH_ISSUES_DEFAULT_REPO="KnickKnackLabs/shimmer"
  export SEARCH_ISSUES_LIMIT="4"
  run search issues model plumbing
  [ "$status" -eq 0 ]
  [[ "$output" == *"[issues] KnickKnackLabs/shimmer#737"* ]]
  grep -q -- '--repo KnickKnackLabs/shimmer' "$BATS_TEST_TMPDIR/gh-args"
  grep -q -- '--limit 4' "$BATS_TEST_TMPDIR/gh-args"
}

@test "all can select GitHub providers with prefixed repo override" {
  run search all --issues --issues-repo KnickKnackLabs/shimmer --issues-limit 2 model plumbing
  [ "$status" -eq 0 ]
  [[ "$output" == *"== issues =="* ]]
  [[ "$output" == *"[issues] KnickKnackLabs/shimmer#737"* ]]
  grep -q -- '--repo KnickKnackLabs/shimmer' "$BATS_TEST_TMPDIR/gh-args"
  grep -q -- '--limit 2' "$BATS_TEST_TMPDIR/gh-args"
}

@test "providers reports configuration" {
  run search providers
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROVIDER"* ]]
  [[ "$output" == *"notes"* ]]
  [[ "$output" == *"human"* ]]
  [[ "$output" == *"web"* ]]
  [[ "$output" == *"SEARCH_ISSUES_DEFAULT_REPO"* ]]
}
