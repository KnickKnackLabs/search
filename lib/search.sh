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

search_print_usage() {
  cat <<'EOF'
Usage:
  search all [provider flags] [provider overrides] <query>
  search notes [--limit N] [--source SOURCE] <query>
  search web [--limit N] [--offset N] [--json] <query>
  search issues [--limit N] [--repo OWNER/REPO] <query>
  search prs [--limit N] [--repo OWNER/REPO] <query>
  search code [--limit N] [--repo OWNER/REPO] <query>
  search providers

Providers:
  notes   Local markdown sources: repo, home, fold, den, human
  web     Brave Search API (BRAVE_SEARCH_API_KEY)
  issues  GitHub issues via gh search issues
  prs     GitHub pull requests via gh search prs
  code    GitHub code via gh search code

Provider env overrides follow SEARCH_<PROVIDER>_<VARIABLE>:
  SEARCH_NOTES_LIMIT=20
  SEARCH_WEB_LIMIT=5
  SEARCH_ISSUES_DEFAULT_REPO=OWNER/REPO
  SEARCH_PRS_DEFAULT_REPO=OWNER/REPO
  SEARCH_CODE_DEFAULT_REPO=OWNER/REPO
EOF
}

search_require_query() {
  local provider="$1"
  local query="$2"

  if [ -z "$query" ]; then
    echo "search: query is required for '$provider'" >&2
    return 1
  fi
}

search_validate_limit() {
  local limit="$1"
  local provider="$2"

  case "$limit" in
    ''|*[!0-9]*)
      echo "search: $provider limit must be a positive integer" >&2
      return 1
      ;;
    0)
      echo "search: $provider limit must be greater than 0" >&2
      return 1
      ;;
  esac
}

search_validate_nonnegative_integer() {
  local value="$1"
  local name="$2"

  case "$value" in
    ''|*[!0-9]*)
      echo "search: $name must be a non-negative integer" >&2
      return 1
      ;;
  esac
}

