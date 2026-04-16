# search

Search across the knowledge you already have access to.

## Early shape

```bash
search obfuscation
search --source fold obfuscation
search source:list
```

V1 is intentionally small:
- local accessible sources only
- `rg`-backed text search
- smart defaults for agent workspace knowledge

## Sources

The first implementation knows about a few source names:
- `repo`
- `zettel`
- `fold`
- `den`
- `human`

If a source is missing locally, it is skipped by default and rejected when explicitly requested.
