#!/bin/bash
# memcp PreCompact hook — Remind to save knowledge before compaction
INPUT=$(cat)
cat <<'EOF'
{"blockExecution": true, "systemMessage": "【PreCompact Knowledge Extraction】Context is about to be compacted. Before compaction:\n1. Use memcp_remember() to save important decisions, findings, preferences\n2. Use memcp_load_context() for large content blocks\n3. Unsaved content will be lost after compaction\n4. Tell the user how many knowledge items were extracted"}
EOF
