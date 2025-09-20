#!/bin/bash

# Obsidian Sync Script Template
# This script syncs your local Notes directory to the remote Obsidian server
# Configure the variables below for your setup

# ===========================================
# CONFIGURATION - EDIT THESE VALUES
# ===========================================

LOCAL_VAULT="$HOME/path/to/your/obsidian/vault"
REMOTE_HOST="your-ssh-host-alias"
REMOTE_VAULT="/path/to/remote/vault/directory"
LOG_FILE="$HOME/obsidian-sync.log"
TRIGGER_FILE="/tmp/obsidian-sync-trigger"

# ===========================================
# SCRIPT LOGIC - DO NOT EDIT BELOW
# ===========================================

# Function to log messages with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to perform the sync
do_sync() {
    local trigger_source="$1"
    
    log_message "Starting Obsidian sync (triggered by: $trigger_source)..."
    
    # Check if local vault exists
    if [ ! -d "$LOCAL_VAULT" ]; then
        log_message "ERROR: Local vault directory does not exist: $LOCAL_VAULT"
        return 1
    fi

    # Sync files using rsync
    # -a: archive mode (preserves permissions, timestamps, etc.)
    # -v: verbose output
    # -z: compress during transfer
    # --delete: delete files on remote that don't exist locally
    # --exclude: exclude certain files/directories
    rsync -avz --delete \
        --exclude='.obsidian/' \
        --exclude='.git/' \
        --exclude='.DS_Store' \
        --exclude='*.tmp' \
        --exclude='Thumbs.db' \
        "$LOCAL_VAULT" "$REMOTE_HOST:$REMOTE_VAULT" \
        2>&1 | while read line; do
            log_message "$line"
        done

    SYNC_RESULT=${PIPESTATUS[0]}

    if [ $SYNC_RESULT -eq 0 ]; then
        log_message "Sync completed successfully"
        
        # Count files synced
        FILE_COUNT=$(find "$LOCAL_VAULT" -name "*.md" | wc -l)
        log_message "Total markdown files in local vault: $FILE_COUNT"
        
        # Remove trigger file if it exists
        if [ -f "$TRIGGER_FILE" ]; then
            rm -f "$TRIGGER_FILE" 2>/dev/null
            log_message "Trigger file removed"
        fi
        
        return 0
    else
        log_message "ERROR: Sync failed with exit code $SYNC_RESULT"
        return $SYNC_RESULT
    fi
}

# Function to watch for trigger file
watch_for_trigger() {
    log_message "Starting trigger file watcher..."
    
    while true; do
        if [ -f "$TRIGGER_FILE" ]; then
            # Read trigger info if possible
            if [ -r "$TRIGGER_FILE" ]; then
                TRIGGER_INFO=$(cat "$TRIGGER_FILE" 2>/dev/null || echo "unknown")
                log_message "Trigger file detected: $TRIGGER_INFO"
            else
                log_message "Trigger file detected"
            fi
            
            # Perform sync
            do_sync "plugin-trigger"
            
            # Small delay to prevent rapid retriggering
            sleep 2
        fi
        
        # Check every 5 seconds
        sleep 5
    done
}

# Main execution
case "${1:-sync}" in
    "sync")
        # Normal sync mode
        do_sync "manual/cron"
        ;;
    "watch")
        # Watch mode for plugin triggers
        watch_for_trigger
        ;;
    "daemon")
        # Daemon mode - both watch for triggers and periodic sync
        log_message "Starting sync daemon mode..."
        
        # Start background watcher
        watch_for_trigger &
        WATCHER_PID=$!
        
        # Periodic sync every 3 minutes
        while true; do
            sleep 180  # 3 minutes
            do_sync "periodic"
        done
        ;;
    *)
        echo "Usage: $0 [sync|watch|daemon]"
        echo "  sync   - Perform one-time sync (default)"
        echo "  watch  - Watch for plugin triggers"
        echo "  daemon - Run both watcher and periodic sync"
        echo ""
        echo "Before using this script:"
        echo "1. Edit the configuration variables at the top of this file"
        echo "2. Set up SSH key authentication to your remote server"
        echo "3. Test the connection: ssh \$REMOTE_HOST"
        echo "4. Make sure the remote directory exists"
        exit 1
        ;;
esac

log_message "Obsidian sync script finished"