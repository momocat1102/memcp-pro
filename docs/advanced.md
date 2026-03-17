# Advanced Configuration

## Memory Scope

memcp supports two scopes for organizing memories:

- **`scope="project"`** (default) — Memories tied to a specific project. Automatically detected from the git repo name or current directory.
- **`scope="global"`** — Cross-project memories. Use for personal preferences, universal knowledge, and patterns that apply everywhere.

**Rule of thumb:** Would this memory be useful in a different project? Yes → global, No → project.

## Environment Variables

Set these in your shell profile or in the MCP server config:

| Variable | Default | Description |
|----------|---------|-------------|
| `MEMCP_DATA_DIR` | `~/.memcp` | Where graph.db and contexts are stored |
| `MEMCP_MAX_INSIGHTS` | 10000 | Maximum number of stored memories |
| `MEMCP_MAX_CONTEXT_SIZE_MB` | 10 | Max size for stored context files |
| `MEMCP_SEMANTIC_DEDUP` | false | Enable semantic deduplication |
| `MEMCP_DEDUP_THRESHOLD` | 0.95 | Similarity threshold for dedup |
| `MEMCP_SECRET_DETECTION` | true | Block saving secrets/credentials |

To set environment variables for the MCP server, edit `~/.claude/mcp.json`:

```json
{
  "mcpServers": {
    "memcp": {
      "command": "/path/to/.venv/bin/python",
      "args": ["-m", "memcp.server"],
      "cwd": "/path/to/memcp",
      "env": {
        "MEMCP_DATA_DIR": "/custom/path",
        "MEMCP_SEMANTIC_DEDUP": "true"
      }
    }
  }
}
```

## Cross-Project Memory Access

By default, each project only sees its own memories plus `_global` memories. To access another project's memories:

```
memcp_recall(project="other-project-name")
memcp_search(query="something", scope="all")
memcp_access_config(project="other-project-name", access="read")
```

## Retention & Cleanup

memcp includes a retention system based on Weibull decay — older, less-reinforced memories naturally fade:

```
memcp_retention_preview()          # See what would be cleaned up
memcp_retention_run()              # Execute retention cleanup
memcp_consolidation_preview()      # See what would be consolidated
memcp_consolidate()                # Merge similar memories
```

## Smart Dedup Workflow

Before saving a memory, check for duplicates:

```
1. memcp_dedup_check(content="what you want to save")
   → Returns 0-3 candidate duplicates

2. memcp_smart_remember(
     content="...",
     decision="CREATE|SKIP|SUPERSEDE|MERGE|SUPPORT",
     l0_abstract="≤100 char summary",
     l1_overview="≤500 char detail"
   )
```

Decisions:
- **CREATE** — New unique knowledge
- **SKIP** — Already exists, don't save
- **SUPERSEDE** — Replace an outdated memory
- **MERGE** — Combine with an existing memory
- **SUPPORT** — Add supporting evidence to an existing memory

## Troubleshooting

### memcp not connecting
1. Check `~/.claude/mcp.json` has the memcp entry
2. Verify the Python path exists: `ls -la ~/.claude/mcp-servers/memcp/.venv/bin/python`
3. Test manually: `~/.claude/mcp-servers/memcp/.venv/bin/python -m memcp.server`

### Memories not loading at session start
1. Check `~/.claude/hooks/memcp-session-start.sh` exists and is executable
2. Check `~/.claude/settings.json` has the SessionStart hook configured
3. Verify graph.db has data: `sqlite3 ~/.memcp/graph.db "SELECT COUNT(*) FROM nodes;"`

### Permission denied on hooks
```bash
chmod +x ~/.claude/hooks/memcp-*.sh
```
