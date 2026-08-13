---
name: medinix-knowledge-pipeline
category: data
description: "Handles the end-to-end knowledge extraction pipeline: JSON chat exports to local Vector Store (.npy/.json) and semantic search extraction into mediNix code. Low-RAM aware. No Chroma/SQL."
---

# medinix-knowledge-pipeline

Dieses Skill steuert die Wissens-Pipeline von großen Chat-Exporten (oder strukturierten Dumps) hin zu einem durchsuchbaren Vektor-Store und schließlich in den Code.

## 1. Trigger & Fokus
- Einlesen riesiger JSON-Dateien (z.B. >50MB Chat-Exporte).
- Extrahieren von Best-Practices ("Gold") aus dem lokalen Vektor-Store, um Module zu patchen.
- Bauen des Vektor-Stores auf einem Host mit extrem wenig RAM.

## 2. Der Build-Prozess (JSON -> Vector-Store)
**Umgebung:**
- Führe den Embed-Prozess IMMER auf dem Remote-Host aus (`root@192.168.2.250:53844`), da der Hermes-Container kein `pip`/`numpy` hat.
- Nutze das Modell `BAAI/bge-base-en-v1.5` (CPU-only).

**RAM-Aware Workflow (Kritisch):**
1. Beende temporäre RAM-Fresser (wie `vec-mcp`), wenn `< 3GB` RAM frei sind (User-Freigabe einholen!).
2. Lese das JSON gestreamt (`ijson`) in Chunks (>80 Zeichen).
3. **CRITICAL SAVE RULE:** Hänge Batches direkt an die `embeddings.npy` an. Akkumuliere Vektoren niemals im RAM! Die Speicherung (`np.save` + `json.dump`) MUSS fest ins Skript gebacken sein, niemals als manueller Post-Run-Schritt.
4. **Unified Store Schema:**
   - `embeddings.npy`: float32 `[N, 768]`
   - `chunks.json`: `[{text, source:"chat"|"github", conv, topic, ts}]`

## 3. Der Retrieval-Prozess (Vektor -> Code)
**Kritische Falle:** Der MCP-Tool `mcp__nixos_vec__search` liefert oft nur die Chunk-*Titel* (z.B. "Jellyfin Fix"), NICHT den Body. 
- Nutze MCP nur zur *Entdeckung* von Themen.
- Logge dich per SSH ein (`:53844`), um in der `chunks.json` den echten, vollen Text (`text`) zu lesen.

**Code-Patching:**
1. Suche in der DB nach *technischen* Keywords (`dev/dri`, `vaapi`, `StateDirectoryMode`), nicht nach bloßen Service-Namen.
2. Wenn du Gold findest, lies das AKTUELLE Modul lokal (z.B. `/opt/data/50-mediNix/`).
3. **Verifiziere** gefundene Systemd-Keys via `medinix-build-gate` (Context7), bevor du sie patchst!
4. Hardcode niemals Werte wie "iHD". Nutze Enum-Mappings über die Config.

## 4. (Optional) GitHub Repo Harvester
Bevor ein völlig neues Service-Modul geschrieben wird, kann (und sollte) das offizielle GitHub-Repo des Dienstes "geerntet" werden:
- Nutze GitHub MCP `search_issues` mit `repo:owner/name label:nixos`.
- Suche nach NixOS-Inkompatibilitäten (.NET EOL, Pfad-Perms).
- **Format:** Dokumentiere die Funde (Patterns, Known Issues, serviceConfig Empfehlungen) als Markdown, bevor du programmierst.
