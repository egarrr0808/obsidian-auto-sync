#!/bin/bash

# Master Obsidian Sync Script
# This wrapper script handles both regular sync triggers and bidirectional sync
# It monitors for different types of trigger files and delegates to appropriate scripts

LOCAL_VAULT="$HOME/Notes/"
LOG_FILE="$HOME/obsidian-sync.log"
SYNC_TRIGGER_FILE="$LOCAL_VAULT/.obsidian/sync-trigger"
DOWNLOAD_TRIGGER_FILE="$LOCAL_VAULT/.obsidian/download-trigger"
BIDIRECTIONAL_SCRIPT="$HOME/sync-obsidian-bidirectional.sh"
ENHANCED_SCRIPT="$HOME/sync-obsidian-enhanced.sh"

# Function to log messages with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to watch for trigger files
watch_for_triggers() {
    log_message "Starting master sync watcher (bidirectional support enabled)..."
    
    while true; do
        # Check for bidirectional sync trigger (upload + download)
        if [ -f "$SYNC_TRIGGER_FILE" ]; then
            if [ -r "$SYNC_TRIGGER_FILE" ]; then
                TRIGGER_INFO=$(cat "$SYNC_TRIGGER_FILE" 2>/dev/null || echo "unknown")
                log_message "Bidirectional sync trigger detected: $TRIGGER_INFO"
            else
                log_message "Bidirectional sync trigger detected"
            fi
            
            # Use bidirectional script for regular sync triggers
            "$BIDIRECTIONAL_SCRIPT" sync
            
            # Small delay to prevent rapid retriggering
            sleep 2
        fi
        
        # Check for download-only trigger
        if [ -f "$DOWNLOAD_TRIGGER_FILE" ]; then
            if [ -r "$DOWNLOAD_TRIGGER_FILE" ]; then
                TRIGGER_INFO=$(cat "$DOWNLOAD_TRIGGER_FILE" 2>/dev/null || echo "unknown")
                log_message "Download-only trigger detected: $TRIGGER_INFO"
            else
                log_message "Download-only trigger detected"
            fi
            
            # Use bidirectional script in download-only mode
            "$BIDIRECTIONAL_SCRIPT" download-only
            
            # Remove the download trigger file
            rm -f "$DOWNLOAD_TRIGGER_FILE" 2>/dev/null
            
            # Small delay
            sleep 2
        fi
        
        # Check every 3 seconds
        sleep 3
    done
}

# Function to run daemon mode
run_daemon() {
    log_message "Starting master sync daemon (bidirectional)..."
    
    # Start background watcher for plugin triggers
    watch_for_triggers &
    local watcher_pid=$!
    
    # Periodic bidirectional sync every 15 minutes
    while true; do
        sleep 900  # 15 minutes
        log_message "Performing periodic bidirectional sync..."
        "$BIDIRECTIONAL_SCRIPT" sync
    done
    
    # Cleanup on exit
    trap "kill $watcher_pid 2>/dev/null" EXIT
}

# Main execution
case "${1:-watch}" in
    "watch")
        # Watch mode for plugin triggers
        watch_for_triggers
        ;;
    "daemon")
        # Full daemon mode - watch + periodic sync
        run_daemon
        ;;
    "sync")
        # One-time bidirectional sync
        "$BIDIRECTIONAL_SCRIPT" sync
        ;;
    "download-only")
        # One-time download check
        "$BIDIRECTIONAL_SCRIPT" download-only
        ;;
    *)
        echo "Usage: $0 [watch|daemon|sync|download-only]"
        echo "  watch        - Watch for plugin triggers (default)"
        echo "  daemon       - Run both watcher and periodic bidirectional sync"
        echo "  sync         - Perform one-time bidirectional sync"
        echo "  download-only - Check for remote changes only"
        exit 1
        ;;
esac

log_message "Master sync script finished"