search_notes() {
  local limit
  local query
  local arg
  local source_name
  local source_path
  local output
  local status
  local line
  local file_path
  local remainder
  local line_no
  local text
  local rel_path
  local count=0
  local had_results=false
  local sources=()
  local query_words=()

  limit="$(search_default_limit notes 20)"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --help|-h)
        search_print_usage
        return 0
        ;;
      --limit|-n)
        if [ "$#" -lt 2 ]; then
          echo "search: --limit requires a value" >&2
          return 1
        fi
        limit="$2"
        shift 2
        ;;
      --source)
        if [ "$#" -lt 2 ]; then
          echo "search: --source requires a value" >&2
          return 1
        fi
        sources+=("$2")
        shift 2
        ;;
      --)
        shift
        while [ "$#" -gt 0 ]; do
          query_words+=("$1")
          shift
        done
        ;;
      -*)
        echo "search: unknown notes option '$1'" >&2
        return 1
        ;;
      *)
        query_words+=("$1")
        shift
        ;;
    esac
  done

  search_validate_limit "$limit" notes || return 1
  query="$(search_join_args ${query_words[@]+"${query_words[@]}"})"
  search_require_query notes "$query" || return 1

  if [ ${#sources[@]} -eq 0 ]; then
    while IFS='|' read -r source_name _source_path; do
      sources+=("$source_name")
    done < <(search_available_note_sources)
  fi

  if [ ${#sources[@]} -eq 0 ]; then
    echo "search: no notes sources are available" >&2
    return 1
  fi

  for source_name in ${sources[@]+"${sources[@]}"}; do
    if ! search_known_note_source "$source_name"; then
      echo "search: unknown notes source '$source_name'" >&2
      return 1
    fi

    source_path="$(search_source_path "$source_name")"
    if [ -z "$source_path" ] || [ ! -e "$source_path" ]; then
      echo "search: notes source '$source_name' is not available" >&2
      return 1
    fi

    output=""
    status=0
    output="$(search_rg "$query" "$source_path")" || status=$?
    if [ "$status" -ne 0 ]; then
      if [ "$status" -ne 1 ]; then
        return "$status"
      fi
      continue
    fi

    while IFS= read -r line; do
      file_path="${line%%:*}"
      remainder="${line#*:}"
      line_no="${remainder%%:*}"
      text="${remainder#*:}"
      rel_path="$(search_relpath "$file_path" "$source_path")"
      printf '[notes:%s] %s:%s: %s\n' "$source_name" "$rel_path" "$line_no" "$text"
      had_results=true
      count=$((count + 1))
      if [ "$count" -ge "$limit" ]; then
        return 0
      fi
    done <<EOF
$output
EOF
  done

  if [ "$had_results" != "true" ]; then
    echo "search: no notes results for '$query'" >&2
    return 1
  fi
}

search_web() {
  local limit
  local offset="0"
  local json_output="false"
  local query
  local response
  local results
  local count
  local query_words=()

  limit="$(search_default_limit web 5)"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --help|-h)
        search_print_usage
        return 0
        ;;
      --limit|-n|--count)
        if [ "$#" -lt 2 ]; then
          echo "search: --limit requires a value" >&2
          return 1
        fi
        limit="$2"
        shift 2
        ;;
      --offset)
        if [ "$#" -lt 2 ]; then
          echo "search: --offset requires a value" >&2
          return 1
        fi
        offset="$2"
        shift 2
        ;;
      --json)
        json_output="true"
        shift
        ;;
      --)
        shift
        while [ "$#" -gt 0 ]; do
          query_words+=("$1")
          shift
        done
        ;;
      -*)
        echo "search: unknown web option '$1'" >&2
        return 1
        ;;
      *)
        query_words+=("$1")
        shift
        ;;
    esac
  done

  search_validate_limit "$limit" web || return 1
  search_validate_nonnegative_integer "$offset" "web offset" || return 1
  query="$(search_join_args ${query_words[@]+"${query_words[@]}"})"
  search_require_query web "$query" || return 1

  if [ -z "${BRAVE_SEARCH_API_KEY:-}" ]; then
    echo "search: BRAVE_SEARCH_API_KEY not set" >&2
    echo "search: get one at https://brave.com/search/api/" >&2
    return 1
  fi

  response="$(${CURL:-curl} -sS -G "https://api.search.brave.com/res/v1/web/search" \
    -H "Accept: application/json" \
    -H "X-Subscription-Token: ${BRAVE_SEARCH_API_KEY}" \
    --data-urlencode "q=${query}" \
    --data-urlencode "count=${limit}" \
    --data-urlencode "offset=${offset}" \
    --compressed)"

  if ! printf '%s\n' "$response" | ${JQ:-jq} empty >/dev/null 2>&1; then
    echo "search: unexpected web response (not JSON)" >&2
    printf '%s\n' "$response" | head -5 >&2
    return 1
  fi

  if printf '%s\n' "$response" | ${JQ:-jq} -e '.type == "ErrorResponse"' >/dev/null 2>&1; then
    printf '%s\n' "$response" | ${JQ:-jq} -r '.detail // .message // "Unknown API error"' >&2
    return 1
  fi

  if [ "$json_output" = "true" ]; then
    printf '%s\n' "$response" | ${JQ:-jq} '.web.results // []'
    return 0
  fi

  results="$(printf '%s\n' "$response" | ${JQ:-jq} -c '.web.results // []')"
  count="$(printf '%s\n' "$results" | ${JQ:-jq} 'length')"

  if [ "$count" = "0" ]; then
    echo "search: no web results for '$query'" >&2
    return 1
  fi

  printf '%s\n' "$results" | ${JQ:-jq} -r '
    def decode_html:
      gsub("<[^>]*>"; "")
      | gsub("&quot;"; "\"")
      | gsub("&amp;"; "&")
      | gsub("&lt;"; "<")
      | gsub("&gt;"; ">")
      | gsub("&#x27;"; "'"'"'")
      | gsub("&#39;"; "'"'"'")
      | gsub("&nbsp;"; " ");

    to_entries[] |
      "[web] " + (.value.title // "Untitled")
      + "\n  " + (.value.url // "")
      + (if (.value.description // "") != "" then
          "\n  " + ((.value.description | decode_html) as $d | if ($d | length) > 200 then $d[0:200] + "..." else $d end)
        else "" end)
  '
}

search_github() {
  local provider="$1"
  local gh_command="$2"
  shift 2
  local limit
  local repo=""
  local query
  local query_words=()
  local output

  limit="$(search_default_limit "$provider" 10)"
  repo="$(search_default_repo "$provider")"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --help|-h)
        search_print_usage
        return 0
        ;;
      --limit|-n)
        if [ "$#" -lt 2 ]; then
          echo "search: --limit requires a value" >&2
          return 1
        fi
        limit="$2"
        shift 2
        ;;
      --repo|-R)
        if [ "$#" -lt 2 ]; then
          echo "search: --repo requires a value" >&2
          return 1
        fi
        repo="$2"
        shift 2
        ;;
      --)
        shift
        while [ "$#" -gt 0 ]; do
          query_words+=("$1")
          shift
        done
        ;;
      -*)
        echo "search: unknown $provider option '$1'" >&2
        return 1
        ;;
      *)
        query_words+=("$1")
        shift
        ;;
    esac
  done

  search_validate_limit "$limit" "$provider" || return 1
  query="$(search_join_args ${query_words[@]+"${query_words[@]}"})"
  search_require_query "$provider" "$query" || return 1

  if [ -z "$repo" ]; then
    echo "search: $provider requires --repo OWNER/REPO or $(search_env_name "$provider" default_repo)" >&2
    return 1
  fi

  case "$provider" in
    issues|prs)
      output="$(${GH:-gh} search "$gh_command" "$query" --repo "$repo" --limit "$limit" --json repository,number,title,url,state --jq \
        '.[] | "['"$provider"'] \(.repository.nameWithOwner)#\(.number) [\(.state)] \(.title)\n  \(.url)"')"
      ;;
    code)
      output="$(${GH:-gh} search code "$query" --repo "$repo" --limit "$limit" --json repository,path,url --jq \
        '.[] | "[code] \(.repository.nameWithOwner):\(.path)\n  \(.url)"')"
      ;;
  esac

  if [ -z "$output" ]; then
    echo "search: no $provider results for '$query'" >&2
    return 1
  fi

  printf '%s\n' "$output"
}

