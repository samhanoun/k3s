import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

function getBaseUrl() {
  const raw = process.env.N8N_BASE_URL || "http://192.168.1.66:5678";
  return raw.replace(/\/+$/, "");
}

function getHeaders() {
  const apiKey = process.env.N8N_API_KEY;
  if (!apiKey) {
    throw new Error(
      "Missing N8N_API_KEY. Generate one in n8n (Settings -> API) and export it in your VS Code environment."
    );
  }

  const headers = {
    Accept: "application/json",
    "Content-Type": "application/json",
    "X-N8N-API-KEY": apiKey
  };

  // Optional: Cloudflare Access Service Token headers
  const cfId = process.env.CF_ACCESS_CLIENT_ID;
  const cfSecret = process.env.CF_ACCESS_CLIENT_SECRET;
  if (cfId && cfSecret) {
    headers["CF-Access-Client-Id"] = cfId;
    headers["CF-Access-Client-Secret"] = cfSecret;
  }

  return headers;
}

async function n8nRequest(method, path, body) {
  const url = `${getBaseUrl()}${path}`;
  const res = await fetch(url, {
    method,
    headers: getHeaders(),
    body: body === undefined ? undefined : JSON.stringify(body)
  });

  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = { raw: text };
  }

  if (!res.ok) {
    const err = new Error(`n8n API ${method} ${path} failed: ${res.status} ${res.statusText}`);
    err.details = data;
    throw err;
  }

  return data;
}

function asText(data) {
  return {
    content: [
      {
        type: "text",
        text: typeof data === "string" ? data : JSON.stringify(data, null, 2)
      }
    ]
  };
}

const server = new McpServer({
  name: "n8n",
  version: "0.1.0"
});

server.tool(
  "n8n_health",
  "Check n8n health endpoint (/healthz).",
  {},
  async () => {
    const url = `${getBaseUrl()}/healthz`;
    const res = await fetch(url);
    const body = await res.text();
    return asText({ url, status: res.status, ok: res.ok, body });
  }
);

server.tool(
  "n8n_list_workflows",
  "List workflows via n8n REST API (/api/v1/workflows).",
  {
    active: z.boolean().optional().describe("Filter by active status (true/false).")
  },
  async ({ active }) => {
    const data = await n8nRequest("GET", "/api/v1/workflows", undefined);
    if (active === undefined) return asText(data);
    const filtered = Array.isArray(data) ? data.filter((w) => Boolean(w?.active) === active) : data;
    return asText(filtered);
  }
);

server.tool(
  "n8n_get_workflow",
  "Get a workflow by id (/api/v1/workflows/{id}).",
  {
    id: z.union([z.number(), z.string()]).describe("Workflow id")
  },
  async ({ id }) => {
    const data = await n8nRequest("GET", `/api/v1/workflows/${id}`, undefined);
    return asText(data);
  }
);

server.tool(
  "n8n_activate_workflow",
  "Activate a workflow (/api/v1/workflows/{id}/activate).",
  {
    id: z.union([z.number(), z.string()]).describe("Workflow id")
  },
  async ({ id }) => {
    const data = await n8nRequest("POST", `/api/v1/workflows/${id}/activate`, undefined);
    return asText(data);
  }
);

server.tool(
  "n8n_deactivate_workflow",
  "Deactivate a workflow (/api/v1/workflows/{id}/deactivate).",
  {
    id: z.union([z.number(), z.string()]).describe("Workflow id")
  },
  async ({ id }) => {
    const data = await n8nRequest("POST", `/api/v1/workflows/${id}/deactivate`, undefined);
    return asText(data);
  }
);

server.tool(
  "n8n_list_executions",
  "List executions (/api/v1/executions).",
  {
    workflowId: z.union([z.number(), z.string()]).optional().describe("Filter executions by workflow id"),
    limit: z.number().int().min(1).max(250).optional().describe("Limit results (1-250)")
  },
  async ({ workflowId, limit }) => {
    const params = new URLSearchParams();
    if (workflowId !== undefined) params.set("workflowId", String(workflowId));
    if (limit !== undefined) params.set("limit", String(limit));
    const qs = params.toString();
    const path = qs ? `/api/v1/executions?${qs}` : "/api/v1/executions";
    const data = await n8nRequest("GET", path, undefined);
    return asText(data);
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
