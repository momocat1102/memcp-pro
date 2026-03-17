#!/usr/bin/env bash
# memcp SessionStart hook — Load memories from graph.db into conversation
INPUT=$(cat)
SOURCE=$(echo "$INPUT" | grep -o '"source":"[^"]*"' | sed 's/"source":"//;s/"//' || echo "startup")
CWD=$(echo "$INPUT" | grep -o '"cwd":"[^"]*"' | sed 's/"cwd":"//;s/"//' || echo "")
SOURCE="${SOURCE:-startup}"
if [[ "$SOURCE" == "resume" ]]; then exit 0; fi
echo "0" > /tmp/claude_session_turns

DATA_DIR="${MEMCP_DATA_DIR:-$HOME/.memcp}"
DB_PATH="$DATA_DIR/graph.db"
PROJECT_NAME="default"
if [[ -n "$CWD" ]]; then
  GIT_NAME=$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null || echo "")
  if [[ -n "$GIT_NAME" ]]; then PROJECT_NAME="$GIT_NAME"; else PROJECT_NAME=$(basename "$CWD"); fi
fi

MEMORIES=""
if [[ -s "$DB_PATH" ]]; then
  MEMORIES=$(sqlite3 -noheader "$DB_PATH" <<EOSQL 2>/dev/null || echo ""
SELECT '- ' || COALESCE(l0_abstract, SUBSTR(content, 1, 120)) FROM nodes
WHERE (project = '$(echo "$PROJECT_NAME" | sed "s/'/''/g")' OR project = '_global')
  AND importance IN ('critical', 'high')
ORDER BY CASE importance WHEN 'critical' THEN 1 WHEN 'high' THEN 2 END, created_at DESC
LIMIT 8;
EOSQL
  )
fi
if [[ -n "$MEMORIES" ]]; then
  echo "=== Memory: Background knowledge loaded ==="
  echo "$MEMORIES"
  echo "================================"
fi
exit 0
