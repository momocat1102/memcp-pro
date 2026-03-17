#!/bin/bash
# memcp PostToolUse hook — Reset turn counter after memcp_remember calls
INPUT=$(cat)
echo "0" > /tmp/claude_session_turns
