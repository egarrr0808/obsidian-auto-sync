const { Plugin, Setting, Notice, PluginSettingTab } = require('obsidian');

const DEFAULT_SETTINGS = {
    serverUrl: 'http://localhost:8080',
    syncInterval: 10, // seconds
    enabled: true,
    showNotices: true,
    lastSyncTimes: {} // track last modified times
};

class AutoServerSyncPlugin extends Plugin {
    constructor(app, manifest) {
        super(app, manifest);
        this.settings = DEFAULT_SETTINGS;
        this.syncTimer = null;
        this.fileModificationTimes = new Map();
        this.pendingSync = false;
    }

    async onload() {
        console.log('Auto Server Sync plugin loading...');
        
        await this.loadSettings();
        
        // Add settings tab
        this.addSettingTab(new AutoServerSyncSettingTab(this.app, this));
        
        // Add status bar item
        this.statusBarItemEl = this.addStatusBarItem();
        this.updateStatusBar('Stopped');
        
        // Add command to toggle sync
        this.addCommand({
            id: 'toggle-auto-sync',
            name: 'Toggle Auto Sync',
            callback: () => {
                this.settings.enabled = !this.settings.enabled;
                this.saveSettings();
                if (this.settings.enabled) {
                    this.startSync();
                    new Notice('Auto sync enabled');
                } else {
                    this.stopSync();
                    new Notice('Auto sync disabled');
                }
            }
        });

        // Add command to sync now
        this.addCommand({
            id: 'sync-now',
            name: 'Sync Now (Bidirectional)',
            callback: () => {
                this.triggerSync();
            }
        });
        
        // Add command to download only
        this.addCommand({
            id: 'download-remote-changes',
            name: 'Download Remote Changes',
            callback: () => {
                this.triggerDownloadOnly();
            }
        });
        
        // Start sync if enabled
        if (this.settings.enabled) {
            this.startSync();
        }
        
        // Start monitoring for remote changes
        this.startRemoteChangeMonitoring();
        
        // Register file modification listener
        this.registerEvent(
            this.app.vault.on('modify', (file) => {
                if (file.extension === 'md') {
                    this.fileModificationTimes.set(file.path, Date.now());
                    if (this.settings.showNotices) {
                        console.log(`File modified: ${file.name}`);
                    }
                }
            })
        );

        // Register file creation listener
        this.registerEvent(
            this.app.vault.on('create', (file) => {
                if (file.extension === 'md') {
                    this.fileModificationTimes.set(file.path, Date.now());
                    if (this.settings.showNotices) {
                        console.log(`File created: ${file.name}`);
                    }
                }
            })
        );

        console.log('Auto Server Sync plugin loaded');
    }

    onunload() {
        console.log('Auto Server Sync plugin unloading...');
        this.stopSync();
        this.stopRemoteChangeMonitoring();
    }

    startSync() {
        if (this.syncTimer) {
            clearInterval(this.syncTimer);
        }
        
        this.syncTimer = setInterval(() => {
            this.checkAndSync();
        }, this.settings.syncInterval * 1000);
        
        this.updateStatusBar('Running');
        console.log(`Auto sync started (interval: ${this.settings.syncInterval}s)`);
    }

    stopSync() {
        if (this.syncTimer) {
            clearInterval(this.syncTimer);
            this.syncTimer = null;
        }
        this.updateStatusBar('Stopped');
        console.log('Auto sync stopped');
    }

    async checkAndSync() {
        if (!this.settings.enabled || this.pendingSync) {
            return;
        }

        try {
            const modifiedFiles = [];
            const currentTime = Date.now();
            
            // Check all markdown files for modifications
            const files = this.app.vault.getMarkdownFiles();
            
            for (const file of files) {
                const filePath = file.path;
                const lastModified = this.fileModificationTimes.get(filePath);
                const lastSynced = this.settings.lastSyncTimes[filePath] || 0;
                
                // If file was modified since last sync
                if (lastModified && lastModified > lastSynced) {
                    modifiedFiles.push(file);
                    // Update last sync time
                    this.settings.lastSyncTimes[file.path] = currentTime;
                }
            }

            if (modifiedFiles.length > 0) {
                this.updateStatusBar(`${modifiedFiles.length} files changed`);
                
                await this.saveSettings();
                
                // Trigger the external sync script
                this.triggerSync();
                
                if (this.settings.showNotices) {
                    new Notice(`Detected ${modifiedFiles.length} modified file(s) - triggering sync`);
                }
                
                console.log(`Detected ${modifiedFiles.length} modified files, sync triggered`);
            } else {
                this.updateStatusBar('Running');
            }
            
        } catch (error) {
            console.error('Sync check error:', error);
            this.updateStatusBar('Error');
        }
    }

