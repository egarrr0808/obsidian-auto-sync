#!/bin/bash

echo "🚀 Starting Obsidian Auto-Sync System..."

# Kill any existing sync daemons
pkill -f sync_obsidian_plugin.sh 2>/dev/null

# Start the sync daemon
nohup /home/egarrr/sync_obsidian_plugin.sh watch > /dev/null 2>&1 &
DAEMON_PID=$!

echo "✅ Sync daemon started (PID: $DAEMON_PID)"
echo "📂 Local vault: /home/egarrr/Md essays/"
echo "🌐 Server URL: http://207.127.93.169:3000"
echo "📝 Log file: /home/egarrr/obsidian-sync.log"

echo ""
echo "🔄 SYNC CAPABILITIES:"
echo "  • Upload: Local changes → Server (every 10s)"
echo "  • Download: Server changes → Local (via plugin polling every 30s)"
echo "  • Conflict resolution: Local changes ignored during server downloads"
echo ""
echo "📋 COMMANDS:"
echo "  • Manual sync: ./sync_obsidian_plugin.sh sync"
echo "  • View logs: tail -f /home/egarrr/obsidian-sync.log"
echo "  • Stop daemon: pkill -f sync_obsidian_plugin.sh"

echo ""
echo "🎯 Ready for use! Open Obsidian and enable the 'Auto Server Sync' plugin."