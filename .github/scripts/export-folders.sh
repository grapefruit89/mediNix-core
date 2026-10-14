#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
EXPORT_DIR="${1:-${EXPORT_DIR:-/tmp/exports}}"
mkdir -p "$EXPORT_DIR"

EXCLUDES=(
  --exclude-pattern "*.png"
  --exclude-pattern "*.jpg"
  --exclude-pattern "*.jpeg"
  --exclude-pattern "*.svg"
  --exclude-pattern "*.ico"
  --exclude-pattern "*.pdf"
  --exclude-pattern "*.drv"
  --exclude-pattern "*.log"
  --exclude-pattern "*.zip"
  --exclude-pattern "$EXPORT_DIR/*"
  --exclude-pattern "$REPO_ROOT/.git/*"
  --exclude-pattern "$REPO_ROOT/.github/*"
)

# 1. Root-Dateien (flake.nix, README.md, default.nix etc.) in eine eigene Datei
echo "→ Exporting root files..."
gitingest "$REPO_ROOT" \
  --output "$EXPORT_DIR/_root.txt" \
  --exclude-pattern "$REPO_ROOT/*/*" \
  "${EXCLUDES[@]}" >/dev/null

# 2. Dynamische mediNix-Domänen (50-core bis 59-guardrails) + lib + docs
FOLDERS=()
for dir in "$REPO_ROOT"/5[0-9]-*; do
  if [[ -d "$dir" ]]; then
    FOLDERS+=("$(basename "$dir")")
  fi
done
for special in "lib" "docs"; do
  if [[ -d "$REPO_ROOT/$special" ]]; then
    FOLDERS+=("$special")
  fi
done

for folder_name in "${FOLDERS[@]}"; do
  folder_path="$REPO_ROOT/$folder_name"
  out_file="$EXPORT_DIR/${folder_name}.txt"
  echo "→ Exporting $folder_name → ${folder_name}.txt..."
  gitingest "$folder_path" \
    --output "$out_file" \
    "${EXCLUDES[@]}" >/dev/null
done

# 3. Vollständiger Gesamt-Dump des Repositories
echo "→ Exporting full repository digest..."
gitingest "$REPO_ROOT" \
  --output "$EXPORT_DIR/_full.txt" \
  "${EXCLUDES[@]}" >/dev/null

# 4. ZIP-Bundle für komfortablen 1-Klick-Download
echo "→ Creating all-exports.zip..."
(
  cd "$EXPORT_DIR"
  rm -f all-exports.zip
  zip -q -9 all-exports.zip ./*.txt
)

echo "✅ All exports successfully generated in $EXPORT_DIR"