    async triggerSync() {
        if (this.pendingSync) {
            return;
        }
        
        this.pendingSync = true;
        this.updateStatusBar('Syncing...');
        
        try {
            // Create a marker file to trigger sync (within vault since we can't write to /tmp)
            const markerPath = '.obsidian/sync-trigger';
            const markerContent = JSON.stringify({
                timestamp: Date.now(),
                vault: this.app.vault.adapter.basePath || 'VAULT_PATH_HERE',
                trigger: 'obsidian-plugin'
            });
            
            // Write marker file using Obsidian's file system
            await this.app.vault.adapter.write(markerPath, markerContent);
            
            // Show sync notification
            if (this.settings.showNotices) {
                new Notice('Sync triggered - files will be uploaded to server');
            }
            
            console.log(`Sync triggered via marker file: ${markerPath}`);
            
            // Reset status after a delay
            setTimeout(() => {
                this.updateStatusBar('Running');
                this.pendingSync = false;
            }, 3000);
            
        } catch (error) {
            console.error('Error triggering sync:', error);
            this.updateStatusBar('Error');
            this.pendingSync = false;
            
            if (this.settings.showNotices) {
                new Notice(`Sync trigger failed: ${error.message}`);
            }
        }
    }

    updateStatusBar(status) {
        if (this.statusBarItemEl) {
            this.statusBarItemEl.setText(`🔄 ${status}`);
        }
    }
    
    async triggerDownloadOnly() {
        if (this.pendingSync) {
            return;
        }
        
        this.pendingSync = true;
        this.updateStatusBar('Checking Remote...');
        
        try {
            // Create a marker file to trigger download-only sync
            const markerPath = '.obsidian/download-trigger';
            const markerContent = JSON.stringify({
                timestamp: Date.now(),
                vault: this.app.vault.adapter.basePath || 'VAULT_PATH_HERE',
                trigger: 'download-only'
            });
            
            await this.app.vault.adapter.write(markerPath, markerContent);
            
            if (this.settings.showNotices) {
                new Notice('Checking for remote changes...');
            }
            
            console.log(`Download-only triggered via marker file: ${markerPath}`);
            
            // Reset status after a delay
            setTimeout(() => {
                this.updateStatusBar('Running');
                this.pendingSync = false;
            }, 5000);
            
        } catch (error) {
            console.error('Error triggering download check:', error);
            this.updateStatusBar('Error');
            this.pendingSync = false;
            
            if (this.settings.showNotices) {
                new Notice(`Download check failed: ${error.message}`);
            }
        }
    }
    
    startRemoteChangeMonitoring() {
        // Monitor for remote change marker files
        this.remoteChangeTimer = setInterval(() => {
            this.checkForRemoteChangeMarkers();
        }, 3000); // Check every 3 seconds
        
        console.log('Remote change monitoring started');
    }
    
    stopRemoteChangeMonitoring() {
        if (this.remoteChangeTimer) {
            clearInterval(this.remoteChangeTimer);
            this.remoteChangeTimer = null;
        }
        console.log('Remote change monitoring stopped');
    }
    
    async checkForRemoteChangeMarkers() {
        try {
            // Look for remote change marker files
            const files = await this.app.vault.adapter.list('.obsidian/');
            
            if (files.files) {
                for (const file of files.files) {
                    if (file.startsWith('.obsidian/remote-change-') && file.endsWith('.json')) {
                        await this.handleRemoteChangeMarker(file);
                    }
                }
            }
        } catch (error) {
            // Silently ignore errors to avoid spam
        }
    }
    
    async handleRemoteChangeMarker(markerFile) {
        try {
            // Read the marker file
            const content = await this.app.vault.adapter.read(markerFile);
            const changeInfo = JSON.parse(content);
            
            if (this.settings.showNotices) {
                new Notice(`Remote change detected: ${changeInfo.file}`);
            }
            
            console.log('Remote change marker detected:', changeInfo);
            
            // Update status briefly
            this.updateStatusBar('Remote Change');
            setTimeout(() => {
                this.updateStatusBar('Running');
            }, 3000);
            
            // Remove the marker file
            await this.app.vault.adapter.remove(markerFile);
            
        } catch (error) {
            console.error('Error handling remote change marker:', error);
        }
    }

    async loadSettings() {
        this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
    }

    async saveSettings() {
        await this.saveData(this.settings);
    }
}

class AutoServerSyncSettingTab extends PluginSettingTab {
    constructor(app, plugin) {
        super(app, plugin);
        this.plugin = plugin;
    }

