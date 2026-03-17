#!/usr/bin/env bash
# memcp-pro — One-click installer for memcp with Claude Code
# Run: bash install.sh

set -e

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }
step()  { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
MEMCP_DIR="$CLAUDE_DIR/mcp-servers/memcp"
MCP_CONFIG="$CLAUDE_DIR/mcp.json"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

ERRORS=()

# ── Step 1: Pre-flight Checks ────────────────────────────
step "Step 1: Pre-flight Checks"

# Python 3.11+
if ! command -v python3 &>/dev/null; then
  err "Python 3 not found. memcp requires Python 3.11+"
  exit 1
fi
PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.minor}')")
PY_MAJOR=$(python3 -c "import sys; print(sys.version_info.major)")
if [ "$PY_MAJOR" -lt 3 ] || [ "$PY_VER" -lt 11 ]; then
  err "Python 3.11+ required (found $(python3 --version))"
  exit 1
fi
ok "Python $(python3 --version | cut -d' ' -f2)"

# sqlite3
if ! command -v sqlite3 &>/dev/null; then
  warn "sqlite3 not found. SessionStart hook needs it to load memories."
  warn "Install: sudo apt install sqlite3 (or brew install sqlite3)"
  ERRORS+=("sqlite3 not installed")
fi

# Claude Code
if ! command -v claude &>/dev/null; then
  warn "Claude Code CLI not found. Install: npm install -g @anthropic-ai/claude-code"
  ERRORS+=("Claude Code CLI not found")
else
  ok "Claude Code detected"
fi

# jq (for JSON merging)
USE_JQ=true
if ! command -v jq &>/dev/null; then
  warn "jq not found. Using Python fallback for JSON merging."
  USE_JQ=false
fi

# ── Step 2: Install memcp Core ───────────────────────────
step "Step 2: Install memcp (Persistent Memory Server)"

mkdir -p "$CLAUDE_DIR/mcp-servers"

if [ -d "$MEMCP_DIR/src" ]; then
  info "memcp already installed at $MEMCP_DIR, updating..."
  cd "$MEMCP_DIR" && git pull --quiet 2>/dev/null || warn "git pull failed, using existing version"
else
  info "Cloning memcp..."
  git clone https://github.com/anthropics/memcp.git "$MEMCP_DIR" 2>/dev/null || {
    if [ -d "$MEMCP_DIR" ]; then
      warn "Clone failed, directory exists. Trying git pull..."
      cd "$MEMCP_DIR" && git pull --quiet 2>/dev/null || true
    else
      err "Failed to clone memcp"
      ERRORS+=("memcp clone failed")
    fi
  }
fi

if [ -d "$MEMCP_DIR" ]; then
  info "Setting up Python environment..."
  cd "$MEMCP_DIR"
  if [ ! -d ".venv" ]; then
    python3 -m venv .venv
  fi
  source .venv/bin/activate
  pip install -e ".[all]" --quiet 2>/dev/null || pip install -e . --quiet 2>/dev/null || {
    err "pip install failed"
    ERRORS+=("memcp pip install failed")
  }
  deactivate

  # Verify
  if "$MEMCP_DIR/.venv/bin/python" -c "import memcp; print('OK')" &>/dev/null; then
    ok "memcp installed and verified"
  else
    warn "memcp installed but import verification failed"
    ERRORS+=("memcp import verification failed")
  fi
else
  err "memcp directory not found, skipping Python setup"
  ERRORS+=("memcp directory missing")
fi

cd "$SCRIPT_DIR"

# ── Step 3: Install Hooks ────────────────────────────────
step "Step 3: Install Hook Scripts"

mkdir -p "$CLAUDE_DIR/hooks"

HOOKS_INSTALLED=0
for hook_file in "$SCRIPT_DIR/hooks/"*.sh; do
  hook_name=$(basename "$hook_file")
  cp "$hook_file" "$CLAUDE_DIR/hooks/$hook_name"
  chmod +x "$CLAUDE_DIR/hooks/$hook_name"
  HOOKS_INSTALLED=$((HOOKS_INSTALLED + 1))
done
ok "$HOOKS_INSTALLED hooks installed"

# ── Step 4: Install Skills ───────────────────────────────
step "Step 4: Install Skills"

mkdir -p "$CLAUDE_DIR/skills"

SKILLS_INSTALLED=0
for skill_dir in "$SCRIPT_DIR/skills/memcp-"*/; do
  skill_name=$(basename "$skill_dir")
  if [ -d "$CLAUDE_DIR/skills/$skill_name" ]; then
    info "$skill_name already exists, updating..."
  fi
  cp -r "$skill_dir" "$CLAUDE_DIR/skills/$skill_name"
  SKILLS_INSTALLED=$((SKILLS_INSTALLED + 1))
done
ok "$SKILLS_INSTALLED skills installed"

# ── Step 5: Configure MCP Server ─────────────────────────
step "Step 5: Register memcp MCP Server"

MEMCP_CMD="$MEMCP_DIR/.venv/bin/python"

