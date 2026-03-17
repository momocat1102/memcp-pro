# memcp-pro

一鍵安裝 [memcp](https://github.com/maydali28/memcp)（v0.3.0）到 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — 跨 session 持久記憶。

## 功能

- 安裝 **memcp** MCP server（持久知識圖譜記憶）
- 自動註冊到 Claude Code，啟動即連接
- 設定 **hooks** 自動載入記憶、提醒存檔
- 新增 **skills** 手動操作記憶（`/memcp-save`、`/memcp-search`、`/memcp-session-start`）
- 設定 **permissions** 讓 memcp 工具免手動批准

安裝完成後，重啟 Claude Code 即可使用。

## 為什麼叫 "Pro"

memcp-pro 安裝的是 memcp 的**增強版 fork**，涵蓋記憶生命週期、搜尋管線、多專案支援的全面升級 — 在實際 Claude Code 工作流中開發與驗證。

### 核心增強（memcp fork 內建）

| 功能 | 說明 |
|------|------|
| **Weibull 衰減引擎** | 三層記憶分類（peripheral → working → core），數學建模的遺忘曲線。每層有不同 beta 參數，重要記憶自然存活更久。 |
| **七種智慧去重決策** | LLM 驅動的去重系統，支援 CREATE、SKIP、MERGE、SUPERSEDE、SUPPORT、CONTEXTUALIZE、CONTRADICT 七種決策。防止記憶膨脹同時保留細微差異。 |
| **L0/L1 分層儲存** | 每筆記憶都有一句話索引（L0，≤100 字元）和結構化概覽（L1，≤500 字元）。搜尋優先比對 L0 加速，再載入 L1 取得細節。 |
| **搜尋管線調校** | 長度正規化、BM25 保護、CJK 閾值（6 字元）、新近度加成、MMR 多樣性、support_count 加成 — 針對多語言實際使用最佳化。 |
| **跨專案記憶存取** | `access.json` 設定支援萬用字元和 `source_project` 標注。跨專案共享知識，不需複製記憶。 |
| **Tier 自動晉升/降級** | 記憶根據召回頻率自動晉升（peripheral → working → core）或降級。常用知識自動變為永久記憶。 |
| **Caller-side 架構** | `memcp_dedup_check` + `memcp_smart_remember` 在 Claude 端執行去重邏輯 — MCP server **不需要 API key**。 |

### Pro 整合層（hooks + skills + 協議）

| 元件 | 說明 |
|------|------|
| **4 個生命週期 Hooks** | SessionStart 自動載入、PreCompact 存檔提醒、漸進式 Stop 警告（10/20/30 輪，context > 55%）、PostToolUse 計數器重置 |
| **3 個 Skills** | `/memcp-save`、`/memcp-search`、`/memcp-session-start` — 手動記憶操作，附引導工作流 |
| **記憶管理協議** | CLAUDE.md 協議：查重 → 決策 → 存入的智慧去重工作流。包含知識提取觸發點和 scope 選擇規則（project vs global） |
| **27 個自動批准工具** | 所有 memcp MCP 工具預設免手動批准，零阻力使用 |

### 測試覆蓋

656 個測試通過，其中 198 個專為 Pro 增強功能撰寫。

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
| MCP 設定（CLI） | `~/.claude/mcp.json` | CLI 的 Server 註冊（合併，不覆蓋）|
| MCP 設定（VSCode） | `~/.claude.json` | VSCode extension 的 Server 註冊（透過 `claude mcp add`）|
| 權限 | `~/.claude/settings.json` | 工具自動批准（合併，不覆蓋）|
| 協議 | `~/.claude/CLAUDE.md` | 記憶管理指引（可選，附加到尾部）|

### 連接原理

**CLI** 啟動時讀取 `~/.claude/mcp.json` 來發現 MCP server。安裝程式會寫入**絕對路徑**（不是 `$HOME`），確保能直接啟動 memcp server。

**VSCode extension** 讀取的是 `~/.claude.json`（專案級設定），這是不同的檔案。安裝程式會執行 `claude mcp add` 同時在此註冊 memcp。

`settings.json` 中的 permissions 讓全部 27 個 memcp 工具免手動批准。

**資料儲存**：記憶資料存在 `~/.memcp/graph.db`（SQLite）。資料庫會在**第一次存入記憶時自動建立** — 不需手動設定。安裝程式會建立 `~/.memcp/` 目錄；`graph.db` 在你第一次呼叫 `memcp_remember` 後出現。

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

## 疑難排解

### VSCode extension 顯示 "No MCP servers configured"

VSCode extension 讀取的是 `~/.claude.json`，而非 `~/.claude/mcp.json`。安裝程式會嘗試透過 `claude mcp add` 註冊，但如果失敗或被跳過：

```bash
claude mcp add memcp -- ~/.claude/mcp-servers/memcp/.venv/bin/python -m memcp.server
```

然後在 VSCode 中 **Reload Window**（`Ctrl+Shift+P` → `Reload Window`）。

### memcp 工具需要手動批准

`~/.claude/settings.json` 中的 permissions 可能沒有正確合併。重新執行 `bash install.sh` — 它是冪等的，會重新合併 permissions。

### 啟動時報 "No 'script_location' key found in configuration"

這是 Alembic migration 錯誤，表示安裝到了**不同的 memcp fork**（不是 `maydali28/memcp`）。某些 fork 使用 Alembic 做資料庫遷移，與 memcp-pro 不相容。

memcp-pro 鎖定 [maydali28/memcp v0.3.0](https://github.com/maydali28/memcp/releases/tag/v0.3.0)，使用輕量的 SQLite `ALTER TABLE ADD COLUMN` 遷移（無 Alembic）。

修復方式：移除錯誤版本，重新安裝：

```bash
rm -rf ~/.claude/mcp-servers/memcp
bash install.sh
```

### 啟動時 Python import 錯誤

venv 可能不完整，重新建立：

```bash
cd ~/.claude/mcp-servers/memcp
rm -rf .venv
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[all]"
deactivate
```

## 致謝

Pro 增強功能的設計參考了以下專案與理論：

- [memcp](https://github.com/maydali28/memcp)（maydali28）— memcp-pro 所增強的核心 MCP 記憶 server。所有 Pro 功能都建構在 memcp 的知識圖譜架構之上（SQLite + 邊關係遍歷 + 27 個 MCP 工具）。
- [Claude Code](https://github.com/anthropics/claude-code)（Anthropic）— memcp-pro 透過 hooks、skills 和 MCP 協定整合的 AI 編碼 Agent。
- [memory-lancedb-pro](https://github.com/CortexReach/memory-lancedb-pro)（CortexReach）— 我們早期的 TypeScript 記憶系統（LanceDB + Jina Embeddings），其認知科學設計模式（Weibull 衰減、七種去重決策、L0/L1/L2 分層儲存）被移植到 memcp 的 Python/SQLite 架構。
- **Weibull 拉伸指數衰減** — 三層衰減模型靈感來自認知科學的遺忘曲線研究，使用 Weibull 分佈模擬不同記憶保留模式。[FSRS](https://github.com/open-spaced-repetition/fsrs4anki)（Free Spaced Repetition Scheduler）曾被評估為替代方案，但因過於複雜（21 個參數）而未採用。
- **BM25 / Okapi BM25** — 搜尋管線的關鍵字匹配和高信度保護基於資訊檢索領域經典的 BM25 排名函數。
- **MMR（Maximal Marginal Relevance）** — 多樣性結果去重遵循 MMR 演算法（Carbonell & Goldstein, 1998），減少搜尋結果中的冗餘。

## 授權

MIT
