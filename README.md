# memcp-pro

One-click setup for [memcp](https://github.com/anthropics/memcp) with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — persistent memory across sessions.

## What This Does

- Installs **memcp** MCP server (persistent knowledge graph memory)
- Registers it with Claude Code so it connects automatically
- Configures **hooks** for auto-loading memories and save reminders
- Adds **skills** for manual memory operations (`/memcp-save`, `/memcp-search`, `/memcp-session-start`)
- Sets up **permissions** so memcp tools work without manual approval

After installation, restart Claude Code and your memories will be there.

## Prerequisites

- **Python 3.11+** — memcp is a Python MCP server
- **sqlite3** — used by the SessionStart hook to query the knowledge graph
- **Claude Code** — `npm install -g @anthropic-ai/claude-code`
- **jq** (optional) — for JSON config merging. Falls back to Python if unavailable

## Quick Start

```bash
git clone https://github.com/momocat1102/memcp-pro.git
cd memcp-pro
bash install.sh
```

Then **restart Claude Code**. That's it.

## What Gets Installed

| Component | Location | Purpose |
|-----------|----------|---------|
| memcp server | `~/.claude/mcp-servers/memcp/` | MCP server with knowledge graph (graph.db) |
| Hooks (4) | `~/.claude/hooks/memcp-*.sh` | Auto-load memories, save reminders, compact protection |
| Skills (3) | `~/.claude/skills/memcp-*/` | `/memcp-save`, `/memcp-search`, `/memcp-session-start` |
| MCP config | `~/.claude/mcp.json` | Server registration (merged, not overwritten) |
| Permissions | `~/.claude/settings.json` | Tool auto-approval (merged, not overwritten) |
| Protocol | `~/.claude/CLAUDE.md` | Memory management guidelines (optional, appended) |

### How It Connects

Claude Code reads `~/.claude/mcp.json` at startup to discover MCP servers. The installer writes the memcp entry with **absolute paths** (not `$HOME`) so Claude Code can launch the server immediately. Permissions in `settings.json` ensure all 27 memcp tools are auto-approved.

## Hooks

| Hook | Event | What It Does |
|------|-------|-------------|
| `memcp-session-start.sh` | SessionStart | Queries graph.db for critical/high-importance memories and injects them into the conversation |
| `memcp-pre-compact.sh` | PreCompact | Blocks compaction and reminds Claude to save knowledge first |
| `memcp-stop.sh` | Stop | Progressive reminders at 10/20/30 turns when context usage > 55% |
| `memcp-reset-counter.sh` | PostToolUse | Resets turn counter after `memcp_remember` calls |

## Skills

| Skill | Trigger | What It Does |
|-------|---------|-------------|
| `/memcp-session-start` | "load memory", "recall context" | Manually load memories from memcp |
| `/memcp-save` | "save memory", "remember this" | Review session and save important knowledge |
| `/memcp-search` | "search memory", "what did we decide about X" | Search the knowledge graph |

## Non-Destructive Config Merging

The installer **never overwrites** your existing `mcp.json` or `settings.json`. It uses `jq` (or Python fallback) to merge memcp entries alongside your existing configuration. Running `install.sh` multiple times is safe (idempotent).

## Works with Agentic Me

This is a **standalone** memory setup that works with any Claude Code project. For the full AI agent collaboration system with Central Command, Dashboard, and multi-agent coordination, see [Agentic Me](https://github.com/momocat1102/agentic-me).

## Uninstall

```bash
bash uninstall.sh
```

Removes hooks, skills, MCP config, and permissions. Your memory data (`~/.memcp/`) is preserved unless you explicitly choose to delete it.

## License

MIT