# Ensure mcp.json exists
if [ ! -f "$MCP_CONFIG" ]; then
  echo '{"mcpServers":{}}' > "$MCP_CONFIG"
  info "Created $MCP_CONFIG"
fi

if [ "$USE_JQ" = true ]; then
  jq --arg cmd "$MEMCP_CMD" --arg cwd "$MEMCP_DIR" \
    '.mcpServers.memcp = {"command": $cmd, "args": ["-m", "memcp.server"], "cwd": $cwd}' \
    "$MCP_CONFIG" > "$MCP_CONFIG.tmp" && mv "$MCP_CONFIG.tmp" "$MCP_CONFIG"
else
  python3 -c "
import json, sys
cfg_path = '$MCP_CONFIG'
with open(cfg_path) as f: cfg = json.load(f)
cfg.setdefault('mcpServers', {})
cfg['mcpServers']['memcp'] = {
    'command': '$MEMCP_CMD',
    'args': ['-m', 'memcp.server'],
    'cwd': '$MEMCP_DIR'
}
with open(cfg_path, 'w') as f: json.dump(cfg, f, indent=2)
"
fi
ok "memcp registered in $MCP_CONFIG"

# ── Step 6: Configure Permissions ────────────────────────
step "Step 6: Configure Permissions & Hooks"

# Ensure settings.json exists
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{"permissions":{"allow":[]},"hooks":{}}' > "$SETTINGS_FILE"
  info "Created $SETTINGS_FILE"
fi

# Backup
cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
info "Backed up settings → settings.json.bak"

PERMS_FILE="$SCRIPT_DIR/config/permissions.json"

