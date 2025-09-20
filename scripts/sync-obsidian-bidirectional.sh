#!/bin/bash

# Bidirectional Obsidian Sync Script
# This script syncs files both ways: local->remote and remote->local
# It includes smart conflict resolution to avoid download loops

LOCAL_VAULT="/home/egarrr/Notes/"
REMOTE_HOST="ChainServer#1"
REMOTE_VAULT="/home/ubuntu/obsidian-vault/"
LOG_FILE="/home/egarrr/obsidian-sync.log"
TRIGGER_FILE="/home/egarrr/Notes/Myself/.obsidian/sync-trigger"
STATE_DIR="/home/egarrr/.obsidian-sync"
UPLOAD_TRACKER="$STATE_DIR/last-uploads"
DOWNLOAD_TRACKER="$STATE_DIR/last-downloads"
MACHINE_ID=$(uname -n)-$(whoami)

# Ensure state directory exists
mkdir -p "$STATE_DIR"

# Function to log messages with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to get file modification time
get_file_mtime() {
    local file_path="$1"
    if [ -f "$file_path" ]; then
        stat -c %Y "$file_path" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to get remote file modification time
get_remote_file_mtime() {
    local remote_file="$1"
    ssh "$REMOTE_HOST" "stat -c %Y '$remote_file' 2>/dev/null || echo '0'"
}

# Function to check if file was recently uploaded by this machine
was_recently_uploaded() {
    local file_path="$1"
    local current_time=$(date +%s)
    local upload_window=300  # 5 minutes
    
    if [ -f "$UPLOAD_TRACKER" ]; then
        # Check if file was uploaded recently by this machine
        grep -q "^$MACHINE_ID:$file_path:" "$UPLOAD_TRACKER" 2>/dev/null
        if [ $? -eq 0 ]; then
            local last_upload=$(grep "^$MACHINE_ID:$file_path:" "$UPLOAD_TRACKER" | tail -1 | cut -d: -f3)
            if [ $((current_time - last_upload)) -lt $upload_window ]; then
                return 0  # Recently uploaded
            fi
        fi
    fi
    return 1  # Not recently uploaded
}

# Function to record file upload
record_upload() {
    local file_path="$1"
    local timestamp=$(date +%s)
    echo "$MACHINE_ID:$file_path:$timestamp" >> "$UPLOAD_TRACKER"
    
    # Keep only last 1000 entries to prevent file from growing too large
    tail -n 1000 "$UPLOAD_TRACKER" > "$UPLOAD_TRACKER.tmp" && mv "$UPLOAD_TRACKER.tmp" "$UPLOAD_TRACKER"
}

# Function to record file download
record_download() {
    local file_path="$1"
    local timestamp=$(date +%s)
    echo "$MACHINE_ID:$file_path:$timestamp" >> "$DOWNLOAD_TRACKER"
    
    # Keep only last 1000 entries
    tail -n 1000 "$DOWNLOAD_TRACKER" > "$DOWNLOAD_TRACKER.tmp" && mv "$DOWNLOAD_TRACKER.tmp" "$DOWNLOAD_TRACKER"
}

# Function to detect remote changes
detect_remote_changes() {
    # Only log if not in quiet mode
    if [ "$QUIET_MODE" != "true" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking for remote changes..." >&2
    fi
    
    local temp_file="/tmp/changed_files_$$"
    rm -f "$temp_file"  # Clean up any previous temp file
    
    # Get list of all markdown files on remote
    local remote_files
    remote_files=$(ssh "$REMOTE_HOST" "find '$REMOTE_VAULT' -name '*.md' -type f 2>/dev/null")
    
    if [ -z "$remote_files" ]; then
        if [ "$QUIET_MODE" != "true" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - No markdown files found on remote server" >&2
        fi
        return 0
    fi
    
    # Process each remote file
    while IFS= read -r remote_file; do
        [ -z "$remote_file" ] && continue
        
        # Convert remote path to local path
        local relative_path="${remote_file#$REMOTE_VAULT}"
        local local_file="$LOCAL_VAULT$relative_path"
        
        # Skip if file was recently uploaded by this machine
        if was_recently_uploaded "$relative_path"; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Skipping $relative_path (recently uploaded by this machine)" >&2
            continue
        fi
        
        # Get modification times
        local remote_mtime=$(get_remote_file_mtime "$remote_file")
        local local_mtime=$(get_file_mtime "$local_file")
        
        # Check if remote file is newer
        if [ "$remote_mtime" -gt "$local_mtime" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Remote change detected: $relative_path (remote: $remote_mtime, local: $local_mtime)" >&2
            echo "$relative_path" >> "$temp_file"
        fi
        
    done <<< "$remote_files"
    
    # Output changed files to stdout only
    if [ -f "$temp_file" ]; then
        cat "$temp_file"
        rm -f "$temp_file"
    fi
}

# Function to download remote changes
download_remote_changes() {
    local files_to_download=("$@")
    
    if [ ${#files_to_download[@]} -eq 0 ]; then
        log_message "No remote changes to download"
        return 0
    fi
    
    log_message "Downloading ${#files_to_download[@]} changed files from remote..."
    
    for file_path in "${files_to_download[@]}"; do
        local remote_file="$REMOTE_VAULT$file_path"
        local local_file="$LOCAL_VAULT$file_path"
        local local_dir=$(dirname "$local_file")
        
        # Ensure local directory exists
        mkdir -p "$local_dir"
        
        # Download the file
        if scp "$REMOTE_HOST:$remote_file" "$local_file" 2>/dev/null; then
            log_message "Downloaded: $file_path"
            record_download "$file_path"
            
            # Create a marker for the plugin to detect the change
            echo "{\"type\":\"download\",\"file\":\"$file_path\",\"timestamp\":$(date +%s000)}" > "/home/egarrr/Notes/Myself/.obsidian/remote-change-$$.json"
        else
            log_message "ERROR: Failed to download: $file_path"
        fi
    done
}

# Function to upload local changes
upload_local_changes() {
    log_message "Uploading local changes to remote..."
    
    # Track which files are being uploaded
    local temp_upload_list=$(mktemp)
    
    # Sync with detailed output to capture what's being transferred
    rsync -avz --delete \
        --exclude='.obsidian/' \
        --exclude='.git/' \
        --exclude='.DS_Store' \
        --exclude='*.tmp' \
        --exclude='Thumbs.db' \
        --out-format='UPLOADED: %n' \
        "$LOCAL_VAULT" "$REMOTE_HOST:$REMOTE_VAULT" \
        2>&1 | while read line; do
            log_message "$line"
            
            # Track uploaded files
            if [[ "$line" == UPLOADED:* ]]; then
                local uploaded_file="${line#UPLOADED: }"
                # Remove trailing slash if it's a directory
                uploaded_file="${uploaded_file%/}"
                if [[ "$uploaded_file" == *.md ]]; then
                    echo "$uploaded_file" >> "$temp_upload_list"
                fi
            fi
        done
    
    # Record all uploaded files
    if [ -f "$temp_upload_list" ]; then
        while IFS= read -r uploaded_file; do
            [ -n "$uploaded_file" ] && record_upload "$uploaded_file"
        done < "$temp_upload_list"
        rm -f "$temp_upload_list"
    fi
    
    local upload_result=${PIPESTATUS[0]}
    
    if [ $upload_result -eq 0 ]; then
        log_message "Upload completed successfully"
        return 0
    else
        log_message "ERROR: Upload failed with exit code $upload_result"
        return $upload_result
    fi
}

# Function to perform bidirectional sync
do_bidirectional_sync() {
    local trigger_source="$1"
    
    log_message "Starting bidirectional sync (triggered by: $trigger_source)..."
    
    # Check if local vault exists
    if [ ! -d "$LOCAL_VAULT" ]; then
        log_message "ERROR: Local vault directory does not exist: $LOCAL_VAULT"
        return 1
    fi
    
    # Check remote connectivity
    if ! ssh "$REMOTE_HOST" "test -d '$REMOTE_VAULT'" 2>/dev/null; then
        log_message "ERROR: Cannot connect to remote host or vault directory does not exist"
        return 1
    fi
    
    # First, detect and download remote changes
    local remote_changes_temp="/tmp/remote_changes_$$"
    detect_remote_changes > "$remote_changes_temp"
    
    if [ -s "$remote_changes_temp" ]; then
        local remote_changes=()
        while IFS= read -r changed_file; do
            remote_changes+=("$changed_file")
        done < "$remote_changes_temp"
        
        if [ ${#remote_changes[@]} -gt 0 ]; then
            download_remote_changes "${remote_changes[@]}"
        fi
    fi
    
    rm -f "$remote_changes_temp"
    
    # Then upload local changes
    upload_local_changes
    
    local sync_result=$?
    
    # Cleanup
    if [ -f "$TRIGGER_FILE" ]; then
        rm -f "$TRIGGER_FILE" 2>/dev/null
        log_message "Trigger file removed"
    fi
    
    # Count total files
    local file_count=$(find "$LOCAL_VAULT" -name "*.md" | wc -l)
    log_message "Total markdown files in local vault: $file_count"
    
    return $sync_result
}

# Function to watch for trigger file
watch_for_trigger() {
    log_message "Starting bidirectional sync watcher..."
    
    while true; do
        if [ -f "$TRIGGER_FILE" ]; then
            # Read trigger info if possible
            if [ -r "$TRIGGER_FILE" ]; then
                TRIGGER_INFO=$(cat "$TRIGGER_FILE" 2>/dev/null || echo "unknown")
                log_message "Trigger file detected: $TRIGGER_INFO"
            else
                log_message "Trigger file detected"
            fi
            
            # Perform bidirectional sync
            do_bidirectional_sync "plugin-trigger"
            
            # Small delay to prevent rapid retriggering
            sleep 2
        fi
        
        # Check every 5 seconds
        sleep 5
    done
}

# Function to run periodic sync daemon
run_sync_daemon() {
    log_message "Starting bidirectional sync daemon..."
    
    # Start background watcher for plugin triggers
    watch_for_trigger &
    local watcher_pid=$!
    
    # Periodic bidirectional sync every 10 minutes
    while true; do
        sleep 600  # 10 minutes
        log_message "Performing periodic bidirectional sync..."
        do_bidirectional_sync "periodic"
    done
    
    # Cleanup on exit
    trap "kill $watcher_pid 2>/dev/null" EXIT
}

# Main execution
case "${1:-sync}" in
    "sync")
        # One-time bidirectional sync
        do_bidirectional_sync "manual"
        ;;
    "watch")
        # Watch mode for plugin triggers only
        watch_for_trigger
        ;;
    "daemon")
        # Full daemon mode - watch + periodic sync
        run_sync_daemon
        ;;
    "download-only")
        # Only check for and download remote changes
        if [ "$QUIET_MODE" != "true" ]; then
            log_message "Checking for remote changes only..."
        fi
        remote_changes_temp="/tmp/remote_changes_$$"
        detect_remote_changes > "$remote_changes_temp"
        
        if [ -s "$remote_changes_temp" ]; then
            remote_changes=()
            while IFS= read -r changed_file; do
                remote_changes+=("$changed_file")
            done < "$remote_changes_temp"
            
            if [ ${#remote_changes[@]} -gt 0 ]; then
                download_remote_changes "${remote_changes[@]}"
            fi
        else
            if [ "$QUIET_MODE" != "true" ]; then
                log_message "No remote changes detected"
            fi
        fi
        
        rm -f "$remote_changes_temp"
        ;;
    "download-only-quiet")
        # Quiet download-only mode (for frequent periodic checks)
        QUIET_MODE="true"
        remote_changes_temp="/tmp/remote_changes_$$"
        detect_remote_changes > "$remote_changes_temp"
        
        if [ -s "$remote_changes_temp" ]; then
            remote_changes=()
            while IFS= read -r changed_file; do
                remote_changes+=("$changed_file")
            done < "$remote_changes_temp"
            
            if [ ${#remote_changes[@]} -gt 0 ]; then
                log_message "Found ${#remote_changes[@]} remote changes, downloading..."
                download_remote_changes "${remote_changes[@]}"
            fi
        fi
        
        rm -f "$remote_changes_temp"
        ;;
    *)
        echo "Usage: $0 [sync|watch|daemon|download-only|download-only-quiet]"
        echo "  sync               - Perform one-time bidirectional sync (default)"
        echo "  watch              - Watch for plugin triggers and sync bidirectionally"
        echo "  daemon             - Run both watcher and periodic bidirectional sync"
        echo "  download-only      - Only check for and download remote changes"
        echo "  download-only-quiet - Quiet download check (for frequent periodic use)"
        exit 1
        ;;
esac

log_message "Bidirectional sync script finished"