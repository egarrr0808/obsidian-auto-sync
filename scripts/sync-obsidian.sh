#!/bin/bash

# Obsidian Auto-Sync Script for Plugin Integration
# This script syncs your local Obsidian vault to the remote server
# Configured for your setup

# ===========================================
# CONFIGURATION
# ===========================================

LOCAL_VAULT="/home/egarrr/Md essays/"
REMOTE_HOST="ubuntu@207.127.93.169"
REMOTE_VAULT="/home/ubuntu/obsidian-vault/"
LOG_FILE="/home/egarrr/obsidian-sync.log"
TRIGGER_FILE="/home/egarrr/Md essays/.obsidian-sync-trigger"
DOWNLOAD_TRIGGER_FILE="/home/egarrr/Md essays/.obsidian-download-trigger"
SSH_KEY="/home/egarrr/.ssh/obsidian_server_key"

# ===========================================
# SCRIPT LOGIC
# ===========================================

# Function to log messages with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to perform download-only sync (for server changes)
do_download_sync() {
    local trigger_source="$1"
    
    log_message "Starting download-only sync (triggered by: $trigger_source)..."
    
    # Check if local vault exists
    if [ ! -d "$LOCAL_VAULT" ]; then
        log_message "ERROR: Local vault directory does not exist: $LOCAL_VAULT"
        return 1
    fi

    # Download server changes to local (no upload)
    log_message "Downloading server changes to local..."
    rsync -avz \
        --exclude='.obsidian/' \
        --exclude='.git/' \
        --exclude='.DS_Store' \
        --exclude='*.tmp' \
        --exclude='Thumbs.db' \
        -e "ssh -i $SSH_KEY" \
        "$REMOTE_HOST:$REMOTE_VAULT" "$LOCAL_VAULT" \
        2>&1 | while read line; do
            log_message "DOWNLOAD: $line"
        done

    DOWNLOAD_RESULT=${PIPESTATUS[0]}

    if [ $DOWNLOAD_RESULT -eq 0 ]; then
        log_message "Download-only sync completed successfully"
        
        # Count files synced
        FILE_COUNT=$(find "$LOCAL_VAULT" -name "*.md" | wc -l)
        log_message "Total markdown files in local vault: $FILE_COUNT"
        
        # Remove download trigger file if it exists
        if [ -f "$DOWNLOAD_TRIGGER_FILE" ]; then
            rm -f "$DOWNLOAD_TRIGGER_FILE" 2>/dev/null
            log_message "Download trigger file removed"
        fi
        
        return 0
    else
        log_message "ERROR: Download sync failed with exit code $DOWNLOAD_RESULT"
        return $DOWNLOAD_RESULT
    fi
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

    # Sync files using rsync (bidirectional)
    # First, upload local changes to server
    log_message "Uploading local changes to server..."
    rsync -avz --delete \
        --exclude='.obsidian/' \
        --exclude='.git/' \
        --exclude='.DS_Store' \
        --exclude='*.tmp' \
        --exclude='Thumbs.db' \
        -e "ssh -i $SSH_KEY" \
        "$LOCAL_VAULT" "$REMOTE_HOST:$REMOTE_VAULT" \
        2>&1 | while read line; do
            log_message "UPLOAD: $line"
        done

    UPLOAD_RESULT=${PIPESTATUS[0]}

    # Then, download any server changes to local
    log_message "Downloading server changes to local..."
    rsync -avz \
        --exclude='.obsidian/' \
        --exclude='.git/' \
        --exclude='.DS_Store' \
        --exclude='*.tmp' \
        --exclude='Thumbs.db' \
        -e "ssh -i $SSH_KEY" \
        "$REMOTE_HOST:$REMOTE_VAULT" "$LOCAL_VAULT" \
        2>&1 | while read line; do
            log_message "DOWNLOAD: $line"
        done

    DOWNLOAD_RESULT=${PIPESTATUS[0]}

    if [ $UPLOAD_RESULT -eq 0 ] && [ $DOWNLOAD_RESULT -eq 0 ]; then
        log_message "Bi-directional sync completed successfully"
        
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
        log_message "ERROR: Sync failed - Upload: $UPLOAD_RESULT, Download: $DOWNLOAD_RESULT"
        return 1
    fi
}

# Function to watch for trigger files
watch_for_trigger() {
    log_message "Starting trigger file watcher (upload and download)..."
    
    while true; do
        # Check for upload trigger (local changes)
        if [ -f "$TRIGGER_FILE" ]; then
            # Read trigger info if possible
            if [ -r "$TRIGGER_FILE" ]; then
                TRIGGER_INFO=$(cat "$TRIGGER_FILE" 2>/dev/null || echo "unknown")
                log_message "Upload trigger file detected: $TRIGGER_INFO"
            else
                log_message "Upload trigger file detected"
            fi
            
            # Perform bi-directional sync
            do_sync "plugin-trigger"
            
            # Small delay to prevent rapid retriggering
            sleep 2
        fi
        
        # Check for download trigger (server changes)
        if [ -f "$DOWNLOAD_TRIGGER_FILE" ]; then
            # Read trigger info if possible
            if [ -r "$DOWNLOAD_TRIGGER_FILE" ]; then
                DOWNLOAD_INFO=$(cat "$DOWNLOAD_TRIGGER_FILE" 2>/dev/null || echo "unknown")
                log_message "Download trigger file detected: $DOWNLOAD_INFO"
            else
                log_message "Download trigger file detected"
            fi
            
            # Perform download-only sync
            do_download_sync "server-changes"
            
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
        echo "  sync   - Perform one-time bi-directional sync (default)"
        echo "  watch  - Watch for plugin triggers"
        echo "  daemon - Run both watcher and periodic sync"
        echo ""
        echo "Configuration:"
        echo "  Local vault:  $LOCAL_VAULT"
        echo "  Remote host:  $REMOTE_HOST"
        echo "  Remote vault: $REMOTE_VAULT"
        echo "  Log file:     $LOG_FILE"
        exit 1
        ;;
esac

log_message "Obsidian sync script finished"