if [ "$USE_JQ" = true ]; then
  # Merge permissions (deduplicated)
  jq --slurpfile new "$PERMS_FILE" \
    '.permissions.allow = ([.permissions.allow // [], $new[0].allow] | add | unique)' \
    "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

  # Merge hooks
  jq '
    # SessionStart
    .hooks.SessionStart = (
      [.hooks.SessionStart // [] | .[] | select(.hooks[0].command | test("memcp-session-start") | not)] +
      [{"matcher": "", "hooks": [{"type": "command", "command": "bash ~/.claude/hooks/memcp-session-start.sh", "timeout": 10000}]}]
    ) |
    # PreCompact
    .hooks.PreCompact = (
      [.hooks.PreCompact // [] | .[] | select(.hooks[0].command | test("memcp-pre-compact") | not)] +
      [{"matcher": "", "hooks": [{"type": "command", "command": "bash ~/.claude/hooks/memcp-pre-compact.sh", "timeout": 5000}]}]
    ) |
    # Stop — add memcp-stop without removing existing hooks
    .hooks.Stop = (
      [.hooks.Stop // [] | .[] | select(.hooks // [] | map(.command // "" | test("memcp-stop")) | any | not)] +
      [{"matcher": "", "hooks": [{"type": "command", "command": "bash ~/.claude/hooks/memcp-stop.sh", "timeout": 5000}]}]
    ) |
    # PostToolUse
    .hooks.PostToolUse = (
      [.hooks.PostToolUse // [] | .[] | select(.hooks[0].command | test("memcp-reset-counter") | not)] +
      [{"matcher": "memcp_remember|memcp_load_context", "hooks": [{"type": "command", "command": "bash ~/.claude/hooks/memcp-reset-counter.sh", "timeout": 3000}]}]
    )
  ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
else
  python3 -c "
import json
settings_path = '$SETTINGS_FILE'
perms_path = '$PERMS_FILE'

with open(settings_path) as f: settings = json.load(f)
with open(perms_path) as f: perms = json.load(f)

# Merge permissions
existing = set(settings.get('permissions', {}).get('allow', []))
new_perms = set(perms.get('allow', []))
settings.setdefault('permissions', {})['allow'] = sorted(existing | new_perms)

# Merge hooks
hooks = settings.setdefault('hooks', {})

def add_hook(event, matcher, command, timeout):
    entries = hooks.get(event, [])
    # Remove existing memcp hook if present
    entries = [e for e in entries if not any(command.split('/')[-1] in (h.get('command','') ) for h in e.get('hooks', []))]
    entries.append({'matcher': matcher, 'hooks': [{'type': 'command', 'command': command, 'timeout': timeout}]})
    hooks[event] = entries

add_hook('SessionStart', '', 'bash ~/.claude/hooks/memcp-session-start.sh', 10000)
add_hook('PreCompact', '', 'bash ~/.claude/hooks/memcp-pre-compact.sh', 5000)

# Stop — preserve existing, add memcp-stop
stop_entries = hooks.get('Stop', [])
stop_entries = [e for e in stop_entries if not any('memcp-stop' in h.get('command','') for h in e.get('hooks', []))]
stop_entries.append({'matcher': '', 'hooks': [{'type': 'command', 'command': 'bash ~/.claude/hooks/memcp-stop.sh', 'timeout': 5000}]})
hooks['Stop'] = stop_entries

add_hook('PostToolUse', 'memcp_remember|memcp_load_context', 'bash ~/.claude/hooks/memcp-reset-counter.sh', 3000)

with open(settings_path, 'w') as f: json.dump(settings, f, indent=2)
"
fi
ok "Permissions and hooks configured"

# ── Step 7: CLAUDE.md Protocol ───────────────────────────
step "Step 7: Memory Management Protocol"

CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
MEMCP_PROTOCOL="$SCRIPT_DIR/config/CLAUDE.md"

if [ -f "$CLAUDE_MD" ] && grep -q "Memory Management Protocol" "$CLAUDE_MD" 2>/dev/null; then
  ok "Memory protocol already in CLAUDE.md"
else
  echo ""
  info "The memory management protocol helps Claude use memcp effectively."
  info "It should be added to $CLAUDE_MD"
  echo ""
  read -p "Append memory protocol to CLAUDE.md? [Y/n] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo "" >> "$CLAUDE_MD"
    cat "$MEMCP_PROTOCOL" >> "$CLAUDE_MD"
    ok "Protocol appended to $CLAUDE_MD"
  else
    info "Skipped. You can manually copy from: $MEMCP_PROTOCOL"
  fi
fi

# ── Step 8: Final Verification ───────────────────────────
step "Step 8: Verification"

PASS=0
FAIL=0

# Check mcp.json has memcp
if [ "$USE_JQ" = true ]; then
  if jq -e '.mcpServers.memcp' "$MCP_CONFIG" &>/dev/null; then
    ok "mcp.json: memcp server registered"
    PASS=$((PASS + 1))
  else
    err "mcp.json: memcp server NOT found"
    FAIL=$((FAIL + 1))
  fi
else
  if grep -q '"memcp"' "$MCP_CONFIG" 2>/dev/null; then
    ok "mcp.json: memcp server registered"
    PASS=$((PASS + 1))
  else
    err "mcp.json: memcp server NOT found"
    FAIL=$((FAIL + 1))
  fi
fi

# Check command path exists
if [ -x "$MEMCP_CMD" ]; then
  ok "memcp Python executable exists and is executable"
  PASS=$((PASS + 1))
else
  err "memcp Python executable not found at $MEMCP_CMD"
  FAIL=$((FAIL + 1))
fi

# Check permissions
if grep -q "mcp__memcp__memcp_remember" "$SETTINGS_FILE" 2>/dev/null; then
  ok "settings.json: memcp permissions configured"
  PASS=$((PASS + 1))
else
  err "settings.json: memcp permissions NOT found"
  FAIL=$((FAIL + 1))
fi

# Check hooks exist
HOOK_COUNT=0
for hook in memcp-session-start.sh memcp-pre-compact.sh memcp-stop.sh memcp-reset-counter.sh; do
  if [ -x "$CLAUDE_DIR/hooks/$hook" ]; then
    HOOK_COUNT=$((HOOK_COUNT + 1))
  fi
done
if [ "$HOOK_COUNT" -eq 4 ]; then
  ok "All 4 hook scripts installed and executable"
  PASS=$((PASS + 1))
else
  warn "Only $HOOK_COUNT/4 hooks installed"
  FAIL=$((FAIL + 1))
fi

# Check skills
SKILL_COUNT=0
for skill in memcp-session-start memcp-save memcp-search; do
  if [ -f "$CLAUDE_DIR/skills/$skill/SKILL.md" ]; then
    SKILL_COUNT=$((SKILL_COUNT + 1))
  fi
done
if [ "$SKILL_COUNT" -eq 3 ]; then
  ok "All 3 skills installed"
  PASS=$((PASS + 1))
else
  warn "Only $SKILL_COUNT/3 skills installed"
  FAIL=$((FAIL + 1))
fi

# ── Summary ──────────────────────────────────────────────
step "Installation Complete!"

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""
  warn "Some issues were encountered:"
  for e in "${ERRORS[@]}"; do
    echo -e "  ${YELLOW}⚠${NC} $e"
  done
  echo ""
fi

echo -e "
${GREEN}memcp for Claude Code is ready!${NC}

${CYAN}Verification:${NC} $PASS passed, $FAIL failed

${CYAN}What was installed:${NC}
  ✓ memcp server    → $MEMCP_DIR
  ✓ Hooks (4)       → $CLAUDE_DIR/hooks/memcp-*.sh
  ✓ Skills (3)      → $CLAUDE_DIR/skills/memcp-*/
  ✓ MCP config      → $MCP_CONFIG
  ✓ Permissions     → $SETTINGS_FILE

${CYAN}Next steps:${NC}
  1. ${YELLOW}Restart Claude Code${NC} to activate memcp
  2. Start a session — memories will auto-load via SessionStart hook
  3. Use /memcp-save to manually save knowledge
  4. Use /memcp-search to search past memories

${CYAN}Uninstall:${NC}
  bash $(dirname "$0")/uninstall.sh
"
