#!/usr/bin/env python3
"""
PixelLab MCP Client & Tool Discovery Utility for SpaceToby.
Reads PIXELLAB_API_KEY and PIXELLAB_MCP_URL from environment (.env),
never hardcoding credentials.
"""
import os
import sys
import json
import urllib.request
import urllib.error


def load_env(env_path=".env"):
    if os.path.exists(env_path):
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                v = v.strip().strip('"').strip("'")
                if k not in os.environ:
                    os.environ[k] = v


class PixelLabMCPClient:
    def __init__(self):
        load_env()
        self.url = os.environ.get("PIXELLAB_MCP_URL", "https://api.pixellab.ai/mcp")
        self.api_key = os.environ.get("PIXELLAB_API_KEY", "")
        if not self.api_key:
            raise RuntimeError("PIXELLAB_API_KEY is not set in environment or .env")
        self.session_id = None
        self.req_id = 0

    def _post(self, payload):
        self.req_id += 1
        data = json.dumps(payload).encode("utf-8")
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "User-Agent": "SpaceToby-MCP-Client/1.0",
        }
        if self.session_id:
            headers["Mcp-Session-Id"] = self.session_id

        req = urllib.request.Request(self.url, data=data, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                sid = resp.headers.get("Mcp-Session-Id") or resp.headers.get("mcp-session-id")
                if sid:
                    self.session_id = sid
                raw = resp.read().decode("utf-8", errors="replace")
                content_type = resp.headers.get("Content-Type", "")
                if "text/event-stream" in content_type or raw.startswith("event:") or "data:" in raw:
                    messages = []
                    for line in raw.splitlines():
                        if line.startswith("data:"):
                            d = line[len("data:"):].strip()
                            if d:
                                try:
                                    messages.append(json.loads(d))
                                except Exception:
                                    pass
                    return messages[-1] if messages else {"raw": raw}
                return json.loads(raw) if raw.strip() else {}
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8", errors="replace")
            return {"error": f"HTTP {e.code}: {err_body}"}

    def initialize(self):
        res = self._post({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2025-03-26",
                "capabilities": {},
                "clientInfo": {"name": "spacetoby-agent", "version": "1.0.0"}
            }
        })
        return res

    def list_tools(self):
        return self._post({
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list",
            "params": {}
        })

    def call_tool(self, name, arguments):
        return self._post({
            "jsonrpc": "2.0",
            "id": self.req_id + 1,
            "method": "tools/call",
            "params": {
                "name": name,
                "arguments": arguments
            }
        })


if __name__ == "__main__":
    client = PixelLabMCPClient()
    cmd = sys.argv[1] if len(sys.argv) > 1 else "discover"
    init_res = client.initialize()
    if cmd == "discover":
        tools_res = client.list_tools()
        tools = tools_res.get("result", {}).get("tools", [])
        print(f"Connected to PixelLab MCP! Session: {client.session_id}, Tools count: {len(tools)}")
        for t in tools:
            print(f"- {t.get('name')}: {t.get('description', '')[:120]}")
            schema = t.get("inputSchema", {}).get("properties", {})
            print(f"    params: {list(schema.keys())}")
    elif cmd == "call":
        tool_name = sys.argv[2]
        tool_args = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        res = client.call_tool(tool_name, tool_args)
        print(json.dumps(res, indent=2))
