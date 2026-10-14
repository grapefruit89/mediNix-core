#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
EXPORT_DIR="${1:-$REPO_ROOT/exports}"

# Altes Export-Verzeichnis komplett leeren / frisch anlegen
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

is_excluded() {
  local f="$1"
  case "$f" in
    *.png|*.jpg|*.jpeg|*.svg|*.ico|*.pdf|*.zip|*.tar.gz|*.drv|*.log|*.sqlite*|*.db|*.bin|*.pyc|*.pyo) return 0 ;;
    */.git/*|*/exports/*|*/.github/*|*/result*|*/.direnv/*|*/__pycache__/*) return 0 ;;
    *) return 1 ;;
  esac
}

get_lang() {
  local filename="$1"
  case "$filename" in
    *.nix) echo "nix" ;;
    *.sh) echo "bash" ;;
    *.py) echo "python" ;;
    *.yml|*.yaml) echo "yaml" ;;
    *.json) echo "json" ;;
    *.md) echo "markdown" ;;
    *.conf|*.ini) echo "ini" ;;
    *.toml) echo "toml" ;;
    *) echo "text" ;;
  esac
}

generate_raw_tree() {
  if command -v tree &> /dev/null; then
    (cd "$REPO_ROOT" && tree -I ".git|exports|result|.direnv|__pycache__" --charset utf-8)
  else
    find "$REPO_ROOT" -not -path '*/.*' -not -path '*/exports*' -not -path '*/result*' | sed "s|$REPO_ROOT|.|" | sort
  fi
}

FULL_TREE_CACHE="$(generate_raw_tree)"

# Lookup-Tabelle für den 3-Zeilen Purpose-Block pro Domäne (AI Documentation Field Guide Standard)
get_purpose_block() {
  local domain="$1"
  case "$domain" in
    "50-core")
      echo -e "> **Purpose:** Host-Baseline, Dezimal-Engine, System-Assertions.\n> **Constraint:** UID = Port = Num * 10 (ADR-0000). Assertions müssen fail-closed greifen.\n> **Dependency:** Bindet zentrale Typverträge ein." ;;
    "51-ingress")
      echo -e "> **Purpose:** Caddy Reverse Proxy, Ingress-Steuerung, Split-Horizon.\n> **Constraint:** .lan ist unverschlüsselt; WAN-Exposition nur für public/stream.\n> **Dependency:** Konsumiert direkt das Manifest." ;;
    "52-security")
      echo -e "> **Purpose:** Host-Härtung, systemd-creds (Sealed-only), VPN-Killswitch.\n> **Constraint:** Keine Klartext-Secrets; Credentials nie unter mediaRoot.\n> **Dependency:** Basiert auf lib/creds.nix." ;;
    "53-acquisition")
      echo -e "> **Purpose:** Prowlarr und Indexer-Infrastruktur.\n> **Constraint:** Ausschließlich interne LAN-Erreichbarkeit (accessGroup = internal).\n> **Dependency:** Nutzt Dezimalrahmen." ;;
    "54-transfer")
      echo -e "> **Purpose:** SABnzbd Usenet-Downloader, Confinement.\n> **Constraint:** Muss zwingend auf SSD/Cache laufen, Spindelwächter blockiert HDDs.\n> **Dependency:** Gekoppelt an VPN-Killswitch (526)." ;;
    "55-playback")
      echo -e "> **Purpose:** Jellyfin Medienserver, Audiobookshelf, Transcoding.\n> **Constraint:** Transcoding MUSS im RAM liegen (/transcode); HDD Read-Only.\n> **Dependency:** Bindet Hardware-Beschleunigung (QSV) ein." ;;
    "56-agents")
      echo -e "> **Purpose:** KI-Agenten-Prompts, Architekturen, Workflows.\n> **Constraint:** Rein dokumentarisch / deklarativ.\n> **Dependency:** Keine Laufzeit-Abhängigkeit." ;;
    "57-maintenance")
      echo -e "> **Purpose:** Backup-Skripte, Secret-Sealing Tools, Wartung.\n> **Constraint:** Backup-Preflight bricht bei Volllast/Limit-Überschreitung ab.\n> **Dependency:** Nutzt systemd-creds." ;;
    "58-observability")
      echo -e "> **Purpose:** Gatus Health-Checks, Monitoring, Alerting.\n> **Constraint:** Muss alle Manifest-Dienste fehlerfrei überwachen.\n> **Dependency:** Konsumiert Manifest-Metadaten." ;;
    "59-guardrails")
      echo -e "> **Purpose:** Cross-Domain Validierungen, Compliance, System-Wächter.\n> **Constraint:** Fängt Architekturbrüche zur Compile-Zeit ab.\n> **Dependency:** Greift auf alle Domänen zu." ;;
    "lib")
      echo -e "> **Purpose:** Geteilte SRE-Bibliotheken (Dezimal-Engine, arr-provision, creds).\n> **Constraint:** Keine applikationsspezifischen Daemons.\n> **Dependency:** Basis für alle Domänen." ;;
    "docs")
      echo -e "> **Purpose:** Architektur-Entscheidungen (ADRs), Guides, Antipatterns.\n> **Constraint:** Dokumentation folgt dem Code.\n> **Dependency:** Statische Referenz." ;;
    *)
      echo -e "> **Purpose:** Repository-Root und übergreifende Konfiguration.\n> **Constraint:** Flake-Einstiegspunkt.\n> **Dependency:** Definiert Inputs." ;;
  esac
}

