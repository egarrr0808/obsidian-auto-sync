#!/bin/bash

# Second Laptop Startup Script
# This script starts the optimized mode for the second laptop
# It will frequently check for remote changes from the primary laptop

SCRIPT_DIR="$(dirname "$0")"
MASTER_SCRIPT="$SCRIPT_DIR/sync-obsidian-master.sh"

echo "🖥️  Starting Second Laptop Mode"
echo "=============================="
echo ""
echo "This mode will:"
echo "• Check for remote changes every 15 seconds"
echo "• Automatically download changes from your primary laptop"
echo "• Still respond to plugin triggers for uploads"
echo "• Only log when changes are actually found"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Check if master script exists
if [ ! -f "$MASTER_SCRIPT" ]; then
    echo "❌ Error: Master sync script not found at $MASTER_SCRIPT"
    exit 1
fi

# Stop any existing sync processes
echo "🔄 Stopping any existing sync processes..."
pkill -f "sync-obsidian-master" 2>/dev/null || echo "No existing processes to stop"

sleep 2

# Start second laptop mode
echo "🚀 Starting second laptop mode..."
echo "📝 Log file: /home/egarrr/obsidian-sync.log"
echo ""

"$MASTER_SCRIPT" second-laptop