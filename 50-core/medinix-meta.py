import sys
import json
import sqlite3
import os
import re
import argparse
import logging
import glob
from pathlib import Path

# --- GLOBAL SETTINGS ---
SCRIPT_DIR = Path(__file__).parent
DB_PATH = SCRIPT_DIR / "second-brain.sqlite"
LOG_FILE = SCRIPT_DIR / "mcp_server.log"

# --- LOGGING SETUP ---
def setup_logger(is_mcp=False):
    logger = logging.getLogger("medinix-meta")
    logger.setLevel(logging.INFO)
    logger.handlers = []
    
    # Always log to file
    file_handler = logging.FileHandler(LOG_FILE)
    file_handler.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(message)s"))
    logger.addHandler(file_handler)
    
    # If MCP, print to stderr. If CLI, print to stdout.
    stream_handler = logging.StreamHandler(sys.stderr if is_mcp else sys.stdout)
    stream_handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(stream_handler)
    
    return logger

logger = logging.getLogger("medinix-meta")

# --- UTILS ---
def parse_yaml_array(val):
    if not val: return []
    val = str(val).strip()
    if val.startswith('[') and val.endswith(']'):
        return re.findall(r'"([^"]+)"', val)
    return []

def get_nix_files(repo_root):
    # Returns all .nix files excluding some directories
    files = []
    for root, _, filenames in os.walk(repo_root):
        if '.gemini' in root or '.git' in root or 'second-brain' in root:
            continue
        for f in filenames:
            if f.endswith('.nix') and f not in ['default.nix', 'flake.nix']:
                files.append(Path(root) / f)
    return files

def extract_metadata(file_path):
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        return None, None
        
    match = re.search(r'^(?:#\s*)?---\s*\n(.*?)\n(?:#\s*)?---\s*\n', content, re.MULTILINE | re.DOTALL)
    if not match:
        return None, content
        
    header = match.group(1)
    metadata = {}
    for line in header.split('\n'):
        line = line.lstrip('#').strip()
        if ':' in line and not line.startswith(' '):
            k, v = line.split(':', 1)
            metadata[k.strip()] = v.strip().strip('"').strip("'")
            
    return metadata, content

# --- CLI: BUILD BRAIN ---
def build_brain():
    logger.info(f"Building Second Brain SQLite DB at {DB_PATH}")
    if DB_PATH.exists():
        DB_PATH.unlink()
        
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    
    cur.execute('''CREATE TABLE modules (id TEXT PRIMARY KEY, file_path TEXT, title TEXT, domain TEXT, folder TEXT, status TEXT, raw_metadata TEXT)''')
    cur.execute('''CREATE TABLE edges (source_id TEXT, target_id TEXT, relation_type TEXT, FOREIGN KEY(source_id) REFERENCES modules(id))''')
    cur.execute('''CREATE VIRTUAL TABLE fts_index USING fts5(id UNINDEXED, title, content)''')
    
    repo_root = SCRIPT_DIR.parent
    files = get_nix_files(repo_root)
    # Also add markdown files
    for root, _, filenames in os.walk(repo_root):
        if '.git' in root or '.gemini' in root: continue
        for f in filenames:
            if f.endswith('.md'): files.append(Path(root) / f)
            
    for file_path in files:
        meta, content = extract_metadata(file_path)
        if not meta: continue
        
        mod_id = meta.get("id", file_path.stem)
        title = meta.get("title", mod_id)
        
        cur.execute('INSERT OR REPLACE INTO modules (id, file_path, title, domain, folder, status, raw_metadata) VALUES (?, ?, ?, ?, ?, ?, ?)',
                    (mod_id, str(file_path.relative_to(repo_root)), title, meta.get("domain", ""), meta.get("folder", ""), meta.get("status", "unknown"), json.dumps(meta)))
        
        cur.execute('INSERT INTO fts_index (id, title, content) VALUES (?, ?, ?)', (mod_id, title, content))
        
        for req in parse_yaml_array(meta.get("requires", "")):
            cur.execute('INSERT INTO edges (source_id, target_id, relation_type) VALUES (?, ?, ?)', (mod_id, req, "requires"))
        for prov in parse_yaml_array(meta.get("provides", "")):
            cur.execute('INSERT INTO edges (source_id, target_id, relation_type) VALUES (?, ?, ?)', (mod_id, prov, "provides"))
            
    conn.commit()
    conn.close()
    logger.info("Second Brain erfolgreich gebaut!")

