# memcp-pro

One-click setup for [memcp](https://github.com/maydali28/memcp) with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — persistent memory across sessions.

## What This Does

- Installs **memcp** MCP server (persistent knowledge graph memory)
- Registers it with Claude Code so it connects automatically
- Configures **hooks** for auto-loading memories and save reminders
- Adds **skills** for manual memory operations (`/memcp-save`, `/memcp-search`, `/memcp-session-start`)
- Sets up **permissions** so memcp tools work without manual approval

After installation, restart Claude Code and your memories will be there.

## What Makes It "Pro"

memcp-pro installs an **enhanced fork** of memcp with upgrades across memory lifecycle, search, and multi-project support — built and battle-tested over real Claude Code workflows.

### Core Enhancements (in memcp fork)

| Feature | What It Does |
|---------|-------------|
| **Weibull Decay Engine** | Three-tier memory classification (peripheral → working → core) with mathematically-modeled forgetting curves. Each tier has distinct decay parameters so important memories last longer naturally. |
| **7-Decision Smart Dedup** | LLM-powered deduplication with 7 decisions: CREATE, SKIP, MERGE, SUPERSEDE, SUPPORT, CONTEXTUALIZE, CONTRADICT. Prevents memory bloat while preserving nuance. |
| **L0/L1 Layered Storage** | Every memory gets a one-sentence index (L0, ≤100 chars) and a structured overview (L1, ≤500 chars). Search matches against L0 first for speed, then loads L1 for detail. |
| **Search Pipeline Tuning** | Length normalization, BM25 protection, CJK-aware thresholds (6 chars), recency boost, MMR diversity, and support_count boost — optimized for real-world multilingual usage. |
| **Cross-Project Memory** | `access.json` config with wildcard patterns and `source_project` annotation. Share knowledge across projects without duplicating memories. |
| **Tier Auto-Promotion** | Memories automatically promote (peripheral → working → core) or demote based on recall frequency. Frequently accessed knowledge becomes permanent. |
| **Caller-Side Architecture** | `memcp_dedup_check` + `memcp_smart_remember` run dedup logic on the Claude side — **no API key needed** in the MCP server. |

### Pro Integration Layer (hooks + skills + protocol)

| Component | What It Does |
|-----------|-------------|
| **4 Lifecycle Hooks** | SessionStart auto-load, PreCompact save reminder, progressive Stop warnings (10/20/30 turns at >55% context), PostToolUse counter reset |
| **3 Skills** | `/memcp-save`, `/memcp-search`, `/memcp-session-start` — manual memory operations with guided workflows |
| **Memory Protocol** | CLAUDE.md protocol for smart dedup workflow: check → decide → store. Includes knowledge extraction triggers and scope selection rules (project vs global) |
| **27 Auto-Approved Tools** | All memcp MCP tools pre-configured for zero-friction usage |

### Test Coverage

656 tests passing, including 198 tests specifically for the pro enhancements.

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

## Acknowledgments

The pro enhancements were designed by studying and building upon these projects and ideas:

- [memcp](https://github.com/maydali28/memcp) by maydali28 — The core MCP memory server that memcp-pro enhances. All pro features are built on top of memcp's knowledge graph architecture (SQLite + edge-based traversal + 27 MCP tools).
- [Claude Code](https://github.com/anthropics/claude-code) by Anthropic — The AI coding agent that memcp-pro integrates with via hooks, skills, and MCP protocol.
- **memory-lancedb-pro** (internal predecessor) — Our earlier TypeScript memory system (LanceDB + Jina Embeddings) whose cognitive-science design patterns (Weibull decay, seven dedup decisions, L0/L1/L2 layered storage) were ported to memcp's Python/SQLite architecture.
- **Weibull stretched exponential decay** — The three-tier decay model is inspired by cognitive science research on forgetting curves, using the Weibull distribution to model different memory retention patterns. [FSRS](https://github.com/open-spaced-repetition/fsrs4anki) (Free Spaced Repetition Scheduler) was evaluated as an alternative but deemed too complex (21 parameters) for this use case.
- **BM25 / Okapi BM25** — The search pipeline's keyword matching and high-confidence protection are based on the classic BM25 ranking function from information retrieval.
- **MMR (Maximal Marginal Relevance)** — The diversity-aware result deduplication follows the MMR algorithm (Carbonell & Goldstein, 1998) to reduce redundancy in search results.

## License

MIT
