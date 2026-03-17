#!/usr/bin/env bash
# memcp-pro — Uninstaller
# Run: bash uninstall.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
step()  { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

CLAUDE_DIR="$HOME/.claude"
MEMCP_DIR="$CLAUDE_DIR/mcp-servers/memcp"
MCP_CONFIG="$CLAUDE_DIR/mcp.json"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

USE_JQ=true
if ! command -v jq &>/dev/null; then
  USE_JQ=false
fi

echo -e "${CYAN}memcp-pro Uninstaller${NC}"
echo ""

# ── Step 1: Remove hooks ─────────────────────────────────
step "Step 1: Remove Hook Scripts"

for hook in memcp-session-start.sh memcp-pre-compact.sh memcp-stop.sh memcp-reset-counter.sh; do
  if [ -f "$CLAUDE_DIR/hooks/$hook" ]; then
    rm "$CLAUDE_DIR/hooks/$hook"
    ok "Removed $hook"
  fi
done

# ── Step 2: Remove skills ────────────────────────────────
step "Step 2: Remove Skills"

for skill in memcp-session-start memcp-save memcp-search; do
  if [ -d "$CLAUDE_DIR/skills/$skill" ]; then
    rm -rf "$CLAUDE_DIR/skills/$skill"
    ok "Removed $skill"
  fi
done

# ── Step 3: Remove from mcp.json ─────────────────────────
step "Step 3: Remove from MCP Config"

if [ -f "$MCP_CONFIG" ]; then
  if [ "$USE_JQ" = true ]; then
    jq 'del(.mcpServers.memcp)' "$MCP_CONFIG" > "$MCP_CONFIG.tmp" && mv "$MCP_CONFIG.tmp" "$MCP_CONFIG"
  else
    python3 -c "
import json
with open('$MCP_CONFIG') as f: cfg = json.load(f)
cfg.get('mcpServers', {}).pop('memcp', None)
with open('$MCP_CONFIG', 'w') as f: json.dump(cfg, f, indent=2)
"
  fi
  ok "Removed memcp from mcp.json"
fi

# ── Step 4: Remove from settings.json ────────────────────
step "Step 4: Remove Permissions & Hooks from Settings"

if [ -f "$SETTINGS_FILE" ]; then
  cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
  info "Backed up settings → settings.json.bak"

  if [ "$USE_JQ" = true ]; then
    jq '
      # Remove memcp permissions
      .permissions.allow = [.permissions.allow // [] | .[] | select(startswith("mcp__memcp__") | not)] |
      # Remove memcp hooks from each event
      .hooks.SessionStart = [.hooks.SessionStart // [] | .[] | select(.hooks // [] | map(.command // "" | test("memcp-session-start")) | any | not)] |
      .hooks.PreCompact = [.hooks.PreCompact // [] | .[] | select(.hooks // [] | map(.command // "" | test("memcp-pre-compact")) | any | not)] |
      .hooks.Stop = [.hooks.Stop // [] | .[] | select(.hooks // [] | map(.command // "" | test("memcp-stop")) | any | not)] |
      .hooks.PostToolUse = [.hooks.PostToolUse // [] | .[] | select(.hooks // [] | map(.command // "" | test("memcp-reset-counter")) | any | not)] |
      # Clean up empty arrays
      if .hooks.SessionStart == [] then del(.hooks.SessionStart) else . end |
      if .hooks.PreCompact == [] then del(.hooks.PreCompact) else . end |
      if .hooks.Stop == [] then del(.hooks.Stop) else . end |
      if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end
    ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  else
    python3 -c "
import json
with open('$SETTINGS_FILE') as f: settings = json.load(f)

# Remove memcp permissions
perms = settings.get('permissions', {}).get('allow', [])
settings['permissions']['allow'] = [p for p in perms if not p.startswith('mcp__memcp__')]

# Remove memcp hooks
hooks = settings.get('hooks', {})
for event, entries in list(hooks.items()):
    hooks[event] = [e for e in entries if not any('memcp-' in h.get('command','') for h in e.get('hooks', []))]
    if not hooks[event]:
        del hooks[event]

with open('$SETTINGS_FILE', 'w') as f: json.dump(settings, f, indent=2)
"
  fi
  ok "Removed memcp permissions and hooks from settings.json"
fi

# ── Step 5: Ask about memcp server ───────────────────────
step "Step 5: memcp Server"

if [ -d "$MEMCP_DIR" ]; then
  echo ""
  warn "memcp server is installed at: $MEMCP_DIR"
  warn "Your memory data is at: ${MEMCP_DATA_DIR:-$HOME/.memcp}"
  echo ""
  read -p "Remove memcp server? (memory data will NOT be deleted) [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$MEMCP_DIR"
    ok "memcp server removed"
  else
    info "Kept memcp server at $MEMCP_DIR"
  fi
else
  info "memcp server not found (already removed or never installed)"
fi

# ── Done ─────────────────────────────────────────────────
step "Uninstall Complete"

echo -e "
${GREEN}memcp has been removed from Claude Code.${NC}

${YELLOW}Note:${NC}
  - Your memory data at ${MEMCP_DATA_DIR:-$HOME/.memcp} was NOT deleted
  - If you added the memory protocol to ~/.claude/CLAUDE.md, remove it manually
  - Restart Claude Code for changes to take effect
"
