# memcp-pro

一鍵安裝 [memcp](https://github.com/maydali28/memcp) 到 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — 跨 session 持久記憶。

## 功能

- 安裝 **memcp** MCP server（持久知識圖譜記憶）
- 自動註冊到 Claude Code，啟動即連接
- 設定 **hooks** 自動載入記憶、提醒存檔
- 新增 **skills** 手動操作記憶（`/memcp-save`、`/memcp-search`、`/memcp-session-start`）
- 設定 **permissions** 讓 memcp 工具免手動批准

安裝完成後，重啟 Claude Code 即可使用。

## 前置需求

- **Python 3.11+** — memcp 是 Python MCP server
- **sqlite3** — SessionStart hook 需要查詢知識圖譜
- **Claude Code** — `npm install -g @anthropic-ai/claude-code`
- **jq**（可選）— 用於 JSON 設定合併，無 jq 時自動使用 Python 替代

## 快速開始

```bash
git clone https://github.com/momocat1102/memcp-pro.git
cd memcp-pro
bash install.sh
```

然後**重啟 Claude Code**，搞定。

## 安裝內容

| 元件 | 位置 | 用途 |
|------|------|------|
| memcp server | `~/.claude/mcp-servers/memcp/` | MCP server，知識圖譜（graph.db）|
| Hooks (4) | `~/.claude/hooks/memcp-*.sh` | 自動載入記憶、存檔提醒、壓縮保護 |
| Skills (3) | `~/.claude/skills/memcp-*/` | `/memcp-save`、`/memcp-search`、`/memcp-session-start` |
| MCP 設定 | `~/.claude/mcp.json` | Server 註冊（合併，不覆蓋）|
| 權限 | `~/.claude/settings.json` | 工具自動批准（合併，不覆蓋）|
| 協議 | `~/.claude/CLAUDE.md` | 記憶管理指引（可選，附加到尾部）|

### 連接原理

Claude Code 啟動時讀取 `~/.claude/mcp.json` 來發現 MCP server。安裝程式會寫入**絕對路徑**（不是 `$HOME`），確保 Claude Code 能直接啟動 memcp server。`settings.json` 中的 permissions 讓全部 27 個 memcp 工具免手動批准。

## Hooks

| Hook | 事件 | 功能 |
|------|------|------|
| `memcp-session-start.sh` | SessionStart | 從 graph.db 查詢 critical/high 記憶，注入對話開頭 |
| `memcp-pre-compact.sh` | PreCompact | 阻擋壓縮，提醒先存記憶 |
| `memcp-stop.sh` | Stop | 10/20/30 輪時漸進提醒（context > 55%）|
| `memcp-reset-counter.sh` | PostToolUse | `memcp_remember` 後重置輪數計數器 |

## Skills

| Skill | 觸發方式 | 功能 |
|-------|---------|------|
| `/memcp-session-start` | "load memory"、"recall context" | 手動載入記憶 |
| `/memcp-save` | "save memory"、"remember this" | 回顧 session 存重要知識 |
| `/memcp-search` | "search memory"、"之前決定了什麼" | 搜尋知識圖譜 |

## 非破壞性設定合併

安裝程式**不會覆蓋**現有的 `mcp.json` 或 `settings.json`，使用 `jq`（或 Python fallback）合併 memcp 設定到現有設定中。重複執行 `install.sh` 是安全的（冪等）。

## 搭配 Agentic Me

這是**獨立的**記憶安裝工具，可用於任何 Claude Code 專案。如需完整的 AI Agent 協作系統（Central Command、Dashboard、多 Agent 協調），請見 [Agentic Me](https://github.com/momocat1102/agentic-me)。

## 解除安裝

```bash
bash uninstall.sh
```

移除 hooks、skills、MCP 設定和 permissions。記憶資料（`~/.memcp/`）會保留，除非你選擇刪除。

## 授權

MIT
