#!/usr/bin/env python3
"""
Filtert die 6 großen DeepSeek-Chats (> 150 Msgs) und generiert 25-Msg Chunks.
"""

from pathlib import Path
import json
import os
import shutil

INPUT_DIR = Path("/home/moritz/repos/mediNix-core/todo/_input")
FILTERED_DIR = INPUT_DIR / "_filtered"
CHUNKS_DIR = INPUT_DIR / "_chunks_v3"
CHUNKS_SYMLINK = Path("/home/moritz/repos/mediNix-core/todo/_chunks_v3")

LARGE_CHATS = [
    "DeepSeek_NixOS-Homelab-Conceptual-Audit_20261025-2334.json",
    "DeepSeek_NixOS-Configuration-Critical-Analysis_20261025-2329.json",
    "DeepSeek_Low-hanging-fruits-für-NixOS-Projekt_20261025-2332.json",
    "DeepSeek_Meinung-zu-NixOS-Implementierungsplan_20261025-2334.json",
    "DeepSeek_NixHome-Architektur-Audit-kritische-Fehler_20261025-2329.json",
    "DeepSeek_NixOS-Security-Audit-Report_20261025-2330.json"
]

# Zielordner anlegen
FILTERED_DIR.mkdir(parents=True, exist_ok=True)
CHUNKS_DIR.mkdir(parents=True, exist_ok=True)
if not CHUNKS_SYMLINK.exists():
    try:
        CHUNKS_SYMLINK.symlink_to("_input/_chunks_v3")
    except Exception:
        pass

# ==============================================================================
# Schritt 1: Text-only-Filter auf alle 6 großen Chats anwenden
# ==============================================================================
results = []

for fname in LARGE_CHATS:
    src_file = INPUT_DIR / fname
    dst_file = FILTERED_DIR / fname
    
    with open(src_file, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    orig_msgs = len(data)
    orig_size = src_file.stat().st_size
    
    filtered_data = []
    user_prompts_truncated = 0
    thinking_removed = 0
    sources_removed = 0
    
    for msg in data:
        new_msg = dict(msg)
        role = msg.get("role", "")
        new_contents = []
        
        contents = msg.get("contents", [])
        if isinstance(contents, list):
            for c in contents:
                if not isinstance(c, dict):
                    new_contents.append(c)
                    continue
                ctype = c.get("type")
                if ctype == "thinking":
                    thinking_removed += 1
                    continue
                elif ctype == "sources":
                    sources_removed += 1
                    continue
                elif ctype == "text":
                    text = c.get("content", "")
                    if role == "user" and len(text) > 5000:
                        user_prompts_truncated += 1
                        cut_len = len(text) - 1000
                        truncated_text = f"{text[:500]}\n[... {cut_len} Zeichen gekürzt ...]\n{text[-500:]}"
                        new_contents.append({"type": "text", "content": truncated_text})
                    else:
                        new_contents.append({"type": "text", "content": text})
                else:
                    new_contents.append(c)
        else:
            # Fallback wenn contents kein Array ist
            new_contents = contents
            
        new_msg["contents"] = new_contents
        filtered_data.append(new_msg)
    
    # In _filtered schreiben
    with open(dst_file, "w", encoding="utf-8") as f:
        json.dump(filtered_data, f, indent=2, ensure_ascii=False)
        f.write("\n")
        
    filt_size = dst_file.stat().st_size
    reduction = (1 - filt_size / orig_size) * 100
    
    # ==============================================================================
    # Schritt 3: Neue Chunks (25 Msgs) aus _filtered/
    # ==============================================================================
    chat_chunk_dir = CHUNKS_DIR / Path(fname).stem
    chat_chunk_dir.mkdir(parents=True, exist_ok=True)
    
    chunks_created = []
    chunk_idx = 0
    for i in range(0, len(filtered_data), 25):
        chunk_slice = filtered_data[i:i+25]
        chunk_file = chat_chunk_dir / f"chunk-{chunk_idx:02d}.json"
        with open(chunk_file, "w", encoding="utf-8") as f:
            json.dump(chunk_slice, f, indent=2, ensure_ascii=False)
            f.write("\n")
        chunks_created.append((chunk_file.name, chunk_file.stat().st_size))
        chunk_idx += 1
        
    max_chunk_size = max(c[1] for c in chunks_created) if chunks_created else 0
    
    results.append({
        "fname": fname,
        "msgs": orig_msgs,
        "orig_size": orig_size,
        "filt_size": filt_size,
        "reduction": reduction,
        "chunks_count": len(chunks_created),
        "max_chunk_size": max_chunk_size,
        "chunks": chunks_created
    })

print("Filterung und Chunking erfolgreich abgeschlossen.")