search_provider_configured_for_all() {
  local provider="$1"
  local repo_arg="$2"

  case "$provider" in
    notes)
      return 0
      ;;
    web)
      [ -n "${BRAVE_SEARCH_API_KEY:-}" ] && return 0
      return 1
      ;;
    issues|prs|code)
      if [ -n "$repo_arg" ] || [ -n "$(search_default_repo "$provider")" ]; then
        return 0
      fi
      return 1
      ;;
  esac
}

search_all() {
  local selected_any=false
  local select_notes=false
  local select_web=false
  local select_issues=false
  local select_prs=false
  local select_code=false
  local query
  local provider
  local had_results=false
  local status
  local query_words=()
  local notes_args=()
  local web_args=()
  local issues_args=()
  local prs_args=()
  local code_args=()
  local issues_repo_arg=""
  local prs_repo_arg=""
  local code_repo_arg=""
  local providers=()

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --help|-h)
        search_print_usage
        return 0
        ;;
      --notes)
        select_notes=true; selected_any=true; shift ;;
      --web)
        select_web=true; selected_any=true; shift ;;
      --issues)
        select_issues=true; selected_any=true; shift ;;
      --prs)
        select_prs=true; selected_any=true; shift ;;
      --code)
        select_code=true; selected_any=true; shift ;;
      --notes-limit)
        [ "$#" -ge 2 ] || { echo "search: --notes-limit requires a value" >&2; return 1; }
        notes_args+=(--limit "$2"); shift 2 ;;
      --notes-source)
        [ "$#" -ge 2 ] || { echo "search: --notes-source requires a value" >&2; return 1; }
        notes_args+=(--source "$2"); shift 2 ;;
      --web-limit)
        [ "$#" -ge 2 ] || { echo "search: --web-limit requires a value" >&2; return 1; }
        web_args+=(--limit "$2"); shift 2 ;;
      --web-offset)
        [ "$#" -ge 2 ] || { echo "search: --web-offset requires a value" >&2; return 1; }
        web_args+=(--offset "$2"); shift 2 ;;
      --issues-limit)
        [ "$#" -ge 2 ] || { echo "search: --issues-limit requires a value" >&2; return 1; }
        issues_args+=(--limit "$2"); shift 2 ;;
      --issues-repo)
        [ "$#" -ge 2 ] || { echo "search: --issues-repo requires a value" >&2; return 1; }
        issues_repo_arg="$2"; issues_args+=(--repo "$2"); shift 2 ;;
      --prs-limit)
        [ "$#" -ge 2 ] || { echo "search: --prs-limit requires a value" >&2; return 1; }
        prs_args+=(--limit "$2"); shift 2 ;;
      --prs-repo)
        [ "$#" -ge 2 ] || { echo "search: --prs-repo requires a value" >&2; return 1; }
        prs_repo_arg="$2"; prs_args+=(--repo "$2"); shift 2 ;;
      --code-limit)
        [ "$#" -ge 2 ] || { echo "search: --code-limit requires a value" >&2; return 1; }
        code_args+=(--limit "$2"); shift 2 ;;
      --code-repo)
        [ "$#" -ge 2 ] || { echo "search: --code-repo requires a value" >&2; return 1; }
        code_repo_arg="$2"; code_args+=(--repo "$2"); shift 2 ;;
      --)
        shift
        while [ "$#" -gt 0 ]; do
          query_words+=("$1")
          shift
        done
        ;;
      -*)
        echo "search: unknown all option '$1'" >&2
        return 1
        ;;
      *)
        query_words+=("$1")
        shift
        ;;
    esac
  done

  query="$(search_join_args ${query_words[@]+"${query_words[@]}"})"
  search_require_query all "$query" || return 1

  if [ "$selected_any" = "true" ]; then
    [ "$select_notes" = "true" ] && providers+=(notes)
    [ "$select_web" = "true" ] && providers+=(web)
    [ "$select_issues" = "true" ] && providers+=(issues)
    [ "$select_prs" = "true" ] && providers+=(prs)
    [ "$select_code" = "true" ] && providers+=(code)
  else
    providers+=(notes)
    search_provider_configured_for_all web "" && providers+=(web)
    search_provider_configured_for_all issues "$issues_repo_arg" && providers+=(issues)
    search_provider_configured_for_all prs "$prs_repo_arg" && providers+=(prs)
    search_provider_configured_for_all code "$code_repo_arg" && providers+=(code)
  fi

  for provider in ${providers[@]+"${providers[@]}"}; do
    printf '== %s ==\n' "$provider"
    status=0
    case "$provider" in
      notes) search_notes ${notes_args[@]+"${notes_args[@]}"} "$query" || status=$? ;;
      web) search_web ${web_args[@]+"${web_args[@]}"} "$query" || status=$? ;;
      issues) search_github issues issues ${issues_args[@]+"${issues_args[@]}"} "$query" || status=$? ;;
      prs) search_github prs prs ${prs_args[@]+"${prs_args[@]}"} "$query" || status=$? ;;
      code) search_github code code ${code_args[@]+"${code_args[@]}"} "$query" || status=$? ;;
    esac

    if [ "$status" -eq 0 ]; then
      had_results=true
    elif [ "$selected_any" = "true" ]; then
      return "$status"
    fi
    printf '\n'
  done

  if [ "$had_results" != "true" ]; then
    echo "search: no results for '$query'" >&2
    return 1
  fi
}

search_providers() {
  local source_name
  local source_path

  printf 'PROVIDER  STATUS\n'
  printf 'notes     available local sources:\n'
  while IFS='|' read -r source_name source_path; do
    printf '          %-8s %s\n' "$source_name" "$source_path"
  done < <(search_available_note_sources)

  if [ -n "${BRAVE_SEARCH_API_KEY:-}" ]; then
    printf 'web       configured (BRAVE_SEARCH_API_KEY set)\n'
  else
    printf 'web       missing BRAVE_SEARCH_API_KEY\n'
  fi

  printf 'issues    %s\n' "$(search_default_repo issues | awk '{ if ($0 == "") print "requires --repo or SEARCH_ISSUES_DEFAULT_REPO"; else print "default repo: " $0 }')"
  printf 'prs       %s\n' "$(search_default_repo prs | awk '{ if ($0 == "") print "requires --repo or SEARCH_PRS_DEFAULT_REPO"; else print "default repo: " $0 }')"
  printf 'code      %s\n' "$(search_default_repo code | awk '{ if ($0 == "") print "requires --repo or SEARCH_CODE_DEFAULT_REPO"; else print "default repo: " $0 }')"
}
