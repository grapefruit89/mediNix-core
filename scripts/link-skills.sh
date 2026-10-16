#!/usr/bin/env bash
# Projekt-Skills fuer den Agenten sichtbar machen - idempotent, lokal.
#
# Regel: Projekt-Skills LEBEN im Repo unter docs/agents/<kategorie>/<skill>/
# (SKILL.md ist die Wahrheit, versioniert). Der Agent findet sie nur, wenn in
# ~/.config/opencode/skills/<name> ein SYMLINK auf genau diesen Ordner liegt.
# Die Symlinks sind maschinenlokal -> nicht versionierbar, deshalb dieses
# Skript (nach jedem frischen Clone einmal ausfuehren).
#
# Aufruf:  bash scripts/link-skills.sh [--dry-run]
# Ziel aendern: OPENCODE_SKILLS_DIR=/pfad bash scripts/link-skills.sh
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TARGET_DIR="${OPENCODE_SKILLS_DIR:-$HOME/.config/opencode/skills}"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

[ -d "$TARGET_DIR" ] || { echo "FEHLER: Zielordner fehlt: $TARGET_DIR" >&2; exit 1; }

linked=0; unchanged=0; pruned=0; conflicts=0

# 1) Verwaiste Symlinks aufraeumen (zeigen ins Repo, Skill existiert nicht mehr).
for link in "$TARGET_DIR"/*; do
  [ -L "$link" ] || continue
  target="$(readlink -f -- "$link" 2>/dev/null || true)"
  case "$target" in
    "$REPO_ROOT"/docs/agents/*)
      if [ ! -f "$target/SKILL.md" ]; then
        echo "  raus (verwaist): $(basename -- "$link")"
        [ "$DRY_RUN" -eq 1 ] || rm -- "$link"
        pruned=$((pruned + 1))
      fi
      ;;
  esac
done

# 2) Alle Projekt-Skills verlinken (Reihenfolge stabil: sortiert).
while IFS= read -r skill; do
  dir="$(dirname -- "$skill")"
  name="$(basename -- "$dir")"
  link="$TARGET_DIR/$name"
  if [ -L "$link" ]; then
    if [ "$(readlink -f -- "$link")" = "$dir" ]; then
      unchanged=$((unchanged + 1))
      continue
    fi
    echo "  aktualisiert: $name"
    [ "$DRY_RUN" -eq 1 ] || ln -sfn -- "$dir" "$link"
    linked=$((linked + 1))
    continue
  fi
  if [ -e "$link" ]; then
    echo "  KONFLIKT (echter Ordner, NICHT ueberschrieben): $name"
    conflicts=$((conflicts + 1))
    continue
  fi
  echo "  verlinkt: $name"
  [ "$DRY_RUN" -eq 1 ] || ln -s -- "$dir" "$link"
  linked=$((linked + 1))
done < <(find "$REPO_ROOT/docs/agents" -mindepth 3 -maxdepth 3 -name SKILL.md | sort)

echo "verlinkt: $linked  unveraendert: $unchanged  aufgeraeumt: $pruned  Konflikte: $conflicts"
[ "$DRY_RUN" -eq 1 ] && echo "(dry-run: nichts geschrieben)"
[ "$conflicts" -eq 0 ] || exit 2
