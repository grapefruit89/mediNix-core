# Querying the unified vector store (vec-mcp) programmatically

The store (`embeddings.npy` + `chunks.json`) lives on Unraid at
`/mnt/user/data/hermes_knowledge/nixos_vectors/`. The query layer is the
`vec-mcp` Docker container (port 8000, `search(query, top_k)` tool).

## The StreamableHTTP session-id bug
A naive `initialize` → `tools/call` client fails with:
```
{'jsonrpc':'2.0','id':'server-error','error':{'code':-32600,'message':'Bad Request: Missing session ID'}}
```
FastMCP's StreamableHTTP transport expects the session id from the **response
HEADER** (`Mcp-Session-Id`), not the JSON body. You must ALSO send
`notifications/initialized` after `initialize`.

## Proven client (worked against vec-mcp, 2026-08-11)
```python
import json, urllib.request, urllib.error
MCP = "http://192.168.2.250:8000/mcp"
HEAD = {"Content-Type":"application/json",
        "Accept":"application/json, text/event-stream"}

def _post(body, sid=None):
    h = dict(HEAD)
    if sid: h["Mcp-Session-Id"] = sid
    req = urllib.request.Request(MCP, data=json.dumps(body).encode(), headers=h)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.read().decode(), r.headers.get("Mcp-Session-Id", sid)
    except urllib.error.HTTPError as e:
        return e.read().decode(), e.headers.get("Mcp-Session-Id", sid)

def _parse(raw):
    if raw.startswith("event:"):
        for line in raw.splitlines():
            if line.startswith("data:"):
                raw = line[5:].strip(); break
    return json.loads(raw)

def search(query, top_k=6):
    init_raw, sid = _post({"jsonrpc":"2.0","id":1,"method":"initialize",
        "params":{"protocolVersion":"2024-11-05","capabilities":{},
                  "clientInfo":{"name":"agent","version":"1"}}})
    _post({"jsonrpc":"2.0","method":"notifications/initialized","params":{}}, sid)
    res_raw, _ = _post({"jsonrpc":"2.0","id":2,"method":"tools/call",
        "params":{"name":"search","arguments":{"query":query,"top_k":top_k}}}, sid)
    return _parse(res_raw)["result"]["content"][0]["text"]
```

## Workflow that enriched 520/530 this session
1. SCP this client to Tower, run it with layer-specific queries
   (e.g. "nftables firewall hardening SSH", "sqlite WAL pragmas performance
   SSD tiering").
2. Write results to `EXTRACT_520_530.md` in the vectors dir as evidence.
3. Grep the returned chunks for gaps vs current modules; fill gaps as ADR-backed
   modules (e.g. BPF sysctl in 524, SQLite-WAL module 536).
4. Do NOT create per-service modules the registry+factory already generate.