# --- CLI: CHECK & GRAPH ---
def check_metadata():
    logger.info("Starte Metadaten- & Graph-Check...")
    repo_root = SCRIPT_DIR.parent
    files = get_nix_files(repo_root)
    
    errors = 0
    all_provides = set()
    all_requires = [] # list of tuples: (module_id, req_name, file_path)
    
    for file_path in files:
        meta, _ = extract_metadata(file_path)
        if not meta:
            logger.warning(f"[FEHLT] Kein Header in {file_path.relative_to(repo_root)}")
            errors += 1
            continue
            
        basename = file_path.stem
        mod_id = meta.get("id", "")
        
        # Check ID
        if mod_id != basename and not mod_id.endswith("-default"):
            logger.error(f"[ID-MISMATCH] {file_path.relative_to(repo_root)}: Dateiname ist '{basename}', aber ID ist '{mod_id}'")
            errors += 1
            
        # Collect graph info
        mod_provides = parse_yaml_array(meta.get("provides", ""))
        for p in mod_provides: all_provides.add(p)
        
        mod_requires = parse_yaml_array(meta.get("requires", ""))
        for r in mod_requires: all_requires.append((mod_id, r, file_path))
        
        # Core modules act as implicit providers for certain things
        all_provides.add(mod_id)
        
    # Analyze Graph
    logger.info("Validiere Dependency-Graphen...")
    for mod_id, req, file_path in all_requires:
        if req not in all_provides and not req.startswith("options."):
            logger.error(f"[GRAPH-DEADLINK] {file_path.relative_to(repo_root)} benötigt '{req}', aber niemand bietet es an (provides)!")
            errors += 1

    if errors > 0:
        logger.error(f"\n[X] {errors} Fehler gefunden. Build sollte abbrechen!")
        sys.exit(1)
    else:
        logger.info("\n[OK] Alle Metadaten und Graphen sind konsistent!")

# --- CLI: REPAIR ---
def repair_metadata():
    logger.info("Starte sanfte Reparatur (nur YAML-Einrckungen)...")
    repo_root = SCRIPT_DIR.parent
    files = get_nix_files(repo_root)
    
    fixed = 0
    for file_path in files:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
            
        match = re.search(r'^(?:#\s*)?---\s*\n(.*?)\n(?:#\s*)?---\s*\n', content, re.MULTILINE | re.DOTALL)
        if not match: continue
        
        header = match.group(1)
        new_header = []
        needs_fix = False
        
        for line in header.split('\n'):
            if line.strip() == "":
                new_header.append("#")
                needs_fix = True
            elif not line.startswith('# '):
                clean = line.lstrip('#').strip()
                new_header.append(f"# {clean}")
                needs_fix = True
            else:
                new_header.append(line)
                
        if needs_fix:
            new_block = "# ---\n" + "\n".join(new_header) + "\n# ---\n"
            new_content = content[:match.start()] + new_block + content[match.end():]
            with open(file_path, "w", encoding="utf-8", newline='\n') as f:
                f.write(new_content)
            logger.info(f"Repariert: {file_path.relative_to(repo_root)}")
            fixed += 1
            
    logger.info(f"Reparatur abgeschlossen. {fixed} Dateien angepasst.")


# --- CLI: SYNC DEPS ---
def sync_deps():
    logger.info("Starte automatischen Dependency-Sync (requires: [...])...")
    repo_root = SCRIPT_DIR.parent
    files = get_nix_files(repo_root)
    synced = 0
    
    for file_path in files:
        with open(file_path, "r", encoding="utf-8") as f:
            code = f.read()
            
        imports = re.findall(r'import\s+[^a-zA-Z0-9]*lib/([a-zA-Z0-9_-]+)\.nix', code)
        reqs = list(set([f"lib/{imp}" for imp in imports]))
        
        match = re.search(r'^(?:#\\s*)?---\\s*\n(.*?)\n(?:#\\s*)?---\\s*\n', code, re.MULTILINE | re.DOTALL)
        if not match: continue
        
        header = match.group(1)
        new_header_lines = []
        requires_found = False
        req_str = '["' + '", "'.join(reqs) + '"]' if reqs else '[]'
        
        for line in header.split('\n'):
            if line.lstrip('#').strip().startswith('requires:'):
                new_header_lines.append(f"# requires: {req_str}")
                requires_found = True
            else:
                new_header_lines.append(line)
                
        if not requires_found:
            new_header_lines.append(f"# requires: {req_str}")
            
        new_block = "# ---\n" + "\n".join(new_header_lines) + "\n# ---\n"
        new_content = code[:match.start()] + new_block + code[match.end():]
        
        if code != new_content:
            with open(file_path, "w", encoding="utf-8", newline='\n') as f:
                f.write(new_content)
            synced += 1
            
    logger.info(f"Sync abgeschlossen! {synced} YAML Header wurden korrigiert.")


