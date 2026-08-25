import sys
import json
import sqlite3
import os
import subprocess
import logging
from pathlib import Path

# --- 1. SETUP LOGGING (stderr + File) ---
log_file = Path(__file__).parent / "mcp_server.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler(sys.stderr)
    ]
)
logger = logging.getLogger("mcp")

# --- 2. AUTO-BUILD DATABASE ---
DB_PATH = Path(__file__).parent / "second-brain.sqlite"
BUILD_SCRIPT = Path(__file__).parent / "build_brain.py"

if not DB_PATH.exists():
    logger.info(f"Datenbank {DB_PATH} fehlt. Führe build_brain.py aus...")
    try:
        # Führe build_brain.py im Kontext des Repo-Roots aus
        repo_root = Path(__file__).parent.parent.parent
        subprocess.run([sys.executable, str(BUILD_SCRIPT)], cwd=str(repo_root), check=True)
        logger.info("Datenbank erfolgreich generiert.")
    except Exception as e:
        logger.error(f"Fehler beim Erstellen der Datenbank: {e}")
        sys.exit(1)

# --- 3. TOOLS LOGIC ---
def search_graph(query):
    logger.info(f"Tool 'search_graph' aufgerufen mit query: {query}")
    try:
        conn = sqlite3.connect(DB_PATH)
        cur = conn.cursor()
        # Verwende MATCH für FTS5
        cur.execute("SELECT id, title FROM fts_index WHERE fts_index MATCH ? LIMIT 10", (query,))
        results = [{"module_id": row[0], "title": row[1]} for row in cur.fetchall()]
        conn.close()
        return json.dumps({"status": "success", "matches": results}, indent=2)
    except Exception as e:
        logger.error(f"SQL Fehler in search_graph: {e}")
        return json.dumps({"error": str(e)})

def get_dependencies(module_id):
    logger.info(f"Tool 'get_dependencies' aufgerufen für: {module_id}")
    try:
        conn = sqlite3.connect(DB_PATH)
        cur = conn.cursor()
        
        cur.execute("SELECT source_id, relation_type FROM edges WHERE target_id = ?", (module_id,))
        required_by = [{"module": row[0], "relation": row[1]} for row in cur.fetchall()]
        
        cur.execute("SELECT target_id, relation_type FROM edges WHERE source_id = ?", (module_id,))
        requires = [{"module": row[0], "relation": row[1]} for row in cur.fetchall()]
        
        conn.close()
        return json.dumps({
            "status": "success", 
            "module": module_id,
            "is_required_by": required_by,
            "requires": requires
        }, indent=2)
    except Exception as e:
        logger.error(f"SQL Fehler in get_dependencies: {e}")
        return json.dumps({"error": str(e)})

def get_metadata(module_id):
    logger.info(f"Tool 'get_metadata' aufgerufen für: {module_id}")
    try:
        conn = sqlite3.connect(DB_PATH)
        cur = conn.cursor()
        cur.execute("SELECT raw_metadata, file_path FROM modules WHERE id = ?", (module_id,))
        row = cur.fetchone()
        conn.close()
        if row:
            return json.dumps({"status": "success", "file_path": row[1], "metadata": json.loads(row[0])}, indent=2)
        return json.dumps({"error": "Module not found"})
    except Exception as e:
        logger.error(f"SQL Fehler in get_metadata: {e}")
        return json.dumps({"error": str(e)})


# --- 4. JSON-RPC (MCP) DISPATCHER ---
TOOLS_DEF = [
    {
        "name": "search_graph",
        "description": "Durchsucht den gesamten Code und die Dokumentation mittels FTS5 nach einem Stichwort (z.B. 'Killswitch' oder 'Caddy').",
        "inputSchema": {
            "type": "object",
            "properties": {"query": {"type": "string", "description": "Der Suchbegriff"}},
            "required": ["query"]
        }
    },
    {
        "name": "get_dependencies",
        "description": "Zeigt, wovon ein Modul abhängt, und welche anderen Module von diesem Modul abhängen (Der Dependency Graph).",
        "inputSchema": {
            "type": "object",
            "properties": {"module_id": {"type": "string", "description": "Die Modul ID (z.B. '511-caddy')"}},
            "required": ["module_id"]
        }
    },
    {
        "name": "get_metadata",
        "description": "Liest den YAML-Metadaten-Header eines Moduls aus (inklusive Context7-Abfragen und Domain-Zugehörigkeit).",
        "inputSchema": {
            "type": "object",
            "properties": {"module_id": {"type": "string", "description": "Die Modul ID (z.B. '511-caddy')"}},
            "required": ["module_id"]
        }
    }
]

def send_response(response_dict):
    out = json.dumps(response_dict)
    sys.stdout.write(out + "\n")
    sys.stdout.flush()

def main():
    logger.info("Starte MCP Second Brain Server (Pure Python)...")
    
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break
                
            req = json.loads(line)
            req_id = req.get("id")
            method = req.get("method")
            
            if method == "initialize":
                logger.info("Empfange 'initialize' Handshake")
                send_response({
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "medinix-brain", "version": "1.0.0"}
                    }
                })
            elif method == "notifications/initialized":
                # client signals readiness, no response needed
                pass
            elif method == "tools/list":
                logger.info("Empfange 'tools/list'")
                send_response({
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {"tools": TOOLS_DEF}
                })
            elif method == "tools/call":
                params = req.get("params", {})
                name = params.get("name")
                args = params.get("arguments", {})
                logger.info(f"Empfange 'tools/call' für Tool: {name}")
                
                result_text = ""
                if name == "search_graph":
                    result_text = search_graph(args.get("query", ""))
                elif name == "get_dependencies":
                    result_text = get_dependencies(args.get("module_id", ""))
                elif name == "get_metadata":
                    result_text = get_metadata(args.get("module_id", ""))
                else:
                    result_text = json.dumps({"error": f"Unknown tool: {name}"})
                
                send_response({
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "content": [{"type": "text", "text": result_text}]
                    }
                })
            else:
                logger.warning(f"Unbekannte Methode: {method}")
                # Optional: return error
                
        except Exception as e:
            logger.error(f"Fehler in der Main-Loop: {e}")

if __name__ == "__main__":
    main()
