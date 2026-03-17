#!/bin/bash
# memcp Stop hook — Progressive memory save reminders based on turn count + context usage
INPUT=$(cat)
COUNTER_FILE="/tmp/claude_session_turns"
if [ -f "$COUNTER_FILE" ]; then COUNT=$(cat "$COUNTER_FILE"); COUNT=$((COUNT + 1)); else COUNT=1; fi
echo "$COUNT" > "$COUNTER_FILE"

CONTEXT_PCT=$(echo "$INPUT" | grep -o '"context_usage_pct":[0-9]*' | grep -o '[0-9]*' || echo "0")
if [ "${CONTEXT_PCT:-0}" -lt 55 ] 2>/dev/null; then exit 0; fi

if [ "$COUNT" -ge 30 ]; then
  echo "【Memory Reminder - URGENT】${COUNT} turns accumulated with high context usage. Please save important knowledge with memcp_remember now."
elif [ "$COUNT" -ge 20 ]; then
  echo "【Memory Reminder - Suggested】${COUNT} turns accumulated. Consider saving decisions and findings with memcp_remember."
elif [ "$COUNT" -ge 10 ]; then
  echo "【Memory Reminder】${COUNT} turns accumulated. Save noteworthy knowledge with memcp_remember."
fi
