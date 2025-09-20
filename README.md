# 🚀 Obsidian Auto Server Sync

> **Real-time bidirectional synchronization between Obsidian and a remote web server**

A complete solution for automatically syncing your Obsidian notes to a remote server and accessing them via a beautiful web interface from anywhere in the world.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js](https://img.shields.io/badge/Node.js-14%2B-green)](https://nodejs.org/)
[![Obsidian](https://img.shields.io/badge/Obsidian-Plugin-purple)](https://obsidian.md/)

## 📖 Overview

This project provides a complete synchronization solution consisting of:

- **🔌 Obsidian Plugin**: Monitors file changes and triggers sync every 10 seconds
- **🌐 Web Server**: Beautiful web interface to view your notes from anywhere
- **🔄 Sync Scripts**: Robust rsync-based synchronization with conflict handling
- **⚙️ Easy Setup**: Automated installation and configuration scripts

## ✨ Features

### 🎯 **Smart Bidirectional Sync**
- **Real-time detection**: Plugin monitors file changes as you edit
- **Bidirectional sync**: Automatically uploads your changes AND downloads changes from other devices
- **Smart conflict resolution**: Tracks locally modified files to avoid overwriting your active edits
- **Server polling**: Checks for changes from other devices every 30 seconds
- **Background operation**: Never interrupts your workflow
- **Intelligent triggering**: Uses separate triggers for upload and download operations

### 🌟 **Web Interface**
- **Responsive design**: Works perfectly on desktop and mobile
- **Live preview**: Beautiful markdown rendering with syntax highlighting
- **File browser**: Easy navigation through your entire vault
- **Auto-refresh**: Updates every 30 seconds automatically

### 🔧 **Easy Installation**
- **One-click setup**: Automated installation scripts
- **Template configs**: Pre-configured templates for common setups
- **Cross-platform**: Works on Linux, macOS, and Windows
- **Docker support**: Optional containerized deployment

## 📁 Project Structure

```
obsidian-auto-sync/
├── 📁 server/                    # Web server application
│   ├── server.js                 # Node.js web server
│   └── package.json              # Dependencies
├── 📁 obsidian-plugin/           # Obsidian plugin
│   ├── main.js                   # Plugin main file
│   ├── manifest.json             # Plugin metadata
│   └── styles.css                # Plugin styles
├── 📁 scripts/                   # Installation & sync scripts
│   ├── sync-obsidian.sh          # Main sync script
│   └── install-plugin.sh         # Plugin installer
├── 📁 config-templates/          # Configuration templates
│   ├── ssh-config-example        # SSH configuration
│   ├── .env.example              # Environment variables
│   └── obsidian-server.service.example # Systemd service
├── 📁 docs/                      # Documentation
└── README.md                     # This file
```

## 🚀 Quick Start

### Prerequisites

- **Obsidian** installed locally
- **Node.js 14+** on your server
- **SSH access** to your remote server
- **rsync** installed (usually pre-installed on Linux/macOS)

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/obsidian-auto-sync.git
cd obsidian-auto-sync
```

### 2. Server Setup

```bash
# Copy server files to your remote server
scp -r server/ user@your-server:~/obsidian-server/

# SSH into your server
ssh user@your-server

# Install dependencies
cd ~/obsidian-server
npm install

# Create vault directory
mkdir -p ~/obsidian-vault

# Start server
npm start
```

The web interface will be available at `http://your-server:8080`

### 3. Local Setup

#### Configure SSH (one-time setup)
```bash
# Copy SSH config template
cp config-templates/ssh-config-example ~/.ssh/config

# Edit with your server details
nano ~/.ssh/config
```

#### Install Obsidian Plugin
```bash
# Configure installation script
nano scripts/install-plugin.sh
# Set OBSIDIAN_VAULT_PATH to your vault location

# Run installer
./scripts/install-plugin.sh
```

#### Configure Sync Script
```bash
# Configure sync script
nano scripts/sync-obsidian.sh
# Set LOCAL_VAULT, REMOTE_HOST, and REMOTE_VAULT

# Test sync
./scripts/sync-obsidian.sh sync

# Start daemon (for real-time sync)
./scripts/sync-obsidian.sh watch &
```

### 4. Enable Plugin in Obsidian

1. Open Obsidian
2. Go to **Settings** → **Community Plugins**
3. Turn **OFF** Safe Mode
4. Find **"Auto Server Sync"** and enable it
5. Configure your server URL in plugin settings

## 🔄 Bidirectional Sync Flow

### **Local Changes → Server**
1. Edit file in Obsidian
2. Plugin detects change immediately
3. Creates `.obsidian-sync-trigger` file
4. Sync script performs bidirectional sync (upload + download)
5. Server and web interface update

### **Remote Changes → Local**
1. Another device makes changes and uploads to server
2. Plugin polls server API every 30 seconds
3. Detects new/modified files on server
4. Creates `.obsidian-download-trigger` file  
5. Sync script performs download-only sync
6. Local vault updates automatically
7. Obsidian refreshes with new content

### **Conflict Prevention**
- Plugin tracks files you've modified locally
- During server polling, locally modified files are ignored
- Grace period of 1 minute after local edits
- Prevents overwriting your active work

## 📚 Detailed Documentation

### 🔌 Plugin Configuration

The Obsidian plugin provides several configurable options:

- **Server URL**: Your web server address (e.g., `http://your-server:8080`)
- **Check Interval**: How often to check for local changes (default: 10 seconds)
- **Server Poll Interval**: How often to check for server changes (default: 30 seconds)
- **Enable Server Polling**: Turn bidirectional sync on/off
- **Notifications**: Enable/disable sync notifications
- **Auto-start**: Start sync when Obsidian launches

### 🌐 Server Configuration

Configure the server using environment variables:

```bash
# Copy environment template
cp config-templates/.env.example server/.env

# Edit configuration
nano server/.env
```

Available options:
- `PORT`: Server port (default: 8080)
- `VAULT_PATH`: Path to your vault directory
- `AUTH_USERNAME`: Optional basic auth username
- `AUTH_PASSWORD`: Optional basic auth password

### 🔄 Sync Modes

The sync script supports multiple modes:

```bash
# One-time bidirectional sync
./scripts/sync-obsidian.sh sync

# Watch for plugin triggers (both upload and download)
./scripts/sync-obsidian.sh watch

# Daemon mode (watch + periodic sync)
./scripts/sync-obsidian.sh daemon

# Quick start (recommended)
./scripts/start-sync.sh
```

### **Trigger Files**
- `.obsidian-sync-trigger`: Created by plugin for local changes → triggers bidirectional sync
- `.obsidian-download-trigger`: Created by plugin for server changes → triggers download-only sync

### 🐳 Docker Deployment

```bash
# Build image
docker build -t obsidian-server server/

# Run container
docker run -d \
  --name obsidian-server \
  -p 8080:8080 \
  -v /path/to/vault:/app/vault:ro \
  obsidian-server
```

## 🔧 Advanced Configuration

### SSL/HTTPS Setup

For production deployments, enable HTTPS:

```bash
# Generate SSL certificate (Let's Encrypt example)
certbot certonly --standalone -d your-domain.com

# Configure in .env
SSL_ENABLED=true
SSL_CERT_PATH=/etc/letsencrypt/live/your-domain.com/fullchain.pem
SSL_KEY_PATH=/etc/letsencrypt/live/your-domain.com/privkey.pem
```

### Systemd Service

For automatic server startup:

```bash
# Copy service template
sudo cp config-templates/obsidian-server.service.example \
        /etc/systemd/system/obsidian-server.service

# Edit paths
sudo nano /etc/systemd/system/obsidian-server.service

# Enable service
sudo systemctl daemon-reload
sudo systemctl enable obsidian-server
sudo systemctl start obsidian-server
```

### Firewall Configuration

Open necessary ports:

```bash
# Allow HTTP
sudo ufw allow 8080

# Allow HTTPS (if using SSL)
sudo ufw allow 443

# Allow SSH
sudo ufw allow ssh
```

## 🐛 Troubleshooting

### Common Issues

**Plugin not appearing in Obsidian:**
- Restart Obsidian completely
- Check that Safe Mode is disabled
- Verify plugin files exist in `.obsidian/plugins/auto-server-sync/`

**Sync not working:**
- Test SSH connection: `ssh your-server-alias`
- Check sync logs: `tail -f ~/obsidian-sync.log`
- Verify remote directory exists and is writable

**Web interface not accessible:**
- Check server logs: `journalctl -u obsidian-server -f`
- Verify firewall rules
- Test locally: `curl http://localhost:8080`

### Debug Mode

Enable verbose logging:

```bash
# Server debug
NODE_ENV=development npm start

# Sync debug
SYNC_DEBUG=1 ./scripts/sync-obsidian.sh sync
```

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines.

### Development Setup

```bash
# Fork and clone
git clone https://github.com/yourusername/obsidian-auto-sync.git
cd obsidian-auto-sync

# Create feature branch
git checkout -b feature/amazing-feature

# Install dependencies
cd server && npm install

# Make changes and test
npm run dev

# Submit PR
```

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Obsidian](https://obsidian.md/) for creating an amazing note-taking app
- [Express.js](https://expressjs.com/) for the web framework
- [markdown-it](https://github.com/markdown-it/markdown-it) for markdown parsing
- The open-source community for inspiration and tools

## 📞 Support

- 📖 **Documentation**: Check the `docs/` folder for detailed guides
- 🐛 **Bug Reports**: Use GitHub Issues
- 💡 **Feature Requests**: Use GitHub Discussions
- 💬 **Chat**: Join our Discord community

---

<p align="center">
  <strong>⭐ If this project helps you, please consider giving it a star! ⭐</strong>
</p>

<p align="center">
  Made with ❤️ by the open-source community
</p>