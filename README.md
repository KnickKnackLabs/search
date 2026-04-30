<div align="center">

# search

**Search across the knowledge providers you already have access to.**

Home notes, HUMAN.md, web results, GitHub issues, pull requests, and code search — one provider-shaped interface instead of another pile of one-off commands.

![shell: bash](https://img.shields.io/badge/shell-bash-4EAA25?style=flat&logo=gnubash&logoColor=white)
[![runtime: mise](https://img.shields.io/badge/runtime-mise-7c3aed?style=flat)](https://mise.jdx.dev)
![tests: 18 passing](https://img.shields.io/badge/tests-18%20passing-brightgreen?style=flat)
![providers: 6](https://img.shields.io/badge/providers-6-blue?style=flat)

</div>

## Shape

The command is explicit about which provider is being searched. There is no naked `search "query"` entry point; use `search all` for blended search or choose a provider directly.

```bash
search all "query"
search notes "query"
search human "query"
search web "query"
search issues --repo OWNER/REPO "query"
search prs --repo OWNER/REPO "query"
search code --repo OWNER/REPO "query"
search providers
```

## Providers

- `notes` — local markdown sources: home notes, plus discovered `home/modules/*` modules
- `human` — Or's HUMAN.md via `HUMAN_MD` or `SEARCH_SOURCE_HUMAN`
- `web` — Brave Search API
- `issues` — GitHub issues via `gh search issues`
- `prs` — GitHub pull requests via `gh search prs`
- `code` — GitHub code via `gh search code`

## Blended search

`search all` runs configured providers. Local notes are always included. HUMAN.md is included when available. Web is included when `BRAVE_SEARCH_API_KEY` is set. GitHub providers are included when they have a default repo configured or a repo override is supplied.

```bash
# Search every configured provider
search all "modules init"

# Provider flags select only those providers
search all --notes --issues "explicit model"
search all --human "obfuscated home"

# Provider-prefixed overrides configure individual providers
search all --notes-limit 3 "frontmatter"
search all --issues --issues-repo KnickKnackLabs/shimmer --issues-limit 5 "model"
```

No `--no-*` flags are provided yet. Selection flags are the simpler narrowing mechanism.

## Provider defaults

Each provider owns its own defaults. Override provider settings with environment variables using `SEARCH_<PROVIDER>_<VARIABLE>`.

```bash
SEARCH_NOTES_LIMIT=5 search notes "query"
SEARCH_HUMAN_LIMIT=5 search human "query"
SEARCH_WEB_LIMIT=3 search web "query"
SEARCH_ISSUES_DEFAULT_REPO=KnickKnackLabs/shimmer search issues "model plumbing"
SEARCH_PRS_DEFAULT_REPO=KnickKnackLabs/search search prs "provider"
SEARCH_CODE_DEFAULT_REPO=KnickKnackLabs/search search code "search_all"
```

GitHub providers intentionally do not hardcode organization defaults. Pass `--repo OWNER/REPO` or set the provider's default repo env var.

## Web search

```bash
export BRAVE_SEARCH_API_KEY=...
search web --limit 5 "mise tasks"
search web --json "mise tasks"
```

## Local notes and HUMAN.md

```bash
search notes "frontmatter"
search notes --source <module-name> "modules init"
search human "obfuscated home"
```

`notes` searches markdown in the agent's home and discovered modules under `home/modules/*`. `human` stays a separate provider even though `search all` includes it when available. Available sources are shown by `search providers`.

## Development

```bash
gh repo clone KnickKnackLabs/search
cd search
mise trust && mise install
mise run test
readme build --check
```

Tests use [BATS](https://github.com/bats-core/bats-core) — 18 tests across 1 suite.

<div align="center">

README generated from `README.tsx` with [readme](https://github.com/KnickKnackLabs/readme).

</div>
