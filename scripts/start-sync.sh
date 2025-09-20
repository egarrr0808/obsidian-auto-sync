#!/bin/bash

# Universal Obsidian Sync Startup Script
# This script starts the same optimal sync mode for ANY laptop
# Both laptops get identical functionality: instant uploads + auto downloads

SCRIPT_DIR="$(dirname "$0")"
MASTER_SCRIPT="$SCRIPT_DIR/sync-obsidian-master.sh"

echo "🚀 Starting Universal Multi-Device Sync"
echo "======================================="
echo ""
echo "✨ This provides identical functionality for ALL laptops:"
echo "• ⚡ Instant uploads when you edit files"
echo "• 🔄 Auto-download changes from other laptops (every 30s)"
echo "• 🔒 Periodic full sync every 15 minutes (safety net)"
echo "• 🎯 Perfect for active editing on any device"
echo ""
echo "📱 Works the same on Laptop 1, Laptop 2, or any device!"
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

# Start daemon mode (same for all laptops)
echo "🚀 Starting daemon mode (universal for all laptops)..."
echo "📝 Log file: /home/egarrr/obsidian-sync.log"
echo ""

"$MASTER_SCRIPT" daemon
