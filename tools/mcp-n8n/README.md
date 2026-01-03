# n8n MCP server

This MCP server exposes a small set of tools that wrap the n8n REST API.

## Install

From the repo root:

```bash
cd tools/mcp-n8n && npm install
```

## Configure credentials

Set environment variables (do **not** commit secrets to git):

- `N8N_API_KEY` (required)
- `N8N_BASE_URL` (optional; defaults to `http://192.168.1.66:5678`)

If you put n8n behind Cloudflare Access and want the MCP server to call the external URL, also set:

- `CF_ACCESS_CLIENT_ID`
- `CF_ACCESS_CLIENT_SECRET`

## VS Code MCP config

The repo includes a server entry in [`.vscode/mcp.json`](.vscode/mcp.json:1) that runs:

- `node tools/mcp-n8n/index.js`

It sets `N8N_BASE_URL` to `http://192.168.1.66:5678` by default.
