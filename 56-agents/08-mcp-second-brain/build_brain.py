import sqlite3
import glob
import re
import json
import os
from pathlib import Path

DB_PATH = "second-brain.sqlite"

def init_db():
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    
    # 1. Modules Table
    cur.execute('''
        CREATE TABLE modules (
            id TEXT PRIMARY KEY,
            file_path TEXT,
            title TEXT,
            domain TEXT,
            folder TEXT,
            status TEXT,
            raw_metadata TEXT
        )
    ''')
    
    # 2. Dependency Graph (Edges)
    cur.execute('''
        CREATE TABLE edges (
            source_id TEXT,
            target_id TEXT,
            relation_type TEXT,
            FOREIGN KEY(source_id) REFERENCES modules(id)
        )
    ''')
    
    # 3. FTS5 Index for Full Text Search
    cur.execute('''
        CREATE VIRTUAL TABLE fts_index USING fts5(
            id UNINDEXED,
            title,
            content
        )
    ''')
    
    conn.commit()
    return conn

def parse_yaml_array(val):
    # Extracts items from '["systemd.services.caddy", "lib/registry"]'
    if not val: return []
    val = val.strip()
    if val.startswith('[') and val.endswith(']'):
        # Extract quoted strings
        return re.findall(r'"([^"]+)"', val)
    return []

def main():
    conn = init_db()
    cur = conn.cursor()
    
    files = glob.glob("**/*.nix", recursive=True) + glob.glob("**/*.md", recursive=True)
    
    for file_path in files:
        if ".gemini" in file_path or "second-brain" in file_path or "build_brain" in file_path:
            continue
            
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()
        except:
            continue

        match = re.search(r'^(?:#\s*)?---\s*\n(.*?)\n(?:#\s*)?---\s*\n', content, re.MULTILINE | re.DOTALL)
        if not match:
            # Let's try the ad-hoc parsing for older markdown files
            match = re.search(r'^---\s*\n(.*?)\n---', content, re.MULTILINE | re.DOTALL)
        
        metadata = {}
        if match:
            header = match.group(1)
            for line in header.split('\n'):
                line = line.lstrip('#').strip()
                if ':' in line and not line.startswith(' '):
                    k, v = line.split(':', 1)
                    metadata[k.strip()] = v.strip().strip('"').strip("'")
        
        # Fallback to filename if no ID in metadata
        mod_id = metadata.get("id", Path(file_path).stem)
        title = metadata.get("title", mod_id)
        domain = metadata.get("domain", "")
        folder = metadata.get("folder", "")
        status = metadata.get("status", "unknown")
        
        # Insert Module
        cur.execute('''
            INSERT OR REPLACE INTO modules (id, file_path, title, domain, folder, status, raw_metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (mod_id, file_path, title, domain, folder, status, json.dumps(metadata)))
        
        # Insert FTS
        cur.execute('''
            INSERT INTO fts_index (id, title, content)
            VALUES (?, ?, ?)
        ''', (mod_id, title, content))
        
        # Insert Edges
        requires = parse_yaml_array(metadata.get("requires", ""))
        for req in requires:
            cur.execute('INSERT INTO edges (source_id, target_id, relation_type) VALUES (?, ?, ?)', (mod_id, req, "requires"))
            
        provides = parse_yaml_array(metadata.get("provides", ""))
        for prov in provides:
            cur.execute('INSERT INTO edges (source_id, target_id, relation_type) VALUES (?, ?, ?)', (mod_id, prov, "provides"))
            
    conn.commit()
    conn.close()
    print(f"Second Brain erfolgreich gebaut! (Datenbank: {DB_PATH})")

if __name__ == "__main__":
    main()