# --- CLI: GENERATE DOCS (AGENTS.md) ---
def generate_docs(check_only=False):
    if check_only:
        logger.info("Pruefe LLM-Wikis (AGENTS.md) auf Aktualitaet (--check)...")
    else:
        logger.info("Generiere LLM-Wiki (AGENTS.md) fuer alle Ordner...")
        
    repo_root = SCRIPT_DIR.parent
    
    folders = {}
    files = get_nix_files(repo_root)
    for file_path in files:
        rel_path = file_path.relative_to(repo_root)
        folder = rel_path.parent
        if str(folder) == ".": continue
        if str(folder) not in folders:
            folders[str(folder)] = []
        
        meta, _ = extract_metadata(file_path)
        if meta:
            folders[str(folder)].append((file_path.name, meta))
            
    docs_created = 0
    errors = 0
    
    for folder_name, modules in folders.items():
        if not re.match(r'^[0-9]{2}-', str(folder_name)):
            continue
            
        agent_md_path = repo_root / folder_name / "AGENTS.md"
        modules.sort(key=lambda x: x[1].get("id", ""))
        
        # Read existing manual content if available
        manual_content = f"# LLM Wiki: `{folder_name}`\n\n> **Zweck:** [BITTE MANUELL AUSFUELLEN: Wofuer ist dieser Ordner zustaendig?]\n\n"
        if agent_md_path.exists():
            with open(agent_md_path, "r", encoding="utf-8") as f:
                existing = f.read()
                if "<!-- AUTO-GENERATED, DO NOT EDIT BELOW -->" in existing:
                    manual_content = existing.split("<!-- AUTO-GENERATED, DO NOT EDIT BELOW -->")[0]
        
        lines = []
        lines.append(manual_content.rstrip())
        lines.append("\n\n<!-- AUTO-GENERATED, DO NOT EDIT BELOW -->\n")
        lines.append("## Module Map\n")
        lines.append("| ID | Modul-Datei | Status | Komplexitaet | Ports |")
        lines.append("|---|---|---|---|---|")
        
        for filename, meta in modules:
            mod_id = meta.get("id", filename)
            status = meta.get("status", "unknown")
            complexity = meta.get("complexity", "-")
            ports_raw = meta.get("ports", "[]")
            ports = ", ".join(parse_yaml_array(ports_raw)) if ports_raw != "[]" else "-"
            lines.append(f"| `{mod_id}` | `{filename}` | {status} | {complexity}/5 | {ports} |")
            
        lines.append("\n## Interne Abhaengigkeiten (Requires)\n")
        lines.append("Die Module in diesem Ordner benoetigen folgende Bibliotheken/Dateien:\n")
        
        all_reqs = set()
        for _, meta in modules:
            reqs = parse_yaml_array(meta.get("requires", "[]"))
            for r in reqs: all_reqs.add(r)
            
        for req in sorted(all_reqs):
            lines.append(f"- `{req}`")
            
        lines.append("\n---\n*Generiert durch `medinix-meta.py generate-docs`*")
        
        new_text = "\n".join(lines) + "\n"
        
        if check_only:
            if not agent_md_path.exists():
                logger.error(f"Fehlende AGENTS.md in {folder_name}")
                errors += 1
            else:
                with open(agent_md_path, "r", encoding="utf-8") as f:
                    current = f.read()
                if current != new_text:
                    logger.error(f"Stale AGENTS.md in {folder_name}. Bitte 'python medinix-meta.py generate-docs' ausfuehren.")
                    errors += 1
        else:
            with open(agent_md_path, "w", encoding="utf-8", newline='\n') as f:
                f.write(new_text)
            docs_created += 1
            
    if check_only:
        if errors > 0:
            logger.error("Doc-Check fehlgeschlagen!")
            import sys
            sys.exit(1)
        else:
            logger.info("Alle AGENTS.md sind up to date!")
    else:
        logger.info(f"Erfolgreich {docs_created} AGENTS.md Dateien generiert!")