dump_folder_to_ki_md() {
  local target_dir="$1"
  local target_md="$2"
  local folder_title="$3"
  local domain_key="$4"
  local include_global_tree="${5:-false}"
  local recursive="${6:-true}"

  : > "$target_md"

  # Header & Purpose Block
  echo "# LLM Ingestion Digest: $folder_title" >> "$target_md"
  echo "Generated automatically for AI context ingestion." >> "$target_md"
  echo -e "\n---" >> "$target_md"
  echo -e "\n## Purpose & Constraints" >> "$target_md"
  get_purpose_block "$domain_key" >> "$target_md"

  # 1. Globaler Repository-Baum
  if [[ "$include_global_tree" == "true" ]]; then
    echo -e "\n---" >> "$target_md"
    echo -e "\n## 0. Full Repository Structure (Context & Dependencies)\n" >> "$target_md"
    echo '```text' >> "$target_md"
    echo "$FULL_TREE_CACHE" >> "$target_md"
    echo '```' >> "$target_md"
  fi

  # 2. Lokaler Verzeichnisbaum
  echo -e "\n---" >> "$target_md"
  echo -e "\n## 1. Local Directory Tree\n" >> "$target_md"
  echo '```text' >> "$target_md"
  if command -v tree &> /dev/null; then
    if [[ "$recursive" == "false" ]]; then
      (cd "$target_dir" && tree -L 1 -I ".git|exports|result|.direnv|__pycache__" --charset utf-8) >> "$target_md" || true
    else
      (cd "$target_dir" && tree -I ".git|exports|result|.direnv|__pycache__" --charset utf-8) >> "$target_md" || true
    fi
  else
    find "$target_dir" -maxdepth 2 -not -path '*/.*' -not -path '*/exports*' | sed "s|$target_dir|.|" >> "$target_md"
  fi
  echo '```' >> "$target_md"

  # Dateien sammeln
  local find_args=("$target_dir")
  if [[ "$recursive" == "false" ]]; then
    find_args+=("-maxdepth" "1")
  fi
  find_args+=("-type" "f" "-print0")

  mapfile -d '' files < <(find "${find_args[@]}" | sort -z)
  local valid_files=()
  for file in "${files[@]}"; do
    if [[ -f "$file" ]] && ! is_excluded "$file"; then
      valid_files+=("$file")
    fi
  done

  # 3. File Inventory & Table of Contents (Plain-Text + GitHub Anchors)
  echo -e "\n---" >> "$target_md"
  echo -e "\n## 2. File Inventory" >> "$target_md"
  for file in "${valid_files[@]}"; do
    local rel_path="${file#$REPO_ROOT/}"
    local anchor
    anchor=$(echo "$rel_path" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-|-$//g')
    echo "- [$rel_path](#file-$anchor) — \`$rel_path\`" >> "$target_md"
  done

  # 4. Datei-Inhalte mit File-Metadaten im Codeblock (RAG-Resilient, 4 Backticks gegen Markdown-Clashes)
  echo -e "\n---" >> "$target_md"
  echo -e "\n## 3. File Contents\n" >> "$target_md"

  for file in "${valid_files[@]}"; do
    local rel_path="${file#$REPO_ROOT/}"
    local anchor
    anchor=$(echo "$rel_path" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-|-$//g')
    local lang
    lang=$(get_lang "$file")

    echo "<a id=\"file-$anchor\"></a>" >> "$target_md"
    echo "### File: \`$rel_path\`" >> "$target_md"
    echo "" >> "$target_md"
    echo '````'"$lang" >> "$target_md"
    echo "# File: $rel_path" >> "$target_md"
    echo "# Language: $lang" >> "$target_md"
    cat "$file" >> "$target_md"
    echo "" >> "$target_md"
    echo '````' >> "$target_md"
    echo "" >> "$target_md"
  done
}

echo "→ 1. Erstelle _index.md (Navigation Hub)..."
{
  echo "# mediNix-core — Navigation Hub"
  echo "**What is this?** Hardened NixOS media and service appliance governed by the Decimal Framework (Port = UID = ID * 10)."
  echo -e "\n---"
  echo -e "\n## Core Domains\n"
  echo "- \`50-core\` — Host-Baseline, Decimal-Engine, Assertions"
  echo "- \`51-ingress\` — Caddy Reverse Proxy, Split-Horizon"
  echo "- \`52-security\` — Credentials, VPN-Killswitch"
  echo "- \`53-acquisition\` — Prowlarr Indexer"
  echo "- \`54-transfer\` — SABnzbd Downloader, Spindel-Wächter"
  echo "- \`55-playback\` — Jellyfin, Audiobookshelf, RAM-Transcode"
  echo "- \`56-agents\` — KI-Agenten-Prompts & Architekturen"
  echo "- \`57-maintenance\` — Backups, Secret Sealing"
  echo "- \`58-observability\` — Gatus Health Checks"
  echo "- \`59-guardrails\` — Compliance & Cross-Domain Checks"
  echo "- \`lib\` — Core Libraries & arr-provision Python Suite"
  echo "- \`docs\` — Architectural Decision Records (ADRs) & Guides"
  echo -e "\n---"
  echo -e "\n## Full Repository Structure\n"
  echo '```text'
  echo "$FULL_TREE_CACHE"
  echo '```'
} > "$EXPORT_DIR/_index.md"

echo "→ 2. Erstelle _root.md..."
dump_folder_to_ki_md "$REPO_ROOT" "$EXPORT_DIR/_root.md" "Repository Root" "root" "false" "false"

echo "→ 3. Erstelle KI-Markdown für alle Domänenordner..."
for dir in "$REPO_ROOT"/5[0-9]-* "$REPO_ROOT/lib" "$REPO_ROOT/docs"; do
  if [[ -d "$dir" ]]; then
    domain_name=$(basename "$dir")
    echo "  -> Erstelle ${domain_name}.md..."
    dump_folder_to_ki_md "$dir" "$EXPORT_DIR/${domain_name}.md" "Domain: $domain_name" "$domain_name" "true" "true"
  fi
done

echo "→ 4. Erstelle _full.md (Gesamtes Repository)..."
dump_folder_to_ki_md "$REPO_ROOT" "$EXPORT_DIR/_full.md" "Full Repository" "root" "false" "true"

echo "→ 5. Erstelle all-exports.zip..."
(cd "$EXPORT_DIR" && zip -q -9 all-exports.zip ./*.md)

echo "✅ Alle wissenschaftlich fundierten KI-Markdown-Exporte erfolgreich erstellt."