    display() {
        const { containerEl } = this;
        containerEl.empty();
        
        containerEl.createEl('h2', { text: 'Auto Server Sync Settings' });
        
        // Info section
        const infoEl = containerEl.createEl('div', { 
            cls: 'setting-item-description',
            text: 'This plugin detects file changes and triggers the external sync script to upload modified files to your server every 10 seconds.'
        });
        infoEl.style.marginBottom = '20px';
        
        new Setting(containerEl)
            .setName('Enable auto sync')
            .setDesc('Automatically detect and sync modified files to server')
            .addToggle(toggle => toggle
                .setValue(this.plugin.settings.enabled)
                .onChange(async (value) => {
                    this.plugin.settings.enabled = value;
                    await this.plugin.saveSettings();
                    
                    if (value) {
                        this.plugin.startSync();
                    } else {
                        this.plugin.stopSync();
                    }
                }));

        new Setting(containerEl)
            .setName('Server URL')
            .setDesc('URL of your Obsidian web server (for reference)')
            .addText(text => text
                .setPlaceholder('http://207.127.93.169:8080')
                .setValue(this.plugin.settings.serverUrl)
                .onChange(async (value) => {
                    this.plugin.settings.serverUrl = value;
                    await this.plugin.saveSettings();
                }));

        new Setting(containerEl)
            .setName('Check interval')
            .setDesc('How often to check for file changes (seconds)')
            .addText(text => text
                .setPlaceholder('10')
                .setValue(this.plugin.settings.syncInterval.toString())
                .onChange(async (value) => {
                    const interval = parseInt(value);
                    if (interval > 0 && interval >= 5) {
                        this.plugin.settings.syncInterval = interval;
                        await this.plugin.saveSettings();
                        
                        // Restart sync with new interval
                        if (this.plugin.settings.enabled) {
                            this.plugin.startSync();
                        }
                    }
                }));

        new Setting(containerEl)
            .setName('Show notifications')
            .setDesc('Show notifications when changes are detected and sync is triggered')
            .addToggle(toggle => toggle
                .setValue(this.plugin.settings.showNotices)
                .onChange(async (value) => {
                    this.plugin.settings.showNotices = value;
                    await this.plugin.saveSettings();
                }));

        // Sync status and controls
        containerEl.createEl('h3', { text: 'Sync Control' });
        
        const statusEl = containerEl.createEl('div', { 
            cls: 'setting-item-description'
        });
        statusEl.innerHTML = this.plugin.settings.enabled 
            ? '✅ Auto sync is <strong>enabled</strong>' 
            : '❌ Auto sync is <strong>disabled</strong>';
        statusEl.style.marginBottom = '15px';
        
        new Setting(containerEl)
            .setName('Trigger bidirectional sync')
            .setDesc('Upload local changes and download remote changes immediately')
            .addButton(button => button
                .setButtonText('Sync Now (Bidirectional)')
                .setClass('mod-cta')
                .onClick(() => {
                    this.plugin.triggerSync();
                }));
                
        new Setting(containerEl)
            .setName('Download remote changes only')
            .setDesc('Check for and download changes from other devices without uploading local changes')
            .addButton(button => button
                .setButtonText('Download Remote Changes')
                .onClick(() => {
                    this.plugin.triggerDownloadOnly();
                }));

        // Clear sync history
        new Setting(containerEl)
            .setName('Reset change tracking')
            .setDesc('Clear the record of file changes (will detect all files as changed on next check)')
            .addButton(button => button
                .setButtonText('Reset')
                .setWarning()
                .onClick(async () => {
                    this.plugin.settings.lastSyncTimes = {};
                    this.plugin.fileModificationTimes.clear();
                    await this.plugin.saveSettings();
                    new Notice('Change tracking history cleared');
                }));

        // Instructions
        containerEl.createEl('h3', { text: 'How it works' });
        const instructionsEl = containerEl.createEl('div', { cls: 'setting-item-description' });
        instructionsEl.innerHTML = `
            <p>This plugin enables <strong>bidirectional synchronization</strong> with your remote server:</p>
            <ul>
                <li>• <strong>Upload:</strong> Monitors local file changes and uploads them to the server</li>
                <li>• <strong>Download:</strong> Detects remote changes and downloads them automatically</li>
                <li>• <strong>Smart Conflict Resolution:</strong> Avoids downloading files you just uploaded</li>
                <li>• <strong>Real-time Notifications:</strong> Shows when files are synced or downloaded</li>
                <li>• <strong>Multiple Device Support:</strong> Works seamlessly across laptops/devices</li>
            </ul>
            <p><strong>Requirements:</strong></p>
            <ul>
                <li>• Enhanced sync script running in watch mode</li>
                <li>• Proper SSH key authentication to remote server</li>
                <li>• Network connectivity to your remote server</li>
            </ul>
        `;
    }
}

module.exports = AutoServerSyncPlugin;