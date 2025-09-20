const express = require("express");
const cors = require("cors");
const fs = require("fs");
const path = require("path");
const chokidar = require("chokidar");
const MarkdownIt = require("markdown-it");

const app = express();
const PORT = process.env.PORT || 8080;
const VAULT_PATH = process.env.VAULT_PATH || "./vault";

// Initialize markdown parser
const md = new MarkdownIt();

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

// API to list all markdown files
app.get("/api/files", (req, res) => {
    const files = [];
    
    function scanDirectory(dir, relativePath = "") {
        try {
            const items = fs.readdirSync(dir);
            items.forEach(item => {
                const fullPath = path.join(dir, item);
                const itemRelativePath = path.join(relativePath, item);
                
                if (fs.statSync(fullPath).isDirectory()) {
                    scanDirectory(fullPath, itemRelativePath);
                } else if (path.extname(item) === ".md") {
                    files.push({
                        name: item,
                        path: itemRelativePath.replace(/\\/g, "/"),
                        fullPath: fullPath
                    });
                }
            });
        } catch (error) {
            console.error("Error reading directory:", error);
        }
    }
    
    scanDirectory(VAULT_PATH);
    res.json(files);
});

// API to get file content
app.post("/api/getfile", (req, res) => {
    const { filepath } = req.body;
    if (!filepath) {
        return res.status(400).json({ error: "Filepath required" });
    }
    
    const fullPath = path.join(VAULT_PATH, filepath);
    
    try {
        const content = fs.readFileSync(fullPath, "utf8");
        const html = md.render(content);
        res.json({ content, html });
    } catch (error) {
        res.status(404).json({ error: "File not found" });
    }
});

// Serve the main app
app.get("/", (req, res) => {
    const htmlContent = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Obsidian Web Viewer</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; display: flex; height: 100vh; background: #f8f9fa; }
        .sidebar { width: 320px; background: white; border-right: 1px solid #e5e7eb; overflow-y: auto; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        .content { flex: 1; padding: 30px; overflow-y: auto; background: white; margin: 10px; border-radius: 8px; box-shadow: 0 0 10px rgba(0,0,0,0.05); }
        .file-item { padding: 12px 16px; cursor: pointer; border-bottom: 1px solid #f3f4f6; transition: background-color 0.2s; }
        .file-item:hover { background: #f9fafb; }
        .file-item.active { background: #dbeafe; border-left: 4px solid #3b82f6; }
        #file-content { max-width: 900px; line-height: 1.7; color: #374151; }
        h1, h2, h3 { margin: 1.5em 0 0.75em 0; color: #111827; }
        h1 { font-size: 2em; }
        h2 { font-size: 1.5em; }
        h3 { font-size: 1.25em; }
        p { margin-bottom: 1.2em; }
        code { background: #f3f4f6; padding: 3px 6px; border-radius: 4px; font-family: 'SF Mono', 'Monaco', 'Cascadia Code', monospace; }
        pre { background: #f8f9fa; padding: 16px; border-radius: 6px; overflow-x: auto; border: 1px solid #e5e7eb; }
        pre code { background: none; padding: 0; }
        .header { background: #1f2937; color: white; padding: 16px; text-align: center; }
        .loading { text-align: center; color: #6b7280; padding: 20px; }
        blockquote { border-left: 4px solid #e5e7eb; padding-left: 16px; margin: 1em 0; color: #6b7280; }
        ul, ol { margin-left: 1.5em; margin-bottom: 1em; }
        li { margin-bottom: 0.5em; }
        .status { padding: 8px 16px; font-size: 0.875em; color: #6b7280; border-bottom: 1px solid #e5e7eb; }
    </style>
</head>
<body>
    <div class="sidebar">
        <div class="header">
            <h3>📝 Obsidian Vault</h3>
        </div>
        <div class="status" id="status">Loading files...</div>
        <div id="file-list"></div>
    </div>
    <div class="content">
        <div id="file-content">
            <h1>🌟 Welcome to Your Obsidian Web Viewer</h1>
            <p>Your personal notes are now accessible from anywhere! Select a file from the sidebar to view its content.</p>
            <h2>Features</h2>
            <ul>
                <li><strong>🔄 Auto-sync:</strong> Your notes sync automatically when using the plugin</li>
                <li><strong>🌐 Web access:</strong> Access your notes from any device with a browser</li>
                <li><strong>📱 Responsive:</strong> Works great on desktop and mobile</li>
                <li><strong>🔍 Live preview:</strong> Markdown rendered beautifully in real-time</li>
            </ul>
            <h2>How it works</h2>
            <p>Your local vault directory is synchronized to this server. Any changes you make locally will appear here when synced.</p>
        </div>
    </div>

    <script>
        let files = [];
        let currentFile = null;

        // Fetch file list
        async function fetchFiles() {
            try {
                const response = await fetch("/api/files");
                files = await response.json();
                renderFileList();
                updateStatus(files.length + " files found");
            } catch (error) {
                console.error("Error fetching files:", error);
                document.getElementById("file-list").innerHTML = "<div class='loading'>❌ Error loading files</div>";
                updateStatus("Error loading files");
            }
        }

        // Update status
        function updateStatus(message) {
            document.getElementById("status").textContent = message;
        }

        // Render file list
        function renderFileList() {
            const fileList = document.getElementById("file-list");
            fileList.innerHTML = "";
            
            if (files.length === 0) {
                fileList.innerHTML = "<div class='loading'>📁 No markdown files found</div>";
                return;
            }
            
            files.forEach(file => {
                const div = document.createElement("div");
                div.className = "file-item";
                div.innerHTML = "<strong>" + file.name + "</strong><br><small style='color: #6b7280;'>" + file.path + "</small>";
                div.onclick = () => selectFile(file, div);
                fileList.appendChild(div);
            });
        }

        // Select and view file
        async function selectFile(file, element) {
            try {
                // Update active state
                document.querySelectorAll(".file-item").forEach(item => {
                    item.classList.remove("active");
                });
                element.classList.add("active");

                updateStatus("Loading " + file.name + "...");

                // Fetch file content
                const response = await fetch("/api/getfile", {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify({ filepath: file.path })
                });
                
                const data = await response.json();
                
                // Display content
                document.getElementById("file-content").innerHTML = data.html;
                currentFile = file;
                updateStatus("Viewing: " + file.name);
            } catch (error) {
                console.error("Error fetching file content:", error);
                document.getElementById("file-content").innerHTML = "<h1>❌ Error</h1><p>Could not load file content.</p>";
                updateStatus("Error loading file");
            }
        }

        // Initialize
        fetchFiles();
        
        // Auto refresh every 30 seconds
        setInterval(() => {
            fetchFiles();
        }, 30000);
    </script>
</body>
</html>
    `;
    res.send(htmlContent);
});

app.listen(PORT, "0.0.0.0", () => {
    console.log("Obsidian web server running on port " + PORT);
    console.log("Serving vault from: " + VAULT_PATH);
    console.log("Access the web interface at: http://localhost:" + PORT);
});