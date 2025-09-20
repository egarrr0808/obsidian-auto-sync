#!/bin/bash

# Obsidian Auto Server Sync Plugin Installation Script
# This script installs the plugin into your Obsidian vault

# ===========================================
# CONFIGURATION - EDIT THESE VALUES
# ===========================================

OBSIDIAN_VAULT_PATH="/home/egarrr/Notes/Myself"
PLUGIN_SOURCE_DIR="$(dirname "$0")/../obsidian-plugin"

# ===========================================
# SCRIPT LOGIC
# ===========================================

echo "🚀 Installing Obsidian Auto Server Sync Plugin..."
echo ""

# Check if vault path is configured
if [[ "$OBSIDIAN_VAULT_PATH" == *"path/to/your"* ]]; then
    echo "❌ Error: Please configure OBSIDIAN_VAULT_PATH in this script first!"
    echo "   Edit this file and set the correct path to your Obsidian vault."
    exit 1
fi

# Check if vault directory exists
if [ ! -d "$OBSIDIAN_VAULT_PATH" ]; then
    echo "❌ Error: Vault directory does not exist: $OBSIDIAN_VAULT_PATH"
    echo "   Please check the path and try again."
    exit 1
fi

# Check if plugin source exists
if [ ! -d "$PLUGIN_SOURCE_DIR" ]; then
    echo "❌ Error: Plugin source directory not found: $PLUGIN_SOURCE_DIR"
    echo "   Make sure you're running this from the correct location."
    exit 1
fi

# Create plugin directories
OBSIDIAN_DIR="$OBSIDIAN_VAULT_PATH/.obsidian"
PLUGIN_DIR="$OBSIDIAN_DIR/plugins/auto-server-sync"
COMMUNITY_PLUGINS_FILE="$OBSIDIAN_DIR/community-plugins.json"

echo "📁 Creating plugin directory..."
mkdir -p "$PLUGIN_DIR"

echo "📄 Copying plugin files..."
cp "$PLUGIN_SOURCE_DIR/manifest.json" "$PLUGIN_DIR/"
cp "$PLUGIN_SOURCE_DIR/main.js" "$PLUGIN_DIR/"
cp "$PLUGIN_SOURCE_DIR/styles.css" "$PLUGIN_DIR/"

# Create or update community-plugins.json
if [ ! -f "$COMMUNITY_PLUGINS_FILE" ]; then
    echo '["auto-server-sync"]' > "$COMMUNITY_PLUGINS_FILE"
    echo "✅ Created community-plugins.json"
else
    # Add plugin to existing community-plugins.json if not already present
    if ! grep -q "auto-server-sync" "$COMMUNITY_PLUGINS_FILE"; then
        # Use jq if available, otherwise use sed
        if command -v jq > /dev/null 2>&1; then
            jq '. += ["auto-server-sync"]' "$COMMUNITY_PLUGINS_FILE" > "${COMMUNITY_PLUGINS_FILE}.tmp" && mv "${COMMUNITY_PLUGINS_FILE}.tmp" "$COMMUNITY_PLUGINS_FILE"
        else
            # Fallback: simple sed replacement (assumes basic JSON array)
            sed 's/]/, "auto-server-sync"]/' "$COMMUNITY_PLUGINS_FILE" > "${COMMUNITY_PLUGINS_FILE}.tmp" && mv "${COMMUNITY_PLUGINS_FILE}.tmp" "$COMMUNITY_PLUGINS_FILE"
        fi
        echo "✅ Added plugin to existing community-plugins.json"
    else
        echo "✅ Plugin already enabled in community-plugins.json"
    fi
fi

# Check plugin files
echo ""
echo "📋 Plugin installation status:"
echo "- Manifest: $([ -f "$PLUGIN_DIR/manifest.json" ] && echo "✅" || echo "❌")"
echo "- Main script: $([ -f "$PLUGIN_DIR/main.js" ] && echo "✅" || echo "❌")"
echo "- Styles: $([ -f "$PLUGIN_DIR/styles.css" ] && echo "✅" || echo "❌")"

echo ""
echo "🎉 Plugin installation complete!"
echo ""
echo "📝 Next steps:"
echo "1. Restart Obsidian completely"
echo "2. Go to Settings → Community Plugins"
echo "3. Turn OFF 'Safe Mode' if it's enabled"
echo "4. Find 'Auto Server Sync' and enable it"
echo "5. Click the settings gear to configure your server URL"
echo ""
echo "📖 The plugin will:"
echo "   • Monitor file changes in real-time"
echo "   • Check for changes every 10 seconds"
echo "   • Trigger sync when changes are detected"
echo "   • Show sync status in the status bar"
echo ""
echo "⚡ Make sure to:"
echo "   • Configure your sync script (scripts/sync-obsidian.sh)"
echo "   • Set up SSH key authentication"
echo "   • Start the sync daemon: ./scripts/sync-obsidian.sh watch &"
echo ""
echo "🌐 Access your notes at: http://your-server:8080"