# --- MCP SERVER (JSON-RPC) ---
def mcp_server():
    global logger
    logger = setup_logger(is_mcp=True)
    logger.info("Starte MCP Second Brain Server (Universal Mode)...")
    
    if not DB_PATH.exists():
        logger.info("Datenbank fehlt. Führe automatischen Build aus...")
        build_brain()
        
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
            "description": "Zeigt den Dependency Graph für ein Modul.",
            "inputSchema": {
                "type": "object",
                "properties": {"module_id": {"type": "string", "description": "Die Modul ID (z.B. '511-caddy')"}},
                "required": ["module_id"]
            }
        },
        {
            "name": "get_metadata",
            "description": "Liest den YAML-Metadaten-Header eines Moduls aus.",
            "inputSchema": {
                "type": "object",
                "properties": {"module_id": {"type": "string", "description": "Die Modul ID (z.B. '511-caddy')"}},
                "required": ["module_id"]
            }
        },
        {
            "name": "check_metadata",
            "description": "Löst den globalen Check-Lauf aus, der verwaiste Abhängigkeiten und ID-Fehler sucht.",
            "inputSchema": {
                "type": "object",
                "properties": {},
                "required": []
            }
        }
    ]

    def send_response(response_dict):
        out = json.dumps(response_dict)
        sys.stdout.write(out + "\n")
        sys.stdout.flush()

    while True:
        try:
            line = sys.stdin.readline()
            if not line: break
                
            req = json.loads(line)
            req_id = req.get("id")
            method = req.get("method")
            
            if method == "initialize":
                send_response({
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "medinix-meta-brain", "version": "2.0.0"}
                    }
                })
            elif method == "notifications/initialized":
                pass
            elif method == "tools/list":
                send_response({"jsonrpc": "2.0", "id": req_id, "result": {"tools": TOOLS_DEF}})
            elif method == "tools/call":
                params = req.get("params", {})
                name = params.get("name")
                args = params.get("arguments", {})
                
                result_text = ""
                try:
                    conn = sqlite3.connect(DB_PATH)
                    cur = conn.cursor()
                    
                    if name == "search_graph":
                        cur.execute("SELECT id, title FROM fts_index WHERE fts_index MATCH ? LIMIT 10", (args.get("query", ""),))
                        result_text = json.dumps([{"id": r[0], "title": r[1]} for r in cur.fetchall()], indent=2)
                    elif name == "get_dependencies":
                        mod_id = args.get("module_id", "")
                        cur.execute("SELECT source_id, relation_type FROM edges WHERE target_id = ?", (mod_id,))
                        req_by = [{"module": r[0], "rel": r[1]} for r in cur.fetchall()]
                        cur.execute("SELECT target_id, relation_type FROM edges WHERE source_id = ?", (mod_id,))
                        reqs = [{"module": r[0], "rel": r[1]} for r in cur.fetchall()]
                        result_text = json.dumps({"is_required_by": req_by, "requires": reqs}, indent=2)
                    elif name == "get_metadata":
                        cur.execute("SELECT raw_metadata FROM modules WHERE id = ?", (args.get("module_id", ""),))
                        row = cur.fetchone()
                        result_text = row[0] if row else "Not found"
                    elif name == "check_metadata":
                        result_text = "Check muss lokal über die CLI aufgerufen werden, da er sys.exit wirft. Bitte `python medinix-meta.py check` nutzen."
                    else:
                        result_text = f"Unknown tool: {name}"
                    conn.close()
                except Exception as e:
                    result_text = f"Error: {e}"
                    
                send_response({"jsonrpc": "2.0", "id": req_id, "result": {"content": [{"type": "text", "text": result_text}]}})
        except Exception as e:
            logger.error(f"MCP Fehler: {e}")

# --- MAIN DISPATCHER ---
def main():
    parser = argparse.ArgumentParser(description="mediNix Meta-Tool & MCP Server")
    parser.add_argument("command", nargs="?", default="mcp", choices=["mcp", "build-brain", "check", "repair", "graph", "sync-deps", "generate-docs", "check-docs"], help="Befehl zum Ausfhren")
    args = parser.parse_args()
    
    if args.command == "mcp":
        mcp_server()
    else:
        global logger
        logger = setup_logger(is_mcp=False)
        if args.command == "build-brain":
            build_brain()
        elif args.command in ["check", "graph"]:
            check_metadata()
        elif args.command == "repair":
            repair_metadata()
        elif args.command == "sync-deps":
            sync_deps()
        elif args.command == "generate-docs":
            generate_docs()
        elif args.command == "check-docs":
            generate_docs(check_only=True)

if __name__ == "__main__":
    main()
