#!/bin/bash

# Multi-Device Sync Daemon Startup Script
# This script starts full bidirectional sync mode for any laptop
# Perfect for active editing with instant uploads and automatic downloads

SCRIPT_DIR="$(dirname "$0")"
MASTER_SCRIPT="$SCRIPT_DIR/sync-obsidian-master.sh"

echo "🖥️  Starting Multi-Device Sync Mode"
echo "=================================="
echo ""
echo "This mode provides full bidirectional sync:"
echo "• ⚡ Instant uploads when you edit files (plugin triggers)"
echo "• 🔄 Auto-download changes from other devices (every 30s)"
echo "• 🔒 Periodic full sync every 15 minutes (safety net)"
echo "• 🎯 Perfect for active editing on any laptop"
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

# Start daemon mode (full bidirectional sync)
echo "🚀 Starting daemon mode (full bidirectional sync)..."
echo "📝 Log file: /home/egarrr/obsidian-sync.log"
echo ""

"$MASTER_SCRIPT" daemon
